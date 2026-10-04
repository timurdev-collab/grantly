import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";


async function listUserObjects(
  adminClient: ReturnType<typeof createClient>,
  bucket: string,
  prefix: string,
): Promise<string[]> {
  const paths: string[] = [];
  const pageSize = 100;

  async function walk(path: string) {
    let offset = 0;

    while (true) {
      const { data, error } = await adminClient.storage
        .from(bucket)
        .list(path, {
          limit: pageSize,
          offset,
          sortBy: { column: "name", order: "asc" },
        });

      if (error) throw error;
      if (!data?.length) break;

      for (const item of data) {
        const childPath = path ? `${path}/${item.name}` : item.name;

        if (item.id) {
          paths.push(childPath);
        } else {
          await walk(childPath);
        }
      }

      if (data.length < pageSize) break;
      offset += pageSize;
    }
  }

  await walk(prefix);
  return paths;
}

async function deleteUserStorage(
  adminClient: ReturnType<typeof createClient>,
  userId: string,
) {
  const buckets = [
    "advisor-media",
    "application-documents",
    "avatars",
    "social-media",
    "university-case-documents",
  ];

  for (const bucket of buckets) {
    const paths = await listUserObjects(adminClient, bucket, userId);

    for (let index = 0; index < paths.length; index += 100) {
      const { error } = await adminClient.storage
        .from(bucket)
        .remove(paths.slice(index, index + 100));

      if (error) throw error;
    }
  }
}

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: { "Content-Type": "application/json" },
    });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const authorization = req.headers.get("Authorization");

  if (!supabaseUrl || !anonKey || !serviceRoleKey || !authorization) {
    return new Response(JSON.stringify({ error: "Unauthorized" }), {
      status: 401,
      headers: { "Content-Type": "application/json" },
    });
  }

  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authorization } },
    auth: { persistSession: false },
  });

  const { data: { user }, error: userError } = await userClient.auth.getUser();

  if (userError || !user) {
    return new Response(JSON.stringify({ error: "Invalid session" }), {
      status: 401,
      headers: { "Content-Type": "application/json" },
    });
  }

  const adminClient = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false },
  });

  const { data: memberships, error: membershipsError } = await adminClient
    .from("conversation_members")
    .select("conversation_id")
    .eq("user_id", user.id);

  if (membershipsError) {
    console.error("delete-account conversation lookup failed", membershipsError);
    return new Response(JSON.stringify({ error: "Unable to prepare account deletion" }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }

  const conversationIds = [
    ...new Set((memberships ?? []).map((row) => row.conversation_id)),
  ];

  try {
    await deleteUserStorage(adminClient, user.id);
  } catch (storageError) {
    console.error("delete-account storage cleanup failed", storageError);
    return new Response(JSON.stringify({ error: "Unable to delete account data" }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }

  const { error: deleteError } = await adminClient.auth.admin.deleteUser(user.id);

  if (deleteError) {
    console.error("delete-account failed", deleteError);
    return new Response(JSON.stringify({ error: "Unable to delete account" }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }

  for (const conversationId of conversationIds) {
    const { count, error: countError } = await adminClient
      .from("conversation_members")
      .select("conversation_id", { count: "exact", head: true })
      .eq("conversation_id", conversationId);

    if (countError) {
      console.error("delete-account conversation cleanup count failed", countError);
      continue;
    }

    if ((count ?? 0) < 2) {
      const { error: cleanupError } = await adminClient
        .from("conversations")
        .delete()
        .eq("id", conversationId);

      if (cleanupError) {
        console.error("delete-account conversation cleanup failed", cleanupError);
      }
    }
  }

  return new Response(JSON.stringify({ deleted: true }), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
});

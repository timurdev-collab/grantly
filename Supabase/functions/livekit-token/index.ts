import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";
import { AccessToken } from "npm:livekit-server-sdk@2";

type RequestBody = {
  call_id?: string;
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "content-type": "application/json",
      "cache-control": "no-store",
    },
  });
}

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") {
    return json({ error: "Method not allowed" }, 405);
  }

  const authorization = req.headers.get("authorization");
  if (!authorization?.toLowerCase().startsWith("bearer ")) {
    return json({ error: "Authentication required" }, 401);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const livekitUrl = Deno.env.get("LIVEKIT_URL");
  const livekitApiKey = Deno.env.get("LIVEKIT_API_KEY");
  const livekitApiSecret = Deno.env.get("LIVEKIT_API_SECRET");

  if (!supabaseUrl || !supabaseAnonKey) {
    return json({ error: "Supabase environment is unavailable" }, 500);
  }

  if (!livekitUrl || !livekitApiKey || !livekitApiSecret) {
    return json(
      {
        error:
          "Video calling is not configured yet. Set LIVEKIT_URL, LIVEKIT_API_KEY and LIVEKIT_API_SECRET.",
      },
      503,
    );
  }

  let body: RequestBody;
  try {
    body = await req.json();
  } catch {
    return json({ error: "Invalid JSON body" }, 400);
  }

  if (!body.call_id) {
    return json({ error: "call_id is required" }, 400);
  }

  const supabase = createClient(
    supabaseUrl,
    supabaseAnonKey,
    {
      global: {
        headers: {
          Authorization: authorization,
        },
      },
    },
  );

  const {
    data: { user },
    error: userError,
  } = await supabase.auth.getUser();

  if (userError || !user) {
    return json({ error: "Invalid session" }, 401);
  }

  const { data: call, error: callError } = await supabase
    .from("advisor_call_sessions")
    .select("id,room_name,assignment_id,status")
    .eq("id", body.call_id)
    .single();

  if (callError || !call) {
    return json({ error: "Call session not found or access denied" }, 404);
  }

  const token = new AccessToken(
    livekitApiKey,
    livekitApiSecret,
    {
      identity: user.id,
      name:
        typeof user.user_metadata?.full_name === "string"
          ? user.user_metadata.full_name
          : user.email ?? "EduT user",
      ttl: "2h",
    },
  );

  token.addGrant({
    roomJoin: true,
    room: call.room_name,
    canPublish: true,
    canSubscribe: true,
    canPublishData: true,
  });

  return json({
    url: livekitUrl,
    token: await token.toJwt(),
    room_name: call.room_name,
  });
});

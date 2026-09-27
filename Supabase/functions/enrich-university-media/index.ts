import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

type Institution = {
  id: string;
  name: string;
  website_url: string | null;
  logo_url: string | null;
  campus_image_url: string | null;
  media_status: string;
};

function absoluteUrl(base: string, candidate: string | null) {
  if (!candidate) return null;

  try {
    return new URL(candidate, base).toString();
  } catch {
    return null;
  }
}

function firstMatch(html: string, patterns: RegExp[]) {
  for (const pattern of patterns) {
    const match = html.match(pattern);
    if (match?.[1]) return match[1].trim();
  }
  return null;
}

async function enrich(row: Institution) {
  if (!row.website_url) {
    return {
      id: row.id,
      logo_url: row.logo_url,
      campus_image_url: row.campus_image_url,
      media_status: "failed",
      media_source_url: null,
      media_error: "Missing website URL"
    };
  }

  try {
    const response = await fetch(row.website_url, {
      redirect: "follow",
      headers: {
        "User-Agent": "Mozilla/5.0 GrantlyInstitutionMedia/1.0"
      },
      signal: AbortSignal.timeout(9000)
    });

    if (!response.ok) {
      throw new Error("HTTP " + response.status);
    }

    const finalUrl = response.url || row.website_url;
    const html = (await response.text()).slice(0, 400000);

    const logoCandidate = firstMatch(html, [
      /<link[^>]+rel=["'][^"']*apple-touch-icon[^"']*["'][^>]+href=["']([^"']+)["']/i,
      /<link[^>]+href=["']([^"']+)["'][^>]+rel=["'][^"']*apple-touch-icon[^"']*["']/i,
      /<link[^>]+rel=["'][^"']*(?:shortcut\s+icon|icon)[^"']*["'][^>]+href=["']([^"']+)["']/i,
      /<link[^>]+href=["']([^"']+)["'][^>]+rel=["'][^"']*(?:shortcut\s+icon|icon)[^"']*["']/i
    ]);

    const imageCandidate = firstMatch(html, [
      /<meta[^>]+property=["']og:image["'][^>]+content=["']([^"']+)["']/i,
      /<meta[^>]+content=["']([^"']+)["'][^>]+property=["']og:image["']/i,
      /<meta[^>]+name=["']twitter:image["'][^>]+content=["']([^"']+)["']/i,
      /<meta[^>]+content=["']([^"']+)["'][^>]+name=["']twitter:image["']/i
    ]);

    const logoUrl = row.logo_url ?? absoluteUrl(finalUrl, logoCandidate);
    const campusImageUrl =
      row.campus_image_url ?? absoluteUrl(finalUrl, imageCandidate);

    const found = [logoUrl, campusImageUrl].filter(Boolean).length;

    return {
      id: row.id,
      logo_url: logoUrl,
      campus_image_url: campusImageUrl,
      media_status: found === 2 ? "ready" : found === 1 ? "partial" : "failed",
      media_source_url: finalUrl,
      media_error: found ? null : "No suitable media metadata found"
    };
  } catch (error) {
    return {
      id: row.id,
      logo_url: row.logo_url,
      campus_image_url: row.campus_image_url,
      media_status: row.logo_url || row.campus_image_url ? "partial" : "failed",
      media_source_url: row.website_url,
      media_error: error instanceof Error ? error.message : "Media fetch failed"
    };
  }
}

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: { "Content-Type": "application/json" }
    });
  }

  const url = Deno.env.get("SUPABASE_URL")!;
  const anon = Deno.env.get("SUPABASE_ANON_KEY")!;
  const serviceRole = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const authorization = req.headers.get("Authorization");

  if (!authorization) {
    return new Response(JSON.stringify({ error: "Unauthorized" }), {
      status: 401,
      headers: { "Content-Type": "application/json" }
    });
  }

  const userClient = createClient(url, anon, {
    global: { headers: { Authorization: authorization } },
    auth: { persistSession: false }
  });

  const { data: { user }, error: userError } =
    await userClient.auth.getUser();

  if (userError || !user) {
    return new Response(JSON.stringify({ error: "Invalid session" }), {
      status: 401,
      headers: { "Content-Type": "application/json" }
    });
  }

  const admin = createClient(url, serviceRole, {
    auth: { persistSession: false }
  });

  const { data: profile } = await admin
    .from("student_profiles")
    .select("role")
    .eq("id", user.id)
    .single();

  if (profile?.role !== "admin") {
    return new Response(JSON.stringify({ error: "Admin access required" }), {
      status: 403,
      headers: { "Content-Type": "application/json" }
    });
  }

  let body: { limit?: number } = {};
  try {
    body = await req.json();
  } catch {}

  const limit = Math.min(Math.max(body.limit ?? 10, 1), 20);

  const { data: rows, error } = await admin
    .from("universities")
    .select("id,name,website_url,logo_url,campus_image_url,media_status")
    .not("website_url", "is", null)
    .or("logo_url.is.null,campus_image_url.is.null,media_status.eq.failed")
    .order("media_checked_at", { ascending: true, nullsFirst: true })
    .limit(limit);

  if (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { "Content-Type": "application/json" }
    });
  }

  const results = [];

  for (let index = 0; index < (rows ?? []).length; index += 4) {
    const chunk = (rows ?? []).slice(index, index + 4);
    results.push(...await Promise.all(chunk.map(enrich)));
  }

  for (const result of results) {
    await admin
      .from("universities")
      .update({
        logo_url: result.logo_url,
        campus_image_url: result.campus_image_url,
        media_status: result.media_status,
        media_checked_at: new Date().toISOString(),
        media_source_url: result.media_source_url,
        media_error: result.media_error
      })
      .eq("id", result.id);
  }

  return new Response(JSON.stringify({
    enriched: results.length,
    ready: results.filter((x) => x.media_status === "ready").length,
    partial: results.filter((x) => x.media_status === "partial").length,
    failed: results.filter((x) => x.media_status === "failed").length
  }), {
    headers: { "Content-Type": "application/json" }
  });
});

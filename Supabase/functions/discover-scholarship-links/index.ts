import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

type Source = {
  id: string;
  host: string;
  display_name: string;
  next_discovery_at: string | null;
  discovery_failure_count: number;
};

function normalizedHost(value: string) {
  return value.toLowerCase().replace(/^www\./, "");
}
function canonicalUrl(value: string) {
  try {
    const url = new URL(value);
    url.hash = "";

    const removable = [
      "utm_source","utm_medium","utm_campaign","utm_term","utm_content",
      "fbclid","gclid","mc_cid","mc_eid"
    ];

    for (const key of removable) {
      url.searchParams.delete(key);
    }

    url.hostname = normalizedHost(url.hostname);
    url.pathname = url.pathname.replace(/\/+$/, "") || "/";

    return url.toString();
  } catch {
    return value.trim().toLowerCase();
  }
}

function decodeHtml(value: string) {
  return value
    .replace(/&amp;/g, "&")
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&nbsp;/g, " ");
}

function stripTags(value: string) {
  return decodeHtml(value.replace(/<[^>]+>/g, " "))
    .replace(/\s+/g, " ")
    .trim();
}

function scoreCandidate(url: URL, text: string) {
  const haystack = `${url.pathname} ${url.search} ${text}`.toLowerCase();

  let score = 0;

  if (/scholarship/.test(haystack)) score += 45;
  if (/fellowship/.test(haystack)) score += 35;
  if (/bursar/.test(haystack)) score += 30;
  if (/financial[-_ ]?aid/.test(haystack)) score += 30;
  if (/funding/.test(haystack)) score += 25;
  if (/award/.test(haystack)) score += 20;
  if (/grant/.test(haystack)) score += 15;
  if (/international/.test(haystack)) score += 8;
  if (/undergraduate|graduate|master|doctoral|phd/.test(haystack)) score += 8;
  if (/apply|admission/.test(haystack)) score += 5;

  if (/news|event|blog|press|privacy|cookie|login|signin|facebook|instagram|linkedin|youtube/.test(haystack)) {
    score -= 25;
  }

  if (url.hash) score -= 5;

  return Math.max(0, Math.min(100, score));
}

function extractLinks(html: string, baseUrl: string, sourceHost: string) {
  const results = new Map<string, { title: string; score: number }>();
  const anchorRegex = /<a\b[^>]*?href\s*=\s*["']([^"'#]+)["'][^>]*>([\s\S]*?)<\/a>/gi;

  for (const match of html.matchAll(anchorRegex)) {
    const rawHref = decodeHtml(match[1]).trim();
    if (!rawHref || /^(mailto:|tel:|javascript:)/i.test(rawHref)) continue;

    let url: URL;
    try {
      url = new URL(rawHref, baseUrl);
    } catch {
      continue;
    }

    if (!/^https?:$/.test(url.protocol)) continue;
    if (normalizedHost(url.hostname) !== normalizedHost(sourceHost)) continue;

    url.hash = "";
    const title = stripTags(match[2]).slice(0, 240);
    const score = scoreCandidate(url, title);

    if (score < 25) continue;

    const canonical = url.toString();
    const existing = results.get(canonical);

    if (!existing || score > existing.score) {
      results.set(canonical, { title, score });
    }
  }

  return [...results.entries()]
    .map(([candidateUrl, meta]) => ({
      candidateUrl,
      title: meta.title || null,
      score: meta.score
    }))
    .sort((a, b) => b.score - a.score)
    .slice(0, 40);
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
  const discoveryToken = req.headers.get("x-grantly-discovery-token");

  const admin = createClient(url, serviceRole, {
    auth: { persistSession: false }
  });

  let authorized = false;

  if (discoveryToken) {
    const { data: scheduler } = await admin
      .from("source_discovery_scheduler_config")
      .select("cron_token,enabled")
      .eq("id", true)
      .maybeSingle();

    authorized = Boolean(
      scheduler?.enabled &&
      scheduler.cron_token &&
      scheduler.cron_token === discoveryToken
    );
  }

  if (!authorized && authorization) {
    const userClient = createClient(url, anon, {
      global: { headers: { Authorization: authorization } },
      auth: { persistSession: false }
    });

    const { data: { user }, error: userError } =
      await userClient.auth.getUser();

    if (!userError && user) {
      const { data: profile } = await admin
        .from("student_profiles")
        .select("role")
        .eq("id", user.id)
        .single();

      authorized = profile?.role === "admin";
    }
  }

  if (!authorized) {
    return new Response(JSON.stringify({ error: "Unauthorized" }), {
      status: 401,
      headers: { "Content-Type": "application/json" }
    });
  }

  let body: { limit?: number; force?: boolean } = {};
  try {
    body = await req.json();
  } catch {}

  const limit = Math.min(Math.max(body.limit ?? 5, 1), 10);
  const now = new Date().toISOString();

  let query = admin
    .from("scholarship_source_registry")
    .select("id,host,display_name,next_discovery_at,discovery_failure_count")
    .eq("is_active", true)
    .order("next_discovery_at", { ascending: true, nullsFirst: true })
    .limit(limit);

  if (!body.force) {
    query = query.or(
      `next_discovery_at.is.null,next_discovery_at.lte.${now}`
    );
  }

  const { data: sources, error: sourceError } = await query;

  if (sourceError) {
    return new Response(JSON.stringify({ error: sourceError.message }), {
      status: 500,
      headers: { "Content-Type": "application/json" }
    });
  }

  let discovered = 0;
  let checked = 0;
  let failed = 0;
  let duplicateSkipped = 0;

  for (const source of (sources ?? []) as Source[]) {
    const { data: scholarships } = await admin
      .from("scholarships")
      .select("id,official_url,link_status")
      .eq("source_registry_id", source.id)
      .eq("status", "published")
      .in("link_status", ["exact", "reachable", "unchecked"])
      .limit(3);

    const seedUrls = [...new Set(
      (scholarships ?? [])
        .map((row) => row.official_url)
        .filter(Boolean)
    )];

    const existingByCanonical = new Map<string, string>();
    for (const scholarship of scholarships ?? []) {
      if (scholarship.official_url) {
        existingByCanonical.set(
          canonicalUrl(scholarship.official_url),
          scholarship.id
        );
      }
    }

    if (!seedUrls.length) {
      await admin
        .from("scholarship_source_registry")
        .update({
          last_discovery_at: now,
          next_discovery_at: new Date(Date.now() + 30 * 86400000).toISOString()
        })
        .eq("id", source.id);
      continue;
    }

    let sourceFound = 0;
    let sourceSucceeded = false;

    for (const seedUrl of seedUrls) {
      try {
        const response = await fetch(seedUrl, {
          redirect: "follow",
          headers: {
            "User-Agent": "Mozilla/5.0 GrantlySourceDiscovery/1.0"
          },
          signal: AbortSignal.timeout(12000)
        });

        if (!response.ok) continue;

        const finalUrl = response.url || seedUrl;
        const html = (await response.text()).slice(0, 500000);
        const candidates = extractLinks(html, finalUrl, source.host);

        for (const candidate of candidates) {
          if (canonicalUrl(candidate.candidateUrl) === canonicalUrl(finalUrl)) {
            continue;
          }

          const duplicateId = existingByCanonical.get(
            canonicalUrl(candidate.candidateUrl)
          );

          const payload: Record<string, unknown> = {
            source_registry_id: source.id,
            candidate_url: candidate.candidateUrl,
            candidate_title: candidate.title,
            discovered_from_url: finalUrl,
            relevance_score: candidate.score,
            last_seen_at: now
          };

          if (duplicateId) {
            payload.status = "ignored";
            payload.duplicate_of_scholarship_id = duplicateId;
            payload.review_note = "Already present in scholarship catalog";
            payload.reviewed_at = now;
          }

          const { error } = await admin
            .from("scholarship_source_candidates")
            .upsert(payload, {
              onConflict: "source_registry_id,candidate_url",
              ignoreDuplicates: false
            });

          if (!error && duplicateId) {
            duplicateSkipped += 1;
          } else if (!error) {
            sourceFound += 1;
          }
        }

        sourceSucceeded = true;
      } catch {
        // Try another seed URL before treating the source as failed.
      }
    }

    checked += 1;
    discovered += sourceFound;

    if (sourceSucceeded) {
      await admin
        .from("scholarship_source_registry")
        .update({
          last_discovery_at: now,
          discovery_failure_count: 0,
          next_discovery_at: new Date(
            Date.now() + (sourceFound > 0 ? 7 : 21) * 86400000
          ).toISOString()
        })
        .eq("id", source.id);
    } else {
      failed += 1;
      const failureCount = (source.discovery_failure_count ?? 0) + 1;

      await admin
        .from("scholarship_source_registry")
        .update({
          last_discovery_at: now,
          discovery_failure_count: failureCount,
          next_discovery_at: new Date(
            Date.now() + Math.min(24 * failureCount, 168) * 3600000
          ).toISOString()
        })
        .eq("id", source.id);
    }
  }

  return new Response(JSON.stringify({
    checked_sources: checked,
    discovered_candidates: discovered,
    failed_sources: failed,
    duplicate_candidates_skipped: duplicateSkipped
  }), {
    headers: { "Content-Type": "application/json" }
  });
});

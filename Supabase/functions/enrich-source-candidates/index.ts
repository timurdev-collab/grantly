import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

function normalizeText(html: string) {
  return html
    .replace(/<script[\s\S]*?<\/script>/gi, " ")
    .replace(/<style[\s\S]*?<\/style>/gi, " ")
    .replace(/<noscript[\s\S]*?<\/noscript>/gi, " ")
    .replace(/<[^>]+>/g, " ")
    .replace(/&nbsp;/g, " ")
    .replace(/&amp;/g, "&")
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'")
    .replace(/\s+/g, " ")
    .trim();
}

function extractTag(html: string, pattern: RegExp) {
  const match = pattern.exec(html);
  return match?.[1]?.replace(/\s+/g, " ").trim() || null;
}

function deadlineCandidate(text: string) {
  const months: Record<string, number> = {
    january:1,february:2,march:3,april:4,may:5,june:6,
    july:7,august:8,september:9,october:10,november:11,december:12
  };

  const clean = text.replace(/\s+/g, " ");
  const patterns = [
    /(?:deadline|apply by|application deadline|closing date|applications close|closes)[^.!?]{0,140}?(\d{1,2})\s+(January|February|March|April|May|June|July|August|September|October|November|December)\s+(20\d{2})/gi,
    /(?:deadline|apply by|application deadline|closing date|applications close|closes)[^.!?]{0,140}?(January|February|March|April|May|June|July|August|September|October|November|December)\s+(\d{1,2})(?:st|nd|rd|th)?[,]?\s+(20\d{2})/gi,
    /(?:deadline|apply by|application deadline|closing date|applications close|closes)[^.!?]{0,140}?(20\d{2})[-/.](\d{1,2})[-/.](\d{1,2})/gi
  ];

  const candidates: Date[] = [];

  for (const pattern of patterns) {
    for (const match of clean.matchAll(pattern)) {
      let date: Date | null = null;

      if (/^20\d{2}$/.test(match[1])) {
        date = new Date(Date.UTC(
          Number(match[1]),
          Number(match[2]) - 1,
          Number(match[3])
        ));
      } else {
        const day = /^\d/.test(match[1]) ? Number(match[1]) : Number(match[2]);
        const monthName = /^\d/.test(match[1]) ? match[2] : match[1];
        const year = Number(match[3]);
        date = new Date(Date.UTC(year, months[monthName.toLowerCase()] - 1, day));
      }

      if (date && !Number.isNaN(date.getTime())) candidates.push(date);
    }
  }

  if (!candidates.length) return { date: null, confidence: null };

  const now = Date.now() - 86400000;
  const future = candidates
    .filter((d) => d.getTime() >= now)
    .sort((a, b) => a.getTime() - b.getTime());

  const selected = future[0] ?? candidates.sort(
    (a, b) => b.getTime() - a.getTime()
  )[0];

  return {
    date: selected.toISOString().slice(0, 10),
    confidence: future.length ? 92 : 70
  };
}

function cycleCandidate(text: string) {
  const focusedPatterns = [
    /(?:applications?|admissions?|scholarships?|intake|academic year|entry)[^.!?]{0,100}?(20\d{2})\s*[\/-]\s*(?:20)?(\d{2})/gi,
    /(?:applications?|admissions?|scholarships?|intake|academic year|entry)[^.!?]{0,100}?\b(20\d{2})\b/gi
  ];

  for (const pattern of focusedPatterns) {
    const match = pattern.exec(text);
    if (!match) continue;

    if (match[2]) {
      const second = match[2].length === 2
        ? match[1].slice(0, 2) + match[2]
        : match[2];
      return { value: `${match[1]}/${second}`, confidence: 88 };
    }

    return { value: match[1], confidence: 78 };
  }

  return { value: null, confidence: null };
}

function excerpt(text: string, regex: RegExp) {
  const match = regex.exec(text);
  if (!match || match.index == null) return null;
  const start = Math.max(0, match.index - 100);
  const end = Math.min(text.length, match.index + 350);
  return text.slice(start, end).trim();
}

async function sha256(value: string) {
  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(value)
  );

  return [...new Uint8Array(digest)]
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
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
  const token = req.headers.get("x-grantly-enrichment-token");

  const admin = createClient(url, serviceRole, {
    auth: { persistSession: false }
  });

  let authorized = false;

  if (token) {
    const { data: scheduler } = await admin
      .from("source_candidate_enrichment_config")
      .select("cron_token,enabled")
      .eq("id", true)
      .maybeSingle();

    authorized = Boolean(
      scheduler?.enabled &&
      scheduler.cron_token &&
      scheduler.cron_token === token
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

  let body: { limit?: number } = {};
  try {
    body = await req.json();
  } catch {}

  const limit = Math.min(Math.max(body.limit ?? 10, 1), 20);

  const { data: candidates, error } = await admin
    .from("scholarship_source_candidates")
    .select("id,source_registry_id,candidate_url")
    .eq("status", "accepted")
    .order("last_seen_at", { ascending: false })
    .limit(limit);

  if (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { "Content-Type": "application/json" }
    });
  }

  let ready = 0;
  let failed = 0;

  for (const candidate of candidates ?? []) {
    const { data: existing } = await admin
      .from("scholarship_source_candidate_profiles")
      .select("id,extraction_status,checked_at")
      .eq("candidate_id", candidate.id)
      .maybeSingle();

    if (existing?.extraction_status === "ready") continue;

    try {
      const response = await fetch(candidate.candidate_url, {
        redirect: "follow",
        headers: {
          "User-Agent": "Mozilla/5.0 GrantlyCandidateEnrichment/1.0"
        },
        signal: AbortSignal.timeout(12000)
      });

      if (!response.ok) {
        throw new Error(`HTTP ${response.status}`);
      }

      const html = (await response.text()).slice(0, 600000);
      const plain = normalizeText(html);
      const deadline = deadlineCandidate(plain);
      const cycle = cycleCandidate(plain);
      const pageTitle = extractTag(
        html,
        /<title[^>]*>([\s\S]*?)<\/title>/i
      );
      const metaDescription = extractTag(
        html,
        /<meta[^>]+name=["']description["'][^>]+content=["']([^"']+)["']/i
      ) ?? extractTag(
        html,
        /<meta[^>]+content=["']([^"']+)["'][^>]+name=["']description["']/i
      );

      const fingerprint = await sha256(plain.slice(0, 250000));
      const now = new Date().toISOString();

      await admin
        .from("scholarship_source_candidate_profiles")
        .upsert({
          candidate_id: candidate.id,
          source_registry_id: candidate.source_registry_id,
          page_title: pageTitle,
          meta_description: metaDescription,
          detected_deadline: deadline.date,
          deadline_confidence: deadline.confidence,
          detected_cycle: cycle.value,
          cycle_confidence: cycle.confidence,
          funding_excerpt: excerpt(
            plain,
            /scholarship|funding|financial aid|bursary|fellowship/i
          ),
          application_excerpt: excerpt(
            plain,
            /deadline|apply by|application deadline|closing date|applications close/i
          ),
          content_fingerprint: fingerprint,
          extraction_status: "ready",
          extraction_error: null,
          checked_at: now,
          updated_at: now
        }, {
          onConflict: "candidate_id"
        });

      ready += 1;
    } catch (err) {
      const message = err instanceof Error
        ? err.message.slice(0, 500)
        : "Unknown extraction error";

      await admin
        .from("scholarship_source_candidate_profiles")
        .upsert({
          candidate_id: candidate.id,
          source_registry_id: candidate.source_registry_id,
          extraction_status: "failed",
          extraction_error: message,
          checked_at: new Date().toISOString(),
          updated_at: new Date().toISOString()
        }, {
          onConflict: "candidate_id"
        });

      failed += 1;
    }
  }

  return new Response(JSON.stringify({
    checked: (candidates ?? []).length,
    ready,
    failed
  }), {
    headers: { "Content-Type": "application/json" }
  });
});

import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

type Scholarship = {
  id: string;
  title: string;
  provider: string;
  official_url: string;
  verification_status: string;
  deadline: string | null;
  application_cycle: string | null;
  source_fingerprint: string | null;
  source_changed_at: string | null;
};

function tokens(value: string) {
  const stop = new Set([
    "university","college","institute","school","scholarship","scholarships",
    "award","awards","international","excellence","student","students",
    "graduate","undergraduate","masters","master","phd","program","programme",
    "of","the","and","for","in","at","global"
  ]);

  return value.toLowerCase()
    .replace(/[^a-z0-9 ]/g, " ")
    .split(/\s+/)
    .filter((word) => word.length >= 4 && !stop.has(word));
}

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
    .trim()
    .toLowerCase();
}

async function sha256(value: string) {
  const data = new TextEncoder().encode(value);
  const digest = await crypto.subtle.digest("SHA-256", data);
  return [...new Uint8Array(digest)]
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

function deadlineCandidate(text: string) {
  const months: Record<string, number> = {
    january:1,february:2,march:3,april:4,may:5,june:6,
    july:7,august:8,september:9,october:10,november:11,december:12
  };

  const clean = text.replace(/\s+/g, " ");
  const patterns = [
    /(?:deadline|apply by|application deadline|closing date|applications close|closes)[^.!?]{0,120}?(\d{1,2})\s+(January|February|March|April|May|June|July|August|September|October|November|December)\s+(20\d{2})/gi,
    /(?:deadline|apply by|application deadline|closing date|applications close|closes)[^.!?]{0,120}?(January|February|March|April|May|June|July|August|September|October|November|December)\s+(\d{1,2})(?:st|nd|rd|th)?[,]?\s+(20\d{2})/gi,
    /(?:deadline|apply by|application deadline|closing date|applications close|closes)[^.!?]{0,120}?(20\d{2})[-/.](\d{1,2})[-/.](\d{1,2})/gi
  ];

  const candidates: Date[] = [];

  for (const pattern of patterns) {
    for (const match of clean.matchAll(pattern)) {
      let date: Date | null = null;

      if (/^20\d{2}$/.test(match[1])) {
        const year = Number(match[1]);
        const month = Number(match[2]);
        const day = Number(match[3]);
        date = new Date(Date.UTC(year, month - 1, day));
      } else {
        let day: number;
        let monthName: string;
        let year: number;

        if (/^\d/.test(match[1])) {
          day = Number(match[1]);
          monthName = match[2];
          year = Number(match[3]);
        } else {
          monthName = match[1];
          day = Number(match[2]);
          year = Number(match[3]);
        }

        const month = months[monthName.toLowerCase()];
        date = new Date(Date.UTC(year, month - 1, day));
      }

      if (date && !Number.isNaN(date.getTime())) {
        candidates.push(date);
      }
    }
  }

  if (!candidates.length) {
    return { date: null, confidence: null };
  }

  const today = Date.now() - 86400000;
  const future = candidates
    .filter((date) => date.getTime() >= today)
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
    /(?:applications?|admissions?|scholarships?|intake|academic year|entry)[^.!?]{0,90}?(20\d{2})\s*[\/-]\s*(?:20)?(\d{2})/gi,
    /(?:applications?|admissions?|scholarships?|intake|academic year|entry)[^.!?]{0,90}?\b(20\d{2})\b/gi
  ];

  for (const pattern of focusedPatterns) {
    const match = pattern.exec(text);
    if (!match) continue;

    if (match[2]) {
      const second = match[2].length === 2
        ? match[1].slice(0, 2) + match[2]
        : match[2];
      return {
        value: `${match[1]}/${second}`,
        confidence: 88
      };
    }

    return { value: match[1], confidence: 78 };
  }

  return { value: null, confidence: null };
}

function cycleStatus(text: string) {
  if (
    /no longer (?:available|offered|running)|programme has ended|program has ended|scholarship has ended|discontinued|will not be offered/.test(text)
  ) {
    return "discontinued";
  }

  if (
    /applications? (?:are|is|have) (?:now )?closed|applications? closed|closed for applications|application period has closed|deadline has passed/.test(text)
  ) {
    return "closed";
  }

  if (
    /rolling basis|rolling admissions|applications? accepted throughout|apply at any time/.test(text)
  ) {
    return "rolling";
  }

  if (
    /applications? (?:will )?open (?:on|from)|applications? opening (?:on|in)|opens? on/.test(text)
  ) {
    return "upcoming";
  }

  if (
    /applications? (?:are|is) (?:now )?open|applications? now open|apply now|currently accepting applications/.test(text)
  ) {
    return "open";
  }

  return "unknown";
}

function deadlineVerificationStatus(
  currentDeadline: string | null,
  candidate: string | null
) {
  const today = new Date().toISOString().slice(0, 10);

  if (currentDeadline && currentDeadline < today) {
    return "expired";
  }

  if (!candidate) {
    return currentDeadline ? "unconfirmed" : "unconfirmed";
  }

  if (!currentDeadline) {
    return "candidate";
  }

  return currentDeadline === candidate ? "verified" : "changed";
}

function nextCheckAt(
  linkStatus: string,
  verificationStatus: string,
  status: string,
  candidateDeadline: string | null,
  currentDeadline: string | null
) {
  const now = Date.now();
  const deadline = candidateDeadline ?? currentDeadline;
  const deadlineMs = deadline
    ? new Date(`${deadline}T00:00:00Z`).getTime()
    : null;
  const daysUntil = deadlineMs == null
    ? null
    : Math.ceil((deadlineMs - now) / 86400000);

  let hours = 168;

  if (linkStatus === "dead" || verificationStatus === "needs_review") {
    hours = 24;
  } else if (status === "discontinued") {
    hours = 720;
  } else if (status === "closed") {
    hours = 72;
  } else if (status === "unknown") {
    hours = 72;
  }

  if (daysUntil != null) {
    if (daysUntil <= 7 && daysUntil >= -1) {
      hours = Math.min(hours, 12);
    } else if (daysUntil <= 30 && daysUntil >= -1) {
      hours = Math.min(hours, 24);
    } else if (daysUntil <= 90 && daysUntil >= -1) {
      hours = Math.min(hours, 72);
    }
  }

  return new Date(now + hours * 3600000).toISOString();
}

async function audit(row: Scholarship) {
  const checkedAt = new Date().toISOString();

  try {
    const original = new URL(row.official_url);
    const originalGeneric =
      original.pathname === "/" || original.pathname === "";

    const response = await fetch(row.official_url, {
      redirect: "follow",
      headers: {
        "User-Agent": "Mozilla/5.0 GrantlyCatalogAuditor/2.0"
      },
      signal: AbortSignal.timeout(12000)
    });

    const finalUrl = response.url || row.official_url;
    const final = new URL(finalUrl);
    const html = (await response.text()).slice(0, 400000);
    const plain = normalizeText(html);
    const fingerprint = await sha256(plain.slice(0, 250000));

    const allTokens = [...new Set([
      ...tokens(row.title),
      ...tokens(row.provider)
    ])];

    const hitCount = allTokens.filter(
      (token) => plain.includes(token)
    ).length;
    const tokenScore = allTokens.length
      ? hitCount / allTokens.length
      : 0;

    const fundingLanguage =
      /scholarship|fellowship|financial aid|funding|bursary|studentship/.test(
        plain
      );
    const finalGeneric =
      final.pathname === "/" || final.pathname === "";

    let linkStatus = "reachable";
    let verificationStatus = row.verification_status;

    if (
      response.status === 404 ||
      response.status === 410 ||
      response.status >= 500
    ) {
      linkStatus = "dead";
      verificationStatus = "needs_review";
    } else if (!response.ok) {
      verificationStatus = "needs_review";
    } else if (originalGeneric || finalGeneric) {
      linkStatus = "generic";
      verificationStatus = "needs_review";
    } else if (fundingLanguage && tokenScore >= 0.35) {
      linkStatus = "exact";
    } else {
      verificationStatus = "needs_review";
    }

    const deadline = deadlineCandidate(plain);
    const cycle = cycleCandidate(plain);
    const status = cycleStatus(plain);
    const deadlineState = deadlineVerificationStatus(
      row.deadline,
      deadline.date
    );

    const changed =
      Boolean(row.source_fingerprint) &&
      row.source_fingerprint !== fingerprint;

    return {
      id: row.id,
      link_status: linkStatus,
      verification_status: verificationStatus,
      final_url: finalUrl,
      source_http_status: response.status,
      source_fingerprint: fingerprint,
      source_changed_at: changed
        ? checkedAt
        : row.source_changed_at,
      last_checked_at: checkedAt,
      audit_error: null,
      deadline_candidate: deadline.date,
      deadline_confidence: deadline.confidence,
      deadline_verification_status: deadlineState,
      cycle_candidate: cycle.value,
      cycle_confidence: cycle.confidence,
      cycle_status: status,
      next_check_at: nextCheckAt(
        linkStatus,
        verificationStatus,
        status,
        deadline.date,
        row.deadline
      )
    };
  } catch (error) {
    const message = error instanceof Error
      ? error.message.slice(0, 500)
      : "Unknown audit error";

    return {
      id: row.id,
      link_status: "dead",
      verification_status: "needs_review",
      final_url: row.official_url,
      source_http_status: null,
      source_fingerprint: row.source_fingerprint,
      source_changed_at: row.source_changed_at,
      last_checked_at: checkedAt,
      audit_error: message,
      deadline_candidate: null,
      deadline_confidence: null,
      deadline_verification_status: row.deadline
        ? deadlineVerificationStatus(row.deadline, null)
        : "unconfirmed",
      cycle_candidate: null,
      cycle_confidence: null,
      cycle_status: "unknown",
      next_check_at: new Date(
        Date.now() + 24 * 3600000
      ).toISOString()
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
  const cronToken = req.headers.get("x-grantly-cron-token");

  const admin = createClient(url, serviceRole, {
    auth: { persistSession: false }
  });

  let authorized = false;

  if (cronToken) {
    const { data: scheduler } = await admin
      .from("scholarship_audit_scheduler_config")
      .select("cron_token,enabled")
      .eq("id", true)
      .maybeSingle();

    authorized = Boolean(
      scheduler?.enabled &&
      scheduler.cron_token &&
      scheduler.cron_token === cronToken
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

  const limit = Math.min(Math.max(body.limit ?? 20, 1), 30);
  const now = new Date().toISOString();

  let query = admin
    .from("scholarships")
    .select(
      "id,title,provider,official_url,verification_status,deadline," +
      "application_cycle,source_fingerprint,source_changed_at"
    )
    .eq("status", "published")
    .order("next_check_at", { ascending: true, nullsFirst: true })
    .limit(limit);

  if (!body.force) {
    query = query.or(
      `next_check_at.is.null,next_check_at.lte.${now}`
    );
  }

  const { data: rows, error } = await query;

  if (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { "Content-Type": "application/json" }
    });
  }

  const results = [];

  for (let index = 0; index < (rows ?? []).length; index += 5) {
    const chunk = (rows ?? []).slice(index, index + 5);
    results.push(...await Promise.all(chunk.map(audit)));
  }

  for (const result of results) {
    await admin
      .from("scholarships")
      .update({
        link_status: result.link_status,
        verification_status: result.verification_status,
        final_url: result.final_url,
        source_http_status: result.source_http_status,
        source_fingerprint: result.source_fingerprint,
        source_changed_at: result.source_changed_at,
        last_checked_at: result.last_checked_at,
        audit_error: result.audit_error,
        deadline_candidate: result.deadline_candidate,
        deadline_confidence: result.deadline_confidence,
        deadline_verification_status:
          result.deadline_verification_status,
        cycle_candidate: result.cycle_candidate,
        cycle_confidence: result.cycle_confidence,
        cycle_status: result.cycle_status,
        next_check_at: result.next_check_at
      })
      .eq("id", result.id);
  }

  return new Response(JSON.stringify({
    audited: results.length,
    exact: results.filter((x) => x.link_status === "exact").length,
    generic: results.filter((x) => x.link_status === "generic").length,
    dead: results.filter((x) => x.link_status === "dead").length,
    reachable: results.filter((x) => x.link_status === "reachable").length,
    changedSources: results.filter(
      (x) => x.source_changed_at === x.last_checked_at
    ).length,
    deadlineCandidates: results.filter(
      (x) => x.deadline_candidate
    ).length,
    deadlineChanges: results.filter(
      (x) => x.deadline_verification_status === "changed"
    ).length,
    detectedCycles: results.filter(
      (x) => x.cycle_candidate
    ).length,
    cycleStatus: {
      open: results.filter((x) => x.cycle_status === "open").length,
      closed: results.filter((x) => x.cycle_status === "closed").length,
      upcoming: results.filter((x) => x.cycle_status === "upcoming").length,
      rolling: results.filter((x) => x.cycle_status === "rolling").length,
      discontinued: results.filter(
        (x) => x.cycle_status === "discontinued"
      ).length
    }
  }), {
    headers: { "Content-Type": "application/json" }
  });
});

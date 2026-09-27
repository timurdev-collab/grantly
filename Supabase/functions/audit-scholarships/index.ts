import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

type Scholarship = {
  id: string;
  title: string;
  provider: string;
  official_url: string;
  verification_status: string;
  link_status: string | null;
  audit_failure_count: number;
  last_successful_check_at: string | null;
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

  const found = new Map<string, string>();

  for (const pattern of patterns) {
    for (const match of clean.matchAll(pattern)) {
      let date: Date | null = null;

      if (/^20\d{2}$/.test(match[1])) {
        const year = Number(match[1]);
        const month = Number(match[2]);
        const day = Number(match[3]);
        date = new Date(Date.UTC(year, month - 1, day));
      } else {
        const numericFirst = /^\d/.test(match[1]);
        const day = numericFirst ? Number(match[1]) : Number(match[2]);
        const monthName = numericFirst ? match[2] : match[1];
        const year = Number(match[3]);
        const month = months[monthName.toLowerCase()];
        date = new Date(Date.UTC(year, month - 1, day));
      }

      if (!date || Number.isNaN(date.getTime())) continue;

      const key = date.toISOString().slice(0, 10);
      const index = match.index ?? 0;
      const evidence = clean.slice(
        Math.max(0, index - 70),
        Math.min(clean.length, index + match[0].length + 90)
      ).trim();

      if (!found.has(key)) {
        found.set(key, evidence);
      }
    }
  }

  const today = Date.now() - 86400000;
  const future = [...found.entries()]
    .map(([date, evidence]) => ({
      date,
      evidence,
      time: new Date(`${date}T00:00:00Z`).getTime()
    }))
    .filter((item) => item.time >= today)
    .sort((a, b) => a.time - b.time);

  if (!future.length) {
    return {
      date: null,
      confidence: null,
      count: found.size,
      ambiguous: false,
      evidence: [...found.values()].slice(0, 3).join(" | ") || null
    };
  }

  if (future.length > 1) {
    return {
      date: null,
      confidence: null,
      count: future.length,
      ambiguous: true,
      evidence: future
        .slice(0, 3)
        .map((item) => `${item.date}: ${item.evidence}`)
        .join(" | ")
    };
  }

  return {
    date: future[0].date,
    confidence: 92,
    count: 1,
    ambiguous: false,
    evidence: future[0].evidence
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
      response.status === 410
    ) {
      linkStatus = "dead";
      verificationStatus = "needs_review";
    } else if (
      response.status === 429 ||
      response.status >= 500
    ) {
      throw new Error(`Transient HTTP ${response.status}`);
    } else if (!response.ok) {
      throw new Error(`HTTP ${response.status}`);
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
      audit_failure_count: 0,
      last_successful_check_at: checkedAt,
      source_fingerprint: fingerprint,
      source_changed_at: changed
        ? checkedAt
        : row.source_changed_at,
      last_checked_at: checkedAt,
      audit_error: null,
      deadline_candidate: deadline.date,
      deadline_confidence: deadline.confidence,
      deadline_candidate_count: deadline.count,
      deadline_ambiguous: deadline.ambiguous,
      deadline_evidence: deadline.evidence,
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
    const failureCount = (row.audit_failure_count ?? 0) + 1;
    const shouldMarkDead = failureCount >= 3;
    const retryHours = failureCount === 1 ? 6 : failureCount === 2 ? 12 : 24;

    return {
      id: row.id,
      link_status: shouldMarkDead
        ? "dead"
        : (row.link_status ?? "unchecked"),
      verification_status: shouldMarkDead
        ? "needs_review"
        : row.verification_status,
      final_url: row.official_url,
      source_http_status: null,
      audit_failure_count: failureCount,
      last_successful_check_at: row.last_successful_check_at,
      source_fingerprint: row.source_fingerprint,
      source_changed_at: row.source_changed_at,
      last_checked_at: checkedAt,
      audit_error: message,
      deadline_candidate: null,
      deadline_confidence: null,
      deadline_candidate_count: 0,
      deadline_ambiguous: false,
      deadline_evidence: null,
      deadline_verification_status: row.deadline
        ? deadlineVerificationStatus(row.deadline, null)
        : "unconfirmed",
      cycle_candidate: null,
      cycle_confidence: null,
      cycle_status: "unknown",
      next_check_at: new Date(
        Date.now() + retryHours * 3600000
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
  const startedMs = Date.now();
  const triggerType = cronToken ? "scheduled" : "manual";

  const { data: auditRun } = await admin
    .from("scholarship_audit_runs")
    .insert({
      trigger_type: triggerType,
      requested_limit: limit,
      status: "running",
      started_at: now
    })
    .select("id")
    .single();

  let query = admin
    .from("scholarships")
    .select(
      "id,title,provider,official_url,verification_status,link_status," +
      "audit_failure_count,last_successful_check_at,deadline," +
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
    if (auditRun?.id) {
      await admin
        .from("scholarship_audit_runs")
        .update({
          status: "failed",
          error_message: error.message,
          completed_at: new Date().toISOString(),
          duration_ms: Date.now() - startedMs
        })
        .eq("id", auditRun.id);
    }

    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { "Content-Type": "application/json" }
    });
  }

  if (auditRun?.id) {
    await admin
      .from("scholarship_audit_runs")
      .update({ selected_count: (rows ?? []).length })
      .eq("id", auditRun.id);
  }

  const results = [];

  for (let index = 0; index < (rows ?? []).length; index += 5) {
    const chunk = (rows ?? []).slice(index, index + 5);
    results.push(...await Promise.all(chunk.map(audit)));
  }

  for (const result of results) {
    const original = (rows ?? []).find((row) => row.id === result.id);

    await admin
      .from("scholarships")
      .update({
        link_status: result.link_status,
        verification_status: result.verification_status,
        final_url: result.final_url,
        source_http_status: result.source_http_status,
        audit_failure_count: result.audit_failure_count,
        last_successful_check_at: result.last_successful_check_at,
        source_fingerprint: result.source_fingerprint,
        source_changed_at: result.source_changed_at,
        last_checked_at: result.last_checked_at,
        audit_error: result.audit_error,
        deadline_candidate: result.deadline_candidate,
        deadline_confidence: result.deadline_confidence,
        deadline_candidate_count: result.deadline_candidate_count,
        deadline_ambiguous: result.deadline_ambiguous,
        deadline_evidence: result.deadline_evidence,
        deadline_verification_status:
          result.deadline_verification_status,
        cycle_candidate: result.cycle_candidate,
        cycle_confidence: result.cycle_confidence,
        cycle_status: result.cycle_status,
        next_check_at: result.next_check_at
      })
      .eq("id", result.id);

    let observationOutcome = "success";

    if (
      result.source_http_status === 404 ||
      result.source_http_status === 410
    ) {
      observationOutcome = "not_found";
    } else if (result.audit_error) {
      const errorText = String(result.audit_error).toLowerCase();

      if (
        errorText.includes("http 401") ||
        errorText.includes("http 403") ||
        errorText.includes("http 429")
      ) {
        observationOutcome = "blocked";
      } else if (
        errorText.includes("transient http") ||
        errorText.includes("http 5")
      ) {
        observationOutcome = "transient_error";
      } else if (
        errorText.includes("timeout") ||
        errorText.includes("abort") ||
        errorText.includes("network") ||
        errorText.includes("fetch")
      ) {
        observationOutcome = "network_error";
      } else {
        observationOutcome = "other_error";
      }
    }

    await admin
      .from("scholarship_audit_observations")
      .insert({
        scholarship_id: result.id,
        audit_run_id: auditRun?.id ?? null,
        checked_at: result.last_checked_at,
        outcome: observationOutcome,
        http_status: result.source_http_status,
        link_status: result.link_status,
        final_url: result.final_url,
        source_fingerprint: result.source_fingerprint,
        source_changed:
          result.source_changed_at === result.last_checked_at,
        deadline_candidate: result.deadline_candidate,
        deadline_confidence: result.deadline_confidence,
        deadline_candidate_count: result.deadline_candidate_count,
        deadline_ambiguous: result.deadline_ambiguous,
        deadline_evidence: result.deadline_evidence,
        cycle_candidate: result.cycle_candidate,
        cycle_confidence: result.cycle_confidence,
        cycle_status: result.cycle_status,
        audit_failure_count: result.audit_failure_count,
        audit_error: result.audit_error
      });

    if (!original) continue;

    const changes: Array<{
      field_name: string;
      old_value: string | null;
      detected_value: string | null;
      confidence: number | null;
    }> = [];

    if (
      result.deadline_candidate &&
      result.deadline_candidate !== original.deadline
    ) {
      changes.push({
        field_name: "deadline",
        old_value: original.deadline,
        detected_value: result.deadline_candidate,
        confidence: result.deadline_confidence
      });
    }

    if (
      result.cycle_candidate &&
      result.cycle_candidate !== original.application_cycle
    ) {
      changes.push({
        field_name: "application_cycle",
        old_value: original.application_cycle,
        detected_value: result.cycle_candidate,
        confidence: result.cycle_confidence
      });
    }

    if (
      result.cycle_status !== "unknown" &&
      result.cycle_status !== "open"
    ) {
      changes.push({
        field_name: "cycle_status",
        old_value: null,
        detected_value: result.cycle_status,
        confidence: 90
      });
    }

    if (
      result.final_url &&
      result.final_url !== original.official_url
    ) {
      changes.push({
        field_name: "official_url",
        old_value: original.official_url,
        detected_value: result.final_url,
        confidence: result.link_status === "exact" ? 95 : 70
      });
    }

    if (
      original.source_fingerprint &&
      result.source_fingerprint &&
      result.source_fingerprint !== original.source_fingerprint
    ) {
      changes.push({
        field_name: "source_content",
        old_value: original.source_fingerprint,
        detected_value: result.source_fingerprint,
        confidence: 100
      });
    }

    for (const change of changes) {
      const { data: existing } = await admin
        .from("scholarship_detected_changes")
        .select("id")
        .eq("scholarship_id", result.id)
        .eq("field_name", change.field_name)
        .eq("detected_value", change.detected_value ?? "")
        .eq("status", "pending")
        .maybeSingle();

      if (existing?.id) {
        await admin
          .from("scholarship_detected_changes")
          .update({
            confidence: change.confidence,
            source_url: result.final_url || original.official_url,
            source_fingerprint: result.source_fingerprint,
            last_detected_at: result.last_checked_at
          })
          .eq("id", existing.id);
      } else {
        await admin
          .from("scholarship_detected_changes")
          .insert({
            scholarship_id: result.id,
            field_name: change.field_name,
            old_value: change.old_value,
            detected_value: change.detected_value,
            confidence: change.confidence,
            source_url: result.final_url || original.official_url,
            source_fingerprint: result.source_fingerprint,
            first_detected_at: result.last_checked_at,
            last_detected_at: result.last_checked_at
          });
      }
    }
  }

  const summary = {
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
    ambiguousDeadlines: results.filter(
      (x) => x.deadline_ambiguous
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
  };

  if (auditRun?.id) {
    await admin
      .from("scholarship_audit_runs")
      .update({
        status: "completed",
        selected_count: results.length,
        exact_count: summary.exact,
        reachable_count: summary.reachable,
        generic_count: summary.generic,
        dead_count: summary.dead,
        changed_source_count: summary.changedSources,
        deadline_candidate_count: summary.deadlineCandidates,
        deadline_change_count: summary.deadlineChanges,
        detected_cycle_count: summary.detectedCycles,
        completed_at: new Date().toISOString(),
        duration_ms: Date.now() - startedMs
      })
      .eq("id", auditRun.id);
  }

  return new Response(JSON.stringify(summary), {
    headers: { "Content-Type": "application/json" }
  });
});

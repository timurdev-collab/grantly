import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

type Scholarship = {
  id: string;
  title: string;
  provider: string;
  official_url: string;
  verification_status: string;
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

function deadlineCandidate(text: string) {
  const months: Record<string, number> = {
    january:1,february:2,march:3,april:4,may:5,june:6,
    july:7,august:8,september:9,october:10,november:11,december:12
  };

  const clean = text.replace(/\s+/g, " ");
  const patterns = [
    /(?:deadline|apply by|application deadline|closing date)[^.!?]{0,90}?(\d{1,2})\s+(January|February|March|April|May|June|July|August|September|October|November|December)\s+(20\d{2})/gi,
    /(?:deadline|apply by|application deadline|closing date)[^.!?]{0,90}?(January|February|March|April|May|June|July|August|September|October|November|December)\s+(\d{1,2})(?:st|nd|rd|th)?[,]?\s+(20\d{2})/gi
  ];

  const future: Date[] = [];

  for (const pattern of patterns) {
    for (const match of clean.matchAll(pattern)) {
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
      const date = new Date(Date.UTC(year, month - 1, day));
      if (date.getTime() >= Date.now() - 86400000) {
        future.push(date);
      }
    }
  }

  if (!future.length) {
    return { date: null, confidence: null };
  }

  future.sort((a, b) => a.getTime() - b.getTime());

  return {
    date: future[0].toISOString().slice(0, 10),
    confidence: 90
  };
}

async function audit(row: Scholarship) {
  try {
    const original = new URL(row.official_url);
    const originalGeneric = original.pathname === "/" || original.pathname === "";

    const response = await fetch(row.official_url, {
      redirect: "follow",
      headers: {
        "User-Agent": "Mozilla/5.0 GrantlyCatalogAuditor/1.0"
      },
      signal: AbortSignal.timeout(9000)
    });

    const finalUrl = response.url || row.official_url;
    const final = new URL(finalUrl);
    const html = (await response.text()).slice(0, 300000);

    const plain = html
      .replace(/<script[\s\S]*?<\/script>/gi, " ")
      .replace(/<style[\s\S]*?<\/style>/gi, " ")
      .replace(/<[^>]+>/g, " ")
      .replace(/&nbsp;/g, " ")
      .replace(/&amp;/g, "&")
      .replace(/\s+/g, " ")
      .toLowerCase();

    const allTokens = [...new Set([
      ...tokens(row.title),
      ...tokens(row.provider)
    ])];

    const hitCount = allTokens.filter((token) => plain.includes(token)).length;
    const tokenScore = allTokens.length ? hitCount / allTokens.length : 0;
    const fundingLanguage =
      /scholarship|fellowship|financial aid|funding|bursary|studentship/.test(plain);
    const finalGeneric = final.pathname === "/" || final.pathname === "";

    let linkStatus = "reachable";
    let verificationStatus = row.verification_status;

    if (response.status === 404 || response.status === 410 || response.status >= 500) {
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

    return {
      id: row.id,
      link_status: linkStatus,
      verification_status: verificationStatus,
      final_url: finalUrl,
      last_checked_at: new Date().toISOString(),
      deadline_candidate: deadline.date,
      deadline_confidence: deadline.confidence
    };
  } catch {
    return {
      id: row.id,
      link_status: "dead",
      verification_status: "needs_review",
      final_url: row.official_url,
      last_checked_at: new Date().toISOString(),
      deadline_candidate: null,
      deadline_confidence: null
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

  const limit = Math.min(Math.max(body.limit ?? 20, 1), 30);

  const { data: rows, error } = await admin
    .from("scholarships")
    .select("id,title,provider,official_url,verification_status")
    .eq("status", "published")
    .in("verification_status", ["curated", "needs_review"])
    .order("last_checked_at", { ascending: true, nullsFirst: true })
    .limit(limit);

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
        last_checked_at: result.last_checked_at,
        deadline_candidate: result.deadline_candidate,
        deadline_confidence: result.deadline_confidence
      })
      .eq("id", result.id);
  }

  return new Response(JSON.stringify({
    audited: results.length,
    exact: results.filter((x) => x.link_status === "exact").length,
    generic: results.filter((x) => x.link_status === "generic").length,
    dead: results.filter((x) => x.link_status === "dead").length,
    reachable: results.filter((x) => x.link_status === "reachable").length,
    deadlineCandidates: results.filter((x) => x.deadline_candidate).length
  }), {
    headers: { "Content-Type": "application/json" }
  });
});

import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

function parseCsv(text: string) {
  const rows: string[][] = [];
  let row: string[] = [];
  let cell = "";
  let quoted = false;

  for (let i = 0; i < text.length; i++) {
    const ch = text[i];
    const next = text[i + 1];

    if (ch === '"' && quoted && next === '"') {
      cell += '"';
      i++;
    } else if (ch === '"') {
      quoted = !quoted;
    } else if (ch === "," && !quoted) {
      row.push(cell);
      cell = "";
    } else if ((ch === "\n" || ch === "\r") && !quoted) {
      if (ch === "\r" && next === "\n") i++;
      row.push(cell);
      if (row.some((x) => x.trim() !== "")) rows.push(row);
      row = [];
      cell = "";
    } else {
      cell += ch;
    }
  }

  if (cell.length || row.length) {
    row.push(cell);
    if (row.some((x) => x.trim() !== "")) rows.push(row);
  }

  if (rows.length < 2) return [];

  const headers = rows[0].map((h) => h.trim());

  return rows.slice(1).map((values) => {
    const obj: Record<string, unknown> = {};

    headers.forEach((header, index) => {
      let value: unknown = values[index]?.trim() ?? "";

      if (["degree_levels","fields","eligible_nationalities"].includes(header)) {
        value = String(value)
          .split(/[|;]/)
          .map((x) => x.trim())
          .filter(Boolean);
      }

      if (["airfare","accommodation","health_insurance","sat_required"].includes(header)) {
        value = ["true","1","yes","y"].includes(String(value).toLowerCase());
      }

      obj[header] = value;
    });

    return obj;
  });
}

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: { "Content-Type": "application/json" }
    });
  }

  const auth = req.headers.get("Authorization");
  if (!auth) {
    return new Response(JSON.stringify({ error: "Unauthorized" }), {
      status: 401,
      headers: { "Content-Type": "application/json" }
    });
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!,
    {
      global: { headers: { Authorization: auth } },
      auth: { persistSession: false }
    }
  );

  const body = await req.json();
  const format = String(body.format ?? "json").toLowerCase();
  const sourceLabel = String(body.source_label ?? "Manual import");
  const sourceUrl = body.source_url ? String(body.source_url) : null;

  let records: unknown[];

  if (format === "csv") {
    records = parseCsv(String(body.content ?? ""));
  } else {
    const parsed = typeof body.content === "string"
      ? JSON.parse(body.content)
      : body.content;

    records = Array.isArray(parsed) ? parsed : [];
  }

  if (!records.length) {
    return new Response(JSON.stringify({ error: "No import rows found" }), {
      status: 400,
      headers: { "Content-Type": "application/json" }
    });
  }

  const { data, error } = await supabase.rpc("stage_scholarship_import", {
    p_source_label: sourceLabel,
    p_source_url: sourceUrl,
    p_records: records
  });

  if (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 400,
      headers: { "Content-Type": "application/json" }
    });
  }

  return new Response(JSON.stringify({
    batch_id: data,
    rows: records.length
  }), {
    headers: { "Content-Type": "application/json" }
  });
});

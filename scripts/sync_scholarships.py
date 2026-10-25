#!/usr/bin/env python3
"""Conservative staging -> production scholarship importer. Dry-run by default."""
import datetime as dt
import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request

STAGING = "cbzriyarlvpmtfbjgede"
PRODUCTION = "bvcabjwriszghmizbwji"
FIELDS = [
    "slug", "title", "provider", "country", "region", "degree_levels",
    "fields", "funding_type", "tuition_coverage", "stipend", "airfare",
    "accommodation", "health_insurance", "min_gpa_percent", "min_ielts",
    "sat_required", "eligible_nationalities", "deadline", "official_url",
    "description", "source_label", "source_url", "source_license",
    "verification_status", "application_cycle", "deadline_notes",
    "link_status", "last_checked_at", "final_url", "cycle_status",
    "deadline_verification_status", "verified_at", "status",
]
def request(project, key, path, method="GET", payload=None):
    url = "https://" + project + ".supabase.co/rest/v1/" + path
    headers = {"apikey": key, "Authorization": "Bearer " + key}
    if payload is not None:
        headers["Content-Type"] = "application/json"
        headers["Prefer"] = "return=representation"
    body = None if payload is None else json.dumps(payload).encode()
    req = urllib.request.Request(url, data=body, headers=headers, method=method)
    with urllib.request.urlopen(req, timeout=30) as response:
        return json.load(response)
def all_rows(project, key):
    rows = []
    offset = 0
    while True:
        path = "scholarships?select=*&order=id.asc&limit=500&offset=" + str(offset)
        batch = request(project, key, path)
        rows.extend(batch)
        if len(batch) < 500:
            return rows
        offset += 500
def eligible(row):
    if row.get("status") != "published" or row.get("verification_status") != "verified":
        return False
    if row.get("link_status") != "exact":
        return False
    if row.get("cycle_status") in ("closed", "discontinued"):
        return False
    if row.get("deadline_verification_status") in ("expired", "rejected"):
        return False
    deadline = row.get("deadline")
    if deadline and deadline < dt.date.today().isoformat():
        return False
    return all(row.get(field) for field in ("slug", "title", "provider", "official_url", "source_url", "verified_at"))
def main():
    staging_key = os.environ["STAGING_SUPABASE_SERVICE_ROLE_KEY"]
    prod_key = os.environ["PRODUCTION_SUPABASE_SERVICE_ROLE_KEY"]
    apply = os.getenv("APPLY_SYNC", "false").lower() == "true"
    if apply and os.getenv("CONFIRM_PRODUCTION_WRITE") != "YES":
        sys.exit("Production write blocked: CONFIRM_PRODUCTION_WRITE must equal YES")
    stage = all_rows(STAGING, staging_key)
    production = all_rows(PRODUCTION, prod_key)
    existing = {r.get("slug", "").lower() for r in production if r.get("slug")}
    existing_urls = {r.get("official_url", "").rstrip("/").lower() for r in production if r.get("official_url")}
    seen = set()
    candidates = []
    for row in stage:
        slug = (row.get("slug") or "").lower()
        url = (row.get("official_url") or "").rstrip("/").lower()
        if not eligible(row) or slug in existing or url in existing_urls or slug in seen:
            continue
        seen.add(slug)
        candidates.append({key: row.get(key) for key in FIELDS if key in row})
    report = {"mode": "apply" if apply else "dry-run", "staging_total": len(stage),
              "production_total": len(production), "eligible_new": len(candidates),
              "slugs": [r["slug"] for r in candidates], "inserted": [], "errors": []}
    if apply:
        for row in candidates:
            try:
                # Never update an existing production scholarship.
                slug = urllib.parse.quote(row["slug"], safe="")
                if request(PRODUCTION, prod_key, "scholarships?select=id&slug=eq." + slug):
                    continue
                inserted = request(PRODUCTION, prod_key, "scholarships", "POST", [row])
                if not inserted:
                    raise RuntimeError("Insert returned no rows")
                check = request(PRODUCTION, prod_key, "scholarships?select=id,status,slug&slug=eq." + slug)
                if len(check) != 1 or check[0]["status"] != "published":
                    raise RuntimeError("Post-write verification failed")
                report["inserted"].append(row["slug"])
            except (urllib.error.HTTPError, RuntimeError) as error:
                report["errors"].append({"slug": row["slug"], "error": str(error)})
    with open("sync-report.json", "w", encoding="utf-8") as out:
        json.dump(report, out, indent=2)
    print(json.dumps({k: v for k, v in report.items() if k != "slugs"}, indent=2))
    if report["errors"]:
        sys.exit(1)
if __name__ == "__main__":
    main()

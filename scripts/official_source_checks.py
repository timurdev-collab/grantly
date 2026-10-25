#!/usr/bin/env python3
"""Read-only, bounded official-link checks. Network reachability is NOT scholarship verification."""
import datetime as dt
import json
import os
import urllib.error
import urllib.parse
import urllib.request

PROJECT = "cbzriyarlvpmtfbjgede"
KEY = os.environ["STAGING_SUPABASE_SERVICE_ROLE_KEY"]
LIMIT = 35
TIMEOUT = 12

def rows():
    result = []
    offset = 0
    while True:
        path = f"scholarships?select=slug,title,status,verification_status,link_status,official_url,source_url,deadline&order=id.asc&limit=500&offset={offset}"
        req = urllib.request.Request(f"https://{PROJECT}.supabase.co/rest/v1/{path}", headers={"apikey": KEY, "Authorization": f"Bearer {KEY}"})
        with urllib.request.urlopen(req, timeout=30) as response:
            batch = json.load(response)
        result.extend(batch)
        if len(batch) < 500:
            return result
        offset += 500

def probe(url):
    if not url:
        return {"result": "missing"}
    parsed = urllib.parse.urlsplit(url)
    if parsed.scheme != "https" or not parsed.hostname:
        return {"result": "invalid_url"}
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "EduT-ScholarshipEvidenceAudit/1.0", "Accept": "text/html,application/xhtml+xml"}, method="GET")
        with urllib.request.urlopen(req, timeout=TIMEOUT) as response:
            final = response.geturl()
            content_type = response.headers.get("Content-Type", "")
            response.read(1024)
            return {"result": "reachable", "status": response.status, "final_url": final, "content_type": content_type}
    except urllib.error.HTTPError as exc:
        return {"result": "http_error_unconfirmed", "status": exc.code}
    except (urllib.error.URLError, TimeoutError, ValueError, OSError) as exc:
        return {"result": "transient_or_network_error", "error_type": type(exc).__name__}

def main():
    all_rows = rows()
    candidates = [r for r in all_rows if r.get("status") in ("published", "draft") and r.get("verification_status") != "verified"]
    # Rotate a deterministic slice every hour so the entire queue is covered.
    window = int(dt.datetime.now(dt.timezone.utc).timestamp() // 3600)
    start = (window * LIMIT) % max(1, len(candidates))
    selected = (candidates[start:] + candidates[:start])[:LIMIT]
    checks = []
    for record in selected:
        checks.append({"slug": record.get("slug"), "title": record.get("title"), "verification_status": record.get("verification_status"), "official_url": record.get("official_url"), "official_url_check": probe(record.get("official_url")), "source_url": record.get("source_url"), "source_url_check": probe(record.get("source_url")) if record.get("source_url") != record.get("official_url") else {"result": "same_as_official_url"}, "requires_manual_programme_evidence_review": True})
    report = {"checked_at": dt.datetime.now(dt.timezone.utc).isoformat(), "total_records": len(all_rows), "unverified_candidates": len(candidates), "checked": len(checks), "records": checks, "notice": "HTTP checks are evidence leads only. Never auto-set verified, exact, closed, archived or published based on these checks."}
    with open("official-source-checks.json", "w", encoding="utf-8") as f:
        json.dump(report, f, indent=2)
    print(json.dumps({k:v for k,v in report.items() if k != "records"}, indent=2))

if __name__ == "__main__":
    main()

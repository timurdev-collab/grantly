#!/usr/bin/env python3
"""Read-only staging verification queue. Never auto-approve scholarships."""
import collections
import datetime as dt
import json
import os
import urllib.request

PROJECT = "cbzriyarlvpmtfbjgede"
KEY = os.environ["STAGING_SUPABASE_SERVICE_ROLE_KEY"]

def fetch_all():
    rows = []
    offset = 0
    while True:
        url = f"https://{PROJECT}.supabase.co/rest/v1/scholarships?select=slug,title,status,verification_status,link_status,official_url,source_url,deadline,verified_at,cycle_status&limit=500&offset={offset}"
        request = urllib.request.Request(url, headers={"apikey": KEY, "Authorization": f"Bearer {KEY}"})
        with urllib.request.urlopen(request, timeout=30) as response:
            batch = json.load(response)
        rows.extend(batch)
        if len(batch) < 500:
            break
        offset += 500
    return rows

def main():
    rows = fetch_all()
    today = dt.date.today().isoformat()
    reasons = collections.Counter()
    queue = []
    for row in rows:
        if row.get("status") != "published":
            continue
        problems = []
        if row.get("verification_status") != "verified":
            problems.append("requires_official_source_verification")
        if row.get("link_status") != "exact":
            problems.append("application_link_not_exact")
        if not row.get("source_url") or not row.get("official_url"):
            problems.append("missing_source_or_official_url")
        if not row.get("verified_at"):
            problems.append("missing_verification_timestamp")
        if row.get("deadline") and row["deadline"] < today:
            problems.append("past_deadline")
        if row.get("cycle_status") in ("closed", "discontinued"):
            problems.append("closed_cycle")
        if problems:
            reasons.update(problems)
            queue.append({"slug": row.get("slug"), "title": row.get("title"), "reasons": problems, "official_url": row.get("official_url"), "source_url": row.get("source_url")})
    queue.sort(key=lambda item: (len(item["reasons"]), item.get("slug") or ""))
    report = {"generated_at": dt.datetime.now(dt.timezone.utc).isoformat(), "staging_total": len(rows), "review_queue_total": len(queue), "reason_counts": dict(reasons), "review_queue": queue}
    with open("scholarship-review-queue.json", "w", encoding="utf-8") as output:
        json.dump(report, output, indent=2)
    print(json.dumps({key: value for key, value in report.items() if key != "review_queue"}, indent=2))
    print("Review queue is read-only. A human must confirm official evidence before marking verified.")

if __name__ == "__main__":
    main()

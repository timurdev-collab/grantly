#!/usr/bin/env python3
"""Produce an evidence-based production scholarship repair queue.

Only harmless canonical URL normalization is eligible for automatic correction.
Scholarship existence, deadlines, application cycles, verification status, and
different-page redirects always require a human reviewer.
"""
import datetime as dt
import json
import os
import urllib.error
import urllib.parse
import urllib.request

PROJECT = "bvcabjwriszghmizbwji"
KEY = os.environ["PRODUCTION_SUPABASE_SERVICE_ROLE_KEY"]
APPLY_SAFE = os.getenv("APPLY_SAFE_CANONICAL_URL_FIXES", "false").lower() == "true"
API = f"https://{PROJECT}.supabase.co/rest/v1/"
HEADERS = {"apikey": KEY, "Authorization": "Bearer " + KEY}
NOW = dt.datetime.now(dt.timezone.utc)
MAX_RECORDS = 1000


def api(path, method="GET", body=None, extra=None):
    data = json.dumps(body).encode() if body is not None else None
    headers = {**HEADERS, **(extra or {})}
    if body is not None:
        headers["Content-Type"] = "application/json"
        headers["Prefer"] = "return=representation"
    req = urllib.request.Request(API + path, headers=headers, data=data, method=method)
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.load(r)


def safe_canonical(old_url, new_url):
    """Only change host-identical URLs whose path differs in case/slash.

    This is NOT a general redirect acceptance rule. A 200 page for a different
    scholarship is never sufficient evidence for updating an official URL.
    """
    if not old_url or not new_url or old_url == new_url:
        return False
    a, b = urllib.parse.urlsplit(old_url), urllib.parse.urlsplit(new_url)
    if (a.scheme, b.scheme) != ("https", "https"):
        return False
    if not a.hostname or a.hostname.lower() != (b.hostname or "").lower():
        return False
    if a.username or a.password or b.username or b.password or a.port or b.port:
        return False
    if a.query != b.query or a.fragment or b.fragment:
        return False
    return urllib.parse.unquote(a.path).lower().rstrip("/") == urllib.parse.unquote(b.path).lower().rstrip("/")


def fetch_source(url):
    """Read-only HTTP confirmation, never treat transient failure as closure."""
    try:
        req = urllib.request.Request(url, headers={
            "User-Agent": "Mozilla/5.0 (compatible; EduTReview/1.0)",
            "Accept": "text/html,application/xhtml+xml"
        })
        with urllib.request.urlopen(req, timeout=12) as response:
            return {"http_status": response.status, "final_url": response.url}
    except urllib.error.HTTPError as exc:
        return {"http_status": exc.code, "error": "http_error"}
    except (urllib.error.URLError, TimeoutError, OSError, ValueError) as exc:
        return {"error": type(exc).__name__}


def canonical_update(record, result):
    """Conditional compare-and-swap: never overwrite a concurrent reviewer."""
    old, new = record["official_url"], record["final_url"]
    if not APPLY_SAFE or not safe_canonical(old, new):
        return False
    if record["link_status"] != "exact" or record.get("source_http_status") != 200:
        return False
    if record.get("audit_error"):
        return False
    checked = dt.datetime.fromisoformat(record["last_checked_at"].replace("Z", "+00:00"))
    if NOW - checked > dt.timedelta(hours=48):
        return False
    if result.get("http_status") != 200 or result.get("final_url") != new:
        return False
    params = urllib.parse.urlencode({
        "id": "eq." + record["id"],
        "official_url": "eq." + old,
        "final_url": "eq." + new,
        "link_status": "eq.exact"
    })
    updated = api("scholarships?" + params, method="PATCH", body={"official_url": new})
    if len(updated) != 1:
        return False
    # Resolve only matching URL proposals, not any deadline or content proposals.
    change_filter = urllib.parse.urlencode({
        "scholarship_id": "eq." + record["id"],
        "field_name": "eq.official_url",
        "status": "eq.pending",
        "detected_value": "eq." + new
    })
    api("scholarship_detected_changes?" + change_filter, method="PATCH",
        body={"status": "accepted", "review_note": "Automatic canonical URL normalization (same domain and path); independently checked HTTP 200.", "reviewed_at": NOW.isoformat()})
    return True



def replacement_leads(record):
    """Suggest existing discovery candidates for human confirmation only."""
    if record["link_status"] != "dead":
        return []
    title = record["title"]
    encoded = urllib.parse.quote(title, safe="")
    try:
        possible = api(
            "scholarship_source_candidates?select=candidate_url,candidate_title,"
            "relevance_score,status&candidate_title=ilike."
            + encoded + "&order=relevance_score.desc&limit=8"
        )
    except (urllib.error.HTTPError, urllib.error.URLError, ValueError):
        return []
    original_host = urllib.parse.urlsplit(record.get("official_url") or "").hostname
    leads = []
    for candidate in possible:
        url = candidate.get("candidate_url") or ""
        parsed = urllib.parse.urlsplit(url)
        if (parsed.scheme != "https" or not original_host
                or parsed.hostname != original_host
                or float(candidate.get("relevance_score") or 0) < 70):
            continue
        leads.append(candidate)
    return leads[:3]

def main():
    rows = api("scholarship_repair_queue?select=*&order=priority.asc,pending_change_count.desc,title.asc&limit=" + str(MAX_RECORDS))
    evidence = []
    applied = []
    errors = []
    for r in rows:
        # Check all broken links and possible canonical redirects; limit traffic.
        candidate = r.get("final_url")
        safe = safe_canonical(r.get("official_url"), candidate)
        probe = fetch_source(candidate) if candidate and (r["link_status"] == "dead" or safe) else None
        item = {
            "id": r["id"], "title": r["title"], "provider": r["provider"],
            "priority": r["priority"], "reason": r["priority_reason"],
            "official_url": r["official_url"], "observed_final_url": candidate,
            "link_status": r["link_status"], "pending_changes": r["pending_change_count"],
            "candidate_probe": probe, "replacement_leads_for_review": replacement_leads(r),
            "safe_canonical_candidate": safe,
            "requires_human_review": not safe or not APPLY_SAFE
        }
        if safe and APPLY_SAFE:
            try:
                if canonical_update(r, probe or {}):
                    item["automatic_result"] = "canonical_url_updated"
                    item["requires_human_review"] = r["pending_change_count"] > 1 or r["verification_status"] == "needs_review"
                    applied.append(r["id"])
                else:
                    item["automatic_result"] = "not_eligible_or_not_confirmed"
            except (urllib.error.HTTPError, urllib.error.URLError, ValueError) as e:
                item["automatic_result"] = "error"
                errors.append({"id": r["id"], "error": type(e).__name__})
        evidence.append(item)
    result = {
        "generated_at": NOW.isoformat(), "mode": "safe-canonical-apply" if APPLY_SAFE else "review-only",
        "total_priority_queue": len(rows), "automatically_fixed": len(applied),
        "errors": errors, "records": evidence,
        "warning": "Never auto-approve deadlines, cycles, scholarships, or redirects to different pages."
    }
    with open("scholarship-repair-report.json", "w", encoding="utf8") as f:
        json.dump(result, f, indent=2, ensure_ascii=False)
    print(json.dumps({k: v for k, v in result.items() if k != "records"}, indent=2))
    if errors:
        raise SystemExit(1)


if __name__ == "__main__":
    main()

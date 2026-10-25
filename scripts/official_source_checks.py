#!/usr/bin/env python3
"""Read-only evidence leads from scholarship source pages; never auto-verify or publish."""
import datetime as dt
import html
from html.parser import HTMLParser
import json
import os
import re
import urllib.error
import urllib.parse
import urllib.request

PROJECT = "cbzriyarlvpmtfbjgede"
KEY = os.environ["STAGING_SUPABASE_SERVICE_ROLE_KEY"]
LIMIT = 35
TIMEOUT = 12
MAX_BYTES = 100000

class PageText(HTMLParser):
    def __init__(self):
        super().__init__()
        self.skip = 0
        self.parts = []
        self.title = []
        self.in_title = False
    def handle_starttag(self, tag, attrs):
        if tag in ("script", "style", "noscript"):
            self.skip += 1
        if tag == "title":
            self.in_title = True
    def handle_endtag(self, tag):
        if tag in ("script", "style", "noscript"):
            self.skip = max(0, self.skip - 1)
        if tag == "title":
            self.in_title = False
    def handle_data(self, data):
        if not self.skip:
            if self.in_title:
                self.title.append(data)
            self.parts.append(data)

def rows():
    result, offset = [], 0
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
        req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0 (compatible; EduTScholarshipAudit/1.0)", "Accept": "text/html,application/xhtml+xml"}, method="GET")
        with urllib.request.urlopen(req, timeout=TIMEOUT) as response:
            final = response.geturl()
            ctype = response.headers.get("Content-Type", "")
            result = {"result": "reachable", "status": response.status, "final_url": final, "content_type": ctype}
            if "text/html" in ctype.lower():
                raw = response.read(MAX_BYTES).decode("utf-8", errors="replace")
                parser = PageText()
                parser.feed(raw)
                plain = re.sub(r"\s+", " ", html.unescape(" ".join(parser.parts))).strip()
                result["page_title"] = " ".join(parser.title).strip()[:250]
                # Evidence excerpts are leads for review, NOT verified scholarship facts.
                matches = list(re.finditer(r"(?i)\b(deadline|apply|applications|eligib|tuition|stipend|scholarship|2026|2027)\w*", plain))
                result["evidence_excerpts"] = [plain[max(0,m.start()-100):min(len(plain),m.end()+170)] for m in matches[:12]]
            return result
    except urllib.error.HTTPError as exc:
        return {"result": "http_error_unconfirmed", "status": exc.code}
    except (urllib.error.URLError, TimeoutError, ValueError, OSError) as exc:
        return {"result": "transient_or_network_error", "error_type": type(exc).__name__}

def main():
    all_rows = rows()
    candidates = [r for r in all_rows if r.get("status") in ("published", "draft") and r.get("verification_status") != "verified"]
    window = int(dt.datetime.now(dt.timezone.utc).timestamp() // 3600)
    start = (window * LIMIT) % max(1, len(candidates))
    selected = (candidates[start:] + candidates[:start])[:LIMIT]
    checks = []
    for record in selected:
        official = record.get("official_url")
        source = record.get("source_url")
        checks.append({
            "slug": record.get("slug"), "title": record.get("title"),
            "verification_status": record.get("verification_status"),
            "official_url": official, "official_url_check": probe(official),
            "source_url": source,
            "source_url_check": probe(source) if source != official else {"result": "same_as_official_url"},
            "source_host_matches_official": bool(source and official and urllib.parse.urlsplit(source).hostname == urllib.parse.urlsplit(official).hostname),
            "requires_manual_programme_evidence_review": True
        })
    report = {
        "checked_at": dt.datetime.now(dt.timezone.utc).isoformat(),
        "total_records": len(all_rows), "unverified_candidates": len(candidates),
        "checked": len(checks), "records": checks,
        "notice": "Extracted page snippets are untrusted evidence leads. No automatic scholarship verification, archival or publication."
    }
    with open("official-source-checks.json", "w", encoding="utf-8") as f:
        json.dump(report, f, indent=2)
    print(json.dumps({k:v for k,v in report.items() if k != "records"}, indent=2))

if __name__ == "__main__":
    main()

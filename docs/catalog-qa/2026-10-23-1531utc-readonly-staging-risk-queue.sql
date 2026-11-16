-- Grantly staging-only READ-ONLY catalog QA queue, verified against staging on 2026-10-23.
-- Baseline: 397 published; 309 needs_review; 251 needs_review with no field provenance;
-- 229 needs_review link only to homepage; 205 have both risk signals.
-- These flags are prioritization heuristics, not verification, fraud or discontinuation findings.
-- Never write directly to published records from this query; use authenticated audited approval.
WITH published AS (
  SELECT s.id, s.title, s.provider, s.country, s.official_url,
         s.deadline, s.application_cycle, s.verification_status,
         s.funding_type, s.eligible_nationalities, s.source_http_status,
         (SELECT count(*) FROM public.scholarship_field_provenance p
          WHERE p.scholarship_id = s.id) AS provenance_count,
         (s.official_url ~* '^https?://[^/]+/?$') AS homepage_only
  FROM public.scholarships s
  WHERE s.status = 'published'
),
risk AS (
  SELECT *,
    (CASE WHEN provenance_count = 0 THEN 4 ELSE 0 END
     + CASE WHEN homepage_only THEN 3 ELSE 0 END
     + CASE WHEN funding_type ~* '(fully funded|full tuition)'
            AND eligible_nationalities @> ARRAY['ALL']::text[] THEN 3 ELSE 0 END
     + CASE WHEN deadline IS NULL THEN 1 ELSE 0 END
     + CASE WHEN title ~* '(loan|assistantship)' THEN 2 ELSE 0 END
     + CASE WHEN source_http_status >= 400 THEN 1 ELSE 0 END
    ) AS triage_score
  FROM published
  WHERE verification_status = 'needs_review'
)
SELECT id,title,provider,country,triage_score,provenance_count,homepage_only,
       funding_type,eligible_nationalities,deadline,application_cycle,
       official_url,source_http_status
FROM risk
ORDER BY triage_score DESC, provider, title
LIMIT 100;

-- Note: HTTP 403/404/5xx flags mean check alternate official programme URLs.
-- They MUST NOT trigger automatic archival or discontinuation labeling.
-- A high score is a research queue only. Field provenance needs a named,
-- programme-specific official source, value/excerpt, cycle and reviewer.

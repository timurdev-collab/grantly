# Grantly staging catalog QA — 2026-10-23 08:25 UTC

**Scope:** Evidence-only on `catalog-qa/2026-10-23-official-sources`, staging project `cbzriyarlvpmtfbjgede`. Not an approval, publication, provenance acceptance or production change. Confirmed staging counts at 08:25:56 UTC: 397 published, 309 published needs_review, 83 drafts, 75 archived, 557 field-provenance entries (207 with accepted_value, 0 with accepted_by). The management connection reports `auth.uid() = NULL` and `is_admin() = false`. All changes below are *proposals* requiring an authenticated reviewer, source audit and staging/CI validation.

## 1. Lund University Global Scholarship — incorrect fully-funded claim

- **Published ID:** `38dcbee8-8772-477d-9f60-c64394c924df` (needs_review; 0 field provenance).
- **Current:** `funding_type = Fully funded`, `tuition_coverage = 25% - 100% tuition reduction`, `eligible_nationalities = [ALL]`, no cycle/deadline.
- **Official programme source:** https://www.lunduniversity.lu.se/admissions/scholarships-and-awards/lund-university-global-scholarship ; indexed current official page https://www.lunduniversity.lu.se/node/83 (last updated 26 Aug 2026).
- **Evidence:** Merit scholarship covers **part or all of tuition fees only**, explicitly **excludes living costs**. For qualifying high-achieving fee-paying applicants from outside EU/EEA. Applicants must choose Lund as first programme choice and separately apply for the scholarship after degree application. Scholarship page currently says 2026 application closed **16 February 2026**, and next scholarship round *usually* opens in early February; **do not infer a 2027 deadline**.
- **Proposed fields:** `funding_type = Partial` or equivalent *tuition-only, up to 100%* taxonomy; `tuition_coverage = partial or full tuition waiver, living costs excluded`; nationality restrictions accurately represented (do not encode ALL); leave deadline null until 2027 call.
- **Source availability caveat:** Live retrieval of an alternate official URL redirected to a temporary Lund website outage page on 23 October. This is **not** evidence that the scholarship has been discontinued.

## 2. KAIST international undergraduate scholarship — duplicate published records

- **Published IDs:** `b9b20deb-9312-4a0f-a70d-feb75d2abdb1` (0 provenance) and `efd87e68-3a6e-4736-bb8a-5916575b55d7` (11 provenance, 2 accepted values). Both link to **identical official scholarship URL**.
- **Official award:** https://admission.kaist.ac.kr/intl-undergraduate/support/scholarships/kaist/
- **Official 2027 timeline:** https://admission.kaist.ac.kr/intl-undergraduate/application/ApplicationGuide/ApplicationTimeline
- **Evidence:** Full tuition waiver for 8 semesters, KRW 350,000 monthly living allowance and medical health insurance. No separate scholarship application: applicant checks the KAIST scholarship option in admissions application. Eligibility is **international undergraduate admission applicants**, not unconditional eligibility for all nationalities. Maintain GPA >2.7/4.3 after first year.
- **2027 early track deadline:** **22 October 2026, 18:00 KST**; **regular fall track:** **14 January 2027, 18:00 KST**. These are *admissions* deadlines, not separate scholarship deadlines. Recommendation-letter deadline differs.
- **Proposed action:** Review the more-provenanced record as canonical; reconcile/possibly archive the other via audited admin workflow only. Preserve both admissions tracks in deadline_notes, and avoid treating expired early track as closure of the regular track. The currently stored 2026-10-22 single deadline can mislead users about regular fall admission.

## 3. Edinburgh Mastercard Foundation Scholars Program — restricted invitation process

- **Published ID:** `eed92694-845c-4781-aa92-b858b16da8b1` (0 provenance).
- **Current:** Bachelor's and Master's, eligible_nationalities [ALL], no application_cycle/deadline.
- **Official how-to:** https://edinburgh-global.ed.ac.uk/mastercard-foundation-scholars-program/apply-for-a-scholarship/how-to-apply
- **Official eligibility:** https://edinburgh-global.ed.ac.uk/mastercard-foundation-scholars-program/apply-for-a-scholarship/eligibility
- **Evidence:** **2027/28 postgraduate** on-campus Master's and online Master's/PG Diploma pathways, not a generic Bachelor's scholarship. African citizens/residents or refugees in an African country meeting age, climate leadership and other criteria. September 15–24, 2026 mandatory virtual information-session attendance was prerequisite to invitation; registration is now closed. Invited applicants must complete declaration by **26 October 2026 17:00 UK time** (may close earlier) and main application by **19 November 2026 17:00 UK time**. Do **not** advertise as open to unrestricted new applicants. One timeline page contains inconsistent October 19 wording, while the current detailed how-to and deadline row say October 26; preserve source discrepancy.
- **Proposed fields:** degree Master's / qualifying PG Diploma (schema may not have Diploma category); country eligibility explicitly restricted; `application_cycle = 2027/28`; stage-specific deadline notes; programme-specific official URL. Do not use 19 November as a universal first-time application deadline.

## 4. Nottingham Developing Solutions — duplicate risk and unsupported universal funding

- **Published IDs:** `9d2e2386-ba7b-44ea-bf3d-d5252fd5982b` (0 provenance, funding_type Varies, half/full tuition) and `2116ac6a-4063-4b13-a0af-4d7edf63f581` (1 unaccepted provenance, funding_type Fully funded, 100% tuition waiver).
- **Existing official URLs:** https://www.nottingham.ac.uk/pgstudy/funding/developing-solutions-masters-scholarship and https://www.nottingham.ac.uk/studywithus/international-applicants/scholarships-fees-and-finance/scholarships/developing-solutions.aspx
- **Caution:** Both appear to describe the same Master's scholarship, but official pages were not retrievable during this run (access blocked). Do not merge, mark verified, archive or set a new 2027 deadline until official source and programme-identity check succeed. Existing record notes 2026/27 deadline 15 April 2026, not a 2027 deadline.

## Reviewer gates

1. Re-fetch official programme pages, record exact field-level excerpts and source timestamps; distinguish temporary HTTP failures from discontinued programmes.
2. Perform semantic duplicate screening against all 397 published, 83 drafts and 636 source candidates.
3. Use authenticated application admin review to accept provenance with reviewer identity, then approved archive/publish functions and audit logs; never directly force publication status through unauthenticated management SQL.
4. Verify before/after staging readbacks and relevant CI checks before considering production.
5. No numerical IELTS/TOEFL/SAT minimum was established by the above scholarship-specific official pages; leave numerical fields unconfirmed instead of inferring from general university admission rules.

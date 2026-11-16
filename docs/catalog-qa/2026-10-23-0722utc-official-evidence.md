# Grantly staging scholarship QA — 2026-10-23 07:22–07:24 UTC

**Scope:** Staging project `cbzriyarlvpmtfbjgede`. Evidence and proposals only. Do not apply production changes, accept provenance, archive, or publish without an authenticated admin reviewer and successful staging/CI validation.

## Staging baseline
Published 397; published needs_review 309; drafts 83; archived 75; provenance 557 (207 accepted, 0 reviewer-attributed); source candidates 636. `auth.uid()` is NULL and `is_admin()` is false in the connected management session.

## Existing published records: corrections to review

### Yale-NUS Scholarship
- Record: `65d89dc3-1b09-41f9-ac1f-00889956e1c9`; published, needs_review, zero provenance.
- **Official evidence:** Yale-NUS College closed 30 June 2025, after its final cohort graduated May 2025. New undergraduate applicants cannot receive the Yale-NUS institutional aid described by this record.
- Source: https://www.yale-nus.edu.sg/ ; https://legacy.yale-nus.edu.sg/stories/closure
- **Recommendation:** Authenticated audited archival after checking for any distinct ongoing legacy awards; do not conflate with NUS College scholarships.

### Émile Boutmy scholarship — duplicate
- Unreviewed: `2ae14d86-bf95-4410-b366-a70c53e02db9`; curated counterpart: `a88b8389-ce8a-4852-9080-b2e8508028d2`. Both published and point to the identical official award page.
- Correct award: Bachelor tuition waiver **full or €9,500**; Master's **€18,500 per year for two years**. It is not a living-expense grant.
- Eligibility: first-time non-EU applicants whose household does not file taxes in EU, with programme-specific exclusions (including certain journalism programmes, one-year Masters, PhDs and some dual degrees).
- 2027 Bachelor's deadlines: international secondary school **13 Jan 2027**; French secondary school **1 Apr 2027**. Master's page says **18 October / 29 November** committees; confirm year and programme route before setting a single deadline.
- Source: https://www.sciencespo.fr/students/en/fees-funding/bursaries-financial-aid/emile-boutmy-scholarship/
- **Recommendation:** Keep canonical curated entry, reconcile and archive duplicate only with admin audit. Fix unrestricted nationality and obsolete €13k claim.

### UBC International Major Entrance Scholarship
- Record: `d6fe449b-4b5c-4d16-b49b-65cdb7885b0e`; published, needs_review, zero provenance.
- UBC's **2027 entry** calendar lists **1 Dec 2026** for IMES/OIS admissions-based award consideration. Do not confuse with the **15 Nov 2026** International Scholars Program application deadline.
- UBC's scholarship page specifies **C$10,000–25,000/year for 2026/27**; 2027/28 amount not yet verified. Existing universal C$40k claim is not supported.
- Eligibility: first-time international undergraduates entering from secondary school, studying on a Canadian study permit, selected for merit and community involvement; not simultaneous International Scholars award nominees.
- Sources: https://you.ubc.ca/applying-ubc/dates-deadlines/ ; https://you.ubc.ca/financial-planning/scholarships-awards-international-students/
- **Recommendation:** Correct deadline, eligibility and funding-year caveat, with field-level evidence.

## Distinct candidate proposals requiring admin-controlled draft review

### University of Waterloo International Student Entrance Scholarship
- Source: https://uwaterloo.ca/future-students/financing/international-scholarships
- Type: first-year **C$10,000** entrance scholarship, automatically considered, no separate scholarship application.
- Eligible: international fee-paying students admitted to full-time first-year degree programmes, with explicit programme, transfer, deferral and 2+2 exclusions.
- **Deadline:** no distinct scholarship deadline on programme page; use programme admissions deadline if verified, labelled as admissions-only.
- Exact title and source URL not found in targeted staging scholarship/source-candidate title search on 23 Oct 2026.
- Language tests/SAT: no scholarship-specific numerical requirement established. Do not populate numerical minima.

### UBC Outstanding International Student Award
- Source: https://you.ubc.ca/financial-planning/scholarships-awards-international-students/
- One-time merit-based entrance award, distinct from renewable IMES and from need-and-merit International Scholars.
- **Value:** official page shows **C$10,000–25,000 for 2025/26**, not a verified 2027/28 amount.
- **2027 entry consideration date:** 1 Dec 2026, according to https://you.ubc.ca/applying-ubc/dates-deadlines/
- Exact title and source URL not found in targeted staging title search on 23 Oct 2026. Hold funding value until current-cycle official amount is published.
- No scholarship-specific IELTS/TOEFL/SAT numerical thresholds verified.

## Gates
No direct SQL updates to `scholarships`, `scholarship_field_provenance`, or source-candidate approval flags using an unauthenticated management session. Use legitimate authenticated application admin actions and preserve audit logs, reviewer identity, source URLs, field evidence, cycle-specific deadlines, staging readbacks and CI checks.

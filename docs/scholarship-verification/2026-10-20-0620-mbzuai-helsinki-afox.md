# Grantly staging scholarship evidence — 2026-10-20 06:20 ICT

Status: **research-only; no staging mutation authorised or executed**. These are proposals, not accepted database provenance or verified status changes. Official pages were checked 2026-10-20.

## 1. MBZUAI Undergraduate Scholarship
- Staging ID: `9fa27a6b-f142-44d7-ae3c-41bfd6ca32c0`; published / needs_review.
- Official source: https://mbzuai.ac.ae/admissions/undergraduate-admissions
- 2027 Fall admissions: Early Action deadline **2026-11-01 17:00 GST**; Regular Decision deadline **2027-02-01 17:00 GST**. Scholarship amounts depend on individual merit/need award; coverage **up to** 100% of tuition and cost of attendance, not guaranteed.
- Conditional **admissions** language threshold: non-native English speakers need IELTS Academic **6.5**, TOEFL iBT **90 (old scale) / 4.5 (new scale)**, or another accepted test, unless eligible for a narrowly defined exemption. Exams normally at physical centers. These are **not separate scholarship-specific thresholds**.
- SAT/ACT are **not required** for admission. A SAT Math score **760** and total SAT **1400** (both) may waive the university's separate screening exam; not a general admissions or scholarship SAT minimum.
- Existing `min_gpa_percent=90` should be re-evaluated: the official admissions FAQ calls 90% a **general competitive guideline**, not a strict minimum. Do not encode as a mandatory eligibility cutoff.
- Existing `min_ielts=NULL` omits conditional admission language testing; use a field that distinguishes admission requirement from scholarship-specific minimum before writing.
- Existing funding, regular deadline and early deadline notes are broadly supported; do not duplicate or relabel them.
- Proposed field evidence: `admissions_english`, `admissions_sat`, `min_gpa_percent`, `deadline_notes` (retain the already correct dates). Preserve direct official URL and quoted page excerpts in audited field provenance.

## 2. University of Helsinki International Scholarship
- Staging ID: `67821593-89ce-4176-991d-845ec3590c72`; published / needs_review.
- Scholarship source: https://www.helsinki.fi/en/admissions-and-education/apply-bachelors-and-masters-programmes/tuition-fees-and-scholarship-programme
- Autumn 2027 Master's application source: https://www.helsinki.fi/en/admissions-and-education/apply-bachelors-and-masters-programmes/apply-international-masters-programmes
- Official: 50% or 100% Master's tuition waiver (mostly 50%); **no living allowance**; 2-year duration conditional on **55 ECTS** in first year; waiver requested with degree application. Application window **2027-01-05 to 2027-01-19**. Current funding and deadline are correctly stored.
- Eligibility: academically excellent **tuition-fee-liable** applicants, generally non-EU/EEA/Swiss citizens without qualifying fee-exempt status; current `eligible_nationalities=['ALL']` is overbroad. Do not simplify residency/fee-status rules to a bare nationality list.
- No universal scholarship-specific IELTS, TOEFL or SAT score was established from the scholarship page; programme-specific language admissions apply.
- Two generic published listings (`8def200f-88af-4f2a-8665-f7a514737d31`, `b8891f50-acfe-4315-a3d7-ec3d74e7cff2`) use the Helsinki homepage and non-programme-specific award names. Both have zero saved/application/notification/product-event references but have historical provenance, audit observations and two detected changes each. **Possible synthetic/duplicate records, not confirmed**. Preserve until named-award identity and detected-change review.

## 3. AfOx Graduate Scholarship (Oxford MBA)
- Staging ID: `335b78c6-2bbc-4fdd-b250-0d12ae09bb58`; published / needs_review.
- Official source: https://www.sbs.ox.ac.uk/oxford-experience/scholarships-and-funding/afox-graduate-scholarships
- 2027–28 MBA; up to three awards; full course fees and living grant **at least GBP 21,805**; African citizenship **and** ordinary residence in Africa; no previous Master's degree; commitment to Africa's development; **2027-01-06** MBA application deadline; no separate scholarship application.
- Existing staging fields and accepted field provenance already align with official source. **No correction or additional duplicate provenance needed.** Scholarship page does not state scholarship-specific IELTS/TOEFL/SAT cutoffs; MBA admissions criteria are separate.

## Workflow constraint and safe next step
- Staging connection uses `postgres` with `auth.uid()=NULL` and `public.is_admin()=false`. Admin RPCs for published corrections, archival and provenance require an authenticated admin session. Do **not** use privileged direct SQL to bypass this restriction.
- Proposed legitimate workflow: authenticated admin review action with explicit official URL, exact excerpt, field name, previous value, proposed value, reviewer UUID and atomic action log; add staging tests for RLS, audit integrity and idempotency, run CI before any production deployment.
- This file documents research only; it is **not** an application of any database change.

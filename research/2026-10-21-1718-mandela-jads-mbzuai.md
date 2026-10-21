# Grantly staging evidence: Mandela Rhodes, AfDB JADS and MBZUAI (2026-10-21)

Research-only record. No database changes are authorized by this document. Evidence verified against official programme pages on 2026-10-21. Do not change production or bypass authenticated staging administration. Preserve field-level provenance and reviewer attribution.

## 1. Mandela Rhodes Scholarship — `62fb7982-8251-4c8e-aed0-2747a014fe02`

**Staging:** published, `needs_review`; `deadline=2027-04-14`, `application_cycle="2028 intake (apply in 2027)"`, both already correct. Existing structured `eligible_nationalities=["ALL"]` is overbroad. `degree_levels=["Master"]` omits eligible one-year Honours. Existing description already correctly mentions these limitations: do not overwrite it.

**Official source:** https://www.mandelarhodes.org/scholarship/apply/

- Eligible citizenship: citizens of **African countries**, irrespective of current residence, **not** all nationalities. Age 19–29 in application year; bachelor's degree completed by 2028-01-01 with >70% or upper-second-class results. Full-time in-person Honours (one year) or Masters (one/two years) at a recognised South African institution; **MBA, predominantly online and block courses excluded**. Leadership development participation mandatory.
- Class of 2028 applications **open 2027-03-09**, **close 2027-04-14 23:59 GMT+2**. All three referees must upload by close.
- Tuition and registration plus Foundation-set allowances for accommodation, meals, study materials, medical aid and personal costs; economy flights for international scholars. **Visa, university application and SAQA fees not funded.** Allowance amounts not specified on official page.
- English postgraduate proficiency required, but **no universal numerical IELTS, TOEFL or SAT minimum** on scholarship page; university admission conditions remain separate.
- **Proposed structured changes (requires authenticated review):** `eligible_nationalities`: use the app's supported African-country codes/region taxonomy rather than `["ALL"]`; `degree_levels`: add the schema-supported Honours/postgraduate category if available, otherwise retain Master and clarify limitation. Do **not** alter the verified deadline, funding or cycle. Do not claim a fixed stipend.

## 2. AfDB Japan Africa Dream Scholarship (JADS) — `66d2b9f6-7869-469d-9db8-f0c2687b7450`

**Staging:** published, `needs_review`, `eligible_nationalities=["ALL"]`, `fields=["All fields"]`, `deadline=NULL`. Its partner-university cycle notes are already appropriately cautious.

**Official source:** https://www.afdb.org/en/about-us/careers/japan-africa-dream-scholarship-jads-program/who-is-eligible-to-apply
**Official preparation guidance:** https://www.afdb.org/en/about-us/careers/japan-africa-dream-scholarship-jads-program/what-can-an-applicant-do-before-the-call

- Eligibility restricted to citizens of **African Development Bank regional member countries**; age generally <=35, eligible bachelor's degree, at least one year of paid employment after graduation (per official criteria), admission to an approved Master's course at partner institution, development-related fields such as energy, agriculture, health, environmental sustainability and engineering.
- Applications proceed through partner universities and nomination. **No single confirmed 2027 programme-wide deadline.** Leave structured `deadline` null pending a university- and intake-specific call.
- Official preparation guidance suggests TOEFL iBT or TOEIC, **but publishes no universal numeric IELTS, TOEFL or SAT threshold**. Check admission rules at each university.
- **Proposed structured changes:** replace unrestricted `eligible_nationalities` and `fields` with validated supported values. Keep funding description, degree level and null deadline unless stronger official evidence emerges.
- **Freshness limitation:** the official eligibility page was last updated 2022-11-09; treat it as general criteria, not proof of an open 2027 call.

## 3. MBZUAI Undergraduate Scholarship — `9fa27a6b-f142-44d7-ae3c-41bfd6ca32c0`

**Staging:** published, `needs_review`, `deadline=2027-02-01`, `application_cycle="Fall 2027"`, `min_ielts=NULL`, `sat_required=false`. Its tuition and stipend descriptions are already conditional and accurate; do not relabel as fully funded.

**Official source:** https://mbzuai.ac.ae/admissions/undergraduate-admissions

- 2027 intake: **Early Action deadline 2026-11-01 17:00 GST**, Regular Decision **2027-02-01 17:00 GST**; both are **undergraduate admission** deadlines, not independently stated scholarship-application deadlines.
- **University admission** language proficiency for applicants whose first language is not English: IELTS Academic **6.5**, TOEFL iBT **90 / 4.5** (the page uses these two score scales), PTE 60, Cambridge C1 180/C2 200, Duolingo 120 with restrictions. Specified exemptions apply to qualifying English-medium education. Home editions not accepted; tests generally valid two years.
- **SAT/ACT not required for general admission**. SAT Math >=760 and total >=1400 together are **one possible screening-exam waiver route**, not universal admission or scholarship eligibility minima.
- Merit- and need-based scholarships **may cover up to 100%** of tuition and cost of attendance. Individual stipend/support varies and is not guaranteed. Published annual tuition is USD 45,000 before scholarship.
- **Proposed structured change:** `min_ielts` from null to 6.5 **only if the product explicitly labels this as a programme admission requirement with exemption metadata**; otherwise preserve null and add an admission-requirements note/evidence, to avoid falsely representing it as a mandatory scholarship threshold. Keep `sat_required=false`. Preserve correct existing dates and funding qualifiers.

## Staging provenance and review guardrails

At research time, `auth.uid()=NULL`, `auth.role()=NULL`, `public.is_admin()=FALSE`. Therefore no catalog edits or accepted provenance entries were made. The three records collectively had **26 provenance rows**, of which **11** had accepted values and **zero** had authenticated `accepted_by` attribution (Mandela 14/8, JADS 8/3, MBZUAI 4/0). Pending detected changes: Mandela 5, JADS 0, MBZUAI 0.

For every authorized future edit: authenticate an admin, verify a supported taxonomy for African-country eligibility, retain prior value, accepted value, source URL, source excerpt, reviewer ID, timestamp and transaction-level audit. Validate staging by readback and CI before production. Never treat an inaccessible source as proof a programme is discontinued.

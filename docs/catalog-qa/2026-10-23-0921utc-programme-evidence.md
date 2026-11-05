# Grantly official-source catalog QA — 2026-10-23 09:21 UTC

Scope: **staging only** (`cbzriyarlvpmtfbjgede`). Research and proposed edits, **not** authenticated reviewer acceptance, verification, archival, or publication. Preserve current published state until the audited admin workflow completes. Do not copy this document into production data without field-by-field review.

## Existing published records requiring review

### 1. Vanier Canada Graduate Scholarship — archive candidate

- Grantly ID: `0f2adcfa-4737-47bb-bee5-0bb0812cc99e`
- Existing status: published / needs_review; legacy value CAD 50,000/year for 3 years.
- UBC Graduate School explicitly marks the Vanier programme **discontinued** and states no future application deadline. The harmonized Canada Graduate Research Scholarship — Doctoral (CGRS D) replaced Vanier beginning with the fall 2025 competition.
- Official institution evidence: https://www.grad.ubc.ca/awards/vanier-scholarship
- Federal replacement programme: https://www.nserc-crsng.gc.ca/Students-Etudiants/PG-CS/CGSD-BESCD_eng.asp
- **Action:** authorize audited archival of Vanier after identity confirmation. Do not overwrite the Vanier record with CGRS D or count the replacement as a second Vanier cycle.
- Existing **private** replacement draft already present: `70931a29-0ce4-4700-bfcd-42f0b4abcbe1`, `Canada Graduate Research Scholarship — Doctoral (CGRS D), 2026 competition`. It has 6 field-provenance rows, **0 accepted**, 0 reviewer-attributed, and a successful source check at 2026-10-23 04:11 UTC. Its 2026 cycle uses agency/institution-specific deadlines, not one universal deadline. CGRS D is CAD 40,000/year for 36 months, not a tuition waiver. Do not publish until legitimate approval and readiness checks pass.

### 2. Norway Quota Scheme — archive candidate

- Grantly ID: `6b9104ae-8be9-47d0-a972-c05dee118b38`
- Published generic Master's record claims unrestricted nationality and no tuition plus stipend; no current named programme URL.
- Norway's Ministry of Education circular F-03-15 (21 October 2015) describes the phase-out of the Quota Scheme from academic year 2016–17.
- Primary government evidence: https://www.regjeringen.no/no/dokumenter/Rundskriv-om-kvoteordningen/id2458725/
- The current official Norwegian tuition guide says non-EU/EEA/Swiss degree students normally pay tuition, subject to specific exemptions: https://studyinnorway.no/tuition-fees-students
- **Action:** authorized audited archival of the obsolete Quota Scheme, not a blanket claim that every current Norwegian scholarship has ended.

### 3. Rice University International Scholarship — clarify need-based aid vs merit

- Grantly ID: `6445ac32-0aef-4f09-8183-e80b38cf356d`
- Existing generic undergraduate record: `ALL` nationality, `Need-based full financial aid`, no cycle/deadline, university homepage URL, zero provenance.
- Rice offers need-based financial aid to a **limited number** of international first-year applicants; admissions are **need-aware**. Admitted international students **receiving** need-based aid have 100% of demonstrated need met by institutional grants, but that is not a universal award guarantee. International transfer applicants are **ineligible** for Rice need-based and merit-based aid. International students cannot apply for aid in later years if they did not request it at admission.
- Official aid page: https://financialaid.rice.edu/apply-aid/international-students
- 2027–28 **CSS Profile financial-aid deadlines**: Early Decision I **15 Nov 2026**, Early Decision II **4 Jan 2027**, Regular Decision **1 Feb 2027**. These are route-specific aid deadlines, not separate scholarship application dates.
- Official admissions page: https://admission.rice.edu/apply/first-year-international-applicants
- Language **admission** requirement if no exemption from 2 years of full-time English-language curriculum: IELTS **7.0**; TOEFL iBT **100** on exams before 21 Jan 2026, or **5.0** on the revised scale on/after that date. These are admission standards, not separately established scholarship thresholds.
- SAT/ACT **recommended, not required** for admission in the 2026–27 application cycle; do not set `sat_required=true`.
- The admissions page separately documents merit scholarships automatically considered for admitted domestic and international first-years. Do not merge need-based aid and merit scholarships into one fixed grant.
- **Action:** refine programme identity, eligibility, funding, deadline_notes and field-level source provenance. Retain `needs_review` until approval.

### 4. University of Western Australia Global Excellence Scholarship — 2027 deadline evidence

- Grantly ID: `5f17a4c3-1dcc-40d8-9577-000a723f894f`
- Already published as partial 10%/20% tuition discount for 2027, 6 provenance rows / 2 accepted; do not create a duplicate.
- Official 2027 page: https://www.uwa.edu.au/study/scholarships-and-fees/scholarships/international-scholarships/global-excellence-scholarship
- Official scholarship listing: https://www.uwa.edu.au/study/scholarship-listing/uwa-global-excellence-scholarship-f1917561
- Listing application period **1 Jul–22 Dec 2026**; automatic consideration through course admission (no separate scholarship form). Undergraduate: equivalent ATAR 85–89.95 = 10% discount; ATAR 90+ = 20%. Postgraduate: WAM 65–74.99 = 10%; WAM 75+ = 20%. Eligible international applicants from all countries; course exclusions apply. No stipend or tuition-free guarantee.
- **Action:** attach programme-specific listing and distinguish scholarship-listing closing date from an independent application deadline; review accepted provenance with attributed reviewer.

### 5. University of Oulu International Scholarship — confirm limited partial waivers

- Grantly ID: `58307b7b-eda6-4b36-9cf2-ad5ff18bc67b`
- Existing record already notes partial continuing-student waivers, not full funding. Keep that distinction.
- Official programme guide: https://www.oulu.fi/en/apply/how-apply/university-oulu-tuition-fees-and-scholarships-for-international-applicants
- No 100% tuition scholarship; continuing-student waiver depends on degree programme, 60 ECTS in prior academic year including mandatory Finnish studies, and other programme conditions. Early-bird first-year discounts are a different benefit. No living-cost stipend established.
- **Action:** verify each eligible programme and intake before giving a universal date/amount; keep `needs_review` pending provenance review.

## Four new UWA programme-specific **private-draft proposals** (not inserted)

All four are distinct named awards from the already-published Global Excellence Scholarship. Targeted staging title/URL checks found no exact matching scholarship or source candidate. Run semantic similarity and source-fingerprint checks again before any insertion. IELTS/TOEFL/SAT: no programme-specific numeric requirements established in the reviewed scholarship sources; leave null unless an applicable admission requirement is independently sourced.

| Proposed programme | Official evidence | Funding and degree | Current timing | Key eligibility and review caveat |
| --- | --- | --- | --- | --- |
| UWA International Student Award | https://www.uwa.edu.au/study/scholarships-and-fees/scholarships/international-scholarships/international-student-award and https://www.uwa.edu.au/study/Scholarship-Listing/uwa-international-student-award-f221201 | 10% tuition discount, eligible UG/PG, 2027 entry | Listing open 31 Aug–22 Dec 2026; automatically assessed with offer | Specified passport-country list; **public landing page and detailed listing disagree** on countries (listing additionally includes Indonesia, Malaysia, Thailand, Vietnam and omits some landing-page entries). Do not publish a definitive nationality array until resolved. |
| UWA ASEAN Scholarship | https://www.uwa.edu.au/study/scholarships-and-fees/scholarships/international-scholarships/asean-scholarship and https://www.uwa.edu.au/study/scholarship-listing/uwa-asean-scholarship-f191752 | 15% tuition discount; degree level **needs resolution** | Listing open 31 Aug–22 Dec 2026 | Brunei, Cambodia, Indonesia, Laos, Malaysia, Myanmar, Philippines, Singapore, Thailand, Vietnam, Timor-Leste; public page says UG/PG while detailed listing says **postgraduate only**. Do not mark Bachelor eligible until clarified. |
| UWA Singapore Polytechnic Scholarship | https://www.uwa.edu.au/study/scholarship-listing/uwa-singapore-polytechnic-scholarship-f269491 | 25% tuition discount (listing also states AUD 12,000/year); eligible Bachelor programmes only | Listing open 2 Apr 2026–31 Jul 2028; automatic consideration | Must have completed diploma at Nanyang, Ngee Ann, Republic, Singapore, or Temasek Polytechnic; eligible degrees: Business, Commerce, Engineering (Honours), Biomedical Science, Science; no separate scholarship form. Confirm how 25% relates to the listing's AUD 12,000/year before finalizing value field. |
| UWA Global Alumni Pathway Scholarship | https://www.uwa.edu.au/study/scholarships-and-fees/scholarships/international-scholarships/global-alumni-pathway-scholarship and https://www.uwa.edu.au/study/scholarship-listing/uwa-global-alumni-pathway-scholarship-f2620761 | 10% tuition discount; eligible postgraduate coursework | Listing open 31 Aug–22 Dec 2026 | International student on Australian student visa; completed UWA Bachelor's/Honours or at least one semester of UWA study-abroad/exchange; eligible full-time postgraduate course. |

## Safe publication/archival gate

1. Verify unique programme identity, active cycle, source freshness and official source URLs.
2. Record field-specific source URLs and evidence for funding, degree, nationality/residence, language testing and application stages. Leave unknown fields null; do not infer IELTS/TOEFL/SAT from other awards.
3. Resolve UWA country-list and degree-level contradictions before candidate promotion.
4. Obtain authenticated Grantly admin reviewer attribution, source-audit success, accepted provenance and draft-readiness success; use only approved application functions.
5. For obsolete published records, use authorized **audited** archival, never unlogged status updates.
6. Validate staging readback and CI; do not merge or deploy to production without both.

## Staging baseline (independent initial read)

2026-10-23 09:21:57 UTC: published **397**, published needs_review **309**, private drafts **83**, archived **75**, provenance rows **557**, accepted provenance **207**, reviewer-attributed **0**, source candidates **636**, admin action logs **8**. `auth.uid()` NULL and `is_admin()` FALSE. No database write authorized by this evidence document.

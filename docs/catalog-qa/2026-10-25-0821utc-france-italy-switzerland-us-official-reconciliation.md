# Grantly official-source catalog reconciliation — 2026-10-25 08:21–08:23 UTC

Scope: **staging only** `cbzriyarlvpmtfbjgede`. **Research proposals, not accepted edits**. No staging write, no publication, no draft creation, no archival, no production change. Authenticated administrator session unavailable: `auth.uid() = NULL`, `is_admin() = false`; management SQL role `postgres` is not an authenticated application admin. Do not bypass this check.

## Independent staging readbacks

| Metric | Initial (08:21 UTC) | Final (08:23:09 UTC) |
| --- | ---: | ---: |
| Published | 397 | 397 |
| Published needs_review | 309 | 309 |
| Private drafts | 83 | 83 |
| Archived | 75 | 75 |
| Field provenance | 557 | 557 |
| Accepted values | 207 | 207 |
| Reviewer-attributed provenance | 0 | 0 |
| Source candidates | 637 | 637 |
| Admin action logs | 8 | 8 |

## Published records — official-source field proposals (12 records)

1. **Emile Boutmy Scholarship** `2ae14d86-bf95-4410-b366-a70c53e02db9` — reconcile with published `a88b8389-ce8a-4852-9080-b2e8508028d2`. Change `eligible_nationalities=['ALL']` to non-EU first-time applicant restriction, household taxation outside EU, and named exceptions; change obsolete `tuition_coverage='Up to €13,000/year'` to Bachelor's full or €9,500 waiver, Master's €18,500/year for two years. Add `application_cycle='2027 intake'` and deadline notes: Bachelor's foreign secondary January 13, 2027; French-secondary April 1, 2027; Master's October 18 / November 29, 2026 committee deadlines. **Do not use one universal deadline**. Scholarship page has no universal IELTS/TOEFL/SAT cutoff. [Sciences Po official](https://www.sciencespo.fr/students/en/fees-funding/bursaries-financial-aid/emile-boutmy-scholarship/).

2. **Sciences Po Emile Boutmy Scholarship** `a88b8389-ce8a-4852-9080-b2e8508028d2` — second published listing of the same named programme; canonical/duplicate review before any archival. Missing scholarship route-specific deadline; already lists 2027 cycle. Same official source as #1.

3. **Sciences Po Excellence Scholarship** `5965ccdb-35e0-48c5-8744-3b7e1e5a9fe4` — generic programme identity and unsupported `tuition_coverage='€10,000/year'`; do not automatically map to Boutmy, nor mark discontinued. Hold for identity evidence from a programme-specific official page. [Sciences Po funding](https://www.sciencespo.fr/students/en/fees-funding/bursaries-financial-aid/emile-boutmy-scholarship/).

4. **ENS International Selection** `20226edb-624c-4087-ac42-0454f95efc99` — **already has correct** 2026-12-15 deadline and 2027 cycle. Correct `fields` to include humanities/literature alongside sciences. €1,000/month for three years and an ENS campus room (not necessarily free accommodation); ENS diploma and Master's upon completion. Both tracks close **December 15, 2026, 14:00 Paris time**. No universal IELTS/TOEFL/SAT cutoff established. [ENS official](https://www.ens.psl.eu/une-formation-d-exception/admission-concours/international/concours-selection-internationale).

5. **EDISU Piemonte Scholarship** `c6859e53-c906-4d1e-845c-419d94d0936a` — add `application_cycle='2026/27'`; degree-specific deadline notes: Bachelor/Master/single-cycle Master **September 4, 2026 at noon Italy time (closed)**; PhD/specialisation **October 28–November 27, 2026 at noon Italy time**. Benefits conditional on income/merit/residence; no guaranteed universal full funding. Do not store a single universal deadline. [EDISU official](https://edisu.piemonte.it/en/scholarships-and-grants/financial-benefits/scholarship-and-grants).

6. **Politecnico di Milano Computer Science Masters Award** `15f0ff80-01f5-46f8-b270-03de0a9cd435` — generic identity not found in the named 2027/28 merit call. Do not assign a merit-tier deadline or funding before mapping identity. [Polimi 2027/28 official call](https://dynamicpoli.polimi.it/fileadmin/user_upload/futuri_studenti/borse-di-studio/Merit_Based_Call_For_Applications_a.y._2027-2028.pdf).

7. **Politecnico di Milano International Scholarship** `1a68ac36-20b8-4141-9148-09222d79d716` — generic umbrella overlaps five named merit tiers. Official 2027/28 application **December 15, 2026 at 12:00 Italy time**; prerequisite MSc admission application fee paid by **December 1, 2026**; English certificate by **March 4, 2027**. Full first-year tuition waiver in all tiers, ~€190 admin fee; *additional gross* grant depends on tier (€10,000 Platinum, €8,000 Milan Gold, €5,000 Piacenza Gold, €2,500 Piacenza Bronze, €0 Silver). Current `tuition_coverage` and `stipend` falsely imply every student receives €10,000. Reconcile umbrella versus tier records before edits. [Official 2027/28 PDF](https://dynamicpoli.polimi.it/fileadmin/user_upload/futuri_studenti/borse-di-studio/Merit_Based_Call_For_Applications_a.y._2027-2028.pdf).

8. **Politecnico di Milano Masters Excellence Scholarship** `801544bc-b412-44cb-be0d-af0026c11db3` — unsupported fixed €5,200/year; reconcile to actual named merit tier before applying deadline/funding. Same official 2027/28 PDF as #7.

9. **EPFL Excellence Fellowship** `2649d957-9d5e-4650-aff1-2d6800d7c85c` — overlaps already-published verified `5120827d-8613-43eb-83d7-2d5ad94c7594` (EPFL Excellence Master Fellowships). Official 2027 funding **CHF 10,000/semester**, guaranteed access to housing (not necessarily free housing); external application deadline **December 15, 2026**, internal consecutive Master **January 31, 2027**. Existing deadline notes already largely correct; canonical duplicate review, no independent count. [EPFL official](https://www.epfl.ch/education/master/master-excellence-fellowships/).

10. **AAUW International Fellowship** `b253fed7-f9b8-47bd-90ef-f340c265afc9` — 2027/28 deadline **September 17, 2026 17:00 ET (closed)** and stipend **$20,000 Master's / $25,000 doctorate** are already correct. Replace `eligible_nationalities=['ALL']` with non-US-citizen/non-US-permanent-resident restrictions and other study-location conditions; eligibility limited to women in STEM degree programmes, first Master's/doctoral degree and GPA >=3.5/4.0. Stored `min_ielts=6.5` is not supported as a universal *scholarship* threshold on reviewed AAUW page: investigate/clear only through authenticated evidence review, not an invented substitute. [AAUW official](https://www.aauw.org/resources/programs/fellowships-grants/aauw-international-fellowships/).

11. **Columbia University Obama Foundation Scholars** `200b5ee0-4879-43e2-8d90-f89eff5c4948` — published as fully funded Master's with guaranteed tuition, living and travel. Historical Columbia track was a **non-degree leadership immersion**; **2026/27 programme is University of Chicago graduate students**, not confirmed new Columbia intake. Programme identity and catalog scope review; do not silently relabel Columbia as Chicago or archive solely for absence of a 2026/27 Columbia cohort. [2026/27 Obama Foundation official](https://www.obama.org/press-releases/2026-2027-university-of-chicago-scholars/) and [2025/26 Columbia official](https://www.obama.org/press-releases/the-obama-foundation-introduces-2025-2026-class-of-obama-scholars/).

12. **Adobe Research Fellowship** `b39558a9-6d36-4928-9912-cab45c9b884b` — generic USA record says $10,000 + internship without a confirmed current programme call. Do not confuse with separate **Adobe India AI Research Fellowship**, already in staging as draft `79930d9a-c401-4b14-b027-70ffff9f15a0`; India programme awards INR 1,200,000 to eligible India-enrolled PhD AI researchers, and 2026 applications are closed. Generic USA record requires its own official cycle and funding evidence. [Adobe India official](https://research.adobe.com/india-ai-research-fellowship/).

## 2027 named scholarship leads — not yet approved/published

**One newly identified distinct programme candidate:** [ENS Bourses Olympiques 2027](https://www.ens.psl.eu/une-formation-d-exception/admission-concours/international/bourses-olympiques), deadline **January 18, 2027**. Gold/silver International Mathematics/Physics Olympiad medal required; final-year secondary or first three higher-ed years; restrictions on recent French enrolment. ENS entrants receive €1,000/month for three years; preparatory stage can receive €500/month; subsidised accommodation and an annual round-trip may be available. ENS diploma confers Master's grade, but some winners enter a preparatory stage first. No exact-title scholarship/source-candidate match in targeted staging queries. **Scope/semantic duplicate review still required.**

**Five distinct named 2027/28 award tiers under one Polimi application call:** Milan Platinum (€10,000 gross + waiver), Milan Gold (€8,000 + waiver), Piacenza Gold (€5,000 + waiver), Piacenza Bronze (€2,500 + waiver), regional Silver (tuition waiver only). Each is explicitly named and has different campus/degree requirements; shared deadline **December 15, 2026 at 12:00 Italy time**. **Do not count five independent programmes until canonical/umbrella policy is resolved.** Official call linked above.

## Four existing private drafts assessed

- `79930d9a-c401-4b14-b027-70ffff9f15a0` Adobe India AI Research: closed 2026, 1 provenance, 0 reviewer attribution, no successful source audit. Hold for new cycle.
- `e9e933fa-8bad-47dd-8fd3-f20df87ace89` Geneviève McMillan-Reba Stewart Foundation — Sciences Po 2027: 3 provenance, 0 reviewer attribution, no successful audit. Check independent identity versus Boutmy sponsor; deadline 2027-01-13.
- `d8ec0b3a-c82c-4592-bb7e-20d468118dc0` EPFL MX Master Fellowship: deadline 2026-11-01; 2 provenance, 0 reviewer attribution, no successful audit. Urgent authenticated review.
- `719cccf5-54e5-4680-a5c0-8e930a8a839c` Mick Hitchcock PhD Scholarship: deadline 2026-10-31; 0 provenance, 0 reviewer attribution, last successful audit 2026-10-05. Urgent provenance and refreshed source audit.

## Gate and outcome

Authenticated application functions inspected: `publish_scholarship_draft`, `update_scholarship_draft`, `record_scholarship_field_provenance`, `promote_source_candidate_to_draft`. They require real admin authentication (candidate promotion alternatively genuine service role). SQL management role is not an application admin; no permission bypass attempted. **Staging edits: 0; publications: 0; database drafts: 0; provenance writes: 0; archival: 0; production: 0.** This file is a review artifact only. Keep QA PR draft until actual staging changes pass CI and audited gates.

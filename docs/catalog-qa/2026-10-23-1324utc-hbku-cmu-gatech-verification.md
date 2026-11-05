# Grantly staging catalog QA — 2026-10-23 13:24 UTC — HBKU, CMU, Georgia Tech

**Status:** official-source research / proposed changes only. **No scholarship row, provenance row, status, or production data was modified.** Do not set `verified`, publish, or archive from this document alone. Administrative approval, programme-specific evidence, field provenance, source audit, semantic duplicate reconciliation, staging validation and CI are required.

**Staging baseline:** 397 published, 309 published needs_review, 83 private drafts, 75 archived, 557 provenance entries (207 with accepted_value, 0 reviewer-attributed), 636 source candidates. Project `cbzriyarlvpmtfbjgede`. Read at 2026-10-23 13:24:33 UTC.

## A. HBKU — six published needs_review records, four particularly misleading

**Primary official funding policy:** https://www.hbku.edu.qa/en/scholarship (read October 23, 2026). Official 2027 College of Science and Engineering admission dates: https://www.hbku.edu.qa/en/cse/admission-requirements .

Official HBKU policy: STEM master's tuition waiver **75%**, SHAPE master's **60%**, STEM/SHAPE PhD **100%**, and some other degrees **0%**; waivers and stipends are *not guaranteed*, depend on merit/need and available funds. Selected international master's recipients may receive **QAR 7,000/month up to 21 months**, international PhD recipients **QAR 9,000/month up to 45 months**, subject to RA/TA commitments and other conditions. **HBKU does not pay housing directly**: students pay for housing from their stipend or personal funds. International students awarded the relevant scholarship may receive one round-trip flight. No separate scholarship application; considered during admissions. For CSE graduate admissions the **international applicant deadline is 2027-02-01**; the **Qatari/resident funding applicant deadline is 2027-03-15**. These are CSE admission dates, not universal scholarship deadlines across every college.

| Published ID | Current Grantly title | Source-backed QA action |
|---|---|---|
| `04e3ba48-f760-4160-b0e1-dee3fa966f39` | HBKU Masters Excellence Scholarship | Current `Fully funded`, `Full tuition + stipend + housing`, `accommodation=true` are not supported by the official policy. Resolve programme identity and correct housing/funding; don't claim a separately named Excellence scholarship without programme-specific proof. |
| `06e74eed-5282-456d-8e97-8b235be85ba7` | HBKU Masters International Scholarship | Same unsupported universal full-tuition and direct-housing claims; likely overlapping generic institutional aid, not proven separate named scholarship. |
| `cf8c0a33-3ea6-4e23-8132-7dc313d27576` | HBKU Phd Excellence Scholarship | PhD tuition waivers can be 100% for eligible programmes, but stipend is conditional and housing is not directly covered. Identity reconciliation needed. |
| `9465904e-4c22-4198-871f-c83e1e2d22ea` | HBKU Phd International Scholarship | Same housing/stipend misrepresentation; confirm programme identity and avoid counting generic aid multiple times. |
| `891681ad-b022-431d-85f3-e9acc21525e9` | HBKU Engineering Masters Award | Funding text already partially reflects conditional 75%/QAR 7k; official URL is generic homepage, deadline/cycle missing; confirm whether an independently named award exists. |
| `e618915f-c5e8-46f8-a240-ec2bb721f1da` | HBKU Engineering Phd Award | Funding text already partially reflects conditional 100%/QAR 9k; official URL generic; verify programme identity before changing status. |

**Field provenance to create upon authorized review:** `tuition_coverage` and `funding_type` (official HBKU waiver table), `stipend` (stipend rates/conditions), `accommodation` (explicit no direct housing), `deadline_notes` / `application_cycle` (CSE admissions page, programme-specific), `official_url` (scholarship policy). **No universal IELTS/TOEFL/SAT values**: check individual programme admissions, and do not assign an institution-wide scholarship score.

## B. Carnegie Mellon — six generic published needs_review records, no programme-specific scholarship source

**Official CMU graduate funding information:** https://www.cmu.edu/graduate/funding/index.html ; College of Engineering https://engineering.cmu.edu/education/graduate-studies/admissions/financial-support/fellowship-assistantships.html ; department-specific PhD RA example https://www.meche.engineering.cmu.edu/education/graduate-programs/tuition.html .

All six records below link to the **university homepage**, have no cycle/deadline, and advertise generic `Partial to full funding` rather than a verifiable independently named award:

| Published ID | Title |
|---|---|
| `cf309cba-9022-452d-8167-4918e983d31e` | Carnegie Mellon University Artificial Intelligence Phd Award |
| `7d4d972e-8d8a-4fed-bc49-04a6a09a45fe` | Carnegie Mellon University Engineering Masters Award |
| `4ea5d339-fd12-41f1-a687-cbbab217bcb3` | Carnegie Mellon University Masters Excellence Scholarship |
| `a05a5eea-5e4b-4c7e-b2ff-cd45ffcf842f` | Carnegie Mellon University Masters International Scholarship |
| `e607d235-4b60-432a-a09c-b0ad1e49d468` | Carnegie Mellon University Phd Excellence Scholarship |
| `3ff7f86c-7a78-4c97-b664-d6d4fd0661a7` | Carnegie Mellon University Phd International Scholarship |

**Disposition:** Do NOT automatically archive as discontinued; programme identity is *unsubstantiated*, not proven discontinued. Hold `needs_review`, search for programme-specific sources, and only reconcile/archive after audited authorized identity determination. CMU publishes real **separately named** awards (Rales Fellows, CyberCorps SFS, etc.), not proof for the generic six. Assistantships may be paid work and are not automatically scholarships.

## C. Georgia Tech — four generic published needs_review records

**Official institution-wide funding guidance:** https://grad.gatech.edu/paying-for-grad-school . GRAs/GTAs are **employment appointments**, typically with tuition waiver and stipend; not an independently named grant for every master's or PhD student. The university says about half of graduate students are employed as GRAs/GTAs, including four in five doctoral students; funding is departmental and conditional.

| Published ID | Title |
|---|---|
| `22202603-cad3-4340-bf82-eed3b0d27430` | Georgia Tech Computer Science Masters Award |
| `92ee615e-4258-41cf-81de-3dae55a1fac6` | Georgia Tech Masters Excellence Scholarship |
| `d814504a-b715-461e-b486-b7b16cf32906` | Georgia Tech Phd Excellence Scholarship |
| `26897df1-236d-4164-b821-96485342ea40` | Georgia Tech Phd International Scholarship |

All four link only to the university homepage, have no confirmed deadline or cycle, and describe teaching/research assistantships. Do not relabel assistantship *jobs* as universal grant programmes. Hold for programme identity reconciliation, not discontinuation.

## D. Five distinct official named scholarship/fellowship candidates (PRIVATE draft proposals, not inserted)

Targeted staging title and URL searches on October 23 returned **zero matches** among existing `scholarships` and `scholarship_source_candidates`; full semantic/alias duplicate clearance is still required.

1. **CMU Rales Fellows Program — 2027**. Official https://www.cmu.edu/graduate/rales-fellows/admission and https://www.cmu.edu/graduate/rales-fellows/about-the-program . Full tuition plus living stipend for selected eligible in-person Pittsburgh STEM master's/doctoral students. Restricted to **U.S. citizens, permanent residents, or DACA recipients** who also meet need/first-generation criteria. **2027 priority review December 15, 2026** (programme-specific degree deadlines still apply). Do not mark globally eligible; stipend amount not universally established in these primary pages. IELTS/TOEFL/SAT scholarship cutoffs not specified.
2. **CMU CyberCorps Scholarship for Service (SFS@CMU)**. Official https://www.cmu.edu/ini/about/sfs.html . For eligible **U.S. citizens or lawful permanent residents** in full-time MSIS or MSAIE-IS; full tuition, **US$37,000 academic-year stipend**, up to **US$4,000/year professional development**; federal service obligation and security-clearance eligibility. Separate 2026/27 deadline not confirmed. Do not imply unrestricted international eligibility.
3. **Georgia Tech Roberto C. Goizueta Fellowship — 2026 competition**. Official https://grad.gatech.edu/events/2026-roberto-c-goizueta-fellowship . **US$6,000 per academic year**, renewable up to eight terms / **US$24,000** maximum, for eligible full-time on-campus Atlanta master's/doctoral students who are **U.S. citizens or permanent residents**; academic, leadership, community, need criteria. **Deadline October 30, 2026, 23:59 Eastern Time**. No tuition-waiver claim; award may supplement other support.
4. **Dolores Zohrab Liebmann Fellowship — Georgia Tech 2027/28 nomination**. Official https://grad.gatech.edu/events/2027-2028-dolores-zohrab-liebmann-fellowship . **Actual tuition excluding fees plus US$18,000/year stipend**, renewable up to three years; **U.S. citizen**, already enrolled graduate student with financial need. **Georgia Tech internal deadline December 4, 2026**, external fund nomination **January 22, 2027**. Max three institutional nominees; no direct application to fund. This is an **external fellowship** with Georgia Tech-specific nomination route; avoid inventing a separate global deadline.
5. **Georgia Tech Institute Fellowship (GTIF)**. Official https://grad.gatech.edu/georgia-tech-institute-fellowship . Additional **US$1,000 per term** *on top of* a President's Fellowship, for selected U.S. citizens/permanent residents applying to Georgia Tech PhD programmes, top 10% of applicant pool; internally nominated/selected. Renewable up to three additional academic years; no standalone public application deadline confirmed. **Partial supplemental fellowship, not fully funded by itself.**

**Proposed provenance fields for each private candidate:** title, provider, degree levels, country, eligible nationalities, funding type, tuition/stipend amount, deadline with precise type/timezone, application cycle, application pathway, official programme URL, restrictions, and `unknown` for scholarship-specific IELTS/TOEFL/SAT unless officially documented. Do not fabricate SAT, IELTS, TOEFL scores or claim universal scholarship eligibility.

## E. Private-draft readiness and publication governance

Staging currently returns `auth.uid() = NULL`, `public.is_admin() = FALSE`. `publish_scholarship_draft` and `scholarship_draft_readiness` require authenticated admin. `promote_source_candidate_to_draft` additionally requires candidate `accepted` or valid authorized service-role context. Management SQL must **not** be used to bypass these guards. The readiness function currently checks source registry, link status, successful audit within 30 days, failure count, ambiguous deadlines and closed cycles; it does **not itself enforce reviewer-attributed field provenance**. Operational review must therefore explicitly enforce provenance before publication rather than treating the function's `ready` flag alone as sufficient.

Urgent private draft blockers observed:
- `2e2644ab-186a-4c84-9a63-cbf761e9ead2` Gordon & Isabel Humphrey, closes Oct 25: `exact` link but no successful audit; 2 accepted-value provenance rows, zero reviewer attribution.
- `27968090-2edf-464d-9236-76f5186b741b` EPFL-WISH, closes Oct 25: `exact` link but no successful audit; 3 provenance rows, none accepted.
- `719cccf5-54e5-4680-a5c0-8e930a8a839c` Mick Hitchcock, closes Oct 31: successful audit Oct 5, **zero provenance rows**.

**Next authorized actions:** (1) obtain legitimate signed-in admin session; (2) verify programme identity and write source-specific provenance for published corrections, with audit history; (3) reconcile generic records without conflating employment and grants; (4) create new candidates as private drafts only after semantic duplicate check; (5) run source audits, human-reviewed provenance and draft readiness; (6) publish/archive through audited functions only; (7) stage/CI validation before any production action.

No automatic archive/publication justified by this document. No HTTP access failure was treated as discontinuation.

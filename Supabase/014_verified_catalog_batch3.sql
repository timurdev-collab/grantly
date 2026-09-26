-- Verify and refresh additional current scholarship programmes from official sources.

update public.scholarships
set status='archived',
    verification_status='needs_review',
    updated_at=now()
where slug in (
  'australia-awards-scholarship',
  'world-bank-scholarship',
  'world-bank-scholarship-program'
);

update public.scholarships
set deadline=null,
    application_cycle='2027 intake',
    deadline_notes='The main 2027 Australia Awards Scholarship round opened February 1, 2026 and closed April 30, 2026. Country-specific eligibility and dates apply.',
    official_url='https://www.dfat.gov.au/people-to-people/australia-awards/australia-awards-scholarships-opening-and-closing-dates',
    source_label='Australian Government DFAT official Australia Awards dates',
    source_url='https://www.dfat.gov.au/people-to-people/australia-awards/australia-awards-scholarships-opening-and-closing-dates',
    verification_status='verified',
    link_status='exact',
    verified_at=now(),
    last_checked_at=now(),
    final_url='https://www.dfat.gov.au/people-to-people/australia-awards/australia-awards-scholarships-opening-and-closing-dates',
    updated_at=now()
where slug='australia-awards';

update public.scholarships
set deadline='2026-12-01',
    application_cycle='2027/28',
    deadline_notes='Initial HKPFS applications close December 1, 2026 at 12:00 noon Hong Kong time. Applicants must also meet their selected universities'' PhD application deadlines.',
    official_url='https://cerg1.ugc.edu.hk/hkpfs/apply.html',
    source_label='Hong Kong Research Grants Council official HKPFS application page',
    source_url='https://cerg1.ugc.edu.hk/hkpfs/apply.html',
    verification_status='verified',
    link_status='exact',
    verified_at=now(),
    last_checked_at=now(),
    final_url='https://cerg1.ugc.edu.hk/hkpfs/apply.html',
    updated_at=now()
where slug='hong-kong-phd-fellowship-scheme';

update public.scholarships
set deadline='2027-04-01',
    application_cycle='2027/28',
    deadline_notes='Applications open October 15, 2026 and close April 1, 2027 at 16:00 CET for programmes starting September 2027.',
    official_url='https://www.utwente.nl/en/education/scholarship-finder/university-of-twente-scholarship/',
    source_label='University of Twente official scholarship finder',
    source_url='https://www.utwente.nl/en/education/scholarship-finder/university-of-twente-scholarship/',
    verification_status='verified',
    link_status='exact',
    verified_at=now(),
    last_checked_at=now(),
    final_url='https://www.utwente.nl/en/education/scholarship-finder/university-of-twente-scholarship/',
    updated_at=now()
where slug='university-of-twente-scholarship-uts';

update public.scholarships
set deadline=null,
    application_cycle='2027 entry',
    deadline_notes='UCL states that the 2027 Global Master''s Scholarship deadline is expected to be in early May 2027; the exact date has not yet been published.',
    official_url='https://www.ucl.ac.uk/study/prospective-students/graduate/funding-your-masters/fund-your-masters-global-masters-scholarship',
    source_label='UCL official Global Master''s Scholarship page',
    source_url='https://www.ucl.ac.uk/study/prospective-students/graduate/funding-your-masters/fund-your-masters-global-masters-scholarship',
    verification_status='verified',
    link_status='exact',
    verified_at=now(),
    last_checked_at=now(),
    final_url='https://www.ucl.ac.uk/study/prospective-students/graduate/funding-your-masters/fund-your-masters-global-masters-scholarship',
    updated_at=now()
where slug='ucl-global-masters-scholarship';

update public.scholarships
set deadline=null,
    application_cycle='2028/29',
    deadline_notes='The 2027/28 Rotary Peace Fellowship round is closed. Rotary says the 2028/29 application will become available in February 2027.',
    official_url='https://www.rotary.org/en/our-programs/peace-fellowships',
    source_label='Rotary International official Peace Fellowships page',
    source_url='https://www.rotary.org/en/our-programs/peace-fellowships',
    verification_status='verified',
    link_status='exact',
    verified_at=now(),
    last_checked_at=now(),
    final_url='https://www.rotary.org/en/our-programs/peace-fellowships',
    updated_at=now()
where slug='rotary-peace-fellowship';

insert into public.scholarships (
  slug,title,provider,country,region,degree_levels,fields,funding_type,
  tuition_coverage,stipend,airfare,accommodation,health_insurance,
  eligible_nationalities,deadline,official_url,status,verified_at,description,
  source_label,source_url,verification_status,application_cycle,deadline_notes,
  link_status,last_checked_at,final_url
) values (
  'jj-wbgsp-2027',
  'Joint Japan/World Bank Graduate Scholarship Program (JJ/WBGSP)',
  'World Bank','Multiple','Global',array['Master'],array['All fields'],'Fully funded',
  'Tuition for participating Master''s programmes',
  'Monthly subsistence allowance; amount varies by host country',
  true,false,true,array['ALL'],'2027-02-26',
  'https://www.worldbank.org/en/programs/scholarships/jj-wbgsp',
  'published',now(),
  'World Bank graduate scholarship for eligible developing-country nationals admitted to participating development-related Master''s programmes.',
  'World Bank official JJ/WBGSP page',
  'https://www.worldbank.org/en/programs/scholarships/jj-wbgsp',
  'verified','2027',
  'Window 1 runs January 18-February 26, 2027. Window 2 runs March 29-May 21, 2027.',
  'exact',now(),
  'https://www.worldbank.org/en/programs/scholarships/jj-wbgsp'
)
on conflict (slug) do update set
  deadline=excluded.deadline,
  official_url=excluded.official_url,
  status=excluded.status,
  verified_at=excluded.verified_at,
  description=excluded.description,
  source_label=excluded.source_label,
  source_url=excluded.source_url,
  verification_status=excluded.verification_status,
  application_cycle=excluded.application_cycle,
  deadline_notes=excluded.deadline_notes,
  link_status=excluded.link_status,
  last_checked_at=excluded.last_checked_at,
  final_url=excluded.final_url,
  updated_at=now();

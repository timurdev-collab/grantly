-- Refresh major global scholarship programmes using current official sources.

update public.scholarships
set status='archived',
    verification_status='needs_review',
    updated_at=now()
where slug in (
  'chevening-scholarship',
  'clarendon-scholarship-oxford',
  'mext-scholarship-japan',
  'turkiye-burslari'
);

update public.scholarships
set deadline='2026-10-06',
    application_cycle='2027/28',
    deadline_notes='Applications close October 6, 2026 at 11:00 UTC.',
    official_url='https://www.chevening.org/scholarships/application-timeline/',
    source_label='Chevening official application timeline',
    source_url='https://www.chevening.org/scholarships/application-timeline/',
    verification_status='verified',
    link_status='exact',
    verified_at=now(),
    last_checked_at=now(),
    final_url='https://www.chevening.org/scholarships/application-timeline/',
    updated_at=now()
where slug='chevening';

update public.scholarships
set deadline=null,
    application_cycle='2027 entry',
    deadline_notes='Applicants are automatically considered by applying to an eligible Oxford Master''s or DPhil course by that course''s December or January funding deadline.',
    official_url='https://www.ox.ac.uk/admissions/graduate/fees-and-funding/funding/clarendon/applicants',
    source_label='University of Oxford Clarendon applicant information',
    source_url='https://www.ox.ac.uk/admissions/graduate/fees-and-funding/funding/clarendon/applicants',
    verification_status='verified',
    link_status='exact',
    verified_at=now(),
    last_checked_at=now(),
    final_url='https://www.ox.ac.uk/admissions/graduate/fees-and-funding/funding/clarendon/applicants',
    updated_at=now()
where slug='clarendon';

update public.scholarships
set deadline=null,
    application_cycle='2027 entry',
    deadline_notes='Applications opened June 1, 2026 for most constituencies. Closing dates vary by constituency; applicants must use the Rhodes constituency page for their deadline.',
    official_url='https://www.rhodeshouse.ox.ac.uk/scholarships/applications/',
    source_label='Rhodes Trust official applications portal',
    source_url='https://www.rhodeshouse.ox.ac.uk/scholarships/applications/',
    verification_status='verified',
    link_status='exact',
    verified_at=now(),
    last_checked_at=now(),
    final_url='https://www.rhodeshouse.ox.ac.uk/scholarships/applications/',
    updated_at=now()
where slug='rhodes';

update public.scholarships
set deadline=null,
    application_cycle='2027 Embassy Recommendation',
    deadline_notes='Recruitment for 2027 arrival took place around April-May 2026, with country-specific schedules handled by Japanese embassies and consulates.',
    official_url='https://www.studyinjapan.go.jp/en/planning/scholarships/mext-scholarships/',
    source_label='Study in Japan / MEXT official scholarship information',
    source_url='https://www.studyinjapan.go.jp/en/planning/scholarships/mext-scholarships/',
    verification_status='verified',
    link_status='exact',
    verified_at=now(),
    last_checked_at=now(),
    final_url='https://www.studyinjapan.go.jp/en/planning/scholarships/mext-scholarships/',
    updated_at=now()
where slug='mext';

update public.scholarships
set deadline='2027-02-20',
    application_cycle='2027 general application',
    deadline_notes='Türkiye Scholarships lists the general full-time application period every year as January 10 through February 20.',
    official_url='https://www.turkiyeburslari.gov.tr/fulltimeprograms',
    source_label='Türkiye Scholarships official full-time programmes page',
    source_url='https://www.turkiyeburslari.gov.tr/fulltimeprograms',
    verification_status='verified',
    link_status='exact',
    verified_at=now(),
    last_checked_at=now(),
    final_url='https://www.turkiyeburslari.gov.tr/fulltimeprograms',
    updated_at=now()
where slug='turkiye-scholarships';

update public.scholarships
set status='published',
    provider='Tsinghua University / Schwarzman Scholars',
    country='China',
    region='Asia',
    degree_levels=array['Master'],
    fields=array['All fields'],
    funding_type='Fully funded',
    deadline=null,
    official_url='https://www.schwarzmanscholars.org/admissions/application-instructions/',
    application_cycle='Class of 2028/29',
    deadline_notes='U.S./Global applications are scheduled for April-September 2027. Chinese passport-holder applications are scheduled for March-May 2027; exact dates have not yet been announced.',
    source_label='Schwarzman Scholars official application instructions',
    source_url='https://www.schwarzmanscholars.org/admissions/application-instructions/',
    verification_status='verified',
    link_status='exact',
    verified_at=now(),
    last_checked_at=now(),
    final_url='https://www.schwarzmanscholars.org/admissions/application-instructions/',
    updated_at=now()
where slug='schwarzman-scholars';

insert into public.scholarships (
  slug,title,provider,country,region,degree_levels,fields,funding_type,
  tuition_coverage,stipend,airfare,accommodation,health_insurance,
  eligible_nationalities,deadline,official_url,status,verified_at,description,
  source_label,source_url,verification_status,application_cycle,deadline_notes,
  link_status,last_checked_at,final_url
) values (
  'commonwealth-masters-scholarships-2027',
  'Commonwealth Master''s Scholarships',
  'Commonwealth Scholarship Commission in the UK',
  'United Kingdom',
  'Europe',
  array['Master'],
  array['All fields'],
  'Fully funded',
  'Approved tuition fees',
  'Living allowance and approved study-related support',
  true,false,false,array['ALL'],'2026-10-20',
  'https://cscuk.fcdo.gov.uk/scholarships/commonwealth-masters-scholarships/',
  'published',now(),
  'FCDO-funded scholarships for eligible candidates from low- and middle-income Commonwealth countries who could not otherwise afford study in the UK.',
  'Commonwealth Scholarship Commission official page',
  'https://cscuk.fcdo.gov.uk/scholarships/commonwealth-masters-scholarships/',
  'verified','2027/28',
  'CSC applications close October 20, 2026 at 16:00 BST. Nominating bodies may set their own earlier deadlines.',
  'exact',now(),
  'https://cscuk.fcdo.gov.uk/scholarships/commonwealth-masters-scholarships/'
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

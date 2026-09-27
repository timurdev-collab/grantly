-- Data reliability step 9: official source registry and provenance.

create or replace function public.normalize_source_host(p_url text)
returns text
language sql
immutable
security invoker
set search_path = public
as $$
  select nullif(
    regexp_replace(
      regexp_replace(lower(btrim(coalesce(p_url, ''))), '^https?://', ''),
      '/.*$',
      ''
    ),
    ''
  );
$$;

create table if not exists public.scholarship_source_registry (
  id uuid primary key default gen_random_uuid(),
  host text not null unique,
  display_name text not null,
  source_kind text not null default 'institution'
    check (source_kind in (
      'government',
      'institution',
      'foundation',
      'official_program',
      'partner',
      'other'
    )),
  trust_level integer not null default 70
    check (trust_level between 0 and 100),
  is_active boolean not null default true,
  first_seen_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),
  last_verified_at timestamptz,
  next_review_at timestamptz,
  notes text
);

alter table public.scholarship_source_registry enable row level security;

revoke all on public.scholarship_source_registry from anon, authenticated;
grant select, insert, update, delete on public.scholarship_source_registry
to authenticated;

drop policy if exists "admins read scholarship source registry"
on public.scholarship_source_registry;

create policy "admins read scholarship source registry"
on public.scholarship_source_registry
for select to authenticated
using (public.is_admin());

drop policy if exists "admins manage scholarship source registry"
on public.scholarship_source_registry;

create policy "admins manage scholarship source registry"
on public.scholarship_source_registry
for all to authenticated
using (public.is_admin())
with check (public.is_admin());

alter table public.scholarships
  add column if not exists source_registry_id uuid
  references public.scholarship_source_registry(id)
  on delete set null;

alter table public.scholarships
  add column if not exists source_authority_score integer;

alter table public.scholarships
  drop constraint if exists scholarships_source_authority_score_check;

alter table public.scholarships
  add constraint scholarships_source_authority_score_check
  check (
    source_authority_score is null or
    source_authority_score between 0 and 100
  );

create index if not exists scholarships_source_registry_idx
  on public.scholarships(source_registry_id);

insert into public.scholarship_source_registry(
  host,
  display_name,
  source_kind,
  trust_level,
  last_seen_at,
  next_review_at
)
select
  public.normalize_source_host(s.official_url) as host,
  coalesce(
    nullif(btrim(max(s.provider)), ''),
    public.normalize_source_host(s.official_url)
  ) as display_name,
  case
    when lower(public.normalize_source_host(s.official_url)) ~
      '(gov\.|\.gov$|government|studyinkorea|studyinjapan|campuschina)'
      then 'government'
    when count(distinct s.provider) = 1
      then 'institution'
    else 'other'
  end as source_kind,
  case
    when lower(public.normalize_source_host(s.official_url)) ~
      '(gov\.|\.gov$|government|studyinkorea|studyinjapan|campuschina)'
      then 95
    else 85
  end as trust_level,
  now(),
  now() + interval '30 days'
from public.scholarships s
where public.normalize_source_host(s.official_url) is not null
group by public.normalize_source_host(s.official_url)
on conflict (host) do update
set last_seen_at = excluded.last_seen_at;

update public.scholarships s
set source_registry_id = r.id,
    source_authority_score = r.trust_level
from public.scholarship_source_registry r
where r.host = public.normalize_source_host(s.official_url)
  and (
    s.source_registry_id is distinct from r.id
    or s.source_authority_score is distinct from r.trust_level
  );

create or replace function public.sync_scholarship_source_registry()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  touched integer := 0;
begin
  insert into public.scholarship_source_registry(
    host,
    display_name,
    source_kind,
    trust_level,
    last_seen_at,
    next_review_at
  )
  select
    public.normalize_source_host(s.official_url),
    coalesce(
      nullif(btrim(max(s.provider)), ''),
      public.normalize_source_host(s.official_url)
    ),
    case
      when lower(public.normalize_source_host(s.official_url)) ~
        '(gov\.|\.gov$|government|studyinkorea|studyinjapan|campuschina)'
        then 'government'
      when count(distinct s.provider) = 1
        then 'institution'
      else 'other'
    end,
    case
      when lower(public.normalize_source_host(s.official_url)) ~
        '(gov\.|\.gov$|government|studyinkorea|studyinjapan|campuschina)'
        then 95
      else 85
    end,
    now(),
    now() + interval '30 days'
  from public.scholarships s
  where public.normalize_source_host(s.official_url) is not null
  group by public.normalize_source_host(s.official_url)
  on conflict (host) do update
  set last_seen_at = excluded.last_seen_at;

  update public.scholarships s
  set source_registry_id = r.id,
      source_authority_score = r.trust_level
  from public.scholarship_source_registry r
  where r.host = public.normalize_source_host(s.official_url)
    and (
      s.source_registry_id is distinct from r.id
      or s.source_authority_score is distinct from r.trust_level
    );

  get diagnostics touched = row_count;
  return touched;
end;
$$;

revoke execute on function public.sync_scholarship_source_registry()
from public, anon, authenticated;
grant execute on function public.sync_scholarship_source_registry()
to postgres;

select cron.unschedule(jobid)
from cron.job
where jobname = 'grantly-source-registry-daily';

select cron.schedule(
  'grantly-source-registry-daily',
  '17 2 * * *',
  $$select public.sync_scholarship_source_registry();$$
);

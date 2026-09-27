-- Data reliability step 12: enrich accepted official-source candidates
-- into reviewable structured metadata without publishing automatically.

create table if not exists public.scholarship_source_candidate_profiles (
  id uuid primary key default gen_random_uuid(),
  candidate_id uuid not null unique
    references public.scholarship_source_candidates(id) on delete cascade,
  source_registry_id uuid not null
    references public.scholarship_source_registry(id) on delete cascade,
  page_title text,
  meta_description text,
  detected_deadline date,
  deadline_confidence integer
    check (deadline_confidence is null or deadline_confidence between 0 and 100),
  detected_cycle text,
  cycle_confidence integer
    check (cycle_confidence is null or cycle_confidence between 0 and 100),
  funding_excerpt text,
  application_excerpt text,
  content_fingerprint text,
  extraction_status text not null default 'pending'
    check (extraction_status in ('pending','ready','failed')),
  extraction_error text,
  checked_at timestamptz,
  updated_at timestamptz not null default now()
);

alter table public.scholarship_source_candidate_profiles enable row level security;

revoke all on public.scholarship_source_candidate_profiles
from anon, authenticated;
grant select on public.scholarship_source_candidate_profiles
to authenticated;

drop policy if exists "admins read source candidate profiles"
on public.scholarship_source_candidate_profiles;

create policy "admins read source candidate profiles"
on public.scholarship_source_candidate_profiles
for select to authenticated
using (public.is_admin());

create index if not exists scholarship_source_candidate_profiles_status_idx
  on public.scholarship_source_candidate_profiles(extraction_status, updated_at desc);

create table if not exists public.source_candidate_enrichment_config (
  id boolean primary key default true check (id),
  endpoint_url text not null,
  cron_token text not null,
  enabled boolean not null default true,
  candidate_limit integer not null default 10
    check (candidate_limit between 1 and 20),
  updated_at timestamptz not null default now()
);

alter table public.source_candidate_enrichment_config enable row level security;
revoke all on public.source_candidate_enrichment_config
from public, anon, authenticated;

create or replace function public.dispatch_source_candidate_enrichment()
returns bigint
language plpgsql
security definer
set search_path = public, extensions, net
as $$
declare
  cfg public.source_candidate_enrichment_config%rowtype;
  request_id bigint;
begin
  select * into cfg
  from public.source_candidate_enrichment_config
  where id = true and enabled = true;

  if not found then
    return null;
  end if;

  select net.http_post(
    url := cfg.endpoint_url,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-grantly-enrichment-token', cfg.cron_token
    ),
    body := jsonb_build_object(
      'limit', cfg.candidate_limit
    ),
    timeout_milliseconds := 60000
  )
  into request_id;

  return request_id;
end;
$$;

revoke execute on function public.dispatch_source_candidate_enrichment()
from public, anon, authenticated;

select cron.unschedule(jobid)
from cron.job
where jobname = 'grantly-source-candidate-enrichment';

select cron.schedule(
  'grantly-source-candidate-enrichment',
  '7 */2 * * *',
  $$select public.dispatch_source_candidate_enrichment();$$
);

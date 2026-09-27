-- Data reliability step 10: official-source scholarship link discovery.
-- Discovers candidate official scholarship/funding pages but never publishes them
-- automatically. Candidates must be reviewed before they affect the catalog.

alter table public.scholarship_source_registry
  add column if not exists next_discovery_at timestamptz;

alter table public.scholarship_source_registry
  add column if not exists last_discovery_at timestamptz;

alter table public.scholarship_source_registry
  add column if not exists discovery_failure_count integer not null default 0;

alter table public.scholarship_source_registry
  drop constraint if exists scholarship_source_registry_discovery_failure_check;

alter table public.scholarship_source_registry
  add constraint scholarship_source_registry_discovery_failure_check
  check (discovery_failure_count >= 0);

update public.scholarship_source_registry
set next_discovery_at = coalesce(next_discovery_at, now())
where is_active = true;

create index if not exists scholarship_source_registry_discovery_idx
  on public.scholarship_source_registry(next_discovery_at)
  where is_active = true;

create table if not exists public.scholarship_source_candidates (
  id uuid primary key default gen_random_uuid(),
  source_registry_id uuid not null
    references public.scholarship_source_registry(id) on delete cascade,
  candidate_url text not null,
  candidate_title text,
  discovered_from_url text not null,
  relevance_score integer not null default 0
    check (relevance_score between 0 and 100),
  status text not null default 'pending'
    check (status in ('pending','accepted','rejected','ignored')),
  first_seen_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),
  reviewed_at timestamptz,
  reviewed_by uuid references auth.users(id) on delete set null,
  review_note text,
  unique(source_registry_id, candidate_url)
);

alter table public.scholarship_source_candidates enable row level security;

revoke all on public.scholarship_source_candidates from anon, authenticated;
grant select, update on public.scholarship_source_candidates to authenticated;

drop policy if exists "admins read scholarship source candidates"
on public.scholarship_source_candidates;

create policy "admins read scholarship source candidates"
on public.scholarship_source_candidates
for select to authenticated
using (public.is_admin());

drop policy if exists "admins review scholarship source candidates"
on public.scholarship_source_candidates;

create policy "admins review scholarship source candidates"
on public.scholarship_source_candidates
for update to authenticated
using (public.is_admin())
with check (public.is_admin());

create index if not exists scholarship_source_candidates_queue_idx
  on public.scholarship_source_candidates(status, relevance_score desc, last_seen_at desc);

create table if not exists public.source_discovery_scheduler_config (
  id boolean primary key default true check (id),
  endpoint_url text not null,
  cron_token text not null,
  enabled boolean not null default true,
  source_limit integer not null default 5
    check (source_limit between 1 and 10),
  updated_at timestamptz not null default now()
);

alter table public.source_discovery_scheduler_config enable row level security;
revoke all on public.source_discovery_scheduler_config
from public, anon, authenticated;

create or replace function public.dispatch_source_discovery()
returns bigint
language plpgsql
security definer
set search_path = public, extensions, net
as $$
declare
  cfg public.source_discovery_scheduler_config%rowtype;
  request_id bigint;
begin
  select * into cfg
  from public.source_discovery_scheduler_config
  where id = true and enabled = true;

  if not found then
    return null;
  end if;

  select net.http_post(
    url := cfg.endpoint_url,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-grantly-discovery-token', cfg.cron_token
    ),
    body := jsonb_build_object(
      'limit', cfg.source_limit,
      'force', false
    ),
    timeout_milliseconds := 60000
  )
  into request_id;

  return request_id;
end;
$$;

revoke execute on function public.dispatch_source_discovery()
from public, anon, authenticated;

select cron.unschedule(jobid)
from cron.job
where jobname = 'grantly-source-discovery';

select cron.schedule(
  'grantly-source-discovery',
  '37 */3 * * *',
  $$select public.dispatch_source_discovery();$$
);

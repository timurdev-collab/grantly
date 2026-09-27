-- Data reliability step 19: per-check audit observations.
-- Preserve what the auditor actually saw on each official source check.

create table if not exists public.scholarship_audit_observations (
  id bigint generated always as identity primary key,
  scholarship_id uuid not null
    references public.scholarships(id) on delete cascade,
  audit_run_id uuid
    references public.scholarship_audit_runs(id) on delete set null,
  checked_at timestamptz not null,
  outcome text not null
    check (outcome in (
      'success',
      'not_found',
      'blocked',
      'transient_error',
      'network_error',
      'other_error'
    )),
  http_status integer,
  link_status text,
  final_url text,
  source_fingerprint text,
  source_changed boolean not null default false,
  deadline_candidate date,
  deadline_confidence integer,
  deadline_candidate_count integer,
  deadline_ambiguous boolean not null default false,
  deadline_evidence text,
  cycle_candidate text,
  cycle_confidence integer,
  cycle_status text,
  audit_failure_count integer not null default 0,
  audit_error text,
  created_at timestamptz not null default now()
);

alter table public.scholarship_audit_observations enable row level security;

revoke all on public.scholarship_audit_observations
from anon, authenticated;

grant select on public.scholarship_audit_observations
to authenticated;

drop policy if exists "admins read scholarship audit observations"
on public.scholarship_audit_observations;

create policy "admins read scholarship audit observations"
on public.scholarship_audit_observations
for select to authenticated
using (public.is_admin());

create index if not exists scholarship_audit_observations_scholarship_idx
  on public.scholarship_audit_observations(
    scholarship_id,
    checked_at desc
  );

create index if not exists scholarship_audit_observations_run_idx
  on public.scholarship_audit_observations(audit_run_id)
  where audit_run_id is not null;

create index if not exists scholarship_audit_observations_outcome_idx
  on public.scholarship_audit_observations(outcome, checked_at desc);

create or replace function public.prune_scholarship_audit_observations()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  removed integer;
begin
  delete from public.scholarship_audit_observations
  where checked_at < now() - interval '180 days';

  get diagnostics removed = row_count;
  return removed;
end;
$$;

revoke execute on function public.prune_scholarship_audit_observations()
from public, anon, authenticated;
grant execute on function public.prune_scholarship_audit_observations()
to postgres;

select cron.unschedule(jobid)
from cron.job
where jobname = 'grantly-audit-observation-prune';

select cron.schedule(
  'grantly-audit-observation-prune',
  '31 3 * * 0',
  $$select public.prune_scholarship_audit_observations();$$
);

-- Data reliability step 8: audit observability and faster backlog processing.

create table if not exists public.scholarship_audit_runs (
  id uuid primary key default gen_random_uuid(),
  trigger_type text not null default 'scheduled'
    check (trigger_type in ('scheduled','manual')),
  requested_limit integer not null
    check (requested_limit between 1 and 30),
  selected_count integer not null default 0,
  exact_count integer not null default 0,
  reachable_count integer not null default 0,
  generic_count integer not null default 0,
  dead_count integer not null default 0,
  changed_source_count integer not null default 0,
  deadline_candidate_count integer not null default 0,
  deadline_change_count integer not null default 0,
  detected_cycle_count integer not null default 0,
  status text not null default 'running'
    check (status in ('running','completed','failed')),
  error_message text,
  started_at timestamptz not null default now(),
  completed_at timestamptz,
  duration_ms integer
);

alter table public.scholarship_audit_runs enable row level security;
revoke all on public.scholarship_audit_runs from anon, authenticated;
grant select on public.scholarship_audit_runs to authenticated;

drop policy if exists "admins read scholarship audit runs"
on public.scholarship_audit_runs;
create policy "admins read scholarship audit runs"
on public.scholarship_audit_runs
for select to authenticated
using (public.is_admin());

create index if not exists scholarship_audit_runs_started_idx
  on public.scholarship_audit_runs(started_at desc);

create index if not exists scholarship_audit_runs_status_idx
  on public.scholarship_audit_runs(status, started_at desc);

update public.scholarship_audit_scheduler_config
set batch_limit = 20,
    updated_at = now()
where id = true;

select cron.unschedule(jobid)
from cron.job
where jobname = 'grantly-scholarship-audit-hourly';

select cron.unschedule(jobid)
from cron.job
where jobname = 'grantly-scholarship-audit-adaptive';

select cron.schedule(
  'grantly-scholarship-audit-adaptive',
  '11,41 * * * *',
  $$select public.dispatch_due_scholarship_audit();$$
);

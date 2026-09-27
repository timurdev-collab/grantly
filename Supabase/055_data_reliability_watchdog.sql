-- Data reliability step 23: watchdog for stuck audit runs and expired leases.

create table if not exists public.data_reliability_watchdog_events (
  id bigint generated always as identity primary key,
  event_type text not null check (
    event_type in ('stale_audit_run','expired_audit_lease')
  ),
  affected_count integer not null default 0,
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

alter table public.data_reliability_watchdog_events enable row level security;

revoke all on public.data_reliability_watchdog_events
from anon, authenticated;

grant select on public.data_reliability_watchdog_events
to authenticated;

drop policy if exists "admins read reliability watchdog events"
on public.data_reliability_watchdog_events;

create policy "admins read reliability watchdog events"
on public.data_reliability_watchdog_events
for select to authenticated
using (public.is_admin());

create index if not exists data_reliability_watchdog_events_created_idx
  on public.data_reliability_watchdog_events(created_at desc);

create or replace function public.run_data_reliability_watchdog()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  stale_runs integer := 0;
  expired_leases integer := 0;
begin
  update public.scholarship_audit_runs
  set
    status = 'failed',
    error_message = coalesce(
      error_message,
      'Watchdog marked run failed after exceeding 20 minutes'
    ),
    completed_at = coalesce(completed_at, now()),
    duration_ms = coalesce(
      duration_ms,
      greatest(
        0,
        floor(
          extract(epoch from (now() - started_at)) * 1000
        )::integer
      )
    )
  where status = 'running'
    and started_at < now() - interval '20 minutes';

  get diagnostics stale_runs = row_count;

  if stale_runs > 0 then
    insert into public.data_reliability_watchdog_events(
      event_type,
      affected_count,
      details
    )
    values (
      'stale_audit_run',
      stale_runs,
      jsonb_build_object(
        'threshold_minutes', 20,
        'repaired_at', now()
      )
    );
  end if;

  update public.scholarships
  set
    audit_lease_until = null,
    audit_lease_token = null
  where audit_lease_until is not null
    and audit_lease_until <= now();

  get diagnostics expired_leases = row_count;

  if expired_leases > 0 then
    insert into public.data_reliability_watchdog_events(
      event_type,
      affected_count,
      details
    )
    values (
      'expired_audit_lease',
      expired_leases,
      jsonb_build_object(
        'released_at', now()
      )
    );
  end if;

  return jsonb_build_object(
    'stale_runs_repaired', stale_runs,
    'expired_leases_released', expired_leases
  );
end;
$$;

revoke execute on function public.run_data_reliability_watchdog()
from public, anon, authenticated;
grant execute on function public.run_data_reliability_watchdog()
to postgres;

select cron.unschedule(jobid)
from cron.job
where jobname = 'grantly-data-reliability-watchdog';

select cron.schedule(
  'grantly-data-reliability-watchdog',
  '*/10 * * * *',
  $$select public.run_data_reliability_watchdog();$$
);

select public.run_data_reliability_watchdog();

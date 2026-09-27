-- Data reliability step 2: adaptive automatic scholarship auditing.

create extension if not exists pg_net with schema extensions;

create table if not exists public.scholarship_audit_scheduler_config (
  id boolean primary key default true check (id),
  endpoint_url text not null,
  cron_token text not null,
  enabled boolean not null default true,
  batch_limit integer not null default 20
    check (batch_limit between 1 and 30),
  updated_at timestamptz not null default now()
);

alter table public.scholarship_audit_scheduler_config enable row level security;
revoke all on public.scholarship_audit_scheduler_config
from public, anon, authenticated;

create or replace function public.dispatch_due_scholarship_audit()
returns bigint
language plpgsql
security definer
set search_path = public, extensions, net
as $$
declare
  cfg public.scholarship_audit_scheduler_config%rowtype;
  request_id bigint;
begin
  select * into cfg
  from public.scholarship_audit_scheduler_config
  where id = true and enabled = true;

  if not found then
    return null;
  end if;

  select net.http_post(
    url := cfg.endpoint_url,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-grantly-cron-token', cfg.cron_token
    ),
    body := jsonb_build_object(
      'limit', cfg.batch_limit,
      'force', false
    ),
    timeout_milliseconds := 60000
  )
  into request_id;

  return request_id;
end;
$$;

revoke execute on function public.dispatch_due_scholarship_audit()
from public, anon, authenticated;

select cron.unschedule(jobid)
from cron.job
where jobname = 'grantly-scholarship-audit-hourly';

select cron.schedule(
  'grantly-scholarship-audit-hourly',
  '11 * * * *',
  $$select public.dispatch_due_scholarship_audit();$$
);

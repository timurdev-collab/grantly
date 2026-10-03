-- Schedule secure APNs delivery for pending app notifications.

create extension if not exists pg_net with schema extensions;

create table if not exists public.notification_dispatch_config (
  id boolean primary key default true check (id),
  endpoint_url text not null,
  cron_token text not null,
  enabled boolean not null default true,
  batch_limit integer not null default 50
    check (batch_limit between 1 and 100),
  updated_at timestamptz not null default now()
);

alter table public.notification_dispatch_config enable row level security;
revoke all on public.notification_dispatch_config
from public, anon, authenticated;

create or replace function public.dispatch_due_push_notifications()
returns bigint
language plpgsql
security definer
set search_path = public, extensions, net
as $$
declare
  cfg public.notification_dispatch_config%rowtype;
  request_id bigint;
begin
  select * into cfg
  from public.notification_dispatch_config
  where id = true and enabled = true;

  if not found then
    return null;
  end if;

  select net.http_post(
    url := cfg.endpoint_url,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-edut-push-token', cfg.cron_token
    ),
    body := jsonb_build_object(
      'limit', cfg.batch_limit
    ),
    timeout_milliseconds := 30000
  )
  into request_id;

  return request_id;
end;
$$;

revoke execute on function public.dispatch_due_push_notifications()
from public, anon, authenticated;

select cron.unschedule(jobid)
from cron.job
where jobname = 'edut-push-dispatch';

select cron.schedule(
  'edut-push-dispatch',
  '*/5 * * * *',
  $$select public.dispatch_due_push_notifications();$$
);

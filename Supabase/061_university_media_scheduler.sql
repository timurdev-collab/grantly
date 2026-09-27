-- UI/data media refresh: continuously enrich university logos and campus imagery
-- from official university website metadata.

create table if not exists public.university_media_scheduler_config (
  id boolean primary key default true check (id),
  endpoint_url text not null,
  cron_token text not null,
  enabled boolean not null default true,
  university_limit integer not null default 20
    check (university_limit between 1 and 30),
  updated_at timestamptz not null default now()
);

alter table public.university_media_scheduler_config enable row level security;

revoke all on public.university_media_scheduler_config
from public, anon, authenticated;

create or replace function public.dispatch_university_media_enrichment()
returns bigint
language plpgsql
security definer
set search_path = public, extensions, net
as $$
declare
  cfg public.university_media_scheduler_config%rowtype;
  request_id bigint;
begin
  select * into cfg
  from public.university_media_scheduler_config
  where id = true and enabled = true;

  if not found then
    return null;
  end if;

  select net.http_post(
    url := cfg.endpoint_url,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-grantly-media-token', cfg.cron_token
    ),
    body := jsonb_build_object(
      'limit', cfg.university_limit
    ),
    timeout_milliseconds := 60000
  )
  into request_id;

  return request_id;
end;
$$;

revoke execute on function public.dispatch_university_media_enrichment()
from public, anon, authenticated;

select cron.unschedule(jobid)
from cron.job
where jobname = 'grantly-university-media-enrichment';

select cron.schedule(
  'grantly-university-media-enrichment',
  '*/20 * * * *',
  $$select public.dispatch_university_media_enrichment();$$
);

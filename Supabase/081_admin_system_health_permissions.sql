-- Allow the admin health dashboard to inspect pg_cron safely.
-- The function performs its own is_admin() authorization check before
-- using elevated privileges to read cron.job.

create or replace function public.admin_system_health()
returns jsonb
language plpgsql
stable
security definer
set search_path = 'public', 'cron'
as $$
declare
  result jsonb;
begin
  if not public.is_admin() then
    raise exception 'Admin access required';
  end if;

  select jsonb_build_object(
    'open_catalog_issues', (
      select count(*) from public.catalog_health_issues
      where resolved_at is null
    ),
    'failed_push_notifications', (
      select count(*) from public.app_notifications
      where push_status = 'failed'
        and created_at >= now() - interval '7 days'
    ),
    'pending_push_notifications', (
      select count(*) from public.app_notifications
      where push_status = 'pending'
        and scheduled_for <= now()
    ),
    'open_backend_errors', (
      select count(*) from public.backend_error_logs
      where resolved_at is null
    ),
    'active_cron_jobs', (
      select count(*) from cron.job
      where active and jobname like 'grantly-%'
    ),
    'cron_jobs', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'name', j.jobname,
          'schedule', j.schedule,
          'active', j.active
        )
        order by j.jobname
      )
      from cron.job j
      where j.jobname like 'grantly-%'
    ), '[]'::jsonb)
  )
  into result;

  return result;
end;
$$;

revoke execute on function public.admin_system_health()
from public, anon;
grant execute on function public.admin_system_health()
to authenticated;

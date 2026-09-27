-- Backend step 8: production hardening, admin operations, audit logs,
-- consistent timestamps and system health.

create schema if not exists private;

revoke all on schema private from public, anon;
grant usage on schema private to authenticated;

create or replace function private.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.student_profiles
    where id = auth.uid()
      and role = 'admin'
  );
$$;

create or replace function private.is_conversation_member(
  conversation_uuid uuid
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.conversation_members
    where conversation_id = conversation_uuid
      and user_id = auth.uid()
  );
$$;

create or replace function private.can_message_conversation(
  conversation_uuid uuid
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select
    private.is_conversation_member(conversation_uuid)
    and not exists (
      select 1
      from public.conversation_members other_member
      join public.user_blocks b
        on (
          (b.blocker_id = auth.uid() and b.blocked_id = other_member.user_id)
          or
          (b.blocked_id = auth.uid() and b.blocker_id = other_member.user_id)
        )
      where other_member.conversation_id = conversation_uuid
        and other_member.user_id <> auth.uid()
    )
    and (
      select count(*)
      from public.messages recent
      where recent.sender_id = auth.uid()
        and recent.created_at > now() - interval '60 seconds'
    ) < 20;
$$;

create or replace function private.start_direct_conversation(
  other_user uuid
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  me uuid := auth.uid();
  existing_id uuid;
  new_id uuid;
begin
  if me is null then
    raise exception 'Not authenticated';
  end if;

  if other_user = me then
    raise exception 'Cannot message yourself';
  end if;

  if exists (
    select 1
    from public.user_blocks
    where (blocker_id = me and blocked_id = other_user)
       or (blocker_id = other_user and blocked_id = me)
  ) then
    raise exception 'Messaging is unavailable between these accounts';
  end if;

  if not exists (
    select 1
    from public.community_profiles
    where id = other_user
      and is_visible = true
  ) then
    raise exception 'User is not available for community messaging';
  end if;

  select c.id into existing_id
  from public.conversations c
  where c.is_direct = true
    and exists (
      select 1
      from public.conversation_members cm
      where cm.conversation_id = c.id
        and cm.user_id = me
    )
    and exists (
      select 1
      from public.conversation_members cm
      where cm.conversation_id = c.id
        and cm.user_id = other_user
    )
    and 2 = (
      select count(*)
      from public.conversation_members cm
      where cm.conversation_id = c.id
    )
  limit 1;

  if existing_id is not null then
    return existing_id;
  end if;

  insert into public.conversations(is_direct)
  values (true)
  returning id into new_id;

  insert into public.conversation_members(conversation_id,user_id)
  values(new_id,me),(new_id,other_user);

  return new_id;
end;
$$;

revoke all on function private.is_admin() from public, anon;
revoke all on function private.is_conversation_member(uuid) from public, anon;
revoke all on function private.can_message_conversation(uuid) from public, anon;
revoke all on function private.start_direct_conversation(uuid) from public, anon;

grant execute on function private.is_admin() to authenticated;
grant execute on function private.is_conversation_member(uuid) to authenticated;
grant execute on function private.can_message_conversation(uuid) to authenticated;
grant execute on function private.start_direct_conversation(uuid) to authenticated;

create or replace function public.is_admin()
returns boolean
language sql
stable
security invoker
set search_path = public, private
as $$
  select private.is_admin();
$$;

create or replace function public.is_conversation_member(
  conversation_uuid uuid
)
returns boolean
language sql
stable
security invoker
set search_path = public, private
as $$
  select private.is_conversation_member(conversation_uuid);
$$;

create or replace function public.can_message_conversation(
  conversation_uuid uuid
)
returns boolean
language sql
stable
security invoker
set search_path = public, private
as $$
  select private.can_message_conversation(conversation_uuid);
$$;

create or replace function public.start_direct_conversation(
  other_user uuid
)
returns uuid
language sql
volatile
security invoker
set search_path = public, private
as $$
  select private.start_direct_conversation(other_user);
$$;

revoke execute on function public.is_admin() from public, anon;
revoke execute on function public.is_conversation_member(uuid) from public, anon;
revoke execute on function public.can_message_conversation(uuid) from public, anon;
revoke execute on function public.start_direct_conversation(uuid) from public, anon;

grant execute on function public.is_admin() to authenticated;
grant execute on function public.is_conversation_member(uuid) to authenticated;
grant execute on function public.can_message_conversation(uuid) to authenticated;
grant execute on function public.start_direct_conversation(uuid) to authenticated;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

revoke execute on function public.set_updated_at()
  from public, anon, authenticated;

do $$
declare
  table_name text;
begin
  foreach table_name in array array[
    'student_profiles',
    'community_profiles',
    'scholarships',
    'saved_scholarships',
    'universities',
    'application_tasks',
    'notification_preferences',
    'push_devices',
    'recommendation_feedback'
  ]
  loop
    execute format(
      'drop trigger if exists %I on public.%I',
      table_name || '_set_updated_at',
      table_name
    );

    execute format(
      'create trigger %I before update on public.%I
       for each row execute function public.set_updated_at()',
      table_name || '_set_updated_at',
      table_name
    );
  end loop;
end $$;

alter table public.scholarships
  drop constraint if exists scholarships_official_url_http_check;
alter table public.scholarships
  add constraint scholarships_official_url_http_check
  check (official_url ~ '^https?://');

alter table public.scholarships
  drop constraint if exists scholarships_source_url_http_check;
alter table public.scholarships
  add constraint scholarships_source_url_http_check
  check (source_url is null or source_url ~ '^https?://');

alter table public.scholarships
  drop constraint if exists scholarships_final_url_http_check;
alter table public.scholarships
  add constraint scholarships_final_url_http_check
  check (final_url is null or final_url ~ '^https?://');

alter table public.scholarships
  drop constraint if exists scholarships_deadline_reasonable_check;
alter table public.scholarships
  add constraint scholarships_deadline_reasonable_check
  check (
    deadline is null
    or deadline between date '2000-01-01' and date '2100-12-31'
  );

create table if not exists public.admin_action_logs (
  id bigint generated always as identity primary key,
  admin_user_id uuid references auth.users(id) on delete set null,
  action text not null,
  target_type text not null,
  target_ids uuid[] not null default '{}',
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

alter table public.admin_action_logs enable row level security;

revoke all on public.admin_action_logs from anon, authenticated;
grant select, insert on public.admin_action_logs to authenticated;

drop policy if exists "admins read action logs" on public.admin_action_logs;
create policy "admins read action logs"
on public.admin_action_logs
for select
to authenticated
using (public.is_admin());

drop policy if exists "admins create action logs" on public.admin_action_logs;
create policy "admins create action logs"
on public.admin_action_logs
for insert
to authenticated
with check (
  public.is_admin()
  and admin_user_id = auth.uid()
);

create index if not exists admin_action_logs_admin_created_idx
  on public.admin_action_logs(admin_user_id, created_at desc);
create index if not exists admin_action_logs_created_idx
  on public.admin_action_logs(created_at desc);

create table if not exists public.backend_error_logs (
  id bigint generated always as identity primary key,
  source text not null,
  severity text not null default 'error'
    check (severity in ('info','warning','error','critical')),
  message text not null,
  context jsonb not null default '{}'::jsonb,
  occurred_at timestamptz not null default now(),
  resolved_at timestamptz
);

alter table public.backend_error_logs enable row level security;

revoke all on public.backend_error_logs from anon, authenticated;
grant select, update on public.backend_error_logs to authenticated;

drop policy if exists "admins read backend errors" on public.backend_error_logs;
create policy "admins read backend errors"
on public.backend_error_logs
for select
to authenticated
using (public.is_admin());

drop policy if exists "admins resolve backend errors" on public.backend_error_logs;
create policy "admins resolve backend errors"
on public.backend_error_logs
for update
to authenticated
using (public.is_admin())
with check (public.is_admin());

create index if not exists backend_error_logs_open_idx
  on public.backend_error_logs(severity, occurred_at desc)
  where resolved_at is null;

create or replace function public.admin_bulk_update_scholarships(
  p_ids uuid[],
  p_action text
)
returns integer
language plpgsql
security invoker
set search_path = public
as $$
declare
  affected integer := 0;
begin
  if not public.is_admin() then
    raise exception 'Admin access required';
  end if;

  if coalesce(cardinality(p_ids), 0) = 0 then
    return 0;
  end if;

  if p_action = 'verify' then
    update public.scholarships
    set
      verification_status = 'verified',
      verified_at = now(),
      status = case when status = 'draft' then 'published' else status end
    where id = any(p_ids);
  elsif p_action = 'archive' then
    update public.scholarships
    set status = 'archived'
    where id = any(p_ids);
  elsif p_action = 'restore' then
    update public.scholarships
    set status = 'published'
    where id = any(p_ids);
  elsif p_action = 'mark_review' then
    update public.scholarships
    set verification_status = 'needs_review'
    where id = any(p_ids);
  else
    raise exception 'Unsupported bulk action: %', p_action;
  end if;

  get diagnostics affected = row_count;

  insert into public.admin_action_logs(
    admin_user_id,
    action,
    target_type,
    target_ids,
    details
  )
  values (
    auth.uid(),
    'bulk_' || p_action,
    'scholarship',
    p_ids,
    jsonb_build_object('affected', affected)
  );

  return affected;
end;
$$;

revoke execute on function public.admin_bulk_update_scholarships(uuid[], text)
  from public, anon;
grant execute on function public.admin_bulk_update_scholarships(uuid[], text)
  to authenticated;

create or replace function public.admin_system_health()
returns jsonb
language plpgsql
stable
security invoker
set search_path = public, cron
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

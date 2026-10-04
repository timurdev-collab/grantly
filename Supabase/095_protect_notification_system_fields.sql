-- Users may acknowledge notifications, but delivery metadata/content is system-owned.

create or replace function public.protect_app_notification_system_fields()
returns trigger
language plpgsql
security invoker
set search_path = public, private
as $$
begin
  if current_user in ('postgres', 'service_role', 'supabase_admin')
     or coalesce(auth.role(), '') = 'service_role'
     or public.is_admin() then
    return new;
  end if;

  if new.user_id is distinct from old.user_id
     or new.kind is distinct from old.kind
     or new.title is distinct from old.title
     or new.body is distinct from old.body
     or new.scholarship_id is distinct from old.scholarship_id
     or new.task_id is distinct from old.task_id
     or new.scheduled_for is distinct from old.scheduled_for
     or new.created_at is distinct from old.created_at
     or new.push_status is distinct from old.push_status
     or new.push_sent_at is distinct from old.push_sent_at
     or new.push_error is distinct from old.push_error then
    raise exception 'Only notification read state can be changed'
      using errcode = '42501';
  end if;

  return new;
end;
$$;

drop trigger if exists app_notifications_protect_system_fields
on public.app_notifications;

create trigger app_notifications_protect_system_fields
before update on public.app_notifications
for each row
execute function public.protect_app_notification_system_fields();

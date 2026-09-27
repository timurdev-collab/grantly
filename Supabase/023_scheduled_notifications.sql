-- Backend step 4: scheduled reminders and notification events.

create extension if not exists pg_cron with schema pg_catalog;

alter table public.app_notifications
  add column if not exists dedupe_key text,
  add column if not exists push_status text not null default 'pending'
    check (push_status in ('pending','sent','failed','skipped')),
  add column if not exists push_sent_at timestamptz,
  add column if not exists push_error text;

create unique index if not exists app_notifications_user_dedupe_idx
  on public.app_notifications(user_id, dedupe_key)
  where dedupe_key is not null;

update public.saved_scholarships ss
set application_deadline = s.deadline
from public.scholarships s
where s.id = ss.scholarship_id
  and ss.application_deadline is null
  and s.deadline is not null;

create or replace function public.recalculate_application_task_due_dates(
  p_user_id uuid,
  p_scholarship_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_deadline date;
begin
  select coalesce(ss.personal_deadline, ss.application_deadline)
  into v_deadline
  from public.saved_scholarships ss
  where ss.user_id = p_user_id
    and ss.scholarship_id = p_scholarship_id;

  if v_deadline is null then
    return;
  end if;

  update public.application_tasks t
  set
    due_at = case t.task_key
      when 'review_requirements' then (v_deadline - 35)::timestamptz
      when 'transcript' then (v_deadline - 28)::timestamptz
      when 'recommendations' then (v_deadline - 21)::timestamptz
      when 'motivation_letter' then (v_deadline - 14)::timestamptz
      when 'documents' then (v_deadline - 7)::timestamptz
      when 'submit' then (v_deadline - 1)::timestamptz
      else t.due_at
    end,
    updated_at = now()
  where t.user_id = p_user_id
    and t.scholarship_id = p_scholarship_id
    and t.task_key is not null;
end;
$$;

create or replace function public.sync_application_deadline_and_tasks()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.recalculate_application_task_due_dates(
    new.user_id,
    new.scholarship_id
  );
  return new;
end;
$$;

drop trigger if exists saved_scholarship_task_due_dates
on public.saved_scholarships;

create trigger saved_scholarship_task_due_dates
after insert or update of application_deadline, personal_deadline
on public.saved_scholarships
for each row
execute function public.sync_application_deadline_and_tasks();

create or replace function public.enqueue_application_notifications()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  inserted_count integer := 0;
  current_count integer := 0;
begin
  insert into public.app_notifications (
    user_id,
    kind,
    title,
    body,
    scholarship_id,
    scheduled_for,
    dedupe_key
  )
  select
    ss.user_id,
    'deadline',
    'Scholarship deadline approaching',
    case
      when days.days = 0 then s.title || ' is due today.'
      when days.days = 1 then s.title || ' is due in 1 day.'
      else s.title || ' is due in ' || days.days || ' days.'
    end,
    ss.scholarship_id,
    now(),
    'deadline:' || ss.scholarship_id::text || ':' || days.days::text || ':' ||
      coalesce(ss.personal_deadline, ss.application_deadline)::text
  from public.saved_scholarships ss
  join public.scholarships s on s.id = ss.scholarship_id
  join public.notification_preferences np on np.user_id = ss.user_id
  cross join (values (7), (3), (1), (0)) as days(days)
  where ss.reminder_enabled
    and np.deadline_reminders
    and coalesce(ss.personal_deadline, ss.application_deadline) is not null
    and coalesce(ss.personal_deadline, ss.application_deadline) - current_date = days.days
  on conflict (user_id, dedupe_key) where dedupe_key is not null do nothing;

  get diagnostics current_count = row_count;
  inserted_count := inserted_count + current_count;

  insert into public.app_notifications (
    user_id,
    kind,
    title,
    body,
    scholarship_id,
    task_id,
    scheduled_for,
    dedupe_key
  )
  select
    t.user_id,
    'task',
    'Application task due',
    t.title || ' for ' || s.title,
    t.scholarship_id,
    t.id,
    now(),
    'task:' || t.id::text || ':' || t.due_at::date::text
  from public.application_tasks t
  join public.scholarships s on s.id = t.scholarship_id
  join public.notification_preferences np on np.user_id = t.user_id
  where np.task_reminders
    and t.completed_at is null
    and t.due_at is not null
    and t.due_at::date <= current_date
    and t.due_at::date >= current_date - 1
  on conflict (user_id, dedupe_key) where dedupe_key is not null do nothing;

  get diagnostics current_count = row_count;
  inserted_count := inserted_count + current_count;

  return inserted_count;
end;
$$;

create or replace function public.notify_new_message()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.app_notifications(
    user_id,
    kind,
    title,
    body,
    scheduled_for,
    dedupe_key
  )
  select
    cm.user_id,
    'message',
    'New message',
    left(new.body, 180),
    now(),
    'message:' || new.id::text || ':' || cm.user_id::text
  from public.conversation_members cm
  left join public.notification_preferences np
    on np.user_id = cm.user_id
  where cm.conversation_id = new.conversation_id
    and cm.user_id <> new.sender_id
    and coalesce(np.message_notifications, true)
  on conflict (user_id, dedupe_key) where dedupe_key is not null do nothing;

  return new;
end;
$$;

drop trigger if exists messages_create_notification on public.messages;
create trigger messages_create_notification
after insert on public.messages
for each row execute function public.notify_new_message();

create or replace function public.notify_saved_scholarship_deadline_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if old.deadline is not distinct from new.deadline then
    return new;
  end if;

  update public.saved_scholarships
  set application_deadline = new.deadline
  where scholarship_id = new.id
    and personal_deadline is null;

  insert into public.app_notifications(
    user_id,
    kind,
    title,
    body,
    scholarship_id,
    scheduled_for,
    dedupe_key
  )
  select
    ss.user_id,
    'scholarship_update',
    'Scholarship deadline updated',
    new.title || ' has an updated deadline: ' || coalesce(new.deadline::text, 'check the official source'),
    new.id,
    now(),
    'deadline-update:' || new.id::text || ':' || coalesce(new.deadline::text, 'none')
  from public.saved_scholarships ss
  where ss.scholarship_id = new.id
  on conflict (user_id, dedupe_key) where dedupe_key is not null do nothing;

  return new;
end;
$$;

drop trigger if exists scholarships_deadline_notification on public.scholarships;
create trigger scholarships_deadline_notification
after update of deadline on public.scholarships
for each row execute function public.notify_saved_scholarship_deadline_change();

select cron.schedule(
  'grantly-application-reminders-hourly',
  '17 * * * *',
  $$select public.enqueue_application_notifications();$$
);

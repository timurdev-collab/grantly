-- Backend step 3: richer application tracker, task checklist, and notification foundation.

alter table public.saved_scholarships
  add column if not exists application_deadline date,
  add column if not exists personal_deadline date,
  add column if not exists submitted_at timestamptz,
  add column if not exists interview_at timestamptz,
  add column if not exists result_at timestamptz,
  add column if not exists documents_complete boolean not null default false,
  add column if not exists reminder_enabled boolean not null default true;

alter table public.saved_scholarships
  drop constraint if exists saved_scholarships_application_status_check;

alter table public.saved_scholarships
  add constraint saved_scholarships_application_status_check
  check (
    application_status in (
      'Planning',
      'Applied',
      'Result',
      'Preparing',
      'Submitted',
      'Interview',
      'Offer',
      'Rejected',
      'Withdrawn'
    )
  );

create table if not exists public.application_tasks (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  scholarship_id uuid not null references public.scholarships(id) on delete cascade,
  task_key text,
  title text not null,
  due_at timestamptz,
  completed_at timestamptz,
  position integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, scholarship_id, task_key)
);

create table if not exists public.notification_preferences (
  user_id uuid primary key references auth.users(id) on delete cascade,
  deadline_reminders boolean not null default true,
  task_reminders boolean not null default true,
  message_notifications boolean not null default true,
  scholarship_match_notifications boolean not null default true,
  updated_at timestamptz not null default now()
);

create table if not exists public.app_notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  kind text not null check (
    kind in (
      'deadline',
      'task',
      'message',
      'new_match',
      'scholarship_update',
      'system'
    )
  ),
  title text not null,
  body text not null,
  scholarship_id uuid references public.scholarships(id) on delete cascade,
  task_id uuid references public.application_tasks(id) on delete cascade,
  read_at timestamptz,
  scheduled_for timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.push_devices (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  platform text not null default 'ios' check (platform in ('ios')),
  token text not null unique,
  environment text not null default 'production'
    check (environment in ('development','production')),
  updated_at timestamptz not null default now()
);

alter table public.application_tasks enable row level security;
alter table public.notification_preferences enable row level security;
alter table public.app_notifications enable row level security;
alter table public.push_devices enable row level security;

revoke all on public.application_tasks,
  public.notification_preferences,
  public.app_notifications,
  public.push_devices
from anon, authenticated;

grant select, insert, update, delete on public.application_tasks to authenticated;
grant select, insert, update on public.notification_preferences to authenticated;
grant select, update on public.app_notifications to authenticated;
grant select, insert, update, delete on public.push_devices to authenticated;

drop policy if exists "users manage own application tasks" on public.application_tasks;
create policy "users manage own application tasks"
on public.application_tasks
for all
to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

drop policy if exists "users manage own notification preferences" on public.notification_preferences;
create policy "users manage own notification preferences"
on public.notification_preferences
for all
to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

drop policy if exists "users read own app notifications" on public.app_notifications;
create policy "users read own app notifications"
on public.app_notifications
for select
to authenticated
using ((select auth.uid()) = user_id);

drop policy if exists "users update own app notifications" on public.app_notifications;
create policy "users update own app notifications"
on public.app_notifications
for update
to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

drop policy if exists "users manage own push devices" on public.push_devices;
create policy "users manage own push devices"
on public.push_devices
for all
to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

create index if not exists application_tasks_user_scholarship_idx
  on public.application_tasks(user_id, scholarship_id, position);

create index if not exists application_tasks_due_idx
  on public.application_tasks(user_id, due_at)
  where completed_at is null;

create index if not exists app_notifications_user_created_idx
  on public.app_notifications(user_id, created_at desc);

create index if not exists app_notifications_scheduled_idx
  on public.app_notifications(scheduled_for)
  where read_at is null;

create index if not exists push_devices_user_idx
  on public.push_devices(user_id);

create or replace function public.create_default_application_tasks()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.application_tasks(
    user_id,
    scholarship_id,
    task_key,
    title,
    position
  )
  values
    (new.user_id, new.scholarship_id, 'review_requirements', 'Review eligibility and requirements', 10),
    (new.user_id, new.scholarship_id, 'transcript', 'Prepare academic transcript', 20),
    (new.user_id, new.scholarship_id, 'motivation_letter', 'Draft motivation letter', 30),
    (new.user_id, new.scholarship_id, 'recommendations', 'Request recommendation letters', 40),
    (new.user_id, new.scholarship_id, 'documents', 'Prepare identity and supporting documents', 50),
    (new.user_id, new.scholarship_id, 'submit', 'Submit application', 60)
  on conflict (user_id, scholarship_id, task_key) do nothing;

  insert into public.notification_preferences(user_id)
  values (new.user_id)
  on conflict (user_id) do nothing;

  return new;
end;
$$;

drop trigger if exists saved_scholarship_default_tasks
on public.saved_scholarships;

create trigger saved_scholarship_default_tasks
after insert on public.saved_scholarships
for each row execute function public.create_default_application_tasks();

insert into public.application_tasks(
  user_id,
  scholarship_id,
  task_key,
  title,
  position
)
select ss.user_id, ss.scholarship_id, v.task_key, v.title, v.position
from public.saved_scholarships ss
cross join (
  values
    ('review_requirements', 'Review eligibility and requirements', 10),
    ('transcript', 'Prepare academic transcript', 20),
    ('motivation_letter', 'Draft motivation letter', 30),
    ('recommendations', 'Request recommendation letters', 40),
    ('documents', 'Prepare identity and supporting documents', 50),
    ('submit', 'Submit application', 60)
) as v(task_key, title, position)
on conflict (user_id, scholarship_id, task_key) do nothing;

insert into public.notification_preferences(user_id)
select distinct user_id
from public.saved_scholarships
on conflict (user_id) do nothing;

create or replace function public.set_application_status(
  p_scholarship_id uuid,
  p_status text
)
returns void
language plpgsql
security invoker
set search_path = public
as $$
begin
  if p_status not in (
    'Planning',
    'Applied',
    'Result',
    'Preparing',
    'Submitted',
    'Interview',
    'Offer',
    'Rejected',
    'Withdrawn'
  ) then
    raise exception 'Invalid application status';
  end if;

  update public.saved_scholarships
  set
    application_status = p_status,
    submitted_at = case
      when p_status in ('Applied','Submitted')
        and submitted_at is null then now()
      else submitted_at
    end,
    interview_at = case
      when p_status = 'Interview'
        and interview_at is null then now()
      else interview_at
    end,
    result_at = case
      when p_status in ('Result','Offer','Rejected')
        and result_at is null then now()
      else result_at
    end,
    updated_at = now()
  where user_id = auth.uid()
    and scholarship_id = p_scholarship_id;
end;
$$;

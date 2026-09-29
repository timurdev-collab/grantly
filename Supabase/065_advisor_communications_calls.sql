-- Advisor/student communications and call-session security layer.

alter table public.advisor_student_assignments
  add column if not exists conversation_id uuid
  references public.conversations(id) on delete set null;

create or replace function public.ensure_advisor_conversation(
  p_assignment_id uuid
)
returns uuid
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  a public.advisor_student_assignments%rowtype;
  v_conversation uuid;
begin
  select * into a
  from public.advisor_student_assignments
  where id = p_assignment_id;

  if not found then
    raise exception 'Advisor relationship not found';
  end if;

  if auth.uid() not in (a.student_id, a.advisor_id)
     and not public.is_admin() then
    raise exception 'Access denied';
  end if;

  if a.status <> 'active' then
    raise exception 'Messaging is available after the advisor accepts the student';
  end if;

  if a.conversation_id is not null then
    return a.conversation_id;
  end if;

  select c.id into v_conversation
  from public.conversations c
  where c.is_direct = true
    and exists (
      select 1 from public.conversation_members cm
      where cm.conversation_id = c.id
        and cm.user_id = a.student_id
    )
    and exists (
      select 1 from public.conversation_members cm
      where cm.conversation_id = c.id
        and cm.user_id = a.advisor_id
    )
    and (
      select count(*)
      from public.conversation_members cm
      where cm.conversation_id = c.id
    ) = 2
  order by c.created_at
  limit 1;

  if v_conversation is null then
    insert into public.conversations(is_direct)
    values (true)
    returning id into v_conversation;

    insert into public.conversation_members(conversation_id,user_id)
    values
      (v_conversation,a.student_id),
      (v_conversation,a.advisor_id);
  end if;

  update public.advisor_student_assignments
  set conversation_id = v_conversation,
      updated_at = now()
  where id = a.id;

  return v_conversation;
end;
$$;

grant execute on function public.ensure_advisor_conversation(uuid)
to authenticated;

create or replace function public.create_advisor_conversation_on_accept()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_conversation uuid;
begin
  if new.status = 'active'
     and old.status is distinct from new.status
     and new.conversation_id is null then

    select c.id into v_conversation
    from public.conversations c
    where c.is_direct = true
      and exists (
        select 1 from public.conversation_members cm
        where cm.conversation_id = c.id
          and cm.user_id = new.student_id
      )
      and exists (
        select 1 from public.conversation_members cm
        where cm.conversation_id = c.id
          and cm.user_id = new.advisor_id
      )
      and (
        select count(*)
        from public.conversation_members cm
        where cm.conversation_id = c.id
      ) = 2
    order by c.created_at
    limit 1;

    if v_conversation is null then
      insert into public.conversations(is_direct)
      values (true)
      returning id into v_conversation;

      insert into public.conversation_members(conversation_id,user_id)
      values
        (v_conversation,new.student_id),
        (v_conversation,new.advisor_id);
    end if;

    new.conversation_id := v_conversation;
  end if;

  return new;
end;
$$;

drop trigger if exists advisor_assignment_create_conversation
on public.advisor_student_assignments;

create trigger advisor_assignment_create_conversation
before update of status
on public.advisor_student_assignments
for each row
execute function public.create_advisor_conversation_on_accept();

create table if not exists public.advisor_call_sessions (
  id uuid primary key default gen_random_uuid(),
  assignment_id uuid not null
    references public.advisor_student_assignments(id) on delete cascade,
  conversation_id uuid
    references public.conversations(id) on delete set null,
  started_by uuid not null references auth.users(id),
  room_name text not null unique,
  status text not null default 'requested'
    check (status in ('requested','scheduled','active','ended','cancelled')),
  scheduled_for timestamptz,
  started_at timestamptz,
  ended_at timestamptz,
  screen_share_allowed boolean not null default true,
  recording_requested boolean not null default false,
  recording_consent_student boolean not null default false,
  recording_consent_advisor boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.advisor_call_sessions enable row level security;

drop policy if exists "call participants select"
on public.advisor_call_sessions;
create policy "call participants select"
on public.advisor_call_sessions
for select
using (
  public.is_admin()
  or exists (
    select 1
    from public.advisor_student_assignments a
    where a.id = assignment_id
      and auth.uid() in (a.student_id,a.advisor_id)
  )
);

drop policy if exists "call participants insert"
on public.advisor_call_sessions;
create policy "call participants insert"
on public.advisor_call_sessions
for insert
with check (
  started_by = auth.uid()
  and exists (
    select 1
    from public.advisor_student_assignments a
    where a.id = assignment_id
      and a.status = 'active'
      and auth.uid() in (a.student_id,a.advisor_id)
  )
);

drop policy if exists "call participants update"
on public.advisor_call_sessions;
create policy "call participants update"
on public.advisor_call_sessions
for update
using (
  public.is_admin()
  or exists (
    select 1
    from public.advisor_student_assignments a
    where a.id = assignment_id
      and a.status = 'active'
      and auth.uid() in (a.student_id,a.advisor_id)
  )
)
with check (
  public.is_admin()
  or exists (
    select 1
    from public.advisor_student_assignments a
    where a.id = assignment_id
      and auth.uid() in (a.student_id,a.advisor_id)
  )
);

grant select,insert,update on public.advisor_call_sessions to authenticated;

create or replace function public.create_advisor_call_session(
  p_assignment_id uuid,
  p_recording_requested boolean default false
)
returns public.advisor_call_sessions
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  a public.advisor_student_assignments%rowtype;
  result public.advisor_call_sessions%rowtype;
  v_conversation uuid;
begin
  select * into a
  from public.advisor_student_assignments
  where id = p_assignment_id
    and status = 'active';

  if not found then
    raise exception 'Active advisor relationship required';
  end if;

  if auth.uid() not in (a.student_id,a.advisor_id) then
    raise exception 'Access denied';
  end if;

  v_conversation := public.ensure_advisor_conversation(p_assignment_id);

  insert into public.advisor_call_sessions(
    assignment_id,
    conversation_id,
    started_by,
    room_name,
    recording_requested,
    recording_consent_student,
    recording_consent_advisor
  )
  values(
    p_assignment_id,
    v_conversation,
    auth.uid(),
    'grantly-' || replace(gen_random_uuid()::text,'-',''),
    p_recording_requested,
    case
      when p_recording_requested and auth.uid() = a.student_id then true
      else false
    end,
    case
      when p_recording_requested and auth.uid() = a.advisor_id then true
      else false
    end
  )
  returning * into result;

  return result;
end;
$$;

grant execute on function public.create_advisor_call_session(uuid,boolean)
to authenticated;

create or replace function public.set_advisor_call_recording_consent(
  p_call_id uuid,
  p_consent boolean
)
returns public.advisor_call_sessions
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  a public.advisor_student_assignments%rowtype;
  result public.advisor_call_sessions%rowtype;
begin
  select a.* into a
  from public.advisor_call_sessions cs
  join public.advisor_student_assignments a on a.id = cs.assignment_id
  where cs.id = p_call_id;

  if not found or auth.uid() not in (a.student_id,a.advisor_id) then
    raise exception 'Access denied';
  end if;

  update public.advisor_call_sessions
  set
    recording_consent_student = case
      when auth.uid() = a.student_id then p_consent
      else recording_consent_student
    end,
    recording_consent_advisor = case
      when auth.uid() = a.advisor_id then p_consent
      else recording_consent_advisor
    end,
    updated_at = now()
  where id = p_call_id
  returning * into result;

  return result;
end;
$$;

grant execute on function public.set_advisor_call_recording_consent(uuid,boolean)
to authenticated;

create index if not exists advisor_call_sessions_assignment_created_idx
on public.advisor_call_sessions(assignment_id,created_at desc);

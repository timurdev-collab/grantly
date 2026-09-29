-- Role-based admin/advisor/student flow

create table if not exists public.advisor_student_assignments (
  id uuid primary key default gen_random_uuid(),
  advisor_id uuid not null references public.advisor_profiles(id) on delete cascade,
  student_id uuid not null references public.student_profiles(id) on delete cascade,
  status text not null default 'requested'
    check (status in ('requested','active','ended','declined')),
  requested_at timestamptz not null default now(),
  activated_at timestamptz,
  ended_at timestamptz,
  updated_at timestamptz not null default now(),
  unique (advisor_id, student_id)
);

alter table public.advisor_student_assignments enable row level security;

create or replace function public.is_advisor()
returns boolean
language sql
stable
set search_path to 'public'
as $$
  select exists(
    select 1
    from public.student_profiles sp
    join public.advisor_profiles ap on ap.id = sp.id
    where sp.id = auth.uid()
      and sp.role = 'advisor'
      and ap.approval_status = 'approved'
      and ap.is_active = true
  );
$$;

grant execute on function public.is_advisor() to authenticated;

drop policy if exists "assignment participants select" on public.advisor_student_assignments;
create policy "assignment participants select"
on public.advisor_student_assignments
for select
using (
  student_id = auth.uid()
  or advisor_id = auth.uid()
  or public.is_admin()
);

drop policy if exists "students request advisor" on public.advisor_student_assignments;
create policy "students request advisor"
on public.advisor_student_assignments
for insert
with check (
  student_id = auth.uid()
  and exists (
    select 1
    from public.student_profiles sp
    where sp.id = auth.uid()
      and sp.role = 'student'
  )
  and exists (
    select 1
    from public.advisor_profiles ap
    where ap.id = advisor_id
      and ap.approval_status = 'approved'
      and ap.is_active = true
  )
);

drop policy if exists "advisor assignment update" on public.advisor_student_assignments;
create policy "advisor assignment update"
on public.advisor_student_assignments
for update
using (
  advisor_id = auth.uid()
  or public.is_admin()
)
with check (
  advisor_id = auth.uid()
  or public.is_admin()
);

grant select, insert, update on public.advisor_student_assignments to authenticated;

create or replace function public.available_advisors()
returns table(
  id uuid,
  display_name text,
  title text,
  bio text,
  specialties text[],
  countries text[],
  languages text[],
  avatar_url text
)
language sql
stable
security definer
set search_path to 'public'
as $$
  select
    ap.id,
    ap.display_name,
    ap.title,
    ap.bio,
    ap.specialties,
    ap.countries,
    ap.languages,
    ap.avatar_url
  from public.advisor_profiles ap
  where ap.approval_status = 'approved'
    and ap.is_active = true
  order by coalesce(ap.display_name, ap.title, 'Advisor');
$$;

grant execute on function public.available_advisors() to authenticated;

create or replace function public.request_advisor(
  p_advisor_id uuid
)
returns public.advisor_student_assignments
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  result public.advisor_student_assignments%rowtype;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  if not exists (
    select 1 from public.student_profiles
    where id = auth.uid() and role = 'student'
  ) then
    raise exception 'Only students can register with an advisor';
  end if;

  if not exists (
    select 1
    from public.advisor_profiles
    where id = p_advisor_id
      and approval_status = 'approved'
      and is_active = true
  ) then
    raise exception 'Advisor is not available';
  end if;

  insert into public.advisor_student_assignments(
    advisor_id, student_id, status, requested_at, updated_at
  )
  values(
    p_advisor_id, auth.uid(), 'requested', now(), now()
  )
  on conflict (advisor_id, student_id) do update set
    status = 'requested',
    requested_at = now(),
    activated_at = null,
    ended_at = null,
    updated_at = now()
  returning * into result;

  return result;
end;
$$;

grant execute on function public.request_advisor(uuid) to authenticated;

create or replace function public.my_advisor_registration()
returns table(
  assignment_id uuid,
  advisor_id uuid,
  advisor_name text,
  advisor_title text,
  advisor_avatar_url text,
  status text,
  requested_at timestamptz
)
language sql
stable
security definer
set search_path to 'public'
as $$
  select
    a.id,
    a.advisor_id,
    coalesce(ap.display_name, 'Advisor'),
    ap.title,
    ap.avatar_url,
    a.status,
    a.requested_at
  from public.advisor_student_assignments a
  join public.advisor_profiles ap on ap.id = a.advisor_id
  where a.student_id = auth.uid()
    and a.status in ('requested','active')
  order by
    case when a.status = 'active' then 0 else 1 end,
    a.updated_at desc
  limit 1;
$$;

grant execute on function public.my_advisor_registration() to authenticated;

create or replace function public.advisor_my_students()
returns table(
  assignment_id uuid,
  student_id uuid,
  full_name text,
  nationality text,
  residence_country text,
  intended_major text,
  degree_level text,
  target_countries text[],
  status text,
  requested_at timestamptz,
  activated_at timestamptz
)
language plpgsql
stable
security definer
set search_path to 'public'
as $$
begin
  if not public.is_advisor() then
    raise exception 'Advisor access required';
  end if;

  return query
  select
    a.id,
    sp.id,
    sp.full_name,
    sp.nationality,
    sp.residence_country,
    sp.intended_major,
    sp.degree_level,
    sp.target_countries,
    a.status,
    a.requested_at,
    a.activated_at
  from public.advisor_student_assignments a
  join public.student_profiles sp on sp.id = a.student_id
  where a.advisor_id = auth.uid()
    and a.status in ('requested','active')
  order by
    case when a.status = 'requested' then 0 else 1 end,
    a.requested_at desc;
end;
$$;

grant execute on function public.advisor_my_students() to authenticated;

create or replace function public.advisor_manage_student(
  p_assignment_id uuid,
  p_action text
)
returns public.advisor_student_assignments
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  result public.advisor_student_assignments%rowtype;
begin
  if not public.is_advisor() then
    raise exception 'Advisor access required';
  end if;

  if p_action not in ('accept','decline','end') then
    raise exception 'Unsupported advisor action';
  end if;

  update public.advisor_student_assignments
  set
    status = case
      when p_action = 'accept' then 'active'
      when p_action = 'decline' then 'declined'
      else 'ended'
    end,
    activated_at = case
      when p_action = 'accept' then now()
      else activated_at
    end,
    ended_at = case
      when p_action in ('decline','end') then now()
      else null
    end,
    updated_at = now()
  where id = p_assignment_id
    and advisor_id = auth.uid()
  returning * into result;

  if not found then
    raise exception 'Student registration not found';
  end if;

  return result;
end;
$$;

grant execute on function public.advisor_manage_student(uuid,text) to authenticated;

create or replace function public.admin_advisor_assignments()
returns table(
  assignment_id uuid,
  advisor_id uuid,
  advisor_name text,
  student_id uuid,
  student_name text,
  student_email text,
  status text,
  requested_at timestamptz,
  activated_at timestamptz
)
language plpgsql
stable
security definer
set search_path to 'public','auth'
as $$
begin
  if not public.is_admin() then
    raise exception 'Admin access required';
  end if;

  return query
  select
    a.id,
    a.advisor_id,
    coalesce(ap.display_name, 'Advisor'),
    a.student_id,
    coalesce(sp.full_name, u.email::text, 'Student'),
    u.email::text,
    a.status,
    a.requested_at,
    a.activated_at
  from public.advisor_student_assignments a
  join public.advisor_profiles ap on ap.id = a.advisor_id
  join public.student_profiles sp on sp.id = a.student_id
  join auth.users u on u.id = a.student_id
  order by a.updated_at desc;
end;
$$;

grant execute on function public.admin_advisor_assignments() to authenticated;

create index if not exists advisor_student_assignments_advisor_status_idx
on public.advisor_student_assignments(advisor_id,status,requested_at desc);

create index if not exists advisor_student_assignments_student_status_idx
on public.advisor_student_assignments(student_id,status,requested_at desc);

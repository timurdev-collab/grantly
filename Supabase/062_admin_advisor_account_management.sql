-- Admin, student and advisor account management

alter type public.user_role add value if not exists 'advisor';

create table if not exists public.advisor_profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  title text,
  bio text,
  specialties text[] not null default '{}',
  countries text[] not null default '{}',
  languages text[] not null default '{}',
  avatar_url text,
  approval_status text not null default 'pending'
    check (approval_status in ('pending','approved','rejected','suspended')),
  is_active boolean not null default false,
  requested_at timestamptz not null default now(),
  reviewed_at timestamptz,
  reviewed_by uuid references auth.users(id),
  review_note text,
  updated_at timestamptz not null default now()
);

alter table public.advisor_profiles enable row level security;

drop policy if exists "approved advisors visible" on public.advisor_profiles;
create policy "approved advisors visible"
on public.advisor_profiles
for select
using (
  (approval_status = 'approved' and is_active = true)
  or id = auth.uid()
  or public.is_admin()
);

drop policy if exists "advisor self insert" on public.advisor_profiles;
create policy "advisor self insert"
on public.advisor_profiles
for insert
with check (id = auth.uid());

drop policy if exists "advisor self update pending" on public.advisor_profiles;
create policy "advisor self update pending"
on public.advisor_profiles
for update
using (id = auth.uid() or public.is_admin())
with check (
  public.is_admin()
  or (
    id = auth.uid()
    and approval_status in ('pending','rejected')
    and is_active = false
  )
);

grant select, insert, update on public.advisor_profiles to authenticated;

create or replace function public.request_advisor_access(
  p_display_name text,
  p_title text default null,
  p_bio text default null,
  p_specialties text[] default '{}',
  p_countries text[] default '{}',
  p_languages text[] default '{}'
)
returns public.advisor_profiles
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  result public.advisor_profiles%rowtype;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  insert into public.advisor_profiles(
    id, display_name, title, bio, specialties, countries, languages,
    approval_status, is_active, requested_at, updated_at
  )
  values(
    auth.uid(),
    nullif(btrim(p_display_name),''),
    nullif(btrim(p_title),''),
    nullif(btrim(p_bio),''),
    coalesce(p_specialties,'{}'),
    coalesce(p_countries,'{}'),
    coalesce(p_languages,'{}'),
    'pending',
    false,
    now(),
    now()
  )
  on conflict (id) do update set
    display_name = excluded.display_name,
    title = excluded.title,
    bio = excluded.bio,
    specialties = excluded.specialties,
    countries = excluded.countries,
    languages = excluded.languages,
    approval_status = case
      when public.advisor_profiles.approval_status = 'approved'
        then 'approved'
      else 'pending'
    end,
    is_active = case
      when public.advisor_profiles.approval_status = 'approved'
        then public.advisor_profiles.is_active
      else false
    end,
    requested_at = case
      when public.advisor_profiles.approval_status = 'approved'
        then public.advisor_profiles.requested_at
      else now()
    end,
    reviewed_at = case
      when public.advisor_profiles.approval_status = 'approved'
        then public.advisor_profiles.reviewed_at
      else null
    end,
    reviewed_by = case
      when public.advisor_profiles.approval_status = 'approved'
        then public.advisor_profiles.reviewed_by
      else null
    end,
    review_note = case
      when public.advisor_profiles.approval_status = 'approved'
        then public.advisor_profiles.review_note
      else null
    end,
    updated_at = now()
  returning * into result;

  return result;
end;
$$;

grant execute on function public.request_advisor_access(text,text,text,text[],text[],text[]) to authenticated;

create or replace function public.admin_user_accounts()
returns table(
  user_id uuid,
  email text,
  full_name text,
  role text,
  account_created_at timestamptz,
  last_sign_in_at timestamptz,
  banned_until timestamptz,
  advisor_status text,
  advisor_title text,
  advisor_active boolean
)
language plpgsql
security definer
set search_path to 'public','auth'
as $$
begin
  if not public.is_admin() then
    raise exception 'Admin access required';
  end if;

  return query
  select
    u.id,
    u.email::text,
    sp.full_name,
    sp.role::text,
    u.created_at,
    u.last_sign_in_at,
    u.banned_until,
    ap.approval_status,
    ap.title,
    ap.is_active
  from auth.users u
  left join public.student_profiles sp on sp.id = u.id
  left join public.advisor_profiles ap on ap.id = u.id
  order by u.created_at desc;
end;
$$;

grant execute on function public.admin_user_accounts() to authenticated;

create or replace function public.admin_review_advisor(
  p_user_id uuid,
  p_action text,
  p_note text default null
)
returns public.advisor_profiles
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  result public.advisor_profiles%rowtype;
  new_status text;
  new_active boolean;
begin
  if not public.is_admin() then
    raise exception 'Admin access required';
  end if;

  if p_user_id = auth.uid() then
    raise exception 'You cannot modify your own advisor approval state';
  end if;

  if p_action not in ('approve','reject','suspend','restore') then
    raise exception 'Unsupported advisor action';
  end if;

  new_status := case
    when p_action in ('approve','restore') then 'approved'
    when p_action = 'reject' then 'rejected'
    else 'suspended'
  end;

  new_active := p_action in ('approve','restore');

  update public.advisor_profiles
  set
    approval_status = new_status,
    is_active = new_active,
    reviewed_at = now(),
    reviewed_by = auth.uid(),
    review_note = nullif(btrim(p_note),''),
    updated_at = now()
  where id = p_user_id
  returning * into result;

  if not found then
    raise exception 'Advisor profile not found';
  end if;

  update public.student_profiles
  set role = case
    when p_action in ('approve','restore','suspend') then 'advisor'::public.user_role
    else 'student'::public.user_role
  end
  where id = p_user_id;

  insert into public.admin_action_logs(
    admin_user_id, action, target_type, target_ids, details
  )
  values(
    auth.uid(),
    'advisor_' || p_action,
    'user',
    array[p_user_id],
    jsonb_build_object('note', nullif(btrim(p_note),''))
  );

  return result;
end;
$$;

grant execute on function public.admin_review_advisor(uuid,text,text) to authenticated;

create or replace function public.admin_set_account_suspended(
  p_user_id uuid,
  p_suspended boolean
)
returns boolean
language plpgsql
security definer
set search_path to 'public','auth'
as $$
begin
  if not public.is_admin() then
    raise exception 'Admin access required';
  end if;

  if p_user_id = auth.uid() then
    raise exception 'You cannot suspend your own account';
  end if;

  update auth.users
  set banned_until = case
    when p_suspended then 'infinity'::timestamptz
    else null
  end
  where id = p_user_id;

  if not found then
    raise exception 'User account not found';
  end if;

  if exists (
    select 1 from public.advisor_profiles where id = p_user_id
  ) then
    update public.advisor_profiles
    set
      is_active = case when p_suspended then false else is_active end,
      approval_status = case
        when p_suspended and approval_status = 'approved' then 'suspended'
        else approval_status
      end,
      updated_at = now()
    where id = p_user_id;
  end if;

  insert into public.admin_action_logs(
    admin_user_id, action, target_type, target_ids, details
  )
  values(
    auth.uid(),
    case when p_suspended then 'suspend_user' else 'restore_user' end,
    'user',
    array[p_user_id],
    jsonb_build_object('suspended', p_suspended)
  );

  return true;
end;
$$;

grant execute on function public.admin_set_account_suspended(uuid,boolean) to authenticated;

create index if not exists advisor_profiles_status_idx
on public.advisor_profiles(approval_status,is_active,requested_at desc);

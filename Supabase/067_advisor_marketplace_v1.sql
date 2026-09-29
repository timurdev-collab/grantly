-- Advisor marketplace v1: richer applications, moderated publishing, media and review history.

alter table public.advisor_profiles
  add column if not exists organization text,
  add column if not exists short_bio text,
  add column if not exists mentoring_approach text,
  add column if not exists years_experience integer,
  add column if not exists linkedin_url text,
  add column if not exists website_url text,
  add column if not exists avatar_storage_path text,
  add column if not exists intro_video_storage_path text,
  add column if not exists intro_video_url text,
  add column if not exists is_featured boolean not null default false,
  add column if not exists display_order integer,
  add column if not exists application_version integer not null default 1;

alter table public.advisor_profiles
  drop constraint if exists advisor_profiles_approval_status_check;

alter table public.advisor_profiles
  add constraint advisor_profiles_approval_status_check
  check (
    approval_status in (
      'pending',
      'changes_requested',
      'approved',
      'rejected',
      'suspended'
    )
  );

alter table public.advisor_profiles
  drop constraint if exists advisor_profiles_years_experience_check;

alter table public.advisor_profiles
  add constraint advisor_profiles_years_experience_check
  check (
    years_experience is null
    or (years_experience >= 0 and years_experience <= 80)
  );

drop policy if exists "advisor self update pending" on public.advisor_profiles;
create policy "advisor self update pending"
on public.advisor_profiles
for update
using (id = auth.uid() or public.is_admin())
with check (
  public.is_admin()
  or (
    id = auth.uid()
    and approval_status in ('pending','changes_requested','rejected')
    and is_active = false
  )
);

create table if not exists public.advisor_review_events (
  id uuid primary key default gen_random_uuid(),
  advisor_id uuid not null references public.advisor_profiles(id) on delete cascade,
  admin_id uuid references auth.users(id) on delete set null,
  action text not null check (
    action in (
      'submitted',
      'resubmitted',
      'approved',
      'changes_requested',
      'rejected',
      'suspended',
      'restored'
    )
  ),
  previous_status text,
  new_status text not null,
  note text,
  application_version integer not null default 1,
  created_at timestamptz not null default now()
);

alter table public.advisor_review_events enable row level security;
revoke all on public.advisor_review_events from anon, authenticated;
grant select on public.advisor_review_events to authenticated;

drop policy if exists "advisor review history visible to owner and admin"
on public.advisor_review_events;

create policy "advisor review history visible to owner and admin"
on public.advisor_review_events
for select
to authenticated
using (
  advisor_id = auth.uid()
  or public.is_admin()
);

insert into storage.buckets(
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
)
values(
  'advisor-media',
  'advisor-media',
  false,
  104857600,
  array[
    'image/jpeg',
    'image/png',
    'image/heic',
    'video/mp4',
    'video/quicktime'
  ]
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "advisor media owner insert" on storage.objects;
create policy "advisor media owner insert"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'advisor-media'
  and (storage.foldername(name))[1] = auth.uid()::text
);

drop policy if exists "advisor media owner update" on storage.objects;
create policy "advisor media owner update"
on storage.objects
for update
to authenticated
using (
  bucket_id = 'advisor-media'
  and (
    (storage.foldername(name))[1] = auth.uid()::text
    or public.is_admin()
  )
)
with check (
  bucket_id = 'advisor-media'
  and (
    (storage.foldername(name))[1] = auth.uid()::text
    or public.is_admin()
  )
);

drop policy if exists "advisor media owner delete" on storage.objects;
create policy "advisor media owner delete"
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'advisor-media'
  and (
    (storage.foldername(name))[1] = auth.uid()::text
    or public.is_admin()
  )
);

drop policy if exists "advisor media approved read" on storage.objects;
create policy "advisor media approved read"
on storage.objects
for select
to authenticated
using (
  bucket_id = 'advisor-media'
  and (
    (storage.foldername(name))[1] = auth.uid()::text
    or public.is_admin()
    or exists (
      select 1
      from public.advisor_profiles ap
      where ap.id::text = (storage.foldername(name))[1]
        and ap.approval_status = 'approved'
        and ap.is_active = true
    )
  )
);

create or replace function public.submit_advisor_application(
  p_display_name text,
  p_title text default null,
  p_organization text default null,
  p_short_bio text default null,
  p_bio text default null,
  p_mentoring_approach text default null,
  p_years_experience integer default null,
  p_specialties text[] default '{}',
  p_countries text[] default '{}',
  p_languages text[] default '{}',
  p_linkedin_url text default null,
  p_website_url text default null,
  p_avatar_storage_path text default null,
  p_intro_video_storage_path text default null,
  p_intro_video_url text default null
)
returns public.advisor_profiles
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  existing public.advisor_profiles%rowtype;
  result public.advisor_profiles%rowtype;
  next_version integer;
  event_action text;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  if nullif(btrim(p_display_name),'') is null then
    raise exception 'Full name is required';
  end if;

  if nullif(btrim(p_title),'') is null then
    raise exception 'Professional title is required';
  end if;

  if nullif(btrim(p_bio),'') is null then
    raise exception 'Professional bio is required';
  end if;

  if coalesce(array_length(p_specialties, 1), 0) = 0 then
    raise exception 'At least one specialty is required';
  end if;

  select *
  into existing
  from public.advisor_profiles
  where id = auth.uid();

  if found and existing.approval_status in ('approved','suspended') then
    raise exception 'Approved advisor profiles are managed from the advisor profile editor';
  end if;

  next_version := coalesce(existing.application_version, 0) + 1;
  event_action := case when existing.id is null then 'submitted' else 'resubmitted' end;

  insert into public.advisor_profiles(
    id,
    display_name,
    title,
    organization,
    short_bio,
    bio,
    mentoring_approach,
    years_experience,
    specialties,
    countries,
    languages,
    linkedin_url,
    website_url,
    avatar_storage_path,
    intro_video_storage_path,
    intro_video_url,
    approval_status,
    is_active,
    requested_at,
    reviewed_at,
    reviewed_by,
    review_note,
    application_version,
    updated_at
  )
  values(
    auth.uid(),
    nullif(btrim(p_display_name),''),
    nullif(btrim(p_title),''),
    nullif(btrim(p_organization),''),
    nullif(btrim(p_short_bio),''),
    nullif(btrim(p_bio),''),
    nullif(btrim(p_mentoring_approach),''),
    p_years_experience,
    coalesce(p_specialties,'{}'),
    coalesce(p_countries,'{}'),
    coalesce(p_languages,'{}'),
    nullif(btrim(p_linkedin_url),''),
    nullif(btrim(p_website_url),''),
    nullif(btrim(p_avatar_storage_path),''),
    nullif(btrim(p_intro_video_storage_path),''),
    nullif(btrim(p_intro_video_url),''),
    'pending',
    false,
    now(),
    null,
    null,
    null,
    next_version,
    now()
  )
  on conflict (id) do update set
    display_name = excluded.display_name,
    title = excluded.title,
    organization = excluded.organization,
    short_bio = excluded.short_bio,
    bio = excluded.bio,
    mentoring_approach = excluded.mentoring_approach,
    years_experience = excluded.years_experience,
    specialties = excluded.specialties,
    countries = excluded.countries,
    languages = excluded.languages,
    linkedin_url = excluded.linkedin_url,
    website_url = excluded.website_url,
    avatar_storage_path = coalesce(excluded.avatar_storage_path, public.advisor_profiles.avatar_storage_path),
    intro_video_storage_path = coalesce(excluded.intro_video_storage_path, public.advisor_profiles.intro_video_storage_path),
    intro_video_url = excluded.intro_video_url,
    approval_status = 'pending',
    is_active = false,
    requested_at = now(),
    reviewed_at = null,
    reviewed_by = null,
    review_note = null,
    application_version = next_version,
    updated_at = now()
  returning * into result;

  insert into public.advisor_review_events(
    advisor_id,
    admin_id,
    action,
    previous_status,
    new_status,
    application_version
  )
  values(
    auth.uid(),
    null,
    event_action,
    existing.approval_status,
    'pending',
    next_version
  );

  return result;
end;
$$;

grant execute on function public.submit_advisor_application(
  text,text,text,text,text,text,integer,text[],text[],text[],
  text,text,text,text,text
) to authenticated;

create or replace function public.my_advisor_application()
returns public.advisor_profiles
language sql
stable
security invoker
set search_path to 'public'
as $$
  select *
  from public.advisor_profiles
  where id = auth.uid()
  limit 1;
$$;

grant execute on function public.my_advisor_application() to authenticated;

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
  existing public.advisor_profiles%rowtype;
  result public.advisor_profiles%rowtype;
  new_status text;
  new_active boolean;
  event_action text;
begin
  if not public.is_admin() then
    raise exception 'Admin access required';
  end if;

  if p_user_id = auth.uid() then
    raise exception 'You cannot modify your own advisor approval state';
  end if;

  if p_action not in (
    'approve',
    'request_changes',
    'reject',
    'suspend',
    'restore'
  ) then
    raise exception 'Unsupported advisor action';
  end if;

  select *
  into existing
  from public.advisor_profiles
  where id = p_user_id;

  if not found then
    raise exception 'Advisor profile not found';
  end if;

  if p_action in ('request_changes','reject') and nullif(btrim(p_note),'') is null then
    raise exception 'A review note is required for this action';
  end if;

  new_status := case
    when p_action in ('approve','restore') then 'approved'
    when p_action = 'request_changes' then 'changes_requested'
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

  update public.student_profiles
  set role = case
    when p_action in ('approve','restore','suspend') then 'advisor'::public.user_role
    else 'student'::public.user_role
  end
  where id = p_user_id;

  event_action := case
    when p_action = 'approve' then 'approved'
    when p_action = 'request_changes' then 'changes_requested'
    when p_action = 'reject' then 'rejected'
    when p_action = 'suspend' then 'suspended'
    else 'restored'
  end;

  insert into public.advisor_review_events(
    advisor_id,
    admin_id,
    action,
    previous_status,
    new_status,
    note,
    application_version
  )
  values(
    p_user_id,
    auth.uid(),
    event_action,
    existing.approval_status,
    new_status,
    nullif(btrim(p_note),''),
    result.application_version
  );

  insert into public.app_notifications(
    user_id,
    kind,
    title,
    body
  )
  values(
    p_user_id,
    'system',
    case
      when p_action in ('approve','restore') then 'Advisor profile approved'
      when p_action = 'request_changes' then 'Advisor application needs changes'
      when p_action = 'reject' then 'Advisor application update'
      else 'Advisor profile suspended'
    end,
    case
      when p_action in ('approve','restore')
        then 'Your advisor profile is approved and visible to students.'
      when p_action = 'request_changes'
        then coalesce(nullif(btrim(p_note),''), 'Please update your application and submit it again.')
      when p_action = 'reject'
        then coalesce(nullif(btrim(p_note),''), 'Your advisor application was not approved.')
      else 'Your advisor profile is temporarily hidden from students.'
    end
  );

  insert into public.admin_action_logs(
    admin_user_id,
    action,
    target_type,
    target_ids,
    details
  )
  values(
    auth.uid(),
    'advisor_' || p_action,
    'user',
    array[p_user_id],
    jsonb_build_object(
      'note',
      nullif(btrim(p_note),''),
      'previous_status',
      existing.approval_status,
      'new_status',
      new_status,
      'application_version',
      result.application_version
    )
  );

  return result;
end;
$$;

grant execute on function public.admin_review_advisor(uuid,text,text) to authenticated;

drop function if exists public.available_advisors();

create function public.available_advisors()
returns table(
  id uuid,
  display_name text,
  title text,
  organization text,
  short_bio text,
  bio text,
  mentoring_approach text,
  years_experience integer,
  specialties text[],
  countries text[],
  languages text[],
  avatar_url text,
  avatar_storage_path text,
  intro_video_storage_path text,
  intro_video_url text,
  linkedin_url text,
  website_url text,
  is_featured boolean
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
    ap.organization,
    ap.short_bio,
    ap.bio,
    ap.mentoring_approach,
    ap.years_experience,
    ap.specialties,
    ap.countries,
    ap.languages,
    ap.avatar_url,
    ap.avatar_storage_path,
    ap.intro_video_storage_path,
    ap.intro_video_url,
    ap.linkedin_url,
    ap.website_url,
    ap.is_featured
  from public.advisor_profiles ap
  where ap.approval_status = 'approved'
    and ap.is_active = true
  order by
    ap.is_featured desc,
    ap.display_order asc nulls last,
    coalesce(ap.display_name, ap.title, 'Advisor');
$$;

grant execute on function public.available_advisors() to authenticated;

create or replace function public.admin_advisor_applications()
returns setof public.advisor_profiles
language plpgsql
stable
security definer
set search_path to 'public'
as $$
begin
  if not public.is_admin() then
    raise exception 'Admin access required';
  end if;

  return query
  select ap.*
  from public.advisor_profiles ap
  order by
    case ap.approval_status
      when 'pending' then 0
      when 'changes_requested' then 1
      when 'approved' then 2
      when 'suspended' then 3
      else 4
    end,
    ap.requested_at desc;
end;
$$;

grant execute on function public.admin_advisor_applications() to authenticated;

create index if not exists advisor_profiles_public_directory_idx
on public.advisor_profiles(
  approval_status,
  is_active,
  is_featured desc,
  display_order,
  requested_at desc
);

create index if not exists advisor_review_events_advisor_created_idx
on public.advisor_review_events(advisor_id, created_at desc);

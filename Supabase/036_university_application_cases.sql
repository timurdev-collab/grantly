create table if not exists public.university_application_cases (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  university_id uuid not null references public.universities(id) on delete cascade,
  program_name text not null default '',
  degree_level text,
  intake text,
  application_status text not null default 'Planning'
    check (application_status in (
      'Planning','Preparing','Submitted','Interview',
      'Offer','Rejected','Withdrawn'
    )),
  application_reference text,
  deadline date,
  notes text not null default '',
  submitted_at timestamptz,
  interview_at timestamptz,
  result_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.university_application_cases enable row level security;
revoke all on public.university_application_cases from anon, authenticated;
grant select, insert, update, delete on public.university_application_cases to authenticated;

drop policy if exists "users manage own university cases" on public.university_application_cases;
create policy "users manage own university cases"
on public.university_application_cases
for all
to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

create index if not exists university_cases_user_idx
  on public.university_application_cases(user_id, updated_at desc);
create index if not exists university_cases_university_idx
  on public.university_application_cases(university_id);

create table if not exists public.university_case_requirements (
  id uuid primary key default gen_random_uuid(),
  case_id uuid not null references public.university_application_cases(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  title text not null,
  category text not null default 'Other',
  is_required boolean not null default true,
  is_official boolean not null default false,
  source_url text,
  notes text,
  position integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.university_case_requirements enable row level security;
revoke all on public.university_case_requirements from anon, authenticated;
grant select, insert, update, delete on public.university_case_requirements to authenticated;

drop policy if exists "users manage own case requirements" on public.university_case_requirements;
create policy "users manage own case requirements"
on public.university_case_requirements
for all
to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

create index if not exists university_case_requirements_case_idx
  on public.university_case_requirements(case_id, position, created_at);

create table if not exists public.university_case_documents (
  id uuid primary key default gen_random_uuid(),
  case_id uuid not null references public.university_application_cases(id) on delete cascade,
  requirement_id uuid references public.university_case_requirements(id) on delete set null,
  user_id uuid not null references auth.users(id) on delete cascade,
  file_name text not null,
  storage_path text not null unique,
  content_type text,
  byte_size bigint,
  created_at timestamptz not null default now()
);

alter table public.university_case_documents enable row level security;
revoke all on public.university_case_documents from anon, authenticated;
grant select, insert, delete on public.university_case_documents to authenticated;

drop policy if exists "users manage own case documents" on public.university_case_documents;
create policy "users manage own case documents"
on public.university_case_documents
for all
to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

create index if not exists university_case_documents_case_idx
  on public.university_case_documents(case_id, created_at desc);

insert into storage.buckets (
  id,name,public,file_size_limit,allowed_mime_types
)
values (
  'university-case-documents',
  'university-case-documents',
  false,
  10485760,
  array[
    'application/pdf','image/jpeg','image/png','image/heic','image/heif'
  ]
)
on conflict (id) do update
set public = excluded.public,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "users upload own university case documents" on storage.objects;
create policy "users upload own university case documents"
on storage.objects for insert to authenticated
with check (
  bucket_id = 'university-case-documents'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

drop policy if exists "users read own university case documents" on storage.objects;
create policy "users read own university case documents"
on storage.objects for select to authenticated
using (
  bucket_id = 'university-case-documents'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

drop policy if exists "users delete own university case documents" on storage.objects;
create policy "users delete own university case documents"
on storage.objects for delete to authenticated
using (
  bucket_id = 'university-case-documents'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

create or replace function public.create_university_application_case(
  p_university_id uuid,
  p_program_name text default '',
  p_degree_level text default null,
  p_intake text default null
)
returns uuid
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_case_id uuid;
begin
  if v_user_id is null then raise exception 'Authentication required'; end if;

  insert into public.university_application_cases (
    user_id,university_id,program_name,degree_level,intake
  )
  values (
    v_user_id,p_university_id,coalesce(trim(p_program_name), ''),
    nullif(trim(p_degree_level), ''),nullif(trim(p_intake), '')
  )
  returning id into v_case_id;

  insert into public.university_case_requirements (
    case_id,user_id,title,category,is_required,is_official,position
  )
  values
    (v_case_id,v_user_id,'Passport / identity document','Identity',true,false,10),
    (v_case_id,v_user_id,'Academic transcript','Academic',true,false,20),
    (v_case_id,v_user_id,'Graduation certificate / diploma','Academic',true,false,30),
    (v_case_id,v_user_id,'Language proficiency result','Testing',true,false,40),
    (v_case_id,v_user_id,'Personal statement / motivation letter','Essay',true,false,50),
    (v_case_id,v_user_id,'Recommendation letter(s)','Recommendation',true,false,60),
    (v_case_id,v_user_id,'CV / résumé','Profile',false,false,70),
    (v_case_id,v_user_id,'Financial proof (if required)','Financial',false,false,80);

  return v_case_id;
end;
$$;
grant execute on function public.create_university_application_case(uuid,text,text,text) to authenticated;

create or replace function public.set_university_case_status(
  p_case_id uuid,
  p_status text
)
returns void
language plpgsql
security invoker
set search_path = public
as $$
begin
  if p_status not in (
    'Planning','Preparing','Submitted','Interview','Offer','Rejected','Withdrawn'
  ) then raise exception 'Invalid status'; end if;

  update public.university_application_cases
  set application_status = p_status,
      submitted_at = case when p_status='Submitted' and submitted_at is null then now() else submitted_at end,
      interview_at = case when p_status='Interview' and interview_at is null then now() else interview_at end,
      result_at = case when p_status in ('Offer','Rejected') and result_at is null then now() else result_at end,
      updated_at = now()
  where id = p_case_id and user_id = auth.uid();
end;
$$;
grant execute on function public.set_university_case_status(uuid,text) to authenticated;

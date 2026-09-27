create table if not exists public.application_documents (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  scholarship_id uuid not null references public.scholarships(id) on delete cascade,
  file_name text not null,
  storage_path text not null unique,
  content_type text,
  byte_size bigint,
  created_at timestamptz not null default now()
);

alter table public.application_documents enable row level security;

revoke all on public.application_documents from anon, authenticated;
grant select, insert, delete on public.application_documents to authenticated;

drop policy if exists "users manage own application documents" on public.application_documents;
create policy "users manage own application documents"
on public.application_documents
for all
to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

create index if not exists application_documents_user_scholarship_idx
  on public.application_documents(user_id, scholarship_id, created_at desc);

insert into storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
)
values (
  'application-documents',
  'application-documents',
  false,
  10485760,
  array[
    'application/pdf',
    'image/jpeg',
    'image/png',
    'image/heic',
    'image/heif'
  ]
)
on conflict (id) do update
set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "users upload own application documents" on storage.objects;
create policy "users upload own application documents"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'application-documents'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

drop policy if exists "users read own application documents" on storage.objects;
create policy "users read own application documents"
on storage.objects
for select
to authenticated
using (
  bucket_id = 'application-documents'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

drop policy if exists "users delete own application documents" on storage.objects;
create policy "users delete own application documents"
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'application-documents'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

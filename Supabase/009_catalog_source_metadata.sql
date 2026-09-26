-- Add source and verification metadata for the expanded scholarship catalog.

alter table public.scholarships
  add column if not exists description text;

alter table public.scholarships
  add column if not exists source_label text;

alter table public.scholarships
  add column if not exists source_url text;

alter table public.scholarships
  add column if not exists source_license text;

alter table public.scholarships
  add column if not exists verification_status text not null default 'verified';

alter table public.scholarships
  drop constraint if exists scholarships_verification_status_check;

alter table public.scholarships
  add constraint scholarships_verification_status_check
  check (verification_status in ('verified','curated','needs_review'));

update public.scholarships
set verification_status = 'verified'
where verified_at is not null;

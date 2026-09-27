-- Track institution media enrichment status.

alter table public.universities
  add column if not exists media_status text not null default 'pending'
  check (media_status in ('pending','ready','partial','failed')),
  add column if not exists media_checked_at timestamptz,
  add column if not exists media_source_url text,
  add column if not exists media_error text;

create index if not exists universities_media_status_idx
  on public.universities(media_status, updated_at);

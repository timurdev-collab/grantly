-- Add automated catalog quality metadata.

alter table public.scholarships
  add column if not exists application_cycle text;

alter table public.scholarships
  add column if not exists deadline_notes text;

alter table public.scholarships
  add column if not exists link_status text not null default 'unchecked';

alter table public.scholarships
  add column if not exists last_checked_at timestamptz;

alter table public.scholarships
  add column if not exists final_url text;

alter table public.scholarships
  add column if not exists deadline_candidate date;

alter table public.scholarships
  add column if not exists deadline_confidence integer;

alter table public.scholarships
  drop constraint if exists scholarships_link_status_check;

alter table public.scholarships
  add constraint scholarships_link_status_check
  check (link_status in ('unchecked','exact','reachable','generic','dead'));

alter table public.scholarships
  drop constraint if exists scholarships_deadline_confidence_check;

alter table public.scholarships
  add constraint scholarships_deadline_confidence_check
  check (deadline_confidence is null or deadline_confidence between 0 and 100);

update public.scholarships
set link_status = case
  when verification_status = 'verified' then 'exact'
  when verification_status = 'curated'
       and official_url ~ '^https?://[^/]+/?$' then 'generic'
  else link_status
end;

update public.scholarships
set verification_status = 'needs_review'
where verification_status = 'curated'
  and official_url ~ '^https?://[^/]+/?$';

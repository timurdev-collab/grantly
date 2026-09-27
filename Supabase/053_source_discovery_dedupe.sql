-- Data reliability step 21: deduplicate discovered official-source links.

alter table public.scholarship_source_candidates
  add column if not exists duplicate_of_scholarship_id uuid
  references public.scholarships(id) on delete set null;

create index if not exists scholarship_source_candidates_duplicate_idx
  on public.scholarship_source_candidates(duplicate_of_scholarship_id)
  where duplicate_of_scholarship_id is not null;

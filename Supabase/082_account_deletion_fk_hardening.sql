-- Ensure administrator account deletion cannot be blocked by advisor review history.

alter table public.advisor_profiles
  drop constraint if exists advisor_profiles_reviewed_by_fkey;

alter table public.advisor_profiles
  add constraint advisor_profiles_reviewed_by_fkey
  foreign key (reviewed_by)
  references auth.users(id)
  on delete set null;

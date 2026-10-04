-- Ensure account deletion cannot be blocked by advisor call history.

alter table public.advisor_call_sessions
  drop constraint if exists advisor_call_sessions_started_by_fkey;

alter table public.advisor_call_sessions
  add constraint advisor_call_sessions_started_by_fkey
  foreign key (started_by)
  references auth.users(id)
  on delete cascade;

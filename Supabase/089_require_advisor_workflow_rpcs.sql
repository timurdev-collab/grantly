-- Require sensitive advisor workflow mutations to go through audited RPCs.
-- The current iOS app already uses these RPCs for all writes.

drop policy if exists "advisor self insert"
on public.advisor_profiles;

drop policy if exists "advisor self update pending"
on public.advisor_profiles;

drop policy if exists "students request advisor"
on public.advisor_student_assignments;

drop policy if exists "advisor assignment update"
on public.advisor_student_assignments;

drop policy if exists "call participants insert"
on public.advisor_call_sessions;

drop policy if exists "call participants update"
on public.advisor_call_sessions;

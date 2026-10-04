-- Remove unnecessary anonymous table privileges from advisor-only data.
-- These tables have no anonymous product surface and should not expose
-- direct table operations before authentication.

revoke all privileges on table public.advisor_call_sessions from anon;
revoke all privileges on table public.advisor_profiles from anon;
revoke all privileges on table public.advisor_student_assignments from anon;

-- Restrict helper RPCs that should never be callable before authentication.
revoke execute on function public.create_university_application_case(uuid,text,text,text)
from public, anon;
grant execute on function public.create_university_application_case(uuid,text,text,text)
to authenticated;

revoke execute on function public.is_advisor()
from public, anon;
grant execute on function public.is_advisor()
to authenticated;

-- Auto-staging changes scholarship data and is reserved for trusted backend jobs.
revoke execute on function public.auto_stage_trusted_source_candidates(integer)
from public, anon, authenticated;
grant execute on function public.auto_stage_trusted_source_candidates(integer)
to service_role;

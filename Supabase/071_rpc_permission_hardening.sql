-- Restrict helper RPCs that should never be callable before authentication.

do $$
begin
  if to_regprocedure(
    'public.create_university_application_case(uuid,text,text,text)'
  ) is not null then
    revoke execute on function
      public.create_university_application_case(uuid,text,text,text)
    from public, anon;
    grant execute on function
      public.create_university_application_case(uuid,text,text,text)
    to authenticated;
  end if;

  if to_regprocedure('public.is_advisor()') is not null then
    revoke execute on function public.is_advisor()
    from public, anon;
    grant execute on function public.is_advisor()
    to authenticated;
  end if;

  -- This function is only present in environments that run the
  -- automated catalog staging pipeline.
  if to_regprocedure(
    'public.auto_stage_trusted_source_candidates(integer)'
  ) is not null then
    revoke execute on function
      public.auto_stage_trusted_source_candidates(integer)
    from public, anon, authenticated;
    grant execute on function
      public.auto_stage_trusted_source_candidates(integer)
    to service_role;
  end if;
end
$$;

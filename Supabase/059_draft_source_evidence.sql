-- Data reliability step 27: expose structured source evidence for admin draft review.

create or replace function public.scholarship_draft_source_evidence(
  p_scholarship_id uuid
)
returns jsonb
language plpgsql
stable
security invoker
set search_path = public
as $$
declare
  c public.scholarship_source_candidates%rowtype;
  p public.scholarship_source_candidate_profiles%rowtype;
begin
  if not public.is_admin() then
    raise exception 'Admin access required';
  end if;

  select * into c
  from public.scholarship_source_candidates
  where draft_scholarship_id = p_scholarship_id
  order by reviewed_at desc nulls last, last_seen_at desc
  limit 1;

  if not found then
    return jsonb_build_object(
      'scholarship_id', p_scholarship_id,
      'available', false
    );
  end if;

  select * into p
  from public.scholarship_source_candidate_profiles
  where candidate_id = c.id;

  if not found then
    return jsonb_build_object(
      'scholarship_id', p_scholarship_id,
      'available', false,
      'candidate_url', c.candidate_url
    );
  end if;

  return jsonb_build_object(
    'scholarship_id', p_scholarship_id,
    'available', true,
    'candidate_url', c.candidate_url,
    'page_title', p.page_title,
    'meta_description', p.meta_description,
    'checked_at', p.checked_at,
    'detected_deadline', p.detected_deadline,
    'deadline_confidence', p.deadline_confidence,
    'detected_cycle', p.detected_cycle,
    'cycle_confidence', p.cycle_confidence,
    'detected_degree_levels', p.detected_degree_levels,
    'degree_confidence', p.degree_confidence,
    'detected_funding_type', p.detected_funding_type,
    'funding_confidence', p.funding_confidence,
    'detected_tuition_coverage', p.detected_tuition_coverage,
    'detected_stipend', p.detected_stipend,
    'detected_airfare', p.detected_airfare,
    'detected_accommodation', p.detected_accommodation,
    'detected_health_insurance', p.detected_health_insurance,
    'detected_eligible_nationalities', p.detected_eligible_nationalities,
    'eligibility_confidence', p.eligibility_confidence,
    'funding_excerpt', p.funding_excerpt,
    'benefits_excerpt', p.benefits_excerpt,
    'eligibility_excerpt', p.eligibility_excerpt,
    'application_excerpt', p.application_excerpt,
    'application_requirements_excerpt', p.application_requirements_excerpt
  );
end;
$$;

revoke execute on function public.scholarship_draft_source_evidence(uuid)
from public, anon;
grant execute on function public.scholarship_draft_source_evidence(uuid)
to authenticated;

-- Data reliability step 26: richer structured extraction for accepted
-- official-source candidates. These fields remain review-first and are never
-- published automatically.

alter table public.scholarship_source_candidate_profiles
  add column if not exists detected_degree_levels text[] not null default '{}',
  add column if not exists degree_confidence integer
    check (degree_confidence is null or degree_confidence between 0 and 100),
  add column if not exists detected_funding_type text,
  add column if not exists funding_confidence integer
    check (funding_confidence is null or funding_confidence between 0 and 100),
  add column if not exists detected_tuition_coverage text,
  add column if not exists detected_stipend text,
  add column if not exists detected_airfare boolean,
  add column if not exists detected_accommodation boolean,
  add column if not exists detected_health_insurance boolean,
  add column if not exists detected_eligible_nationalities text[] not null default '{}',
  add column if not exists eligibility_confidence integer
    check (eligibility_confidence is null or eligibility_confidence between 0 and 100),
  add column if not exists benefits_excerpt text,
  add column if not exists eligibility_excerpt text,
  add column if not exists application_requirements_excerpt text;

create or replace function public.sync_source_candidate_draft_profile(
  p_candidate_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  c public.scholarship_source_candidates%rowtype;
  p public.scholarship_source_candidate_profiles%rowtype;
begin
  if coalesce(auth.role(), '') <> 'service_role'
     and not public.is_admin() then
    raise exception 'Admin access required';
  end if;

  select * into c
  from public.scholarship_source_candidates
  where id = p_candidate_id;

  if not found or c.draft_scholarship_id is null then
    return null;
  end if;

  select * into p
  from public.scholarship_source_candidate_profiles
  where candidate_id = p_candidate_id
    and extraction_status = 'ready';

  if not found then
    return c.draft_scholarship_id;
  end if;

  update public.scholarships s
  set
    description = coalesce(
      nullif(btrim(p.meta_description), ''),
      s.description
    ),
    degree_levels = case
      when coalesce(cardinality(s.degree_levels), 0) = 0
        and cardinality(p.detected_degree_levels) > 0
      then p.detected_degree_levels
      else s.degree_levels
    end,
    funding_type = case
      when coalesce(nullif(btrim(s.funding_type), ''), 'Varies') = 'Varies'
        and nullif(btrim(p.detected_funding_type), '') is not null
      then p.detected_funding_type
      else s.funding_type
    end,
    tuition_coverage = coalesce(
      s.tuition_coverage,
      nullif(btrim(p.detected_tuition_coverage), '')
    ),
    stipend = coalesce(
      s.stipend,
      nullif(btrim(p.detected_stipend), '')
    ),
    airfare = case
      when s.airfare = false and p.detected_airfare is true then true
      else s.airfare
    end,
    accommodation = case
      when s.accommodation = false and p.detected_accommodation is true then true
      else s.accommodation
    end,
    health_insurance = case
      when s.health_insurance = false and p.detected_health_insurance is true then true
      else s.health_insurance
    end,
    eligible_nationalities = case
      when s.eligible_nationalities = array['ALL']
        and cardinality(p.detected_eligible_nationalities) > 0
      then p.detected_eligible_nationalities
      else s.eligible_nationalities
    end,
    deadline_candidate = p.detected_deadline,
    deadline_confidence = p.deadline_confidence,
    deadline_verification_status = case
      when p.detected_deadline is not null then 'candidate'
      else s.deadline_verification_status
    end,
    cycle_candidate = p.detected_cycle,
    cycle_confidence = p.cycle_confidence,
    source_fingerprint = p.content_fingerprint,
    next_check_at = now(),
    updated_at = now()
  where s.id = c.draft_scholarship_id
    and s.status = 'draft';

  return c.draft_scholarship_id;
end;
$$;

revoke execute on function public.sync_source_candidate_draft_profile(uuid)
from public, anon;
grant execute on function public.sync_source_candidate_draft_profile(uuid)
to authenticated, service_role;

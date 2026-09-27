-- Data reliability step 24: turn accepted official-source discoveries
-- into private draft scholarships without bypassing review or audit gates.

alter table public.scholarship_source_candidates
  add column if not exists draft_scholarship_id uuid
  references public.scholarships(id) on delete set null;

create index if not exists scholarship_source_candidates_draft_idx
  on public.scholarship_source_candidates(draft_scholarship_id)
  where draft_scholarship_id is not null;

create or replace function public.promote_source_candidate_to_draft(
  p_candidate_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  c public.scholarship_source_candidates%rowtype;
  r public.scholarship_source_registry%rowtype;
  p public.scholarship_source_candidate_profiles%rowtype;
  seed public.scholarships%rowtype;
  new_id uuid;
  base_title text;
  base_slug text;
  suffix text;
begin
  if coalesce(auth.role(), '') <> 'service_role'
     and not public.is_admin() then
    raise exception 'Admin access required';
  end if;

  select * into c
  from public.scholarship_source_candidates
  where id = p_candidate_id
  for update;

  if not found then
    raise exception 'Source candidate not found';
  end if;

  if c.duplicate_of_scholarship_id is not null then
    return c.duplicate_of_scholarship_id;
  end if;

  if c.draft_scholarship_id is not null then
    return c.draft_scholarship_id;
  end if;

  if c.status <> 'accepted' then
    raise exception 'Source candidate must be accepted first';
  end if;

  select * into r
  from public.scholarship_source_registry
  where id = c.source_registry_id;

  select * into p
  from public.scholarship_source_candidate_profiles
  where candidate_id = c.id;

  select * into seed
  from public.scholarships
  where source_registry_id = c.source_registry_id
  order by
    (status = 'published') desc,
    reliability_score desc nulls last,
    updated_at desc
  limit 1;

  base_title := coalesce(
    nullif(btrim(p.page_title), ''),
    nullif(btrim(c.candidate_title), ''),
    nullif(btrim(r.display_name), '') || ' Scholarship'
  );

  base_slug := lower(
    regexp_replace(
      regexp_replace(base_title, '[^a-zA-Z0-9]+', '-', 'g'),
      '(^-|-$)',
      '',
      'g'
    )
  );

  if base_slug is null or base_slug = '' then
    base_slug := 'discovered-scholarship';
  end if;

  suffix := substr(replace(c.id::text, '-', ''), 1, 8);

  insert into public.scholarships(
    slug,
    title,
    provider,
    country,
    region,
    degree_levels,
    fields,
    funding_type,
    tuition_coverage,
    stipend,
    airfare,
    accommodation,
    health_insurance,
    sat_required,
    eligible_nationalities,
    deadline,
    official_url,
    status,
    description,
    source_label,
    source_url,
    source_license,
    verification_status,
    application_cycle,
    deadline_notes,
    link_status,
    last_checked_at,
    final_url,
    deadline_candidate,
    deadline_confidence,
    source_fingerprint,
    cycle_candidate,
    cycle_confidence,
    deadline_verification_status,
    cycle_status,
    next_check_at,
    source_registry_id,
    source_authority_score
  )
  values (
    base_slug || '-' || suffix,
    base_title,
    coalesce(
      nullif(btrim(r.display_name), ''),
      nullif(btrim(seed.provider), ''),
      'Official provider'
    ),
    coalesce(nullif(btrim(seed.country), ''), 'Unknown'),
    coalesce(nullif(btrim(seed.region), ''), 'Global'),
    coalesce(seed.degree_levels, '{}'),
    coalesce(seed.fields, array['All fields']),
    coalesce(nullif(btrim(seed.funding_type), ''), 'Varies'),
    null,
    null,
    false,
    false,
    false,
    false,
    array['ALL'],
    null,
    c.candidate_url,
    'draft',
    nullif(btrim(p.meta_description), ''),
    'Official source discovery',
    c.discovered_from_url,
    null,
    'needs_review',
    null,
    null,
    'unchecked',
    null,
    c.candidate_url,
    p.detected_deadline,
    p.deadline_confidence,
    p.content_fingerprint,
    p.detected_cycle,
    p.cycle_confidence,
    case
      when p.detected_deadline is not null then 'candidate'
      else 'unconfirmed'
    end,
    'unknown',
    now(),
    c.source_registry_id,
    r.trust_level
  )
  returning id into new_id;

  update public.scholarship_source_candidates
  set draft_scholarship_id = new_id
  where id = c.id;

  insert into public.admin_action_logs(
    admin_user_id,
    action,
    target_type,
    target_ids,
    details
  )
  values (
    auth.uid(),
    'promote_source_candidate_to_draft',
    'scholarship',
    array[new_id],
    jsonb_build_object(
      'candidate_id', c.id,
      'source_registry_id', c.source_registry_id,
      'official_url', c.candidate_url
    )
  );

  return new_id;
end;
$$;

revoke execute on function public.promote_source_candidate_to_draft(uuid)
from public, anon;
grant execute on function public.promote_source_candidate_to_draft(uuid)
to authenticated, service_role;

create or replace function public.accept_source_candidate(
  p_candidate_id uuid,
  p_note text default null
)
returns uuid
language plpgsql
security invoker
set search_path = public
as $$
declare
  result_id uuid;
begin
  if not public.is_admin() then
    raise exception 'Admin access required';
  end if;

  update public.scholarship_source_candidates
  set
    status = 'accepted',
    reviewed_at = now(),
    reviewed_by = auth.uid(),
    review_note = nullif(btrim(p_note), '')
  where id = p_candidate_id
    and status = 'pending';

  if not found then
    raise exception 'Pending source candidate not found';
  end if;

  result_id := public.promote_source_candidate_to_draft(p_candidate_id);
  return result_id;
end;
$$;

revoke execute on function public.accept_source_candidate(uuid,text)
from public, anon;
grant execute on function public.accept_source_candidate(uuid,text)
to authenticated;

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

  update public.scholarships
  set
    description = coalesce(
      nullif(btrim(p.meta_description), ''),
      description
    ),
    deadline_candidate = p.detected_deadline,
    deadline_confidence = p.deadline_confidence,
    deadline_verification_status = case
      when p.detected_deadline is not null then 'candidate'
      else deadline_verification_status
    end,
    cycle_candidate = p.detected_cycle,
    cycle_confidence = p.cycle_confidence,
    source_fingerprint = p.content_fingerprint,
    next_check_at = now(),
    updated_at = now()
  where id = c.draft_scholarship_id
    and status = 'draft';

  return c.draft_scholarship_id;
end;
$$;

revoke execute on function public.sync_source_candidate_draft_profile(uuid)
from public, anon;
grant execute on function public.sync_source_candidate_draft_profile(uuid)
to authenticated, service_role;

create or replace function public.claim_due_scholarship_audits(
  p_limit integer default 20,
  p_force boolean default false
)
returns table (
  id uuid,
  title text,
  provider text,
  official_url text,
  verification_status text,
  link_status text,
  audit_failure_count integer,
  last_successful_check_at timestamptz,
  deadline date,
  application_cycle text,
  source_fingerprint text,
  source_changed_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
begin
  return query
  with candidates as (
    select s.id
    from public.scholarships s
    where (
        s.status = 'published'
        or (
          s.status = 'draft'
          and s.verification_status = 'needs_review'
        )
      )
      and (
        p_force
        or s.next_check_at is null
        or s.next_check_at <= now()
      )
      and (
        s.audit_lease_until is null
        or s.audit_lease_until <= now()
      )
    order by
      (s.status = 'draft') desc,
      s.next_check_at asc nulls first
    for update skip locked
    limit greatest(1, least(coalesce(p_limit, 20), 30))
  )
  update public.scholarships s
  set
    audit_lease_until = now() + interval '15 minutes',
    audit_lease_token = gen_random_uuid()
  from candidates c
  where s.id = c.id
  returning
    s.id,
    s.title,
    s.provider,
    s.official_url,
    s.verification_status,
    s.link_status,
    s.audit_failure_count,
    s.last_successful_check_at,
    s.deadline,
    s.application_cycle,
    s.source_fingerprint,
    s.source_changed_at;
end;
$$;

revoke execute on function public.claim_due_scholarship_audits(integer,boolean)
from public, anon, authenticated;
grant execute on function public.claim_due_scholarship_audits(integer,boolean)
to service_role;

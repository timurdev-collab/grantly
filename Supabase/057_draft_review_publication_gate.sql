-- Data reliability step 25: structured admin draft review and publication gate.

create or replace function public.scholarship_draft_readiness(
  p_scholarship_id uuid
)
returns jsonb
language plpgsql
stable
security invoker
set search_path = public
as $$
declare
  s public.scholarships%rowtype;
  blockers text[] := '{}';
  warnings text[] := '{}';
begin
  if not public.is_admin() then
    raise exception 'Admin access required';
  end if;

  select * into s
  from public.scholarships
  where id = p_scholarship_id;

  if not found then
    raise exception 'Scholarship not found';
  end if;

  if s.status <> 'draft' then
    blockers := array_append(blockers, 'Scholarship is not a draft');
  end if;

  if nullif(btrim(s.title), '') is null then
    blockers := array_append(blockers, 'Title is required');
  end if;

  if nullif(btrim(s.provider), '') is null
     or lower(btrim(s.provider)) = 'official provider' then
    blockers := array_append(blockers, 'Provider must be confirmed');
  end if;

  if nullif(btrim(s.country), '') is null
     or lower(btrim(s.country)) = 'unknown' then
    blockers := array_append(blockers, 'Country must be confirmed');
  end if;

  if nullif(btrim(s.region), '') is null then
    blockers := array_append(blockers, 'Region is required');
  end if;

  if coalesce(cardinality(s.degree_levels), 0) = 0 then
    blockers := array_append(blockers, 'At least one study level is required');
  end if;

  if coalesce(cardinality(s.fields), 0) = 0 then
    blockers := array_append(blockers, 'At least one field is required');
  end if;

  if nullif(btrim(s.funding_type), '') is null then
    blockers := array_append(blockers, 'Funding type is required');
  end if;

  if s.official_url is null or s.official_url !~ '^https?://' then
    blockers := array_append(blockers, 'A valid official URL is required');
  end if;

  if s.source_registry_id is null then
    blockers := array_append(blockers, 'Official source provenance is missing');
  end if;

  if coalesce(s.link_status, 'unchecked') not in ('exact', 'reachable') then
    blockers := array_append(
      blockers,
      'Official source must pass a successful link audit'
    );
  end if;

  if s.last_successful_check_at is null then
    blockers := array_append(
      blockers,
      'Official source has not completed a successful audit'
    );
  elsif s.last_successful_check_at < now() - interval '30 days' then
    blockers := array_append(
      blockers,
      'Official source verification is older than 30 days'
    );
  end if;

  if coalesce(s.audit_failure_count, 0) > 0 then
    blockers := array_append(
      blockers,
      'Latest source audit has unresolved failures'
    );
  end if;

  if coalesce(s.deadline_ambiguous, false) then
    blockers := array_append(
      blockers,
      'Multiple possible deadlines require manual review'
    );
  end if;

  if coalesce(s.cycle_status, 'unknown') in ('closed', 'discontinued') then
    blockers := array_append(
      blockers,
      'Current application cycle is closed or discontinued'
    );
  end if;

  if s.deadline is null then
    if s.deadline_candidate is not null then
      warnings := array_append(
        warnings,
        'A deadline candidate exists but has not been confirmed'
      );
    else
      warnings := array_append(
        warnings,
        'Deadline not yet confirmed'
      );
    end if;
  end if;

  if s.application_cycle is null then
    if s.cycle_candidate is not null then
      warnings := array_append(
        warnings,
        'An application-cycle candidate exists but has not been confirmed'
      );
    else
      warnings := array_append(
        warnings,
        'Application cycle is not yet confirmed'
      );
    end if;
  end if;

  if nullif(btrim(coalesce(s.description, '')), '') is null then
    warnings := array_append(
      warnings,
      'Description is empty'
    );
  end if;

  return jsonb_build_object(
    'scholarship_id', s.id,
    'ready', cardinality(blockers) = 0,
    'blockers', to_jsonb(blockers),
    'warnings', to_jsonb(warnings),
    'link_status', s.link_status,
    'last_successful_check_at', s.last_successful_check_at,
    'deadline_candidate', s.deadline_candidate,
    'deadline_confidence', s.deadline_confidence,
    'cycle_candidate', s.cycle_candidate,
    'cycle_confidence', s.cycle_confidence
  );
end;
$$;

revoke execute on function public.scholarship_draft_readiness(uuid)
from public, anon;
grant execute on function public.scholarship_draft_readiness(uuid)
to authenticated;

create or replace function public.update_scholarship_draft(
  p_scholarship_id uuid,
  p_patch jsonb
)
returns public.scholarships
language plpgsql
security invoker
set search_path = public
as $$
declare
  result public.scholarships%rowtype;
  invalid_key text;
  confirmed_deadline date;
begin
  if not public.is_admin() then
    raise exception 'Admin access required';
  end if;

  if jsonb_typeof(p_patch) <> 'object' then
    raise exception 'Patch must be a JSON object';
  end if;

  select key into invalid_key
  from jsonb_object_keys(p_patch) key
  where key not in (
    'title',
    'provider',
    'country',
    'region',
    'degree_levels',
    'fields',
    'funding_type',
    'tuition_coverage',
    'stipend',
    'airfare',
    'accommodation',
    'health_insurance',
    'sat_required',
    'eligible_nationalities',
    'description',
    'application_cycle',
    'deadline',
    'deadline_notes'
  )
  limit 1;

  if invalid_key is not null then
    raise exception 'Unsupported draft field: %', invalid_key;
  end if;

  if p_patch ? 'deadline' then
    begin
      confirmed_deadline := nullif(btrim(p_patch->>'deadline'), '')::date;
    exception when others then
      raise exception 'Invalid deadline';
    end;
  end if;

  update public.scholarships s
  set
    title = case
      when p_patch ? 'title' then nullif(btrim(p_patch->>'title'), '')
      else s.title
    end,
    provider = case
      when p_patch ? 'provider' then nullif(btrim(p_patch->>'provider'), '')
      else s.provider
    end,
    country = case
      when p_patch ? 'country' then nullif(btrim(p_patch->>'country'), '')
      else s.country
    end,
    region = case
      when p_patch ? 'region' then nullif(btrim(p_patch->>'region'), '')
      else s.region
    end,
    degree_levels = case
      when p_patch ? 'degree_levels' then
        array(
          select value
          from jsonb_array_elements_text(p_patch->'degree_levels')
          where nullif(btrim(value), '') is not null
        )
      else s.degree_levels
    end,
    fields = case
      when p_patch ? 'fields' then
        array(
          select value
          from jsonb_array_elements_text(p_patch->'fields')
          where nullif(btrim(value), '') is not null
        )
      else s.fields
    end,
    funding_type = case
      when p_patch ? 'funding_type'
        then nullif(btrim(p_patch->>'funding_type'), '')
      else s.funding_type
    end,
    tuition_coverage = case
      when p_patch ? 'tuition_coverage'
        then nullif(btrim(p_patch->>'tuition_coverage'), '')
      else s.tuition_coverage
    end,
    stipend = case
      when p_patch ? 'stipend'
        then nullif(btrim(p_patch->>'stipend'), '')
      else s.stipend
    end,
    airfare = case
      when p_patch ? 'airfare'
        then coalesce((p_patch->>'airfare')::boolean, false)
      else s.airfare
    end,
    accommodation = case
      when p_patch ? 'accommodation'
        then coalesce((p_patch->>'accommodation')::boolean, false)
      else s.accommodation
    end,
    health_insurance = case
      when p_patch ? 'health_insurance'
        then coalesce((p_patch->>'health_insurance')::boolean, false)
      else s.health_insurance
    end,
    sat_required = case
      when p_patch ? 'sat_required'
        then coalesce((p_patch->>'sat_required')::boolean, false)
      else s.sat_required
    end,
    eligible_nationalities = case
      when p_patch ? 'eligible_nationalities' then
        array(
          select value
          from jsonb_array_elements_text(p_patch->'eligible_nationalities')
          where nullif(btrim(value), '') is not null
        )
      else s.eligible_nationalities
    end,
    description = case
      when p_patch ? 'description'
        then nullif(btrim(p_patch->>'description'), '')
      else s.description
    end,
    application_cycle = case
      when p_patch ? 'application_cycle'
        then nullif(btrim(p_patch->>'application_cycle'), '')
      else s.application_cycle
    end,
    deadline = case
      when p_patch ? 'deadline' then confirmed_deadline
      else s.deadline
    end,
    deadline_candidate = case
      when p_patch ? 'deadline' then confirmed_deadline
      else s.deadline_candidate
    end,
    deadline_confidence = case
      when p_patch ? 'deadline' and confirmed_deadline is not null
        then 100
      when p_patch ? 'deadline' then null
      else s.deadline_confidence
    end,
    deadline_verification_status = case
      when p_patch ? 'deadline' and confirmed_deadline is not null
        then 'verified'
      when p_patch ? 'deadline' then 'unconfirmed'
      else s.deadline_verification_status
    end,
    deadline_ambiguous = case
      when p_patch ? 'deadline' then false
      else s.deadline_ambiguous
    end,
    deadline_notes = case
      when p_patch ? 'deadline_notes'
        then nullif(btrim(p_patch->>'deadline_notes'), '')
      else s.deadline_notes
    end,
    updated_at = now()
  where s.id = p_scholarship_id
    and s.status = 'draft'
  returning s.* into result;

  if not found then
    raise exception 'Draft scholarship not found';
  end if;

  insert into public.admin_action_logs(
    admin_user_id,
    action,
    target_type,
    target_ids,
    details
  )
  values (
    auth.uid(),
    'update_scholarship_draft',
    'scholarship',
    array[p_scholarship_id],
    jsonb_build_object(
      'fields', (
        select jsonb_agg(key)
        from jsonb_object_keys(p_patch) key
      )
    )
  );

  return result;
end;
$$;

revoke execute on function public.update_scholarship_draft(uuid,jsonb)
from public, anon;
grant execute on function public.update_scholarship_draft(uuid,jsonb)
to authenticated;

create or replace function public.publish_scholarship_draft(
  p_scholarship_id uuid
)
returns public.scholarships
language plpgsql
security invoker
set search_path = public
as $$
declare
  readiness jsonb;
  blockers jsonb;
  result public.scholarships%rowtype;
begin
  if not public.is_admin() then
    raise exception 'Admin access required';
  end if;

  readiness := public.scholarship_draft_readiness(p_scholarship_id);
  blockers := readiness->'blockers';

  if coalesce(jsonb_array_length(blockers), 0) > 0 then
    raise exception 'Draft is not ready to publish: %',
      array_to_string(
        array(
          select jsonb_array_elements_text(blockers)
        ),
        '; '
      );
  end if;

  update public.scholarships
  set
    status = 'published',
    verification_status = 'verified',
    verified_at = now(),
    updated_at = now()
  where id = p_scholarship_id
    and status = 'draft'
  returning * into result;

  if not found then
    raise exception 'Draft scholarship not found';
  end if;

  insert into public.admin_action_logs(
    admin_user_id,
    action,
    target_type,
    target_ids,
    details
  )
  values (
    auth.uid(),
    'publish_scholarship_draft',
    'scholarship',
    array[p_scholarship_id],
    jsonb_build_object(
      'warnings', readiness->'warnings',
      'source_checked_at', result.last_successful_check_at
    )
  );

  return result;
end;
$$;

revoke execute on function public.publish_scholarship_draft(uuid)
from public, anon;
grant execute on function public.publish_scholarship_draft(uuid)
to authenticated;

-- Prevent the generic bulk verify action from bypassing the draft publication gate.
create or replace function public.admin_bulk_update_scholarships(
  p_ids uuid[],
  p_action text
)
returns integer
language plpgsql
security invoker
set search_path = public
as $$
declare
  affected integer := 0;
begin
  if not public.is_admin() then
    raise exception 'Admin access required';
  end if;

  if coalesce(cardinality(p_ids), 0) = 0 then
    return 0;
  end if;

  if p_action = 'verify' then
    update public.scholarships
    set
      verification_status = 'verified',
      verified_at = now()
    where id = any(p_ids)
      and status <> 'draft';
  elsif p_action = 'archive' then
    update public.scholarships
    set status = 'archived'
    where id = any(p_ids);
  elsif p_action = 'restore' then
    update public.scholarships
    set status = 'published'
    where id = any(p_ids)
      and status = 'archived';
  elsif p_action = 'mark_review' then
    update public.scholarships
    set verification_status = 'needs_review'
    where id = any(p_ids);
  else
    raise exception 'Unsupported bulk action: %', p_action;
  end if;

  get diagnostics affected = row_count;

  insert into public.admin_action_logs(
    admin_user_id,
    action,
    target_type,
    target_ids,
    details
  )
  values (
    auth.uid(),
    'bulk_' || p_action,
    'scholarship',
    p_ids,
    jsonb_build_object('affected', affected)
  );

  return affected;
end;
$$;

revoke execute on function public.admin_bulk_update_scholarships(uuid[],text)
from public, anon;
grant execute on function public.admin_bulk_update_scholarships(uuid[],text)
to authenticated;

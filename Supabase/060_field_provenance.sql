-- Data reliability step 28: durable field-level provenance and acceptance history.

create table if not exists public.scholarship_field_provenance (
  id uuid primary key default gen_random_uuid(),
  scholarship_id uuid not null
    references public.scholarships(id) on delete cascade,
  field_name text not null,
  provenance_type text not null
    check (provenance_type in ('manual','source_extracted')),
  source_candidate_id uuid
    references public.scholarship_source_candidates(id) on delete set null,
  source_url text,
  evidence_excerpt text,
  confidence integer
    check (confidence is null or confidence between 0 and 100),
  previous_value jsonb,
  accepted_value jsonb,
  accepted_by uuid references auth.users(id) on delete set null,
  accepted_at timestamptz not null default now()
);

alter table public.scholarship_field_provenance enable row level security;

revoke all on public.scholarship_field_provenance
from anon, authenticated;

grant select on public.scholarship_field_provenance
to authenticated;

drop policy if exists "admins read scholarship field provenance"
on public.scholarship_field_provenance;

create policy "admins read scholarship field provenance"
on public.scholarship_field_provenance
for select to authenticated
using (public.is_admin());

create index if not exists scholarship_field_provenance_lookup_idx
  on public.scholarship_field_provenance(
    scholarship_id,
    field_name,
    accepted_at desc
  );

create or replace function public.record_scholarship_field_provenance(
  p_scholarship_id uuid,
  p_field_name text,
  p_previous_value jsonb,
  p_accepted_value jsonb
)
returns uuid
language plpgsql
security invoker
set search_path = public
as $$
declare
  c public.scholarship_source_candidates%rowtype;
  p public.scholarship_source_candidate_profiles%rowtype;
  provenance_type text := 'manual';
  evidence text;
  confidence integer;
  source_url text;
  new_id uuid;
  matches_source boolean := false;
begin
  if not public.is_admin() then
    raise exception 'Admin access required';
  end if;

  select * into c
  from public.scholarship_source_candidates
  where draft_scholarship_id = p_scholarship_id
  order by reviewed_at desc nulls last, last_seen_at desc
  limit 1;

  if found then
    select * into p
    from public.scholarship_source_candidate_profiles
    where candidate_id = c.id;

    source_url := c.candidate_url;

    if found then
      case p_field_name
        when 'degree_levels' then
          matches_source :=
            p_accepted_value = to_jsonb(p.detected_degree_levels);
          evidence := p.eligibility_excerpt;
          confidence := p.degree_confidence;
        when 'funding_type' then
          matches_source :=
            p_accepted_value = to_jsonb(p.detected_funding_type);
          evidence := p.funding_excerpt;
          confidence := p.funding_confidence;
        when 'tuition_coverage' then
          matches_source :=
            p_accepted_value = to_jsonb(p.detected_tuition_coverage);
          evidence := p.benefits_excerpt;
          confidence := p.funding_confidence;
        when 'stipend' then
          matches_source :=
            p_accepted_value = to_jsonb(p.detected_stipend);
          evidence := p.benefits_excerpt;
          confidence := p.funding_confidence;
        when 'airfare' then
          matches_source :=
            p_accepted_value = to_jsonb(p.detected_airfare);
          evidence := p.benefits_excerpt;
          confidence := p.funding_confidence;
        when 'accommodation' then
          matches_source :=
            p_accepted_value = to_jsonb(p.detected_accommodation);
          evidence := p.benefits_excerpt;
          confidence := p.funding_confidence;
        when 'health_insurance' then
          matches_source :=
            p_accepted_value = to_jsonb(p.detected_health_insurance);
          evidence := p.benefits_excerpt;
          confidence := p.funding_confidence;
        when 'eligible_nationalities' then
          matches_source :=
            p_accepted_value = to_jsonb(p.detected_eligible_nationalities);
          evidence := p.eligibility_excerpt;
          confidence := p.eligibility_confidence;
        when 'application_cycle' then
          matches_source :=
            p_accepted_value = to_jsonb(p.detected_cycle);
          evidence := p.application_excerpt;
          confidence := p.cycle_confidence;
        when 'deadline' then
          matches_source :=
            p_accepted_value = to_jsonb(p.detected_deadline::text);
          evidence := p.application_excerpt;
          confidence := p.deadline_confidence;
        when 'description' then
          matches_source :=
            p_accepted_value = to_jsonb(p.meta_description);
          evidence := p.meta_description;
          confidence := null;
        else
          matches_source := false;
      end case;
    end if;
  end if;

  if matches_source then
    provenance_type := 'source_extracted';
  else
    source_url := null;
    evidence := null;
    confidence := null;
  end if;

  insert into public.scholarship_field_provenance(
    scholarship_id,
    field_name,
    provenance_type,
    source_candidate_id,
    source_url,
    evidence_excerpt,
    confidence,
    previous_value,
    accepted_value,
    accepted_by
  )
  values (
    p_scholarship_id,
    p_field_name,
    provenance_type,
    case when provenance_type = 'source_extracted' then c.id else null end,
    source_url,
    evidence,
    confidence,
    p_previous_value,
    p_accepted_value,
    auth.uid()
  )
  returning id into new_id;

  return new_id;
end;
$$;

revoke execute on function public.record_scholarship_field_provenance(
  uuid,text,jsonb,jsonb
) from public, anon;
grant execute on function public.record_scholarship_field_provenance(
  uuid,text,jsonb,jsonb
) to authenticated;

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
  before_row public.scholarships%rowtype;
  result public.scholarships%rowtype;
  invalid_key text;
  confirmed_deadline date;
  field_name text;
  before_value jsonb;
  after_value jsonb;
begin
  if not public.is_admin() then
    raise exception 'Admin access required';
  end if;

  if jsonb_typeof(p_patch) <> 'object' then
    raise exception 'Patch must be a JSON object';
  end if;

  select * into before_row
  from public.scholarships
  where id = p_scholarship_id
    and status = 'draft'
  for update;

  if not found then
    raise exception 'Draft scholarship not found';
  end if;

  select key into invalid_key
  from jsonb_object_keys(p_patch) key
  where key not in (
    'title','provider','country','region','degree_levels','fields',
    'funding_type','tuition_coverage','stipend','airfare','accommodation',
    'health_insurance','sat_required','eligible_nationalities','description',
    'application_cycle','deadline','deadline_notes'
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
    title = case when p_patch ? 'title'
      then nullif(btrim(p_patch->>'title'), '') else s.title end,
    provider = case when p_patch ? 'provider'
      then nullif(btrim(p_patch->>'provider'), '') else s.provider end,
    country = case when p_patch ? 'country'
      then nullif(btrim(p_patch->>'country'), '') else s.country end,
    region = case when p_patch ? 'region'
      then nullif(btrim(p_patch->>'region'), '') else s.region end,
    degree_levels = case when p_patch ? 'degree_levels' then
      array(
        select value
        from jsonb_array_elements_text(p_patch->'degree_levels')
        where nullif(btrim(value), '') is not null
      ) else s.degree_levels end,
    fields = case when p_patch ? 'fields' then
      array(
        select value
        from jsonb_array_elements_text(p_patch->'fields')
        where nullif(btrim(value), '') is not null
      ) else s.fields end,
    funding_type = case when p_patch ? 'funding_type'
      then nullif(btrim(p_patch->>'funding_type'), '') else s.funding_type end,
    tuition_coverage = case when p_patch ? 'tuition_coverage'
      then nullif(btrim(p_patch->>'tuition_coverage'), '') else s.tuition_coverage end,
    stipend = case when p_patch ? 'stipend'
      then nullif(btrim(p_patch->>'stipend'), '') else s.stipend end,
    airfare = case when p_patch ? 'airfare'
      then coalesce((p_patch->>'airfare')::boolean, false) else s.airfare end,
    accommodation = case when p_patch ? 'accommodation'
      then coalesce((p_patch->>'accommodation')::boolean, false) else s.accommodation end,
    health_insurance = case when p_patch ? 'health_insurance'
      then coalesce((p_patch->>'health_insurance')::boolean, false) else s.health_insurance end,
    sat_required = case when p_patch ? 'sat_required'
      then coalesce((p_patch->>'sat_required')::boolean, false) else s.sat_required end,
    eligible_nationalities = case when p_patch ? 'eligible_nationalities' then
      array(
        select value
        from jsonb_array_elements_text(p_patch->'eligible_nationalities')
        where nullif(btrim(value), '') is not null
      ) else s.eligible_nationalities end,
    description = case when p_patch ? 'description'
      then nullif(btrim(p_patch->>'description'), '') else s.description end,
    application_cycle = case when p_patch ? 'application_cycle'
      then nullif(btrim(p_patch->>'application_cycle'), '') else s.application_cycle end,
    deadline = case when p_patch ? 'deadline'
      then confirmed_deadline else s.deadline end,
    deadline_candidate = case when p_patch ? 'deadline'
      then confirmed_deadline else s.deadline_candidate end,
    deadline_confidence = case
      when p_patch ? 'deadline' and confirmed_deadline is not null then 100
      when p_patch ? 'deadline' then null
      else s.deadline_confidence
    end,
    deadline_verification_status = case
      when p_patch ? 'deadline' and confirmed_deadline is not null then 'verified'
      when p_patch ? 'deadline' then 'unconfirmed'
      else s.deadline_verification_status
    end,
    deadline_ambiguous = case when p_patch ? 'deadline'
      then false else s.deadline_ambiguous end,
    deadline_notes = case when p_patch ? 'deadline_notes'
      then nullif(btrim(p_patch->>'deadline_notes'), '') else s.deadline_notes end,
    updated_at = now()
  where s.id = p_scholarship_id
  returning s.* into result;

  for field_name in
    select key from jsonb_object_keys(p_patch) key
  loop
    before_value := case field_name
      when 'title' then to_jsonb(before_row.title)
      when 'provider' then to_jsonb(before_row.provider)
      when 'country' then to_jsonb(before_row.country)
      when 'region' then to_jsonb(before_row.region)
      when 'degree_levels' then to_jsonb(before_row.degree_levels)
      when 'fields' then to_jsonb(before_row.fields)
      when 'funding_type' then to_jsonb(before_row.funding_type)
      when 'tuition_coverage' then to_jsonb(before_row.tuition_coverage)
      when 'stipend' then to_jsonb(before_row.stipend)
      when 'airfare' then to_jsonb(before_row.airfare)
      when 'accommodation' then to_jsonb(before_row.accommodation)
      when 'health_insurance' then to_jsonb(before_row.health_insurance)
      when 'sat_required' then to_jsonb(before_row.sat_required)
      when 'eligible_nationalities' then to_jsonb(before_row.eligible_nationalities)
      when 'description' then to_jsonb(before_row.description)
      when 'application_cycle' then to_jsonb(before_row.application_cycle)
      when 'deadline' then to_jsonb(before_row.deadline::text)
      when 'deadline_notes' then to_jsonb(before_row.deadline_notes)
      else 'null'::jsonb
    end;

    after_value := case field_name
      when 'title' then to_jsonb(result.title)
      when 'provider' then to_jsonb(result.provider)
      when 'country' then to_jsonb(result.country)
      when 'region' then to_jsonb(result.region)
      when 'degree_levels' then to_jsonb(result.degree_levels)
      when 'fields' then to_jsonb(result.fields)
      when 'funding_type' then to_jsonb(result.funding_type)
      when 'tuition_coverage' then to_jsonb(result.tuition_coverage)
      when 'stipend' then to_jsonb(result.stipend)
      when 'airfare' then to_jsonb(result.airfare)
      when 'accommodation' then to_jsonb(result.accommodation)
      when 'health_insurance' then to_jsonb(result.health_insurance)
      when 'sat_required' then to_jsonb(result.sat_required)
      when 'eligible_nationalities' then to_jsonb(result.eligible_nationalities)
      when 'description' then to_jsonb(result.description)
      when 'application_cycle' then to_jsonb(result.application_cycle)
      when 'deadline' then to_jsonb(result.deadline::text)
      when 'deadline_notes' then to_jsonb(result.deadline_notes)
      else 'null'::jsonb
    end;

    if before_value is distinct from after_value then
      perform public.record_scholarship_field_provenance(
        p_scholarship_id,
        field_name,
        before_value,
        after_value
      );
    end if;
  end loop;

  insert into public.admin_action_logs(
    admin_user_id, action, target_type, target_ids, details
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

create or replace function public.scholarship_field_provenance_history(
  p_scholarship_id uuid
)
returns table (
  id uuid,
  field_name text,
  provenance_type text,
  source_url text,
  evidence_excerpt text,
  confidence integer,
  previous_value jsonb,
  accepted_value jsonb,
  accepted_by uuid,
  accepted_at timestamptz
)
language sql
stable
security invoker
set search_path = public
as $$
  select
    p.id,
    p.field_name,
    p.provenance_type,
    p.source_url,
    p.evidence_excerpt,
    p.confidence,
    p.previous_value,
    p.accepted_value,
    p.accepted_by,
    p.accepted_at
  from public.scholarship_field_provenance p
  where p.scholarship_id = p_scholarship_id
    and public.is_admin()
  order by p.accepted_at desc;
$$;

revoke execute on function public.scholarship_field_provenance_history(uuid)
from public, anon;
grant execute on function public.scholarship_field_provenance_history(uuid)
to authenticated;

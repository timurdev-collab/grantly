-- Data reliability step 17: quality-gate imported scholarship data.
-- Imported data may be useful, but it is never treated as verified merely because it was imported.

create or replace function public.commit_scholarship_import(p_batch_id uuid)
returns jsonb
language plpgsql
security invoker
set search_path = public
as $$
declare
  row_record public.scholarship_import_rows%rowtype;
  p jsonb;
  target_id uuid;
  inserted_count integer := 0;
  updated_count integer := 0;
  skipped_count integer := 0;
begin
  if not public.is_admin() then raise exception 'Admin access required'; end if;

  if not exists (
    select 1 from public.scholarship_import_batches
    where id = p_batch_id and status = 'staged'
  ) then
    raise exception 'Import batch is not staged';
  end if;

  for row_record in
    select * from public.scholarship_import_rows
    where batch_id = p_batch_id
    order by row_number
  loop
    p := row_record.normalized_payload;

    if row_record.proposed_action = 'insert' then
      insert into public.scholarships(
        slug,title,provider,country,region,degree_levels,fields,
        funding_type,tuition_coverage,stipend,airfare,accommodation,
        health_insurance,sat_required,eligible_nationalities,deadline,
        official_url,status,description,source_label,source_url,
        source_license,verification_status,application_cycle,
        deadline_notes,last_checked_at,last_successful_check_at,
        link_status,deadline_verification_status,cycle_status,next_check_at
      )
      values (
        p->>'slug',p->>'title',p->>'provider',p->>'country',p->>'region',
        array(select jsonb_array_elements_text(p->'degree_levels')),
        array(select jsonb_array_elements_text(p->'fields')),
        p->>'funding_type',p->>'tuition_coverage',p->>'stipend',
        coalesce((p->>'airfare')::boolean,false),
        coalesce((p->>'accommodation')::boolean,false),
        coalesce((p->>'health_insurance')::boolean,false),
        coalesce((p->>'sat_required')::boolean,false),
        array(select jsonb_array_elements_text(p->'eligible_nationalities')),
        nullif(p->>'deadline','')::date,
        p->>'official_url',
        case when p->>'status' = 'archived' then 'archived' else 'draft' end,
        p->>'description',
        p->>'source_label',
        p->>'source_url',
        p->>'source_license',
        'needs_review',
        p->>'application_cycle',
        p->>'deadline_notes',
        null,
        null,
        'unchecked',
        case
          when nullif(p->>'deadline','') is not null then 'candidate'
          else 'unconfirmed'
        end,
        'unknown',
        now()
      )
      returning id into target_id;

      update public.scholarship_import_rows
      set applied_scholarship_id = target_id
      where id = row_record.id;

      inserted_count := inserted_count + 1;

    elsif row_record.proposed_action = 'update' then
      target_id := row_record.matched_scholarship_id;

      update public.scholarship_import_rows
      set before_snapshot = (
        select to_jsonb(s)
        from public.scholarships s
        where s.id = target_id
      )
      where id = row_record.id;

      update public.scholarships
      set
        title = p->>'title',
        provider = p->>'provider',
        country = p->>'country',
        region = p->>'region',
        degree_levels = array(
          select jsonb_array_elements_text(p->'degree_levels')
        ),
        fields = array(
          select jsonb_array_elements_text(p->'fields')
        ),
        funding_type = p->>'funding_type',
        tuition_coverage = p->>'tuition_coverage',
        stipend = p->>'stipend',
        airfare = coalesce((p->>'airfare')::boolean,false),
        accommodation = coalesce((p->>'accommodation')::boolean,false),
        health_insurance = coalesce((p->>'health_insurance')::boolean,false),
        sat_required = coalesce((p->>'sat_required')::boolean,false),
        eligible_nationalities = array(
          select jsonb_array_elements_text(p->'eligible_nationalities')
        ),
        deadline = nullif(p->>'deadline','')::date,
        official_url = p->>'official_url',
        description = p->>'description',
        source_label = p->>'source_label',
        source_url = p->>'source_url',
        source_license = p->>'source_license',
        application_cycle = p->>'application_cycle',
        deadline_notes = p->>'deadline_notes',
        verification_status = 'needs_review',
        link_status = 'unchecked',
        last_checked_at = null,
        last_successful_check_at = null,
        audit_error = null,
        audit_failure_count = 0,
        deadline_candidate = nullif(p->>'deadline','')::date,
        deadline_confidence = case
          when nullif(p->>'deadline','') is not null then 50
          else null
        end,
        deadline_verification_status = case
          when nullif(p->>'deadline','') is not null then 'candidate'
          else 'unconfirmed'
        end,
        cycle_candidate = p->>'application_cycle',
        cycle_confidence = case
          when nullif(p->>'application_cycle','') is not null then 50
          else null
        end,
        cycle_status = 'unknown',
        next_check_at = now(),
        updated_at = now()
      where id = target_id;

      update public.scholarship_import_rows
      set applied_scholarship_id = target_id
      where id = row_record.id;

      updated_count := updated_count + 1;

    elsif row_record.proposed_action = 'skip' then
      skipped_count := skipped_count + 1;
    end if;
  end loop;

  update public.scholarship_import_batches
  set
    status = 'committed',
    insert_count = inserted_count,
    update_count = updated_count,
    skip_count = skipped_count,
    committed_at = now()
  where id = p_batch_id;

  insert into public.admin_action_logs(
    admin_user_id,
    action,
    target_type,
    details
  )
  values (
    auth.uid(),
    'commit_scholarship_import',
    'import_batch',
    jsonb_build_object(
      'batch_id', p_batch_id,
      'inserted', inserted_count,
      'updated', updated_count,
      'skipped', skipped_count,
      'quality_gate', true
    )
  );

  return jsonb_build_object(
    'inserted', inserted_count,
    'updated', updated_count,
    'skipped', skipped_count
  );
end;
$$;

revoke execute on function public.commit_scholarship_import(uuid)
from public, anon;

grant execute on function public.commit_scholarship_import(uuid)
to authenticated;

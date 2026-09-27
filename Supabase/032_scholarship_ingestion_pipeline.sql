-- Backend step 9: structured scholarship ingestion, validation,
-- deduplication, provenance, import history and rollback.

create table if not exists public.scholarship_import_batches (
  id uuid primary key default gen_random_uuid(),
  created_by uuid references auth.users(id) on delete set null,
  source_label text not null,
  source_url text,
  status text not null default 'staged'
    check (status in ('staged','committed','rolled_back','failed')),
  total_rows integer not null default 0,
  insert_count integer not null default 0,
  update_count integer not null default 0,
  skip_count integer not null default 0,
  error_count integer not null default 0,
  committed_at timestamptz,
  rolled_back_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.scholarship_import_rows (
  id bigint generated always as identity primary key,
  batch_id uuid not null references public.scholarship_import_batches(id) on delete cascade,
  row_number integer not null,
  raw_payload jsonb not null,
  normalized_payload jsonb,
  matched_scholarship_id uuid references public.scholarships(id) on delete set null,
  proposed_action text not null default 'error'
    check (proposed_action in ('insert','update','skip','error')),
  validation_errors text[] not null default '{}',
  applied_scholarship_id uuid references public.scholarships(id) on delete set null,
  before_snapshot jsonb,
  created_at timestamptz not null default now(),
  unique(batch_id, row_number)
);

alter table public.scholarship_import_batches enable row level security;
alter table public.scholarship_import_rows enable row level security;

revoke all on public.scholarship_import_batches, public.scholarship_import_rows
from anon, authenticated;

grant select on public.scholarship_import_batches, public.scholarship_import_rows
to authenticated;

drop policy if exists "admins read import batches" on public.scholarship_import_batches;
create policy "admins read import batches"
on public.scholarship_import_batches
for select to authenticated
using (public.is_admin());

drop policy if exists "admins read import rows" on public.scholarship_import_rows;
create policy "admins read import rows"
on public.scholarship_import_rows
for select to authenticated
using (public.is_admin());

create index if not exists scholarship_import_batches_created_idx
  on public.scholarship_import_batches(created_at desc);
create index if not exists scholarship_import_rows_batch_idx
  on public.scholarship_import_rows(batch_id, row_number);
create index if not exists scholarship_import_rows_match_idx
  on public.scholarship_import_rows(matched_scholarship_id)
  where matched_scholarship_id is not null;

create or replace function public.normalize_import_text_array(p_value jsonb)
returns text[]
language plpgsql
immutable
security invoker
set search_path = public
as $$
declare
  result text[];
begin
  if p_value is null or p_value = 'null'::jsonb then return '{}'; end if;

  if jsonb_typeof(p_value) = 'array' then
    select coalesce(array_agg(distinct btrim(value)) filter (where btrim(value) <> ''), '{}')
    into result
    from jsonb_array_elements_text(p_value);
    return result;
  end if;

  if jsonb_typeof(p_value) = 'string' then
    select coalesce(array_agg(distinct btrim(value)) filter (where btrim(value) <> ''), '{}')
    into result
    from unnest(string_to_array(trim(both '"' from p_value::text), ',')) value;
    return result;
  end if;

  return '{}';
end;
$$;

create or replace function public.stage_scholarship_import(
  p_source_label text,
  p_source_url text,
  p_records jsonb
)
returns uuid
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_batch_id uuid;
  rec jsonb;
  rn integer := 0;
  normalized jsonb;
  errors text[];
  matched uuid;
  action text;
  degree_levels text[];
  fields text[];
  nationalities text[];
  v_title text;
  v_provider text;
  v_country text;
  v_slug text;
  v_url text;
  v_deadline date;
  v_status text;
  v_verification text;
  v_funding text;
begin
  if not public.is_admin() then raise exception 'Admin access required'; end if;
  if jsonb_typeof(p_records) <> 'array' then raise exception 'Import records must be a JSON array'; end if;

  insert into public.scholarship_import_batches(created_by, source_label, source_url)
  values (
    auth.uid(),
    coalesce(nullif(btrim(p_source_label), ''), 'Manual import'),
    nullif(btrim(p_source_url), '')
  )
  returning id into v_batch_id;

  for rec in select value from jsonb_array_elements(p_records)
  loop
    rn := rn + 1;
    errors := '{}';
    matched := null;
    action := 'error';

    v_title := nullif(btrim(rec->>'title'), '');
    v_provider := nullif(btrim(rec->>'provider'), '');
    v_country := nullif(btrim(rec->>'country'), '');
    v_funding := coalesce(nullif(btrim(rec->>'funding_type'), ''), 'Varies');
    v_url := nullif(btrim(rec->>'official_url'), '');
    v_status := coalesce(nullif(btrim(rec->>'status'), ''), 'draft');
    v_verification := coalesce(nullif(btrim(rec->>'verification_status'), ''), 'needs_review');

    v_slug := nullif(btrim(rec->>'slug'), '');
    if v_slug is null and v_title is not null then
      v_slug := lower(regexp_replace(regexp_replace(v_title, '[^a-zA-Z0-9]+', '-', 'g'), '(^-|-$)', '', 'g'));
    end if;

    degree_levels := public.normalize_import_text_array(rec->'degree_levels');
    fields := public.normalize_import_text_array(rec->'fields');
    nationalities := public.normalize_import_text_array(rec->'eligible_nationalities');

    if cardinality(fields) = 0 then fields := array['All fields']; end if;
    if cardinality(nationalities) = 0 then nationalities := array['ALL']; end if;

    begin
      v_deadline := nullif(btrim(rec->>'deadline'), '')::date;
    exception when others then
      v_deadline := null;
      errors := array_append(errors, 'Invalid deadline');
    end;

    if v_title is null then errors := array_append(errors, 'Missing title'); end if;
    if v_provider is null then errors := array_append(errors, 'Missing provider'); end if;
    if v_country is null then errors := array_append(errors, 'Missing country'); end if;
    if v_url is null or v_url !~ '^https?://' then errors := array_append(errors, 'Missing or invalid official_url'); end if;

    if v_status not in ('draft','published','archived') then
      errors := array_append(errors, 'Invalid status');
      v_status := 'draft';
    end if;

    if v_verification not in ('verified','curated','needs_review') then
      errors := array_append(errors, 'Invalid verification_status');
      v_verification := 'needs_review';
    end if;

    normalized := jsonb_build_object(
      'slug', v_slug,
      'title', v_title,
      'provider', v_provider,
      'country', v_country,
      'region', coalesce(nullif(btrim(rec->>'region'), ''), 'Global'),
      'degree_levels', to_jsonb(degree_levels),
      'fields', to_jsonb(fields),
      'funding_type', v_funding,
      'tuition_coverage', nullif(btrim(rec->>'tuition_coverage'), ''),
      'stipend', nullif(btrim(rec->>'stipend'), ''),
      'airfare', coalesce((rec->>'airfare')::boolean, false),
      'accommodation', coalesce((rec->>'accommodation')::boolean, false),
      'health_insurance', coalesce((rec->>'health_insurance')::boolean, false),
      'sat_required', coalesce((rec->>'sat_required')::boolean, false),
      'eligible_nationalities', to_jsonb(nationalities),
      'deadline', case when v_deadline is null then null else to_jsonb(v_deadline) end,
      'official_url', v_url,
      'status', v_status,
      'description', nullif(btrim(rec->>'description'), ''),
      'source_label', coalesce(nullif(btrim(rec->>'source_label'), ''), p_source_label),
      'source_url', coalesce(nullif(btrim(rec->>'source_url'), ''), p_source_url),
      'source_license', nullif(btrim(rec->>'source_license'), ''),
      'verification_status', v_verification,
      'application_cycle', nullif(btrim(rec->>'application_cycle'), ''),
      'deadline_notes', nullif(btrim(rec->>'deadline_notes'), '')
    );

    if cardinality(errors) = 0 then
      select s.id into matched
      from public.scholarships s
      where lower(btrim(s.title)) = lower(btrim(v_title))
        and lower(btrim(s.provider)) = lower(btrim(v_provider))
        and lower(btrim(s.country)) = lower(btrim(v_country))
      order by s.updated_at desc
      limit 1;

      if matched is null and v_slug is not null then
        select s.id into matched
        from public.scholarships s
        where lower(s.slug) = lower(v_slug)
        limit 1;
      end if;

      if matched is null then
        action := 'insert';
      elsif exists (
        select 1
        from public.scholarships s
        where s.id = matched
          and lower(btrim(s.title)) = lower(btrim(v_title))
          and lower(btrim(s.provider)) = lower(btrim(v_provider))
          and lower(btrim(s.country)) = lower(btrim(v_country))
          and lower(btrim(s.official_url)) = lower(btrim(v_url))
          and s.deadline is not distinct from v_deadline
          and lower(s.funding_type) = lower(v_funding)
      ) then
        action := 'skip';
      else
        action := 'update';
      end if;
    end if;

    insert into public.scholarship_import_rows(
      batch_id,row_number,raw_payload,normalized_payload,
      matched_scholarship_id,proposed_action,validation_errors
    )
    values (v_batch_id,rn,rec,normalized,matched,action,errors);
  end loop;

  update public.scholarship_import_batches b
  set
    total_rows = x.total_rows,
    insert_count = x.insert_count,
    update_count = x.update_count,
    skip_count = x.skip_count,
    error_count = x.error_count
  from (
    select
      count(*)::integer as total_rows,
      count(*) filter (where proposed_action = 'insert')::integer as insert_count,
      count(*) filter (where proposed_action = 'update')::integer as update_count,
      count(*) filter (where proposed_action = 'skip')::integer as skip_count,
      count(*) filter (where proposed_action = 'error')::integer as error_count
    from public.scholarship_import_rows
    where batch_id = v_batch_id
  ) x
  where b.id = v_batch_id;

  insert into public.admin_action_logs(admin_user_id,action,target_type,details)
  values (auth.uid(),'stage_scholarship_import','import_batch',jsonb_build_object('batch_id', v_batch_id));

  return v_batch_id;
end;
$$;

revoke execute on function public.stage_scholarship_import(text,text,jsonb) from public, anon;
grant execute on function public.stage_scholarship_import(text,text,jsonb) to authenticated;

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
    where batch_id = p_batch_id order by row_number
  loop
    p := row_record.normalized_payload;

    if row_record.proposed_action = 'insert' then
      insert into public.scholarships(
        slug,title,provider,country,region,degree_levels,fields,
        funding_type,tuition_coverage,stipend,airfare,accommodation,
        health_insurance,sat_required,eligible_nationalities,deadline,
        official_url,status,description,source_label,source_url,
        source_license,verification_status,application_cycle,
        deadline_notes,last_checked_at
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
        p->>'official_url',p->>'status',p->>'description',
        p->>'source_label',p->>'source_url',p->>'source_license',
        p->>'verification_status',p->>'application_cycle',
        p->>'deadline_notes',now()
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
        select to_jsonb(s) from public.scholarships s where s.id = target_id
      )
      where id = row_record.id;

      update public.scholarships
      set
        title = p->>'title',
        provider = p->>'provider',
        country = p->>'country',
        region = p->>'region',
        degree_levels = array(select jsonb_array_elements_text(p->'degree_levels')),
        fields = array(select jsonb_array_elements_text(p->'fields')),
        funding_type = p->>'funding_type',
        tuition_coverage = p->>'tuition_coverage',
        stipend = p->>'stipend',
        airfare = coalesce((p->>'airfare')::boolean,false),
        accommodation = coalesce((p->>'accommodation')::boolean,false),
        health_insurance = coalesce((p->>'health_insurance')::boolean,false),
        sat_required = coalesce((p->>'sat_required')::boolean,false),
        eligible_nationalities = array(select jsonb_array_elements_text(p->'eligible_nationalities')),
        deadline = nullif(p->>'deadline','')::date,
        official_url = p->>'official_url',
        status = p->>'status',
        description = p->>'description',
        source_label = p->>'source_label',
        source_url = p->>'source_url',
        source_license = p->>'source_license',
        verification_status = p->>'verification_status',
        application_cycle = p->>'application_cycle',
        deadline_notes = p->>'deadline_notes',
        last_checked_at = now()
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
  set status='committed', insert_count=inserted_count,
      update_count=updated_count, skip_count=skipped_count,
      committed_at=now()
  where id=p_batch_id;

  insert into public.admin_action_logs(admin_user_id,action,target_type,details)
  values (
    auth.uid(),'commit_scholarship_import','import_batch',
    jsonb_build_object('batch_id',p_batch_id,'inserted',inserted_count,'updated',updated_count,'skipped',skipped_count)
  );

  return jsonb_build_object('inserted',inserted_count,'updated',updated_count,'skipped',skipped_count);
end;
$$;

revoke execute on function public.commit_scholarship_import(uuid) from public, anon;
grant execute on function public.commit_scholarship_import(uuid) to authenticated;

create or replace function public.rollback_scholarship_import(p_batch_id uuid)
returns jsonb
language plpgsql
security invoker
set search_path = public
as $$
declare
  row_record public.scholarship_import_rows%rowtype;
  snap jsonb;
  removed_count integer := 0;
  restored_count integer := 0;
begin
  if not public.is_admin() then raise exception 'Admin access required'; end if;

  if not exists (
    select 1 from public.scholarship_import_batches
    where id=p_batch_id and status='committed'
  ) then
    raise exception 'Import batch is not committed';
  end if;

  for row_record in
    select * from public.scholarship_import_rows
    where batch_id=p_batch_id order by row_number desc
  loop
    if row_record.proposed_action='insert'
       and row_record.applied_scholarship_id is not null then
      delete from public.scholarships
      where id=row_record.applied_scholarship_id;
      removed_count := removed_count + 1;

    elsif row_record.proposed_action='update'
       and row_record.applied_scholarship_id is not null
       and row_record.before_snapshot is not null then
      snap := row_record.before_snapshot;

      update public.scholarships
      set
        slug=snap->>'slug',
        title=snap->>'title',
        provider=snap->>'provider',
        country=snap->>'country',
        region=snap->>'region',
        degree_levels=array(select jsonb_array_elements_text(snap->'degree_levels')),
        fields=array(select jsonb_array_elements_text(snap->'fields')),
        funding_type=snap->>'funding_type',
        tuition_coverage=snap->>'tuition_coverage',
        stipend=snap->>'stipend',
        airfare=coalesce((snap->>'airfare')::boolean,false),
        accommodation=coalesce((snap->>'accommodation')::boolean,false),
        health_insurance=coalesce((snap->>'health_insurance')::boolean,false),
        min_gpa_percent=nullif(snap->>'min_gpa_percent','')::numeric,
        min_ielts=nullif(snap->>'min_ielts','')::numeric,
        sat_required=coalesce((snap->>'sat_required')::boolean,false),
        eligible_nationalities=array(select jsonb_array_elements_text(snap->'eligible_nationalities')),
        deadline=nullif(snap->>'deadline','')::date,
        official_url=snap->>'official_url',
        status=snap->>'status',
        verified_at=nullif(snap->>'verified_at','')::timestamptz,
        description=snap->>'description',
        source_label=snap->>'source_label',
        source_url=snap->>'source_url',
        source_license=snap->>'source_license',
        verification_status=snap->>'verification_status',
        application_cycle=snap->>'application_cycle',
        deadline_notes=snap->>'deadline_notes',
        link_status=snap->>'link_status',
        last_checked_at=nullif(snap->>'last_checked_at','')::timestamptz,
        final_url=snap->>'final_url',
        deadline_candidate=nullif(snap->>'deadline_candidate','')::date,
        deadline_confidence=nullif(snap->>'deadline_confidence','')::integer
      where id=row_record.applied_scholarship_id;

      restored_count := restored_count + 1;
    end if;
  end loop;

  update public.scholarship_import_batches
  set status='rolled_back', rolled_back_at=now()
  where id=p_batch_id;

  insert into public.admin_action_logs(admin_user_id,action,target_type,details)
  values (
    auth.uid(),'rollback_scholarship_import','import_batch',
    jsonb_build_object('batch_id',p_batch_id,'removed',removed_count,'restored',restored_count)
  );

  return jsonb_build_object('removed',removed_count,'restored',restored_count);
end;
$$;

revoke execute on function public.rollback_scholarship_import(uuid) from public, anon;
grant execute on function public.rollback_scholarship_import(uuid) to authenticated;

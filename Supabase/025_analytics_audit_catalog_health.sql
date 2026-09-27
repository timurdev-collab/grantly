-- Backend step 5: product analytics, scholarship audit history, and catalog health.

create table if not exists public.product_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete set null,
  event_name text not null check (
    event_name in (
      'scholarship_view',
      'scholarship_save',
      'scholarship_unsave',
      'official_site_click',
      'search',
      'zero_result_search',
      'application_status_change',
      'notification_open'
    )
  ),
  scholarship_id uuid references public.scholarships(id) on delete set null,
  properties jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

alter table public.product_events enable row level security;
revoke all on public.product_events from anon, authenticated;
grant insert on public.product_events to authenticated;

drop policy if exists "users insert own analytics" on public.product_events;
create policy "users insert own analytics"
on public.product_events
for insert
to authenticated
with check (
  user_id is null or user_id = (select auth.uid())
);

create index if not exists product_events_name_created_idx
  on public.product_events(event_name, created_at desc);
create index if not exists product_events_scholarship_idx
  on public.product_events(scholarship_id, created_at desc)
  where scholarship_id is not null;
create index if not exists product_events_user_idx
  on public.product_events(user_id, created_at desc)
  where user_id is not null;

create table if not exists public.scholarship_change_history (
  id bigint generated always as identity primary key,
  scholarship_id uuid not null references public.scholarships(id) on delete cascade,
  changed_at timestamptz not null default now(),
  changed_by uuid references auth.users(id) on delete set null,
  changed_fields text[] not null default '{}',
  old_values jsonb not null,
  new_values jsonb not null
);

alter table public.scholarship_change_history enable row level security;
revoke all on public.scholarship_change_history from anon, authenticated;
grant select on public.scholarship_change_history to authenticated;

drop policy if exists "admins read scholarship history" on public.scholarship_change_history;
create policy "admins read scholarship history"
on public.scholarship_change_history
for select
to authenticated
using (public.is_admin());

create index if not exists scholarship_history_scholarship_idx
  on public.scholarship_change_history(scholarship_id, changed_at desc);

create or replace function public.capture_scholarship_history()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  tracked text[] := array[
    'title','provider','country','region','degree_levels','fields',
    'funding_type','tuition_coverage','stipend','airfare','accommodation',
    'health_insurance','min_gpa_percent','min_ielts',
    'eligible_nationalities','deadline','official_url','status',
    'verification_status','link_status'
  ];
  changed text[] := '{}';
  key text;
  old_json jsonb := to_jsonb(old);
  new_json jsonb := to_jsonb(new);
begin
  foreach key in array tracked loop
    if old_json -> key is distinct from new_json -> key then
      changed := array_append(changed, key);
    end if;
  end loop;

  if cardinality(changed) > 0 then
    insert into public.scholarship_change_history(
      scholarship_id, changed_by, changed_fields, old_values, new_values
    )
    values (
      new.id, auth.uid(), changed, old_json, new_json
    );
  end if;

  return new;
end;
$$;

revoke execute on function public.capture_scholarship_history()
  from public, anon, authenticated;

drop trigger if exists scholarships_capture_history on public.scholarships;
create trigger scholarships_capture_history
after update on public.scholarships
for each row execute function public.capture_scholarship_history();

create table if not exists public.catalog_health_issues (
  id uuid primary key default gen_random_uuid(),
  scholarship_id uuid not null references public.scholarships(id) on delete cascade,
  issue_type text not null check (
    issue_type in (
      'expired_deadline',
      'stale_source_check',
      'dead_link',
      'generic_link',
      'needs_review'
    )
  ),
  detail text not null,
  detected_at timestamptz not null default now(),
  resolved_at timestamptz,
  unique (scholarship_id, issue_type)
);

alter table public.catalog_health_issues enable row level security;
revoke all on public.catalog_health_issues from anon, authenticated;
grant select, update on public.catalog_health_issues to authenticated;

drop policy if exists "admins read catalog health" on public.catalog_health_issues;
create policy "admins read catalog health"
on public.catalog_health_issues
for select
to authenticated
using (public.is_admin());

drop policy if exists "admins update catalog health" on public.catalog_health_issues;
create policy "admins update catalog health"
on public.catalog_health_issues
for update
to authenticated
using (public.is_admin())
with check (public.is_admin());

create index if not exists catalog_health_open_idx
  on public.catalog_health_issues(issue_type, detected_at desc)
  where resolved_at is null;

create or replace function public.refresh_catalog_health_issues()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  touched integer := 0;
  current_count integer := 0;
begin
  insert into public.catalog_health_issues(
    scholarship_id, issue_type, detail, detected_at, resolved_at
  )
  select
    s.id,
    'expired_deadline',
    'Published scholarship deadline passed on ' || s.deadline::text,
    now(),
    null
  from public.scholarships s
  where s.status = 'published'
    and s.deadline is not null
    and s.deadline < current_date
  on conflict (scholarship_id, issue_type)
  do update set
    detail = excluded.detail,
    detected_at = excluded.detected_at,
    resolved_at = null;

  get diagnostics current_count = row_count;
  touched := touched + current_count;

  insert into public.catalog_health_issues(
    scholarship_id, issue_type, detail, detected_at, resolved_at
  )
  select
    s.id,
    'stale_source_check',
    'Official source has not been checked in more than 30 days.',
    now(),
    null
  from public.scholarships s
  where s.status = 'published'
    and (
      s.last_checked_at is null
      or s.last_checked_at < now() - interval '30 days'
    )
  on conflict (scholarship_id, issue_type)
  do update set
    detail = excluded.detail,
    detected_at = excluded.detected_at,
    resolved_at = null;

  get diagnostics current_count = row_count;
  touched := touched + current_count;

  insert into public.catalog_health_issues(
    scholarship_id, issue_type, detail, detected_at, resolved_at
  )
  select
    s.id,
    case when s.link_status = 'dead' then 'dead_link' else 'generic_link' end,
    case
      when s.link_status = 'dead' then 'Official source is unavailable.'
      else 'Official source points to a generic page.'
    end,
    now(),
    null
  from public.scholarships s
  where s.status = 'published'
    and s.link_status in ('dead', 'generic')
  on conflict (scholarship_id, issue_type)
  do update set
    detail = excluded.detail,
    detected_at = excluded.detected_at,
    resolved_at = null;

  get diagnostics current_count = row_count;
  touched := touched + current_count;

  insert into public.catalog_health_issues(
    scholarship_id, issue_type, detail, detected_at, resolved_at
  )
  select
    s.id,
    'needs_review',
    'Scholarship verification status requires review.',
    now(),
    null
  from public.scholarships s
  where s.status = 'published'
    and s.verification_status = 'needs_review'
  on conflict (scholarship_id, issue_type)
  do update set
    detail = excluded.detail,
    detected_at = excluded.detected_at,
    resolved_at = null;

  get diagnostics current_count = row_count;
  touched := touched + current_count;

  update public.catalog_health_issues i
  set resolved_at = now()
  where i.resolved_at is null
    and not exists (
      select 1
      from public.scholarships s
      where s.id = i.scholarship_id
        and (
          (i.issue_type = 'expired_deadline'
            and s.status = 'published'
            and s.deadline is not null
            and s.deadline < current_date)
          or
          (i.issue_type = 'stale_source_check'
            and s.status = 'published'
            and (
              s.last_checked_at is null
              or s.last_checked_at < now() - interval '30 days'
            ))
          or
          (i.issue_type = 'dead_link'
            and s.status = 'published'
            and s.link_status = 'dead')
          or
          (i.issue_type = 'generic_link'
            and s.status = 'published'
            and s.link_status = 'generic')
          or
          (i.issue_type = 'needs_review'
            and s.status = 'published'
            and s.verification_status = 'needs_review')
        )
    );

  return touched;
end;
$$;

revoke execute on function public.refresh_catalog_health_issues()
  from public, anon, authenticated;
grant execute on function public.refresh_catalog_health_issues()
  to postgres;

select cron.schedule(
  'grantly-catalog-health-daily',
  '42 2 * * *',
  $$select public.refresh_catalog_health_issues();$$
);

create or replace function public.admin_analytics_summary(
  p_days integer default 30
)
returns jsonb
language plpgsql
stable
security invoker
set search_path = public
as $$
declare
  result jsonb;
  since_time timestamptz;
begin
  if not public.is_admin() then
    raise exception 'Admin access required';
  end if;

  since_time := now() - make_interval(days => greatest(1, least(p_days, 365)));

  select jsonb_build_object(
    'days', greatest(1, least(p_days, 365)),
    'views', (
      select count(*) from public.product_events
      where event_name = 'scholarship_view' and created_at >= since_time
    ),
    'saves', (
      select count(*) from public.product_events
      where event_name = 'scholarship_save' and created_at >= since_time
    ),
    'official_clicks', (
      select count(*) from public.product_events
      where event_name = 'official_site_click' and created_at >= since_time
    ),
    'applications', (
      select count(*) from public.product_events
      where event_name = 'application_status_change'
        and created_at >= since_time
        and properties ->> 'status' in ('Submitted','Applied')
    ),
    'searches', (
      select count(*) from public.product_events
      where event_name = 'search' and created_at >= since_time
    ),
    'zero_result_searches', (
      select count(*) from public.product_events
      where event_name = 'zero_result_search' and created_at >= since_time
    ),
    'open_health_issues', (
      select count(*) from public.catalog_health_issues
      where resolved_at is null
    ),
    'top_scholarships', coalesce((
      select jsonb_agg(row_data)
      from (
        select jsonb_build_object(
          'id', s.id,
          'title', s.title,
          'provider', s.provider,
          'views', count(*) filter (where e.event_name = 'scholarship_view'),
          'saves', count(*) filter (where e.event_name = 'scholarship_save'),
          'official_clicks', count(*) filter (where e.event_name = 'official_site_click')
        ) as row_data
        from public.product_events e
        join public.scholarships s on s.id = e.scholarship_id
        where e.created_at >= since_time
          and e.scholarship_id is not null
        group by s.id, s.title, s.provider
        order by count(*) filter (where e.event_name = 'scholarship_view') desc,
                 count(*) filter (where e.event_name = 'scholarship_save') desc
        limit 10
      ) ranked
    ), '[]'::jsonb)
  )
  into result;

  return result;
end;
$$;

revoke execute on function public.admin_analytics_summary(integer)
  from public, anon;
grant execute on function public.admin_analytics_summary(integer)
  to authenticated;

create or replace function public.find_scholarship_duplicates(
  p_title text,
  p_provider text,
  p_country text
)
returns table (
  id uuid,
  title text,
  provider text,
  country text,
  similarity_score integer
)
language sql
stable
security invoker
set search_path = public
as $$
  select
    s.id,
    s.title,
    s.provider,
    s.country,
    (
      (case when lower(btrim(s.title)) = lower(btrim(p_title)) then 60 else 0 end) +
      (case when lower(btrim(s.provider)) = lower(btrim(p_provider)) then 30 else 0 end) +
      (case when lower(btrim(s.country)) = lower(btrim(p_country)) then 10 else 0 end)
    )::integer
  from public.scholarships s
  where
    lower(btrim(s.title)) = lower(btrim(p_title))
    or (
      lower(btrim(s.provider)) = lower(btrim(p_provider))
      and lower(btrim(s.country)) = lower(btrim(p_country))
      and lower(s.title) like '%' || lower(split_part(btrim(p_title), ' ', 1)) || '%'
    )
  order by 5 desc, s.title
  limit 10;
$$;

revoke execute on function public.find_scholarship_duplicates(text, text, text)
  from public, anon;
grant execute on function public.find_scholarship_duplicates(text, text, text)
  to authenticated;

select public.refresh_catalog_health_issues();

-- Data reliability step 18: protect against ambiguous deadline pages.
-- Multiple distinct deadline-like dates are treated as ambiguous evidence,
-- not as a single confirmed deadline candidate.

alter table public.scholarships
  add column if not exists deadline_candidate_count integer;

alter table public.scholarships
  add column if not exists deadline_ambiguous boolean not null default false;

alter table public.scholarships
  add column if not exists deadline_evidence text;

alter table public.scholarships
  drop constraint if exists scholarships_deadline_candidate_count_check;

alter table public.scholarships
  add constraint scholarships_deadline_candidate_count_check
  check (
    deadline_candidate_count is null or
    deadline_candidate_count >= 0
  );

alter table public.catalog_health_issues
  drop constraint if exists catalog_health_issues_issue_type_check;

alter table public.catalog_health_issues
  add constraint catalog_health_issues_issue_type_check
  check (
    issue_type in (
      'expired_deadline',
      'stale_source_check',
      'dead_link',
      'generic_link',
      'needs_review',
      'deadline_changed',
      'new_cycle_detected',
      'cycle_closed',
      'source_changed',
      'repeated_audit_failure',
      'ambiguous_deadline'
    )
  );

create or replace function public.refresh_reliability_health_issues()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  touched integer := 0;
  current_count integer := 0;
begin
  perform public.refresh_catalog_health_issues();

  insert into public.catalog_health_issues(
    scholarship_id, issue_type, detail, detected_at, resolved_at
  )
  select
    s.id,
    'deadline_changed',
    'Official source suggests a different deadline: ' ||
      coalesce(s.deadline_candidate::text, 'unknown') ||
      '. Current confirmed deadline: ' ||
      coalesce(s.deadline::text, 'not set') || '.',
    now(),
    null::timestamptz
  from public.scholarships s
  where s.status = 'published'
    and s.deadline_verification_status = 'changed'
    and coalesce(s.deadline_ambiguous, false) = false
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
    'ambiguous_deadline',
    'The official source contains ' ||
      coalesce(s.deadline_candidate_count, 0)::text ||
      ' distinct deadline-like dates. Manual review is required.',
    now(),
    null::timestamptz
  from public.scholarships s
  where s.status = 'published'
    and coalesce(s.deadline_ambiguous, false) = true
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
  select distinct
    c.scholarship_id,
    'new_cycle_detected',
    'A possible new application cycle was detected and is waiting for review.',
    now(),
    null::timestamptz
  from public.scholarship_detected_changes c
  join public.scholarships s on s.id = c.scholarship_id
  where c.status = 'pending'
    and c.field_name in ('application_cycle', 'cycle_status')
    and s.status = 'published'
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
    'cycle_closed',
    case
      when s.cycle_status = 'discontinued'
        then 'Official source appears to indicate this scholarship is discontinued.'
      else 'Current application cycle appears to be closed.'
    end,
    now(),
    null::timestamptz
  from public.scholarships s
  where s.status = 'published'
    and s.cycle_status in ('closed', 'discontinued')
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
  select distinct
    c.scholarship_id,
    'source_changed',
    'The official source page content changed since the previous successful check.',
    now(),
    null::timestamptz
  from public.scholarship_detected_changes c
  join public.scholarships s on s.id = c.scholarship_id
  where c.status = 'pending'
    and c.field_name = 'source_content'
    and s.status = 'published'
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
    'repeated_audit_failure',
    'Official source audit has failed ' ||
      s.audit_failure_count::text ||
      ' consecutive times.',
    now(),
    null::timestamptz
  from public.scholarships s
  where s.status = 'published'
    and s.audit_failure_count >= 2
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
    and i.issue_type in (
      'deadline_changed',
      'new_cycle_detected',
      'cycle_closed',
      'source_changed',
      'repeated_audit_failure',
      'ambiguous_deadline'
    )
    and not exists (
      select 1
      from public.scholarships s
      where s.id = i.scholarship_id
        and (
          (
            i.issue_type = 'deadline_changed'
            and s.status = 'published'
            and s.deadline_verification_status = 'changed'
            and coalesce(s.deadline_ambiguous, false) = false
          )
          or (
            i.issue_type = 'ambiguous_deadline'
            and s.status = 'published'
            and coalesce(s.deadline_ambiguous, false) = true
          )
          or (
            i.issue_type = 'new_cycle_detected'
            and s.status = 'published'
            and exists (
              select 1
              from public.scholarship_detected_changes c
              where c.scholarship_id = s.id
                and c.status = 'pending'
                and c.field_name in ('application_cycle', 'cycle_status')
            )
          )
          or (
            i.issue_type = 'cycle_closed'
            and s.status = 'published'
            and s.cycle_status in ('closed', 'discontinued')
          )
          or (
            i.issue_type = 'source_changed'
            and s.status = 'published'
            and exists (
              select 1
              from public.scholarship_detected_changes c
              where c.scholarship_id = s.id
                and c.status = 'pending'
                and c.field_name = 'source_content'
            )
          )
          or (
            i.issue_type = 'repeated_audit_failure'
            and s.status = 'published'
            and s.audit_failure_count >= 2
          )
        )
    );

  return touched;
end;
$$;

revoke execute on function public.refresh_reliability_health_issues()
from public, anon, authenticated;
grant execute on function public.refresh_reliability_health_issues()
to postgres;

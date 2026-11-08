-- Live priority queue for published scholarship corrections.
-- Applied in production and staging on 2026-11-08.
-- A security-invoker view preserves the base tables' RLS.
create or replace view public.scholarship_repair_queue
with (security_invoker = true)
as
with pending as (
  select scholarship_id,
    count(*)::integer as pending_change_count,
    bool_or(field_name = 'deadline') as has_deadline_change,
    bool_or(field_name = 'official_url') as has_url_change,
    bool_or(field_name in ('application_cycle', 'cycle_status')) as has_cycle_change,
    max(last_detected_at) as last_change_detected_at
  from public.scholarship_detected_changes
  where status = 'pending'
  group by scholarship_id
)
select s.id,s.slug,s.title,s.provider,s.status,s.verification_status,
  s.link_status,s.official_url,s.final_url,s.source_http_status,
  s.audit_error,s.last_checked_at,s.next_check_at,
  coalesce(p.pending_change_count,0) as pending_change_count,
  coalesce(p.has_deadline_change,false) as has_deadline_change,
  coalesce(p.has_url_change,false) as has_url_change,
  coalesce(p.has_cycle_change,false) as has_cycle_change,
  p.last_change_detected_at,
  case
    when s.link_status = 'dead' then 1
    when s.link_status = 'unchecked' then 2
    when coalesce(p.has_deadline_change,false) then 3
    when coalesce(p.has_url_change,false) then 4
    when coalesce(p.has_cycle_change,false) then 5
    when s.link_status = 'generic' then 6
    when s.verification_status = 'needs_review' then 7
    else 8
  end as priority,
  case
    when s.link_status = 'dead' then 'broken_official_link'
    when s.link_status = 'unchecked' then 'source_check_failed'
    when coalesce(p.has_deadline_change,false) then 'deadline_change'
    when coalesce(p.has_url_change,false) then 'official_url_change'
    when coalesce(p.has_cycle_change,false) then 'application_cycle_change'
    when s.link_status = 'generic' then 'generic_source'
    when s.verification_status = 'needs_review' then 'verification_pending'
    else 'routine'
  end as priority_reason
from public.scholarships s
left join pending p on p.scholarship_id=s.id
where s.status='published'
  and (s.verification_status='needs_review'
    or s.link_status in ('dead','unchecked','generic')
    or coalesce(p.pending_change_count,0)>0);

revoke all on public.scholarship_repair_queue from public, anon, authenticated;

grant select on public.scholarship_repair_queue to service_role;

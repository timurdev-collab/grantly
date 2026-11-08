-- Fix: protect live/published scholarships from starvation by the draft backlog.
-- The scheduler runs every 30 minutes in batches of 20.
-- Keep all existing eligibility, leasing, and source verification logic.
-- This migration does NOT modify verification dates or scholarship content.

create or replace function public.claim_due_scholarship_audits(
  p_limit integer default 20,
  p_force boolean default false
)
returns table(
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
set search_path to 'public'
as $function$
begin
  return query
  with candidates as (
    select s.id
    from public.scholarships s
    where (
      s.status = 'published'
      or (s.status = 'draft' and s.verification_status = 'needs_review')
    )
    and (p_force or s.next_check_at is null or s.next_check_at <= now())
    and (s.audit_lease_until is null or s.audit_lease_until <= now())
    order by
      (s.status = 'published') desc,
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
    s.id, s.title, s.provider, s.official_url,
    s.verification_status, s.link_status, s.audit_failure_count,
    s.last_successful_check_at, s.deadline, s.application_cycle,
    s.source_fingerprint, s.source_changed_at;
end;
$function$;

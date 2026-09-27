-- Data reliability step 6: transient failure resilience.
-- Temporary network/server failures should not immediately classify a source as dead.

alter table public.scholarships
  add column if not exists audit_failure_count integer not null default 0;

alter table public.scholarships
  add column if not exists last_successful_check_at timestamptz;

alter table public.scholarships
  drop constraint if exists scholarships_audit_failure_count_check;

alter table public.scholarships
  add constraint scholarships_audit_failure_count_check
  check (audit_failure_count >= 0);

update public.scholarships
set last_successful_check_at = coalesce(last_successful_check_at, last_checked_at)
where last_checked_at is not null
  and coalesce(link_status, 'unchecked') not in ('dead');

create index if not exists scholarships_audit_failure_idx
  on public.scholarships(audit_failure_count desc, next_check_at)
  where status = 'published' and audit_failure_count > 0;

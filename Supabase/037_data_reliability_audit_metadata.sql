-- Data reliability step 1: richer source auditing metadata.

alter table public.scholarships
  add column if not exists source_fingerprint text;

alter table public.scholarships
  add column if not exists source_changed_at timestamptz;

alter table public.scholarships
  add column if not exists source_http_status integer;

alter table public.scholarships
  add column if not exists audit_error text;

alter table public.scholarships
  add column if not exists cycle_status text not null default 'unknown';

alter table public.scholarships
  add column if not exists cycle_candidate text;

alter table public.scholarships
  add column if not exists cycle_confidence integer;

alter table public.scholarships
  add column if not exists deadline_verification_status text not null default 'unconfirmed';

alter table public.scholarships
  add column if not exists next_check_at timestamptz;

alter table public.scholarships
  drop constraint if exists scholarships_cycle_status_check;

alter table public.scholarships
  add constraint scholarships_cycle_status_check
  check (cycle_status in (
    'unknown','open','closed','upcoming','rolling','discontinued'
  ));

alter table public.scholarships
  drop constraint if exists scholarships_cycle_confidence_check;

alter table public.scholarships
  add constraint scholarships_cycle_confidence_check
  check (cycle_confidence is null or cycle_confidence between 0 and 100);

alter table public.scholarships
  drop constraint if exists scholarships_deadline_verification_status_check;

alter table public.scholarships
  add constraint scholarships_deadline_verification_status_check
  check (deadline_verification_status in (
    'unconfirmed','candidate','verified','changed','expired'
  ));

alter table public.scholarships
  drop constraint if exists scholarships_source_http_status_check;

alter table public.scholarships
  add constraint scholarships_source_http_status_check
  check (
    source_http_status is null or
    (source_http_status between 100 and 599)
  );

create index if not exists scholarships_next_check_idx
  on public.scholarships(next_check_at)
  where status = 'published';

update public.scholarships
set
  deadline_verification_status = case
    when deadline is not null and deadline < current_date then 'expired'
    when deadline is not null and verification_status = 'verified' then 'verified'
    when deadline_candidate is not null and deadline is distinct from deadline_candidate then 'changed'
    when deadline_candidate is not null then 'candidate'
    else 'unconfirmed'
  end,
  next_check_at = coalesce(
    next_check_at,
    case
      when deadline is not null and deadline <= current_date + 30 then now()
      when verification_status = 'needs_review' then now()
      when link_status in ('dead','generic','unchecked') then now()
      else now() + interval '7 days'
    end
  );

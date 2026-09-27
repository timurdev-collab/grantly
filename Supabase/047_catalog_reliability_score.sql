-- Data reliability step 13: catalog reliability scoring.
-- Scores are deterministic and based only on observed source/verification metadata.

alter table public.scholarships
  add column if not exists reliability_score integer not null default 0;

alter table public.scholarships
  drop constraint if exists scholarships_reliability_score_check;

alter table public.scholarships
  add constraint scholarships_reliability_score_check
  check (reliability_score between 0 and 100);

create or replace function public.calculate_scholarship_reliability_score(
  s public.scholarships
)
returns integer
language plpgsql
stable
security invoker
set search_path = public
as $$
declare
  score integer := 25;
  age_days numeric;
begin
  score := score + least(20, greatest(0, coalesce(s.source_authority_score, 50) / 5));

  score := score + case coalesce(s.verification_status, 'needs_review')
    when 'verified' then 15
    when 'curated' then 8
    else -15
  end;

  score := score + case coalesce(s.link_status, 'unchecked')
    when 'exact' then 20
    when 'reachable' then 10
    when 'unchecked' then 0
    when 'generic' then -15
    when 'dead' then -30
    else 0
  end;

  if s.last_successful_check_at is null then
    score := score - 5;
  else
    age_days := extract(epoch from (now() - s.last_successful_check_at)) / 86400.0;

    if age_days <= 7 then
      score := score + 15;
    elsif age_days <= 30 then
      score := score + 8;
    elsif age_days <= 60 then
      score := score + 2;
    else
      score := score - 8;
    end if;
  end if;

  score := score + case coalesce(s.deadline_verification_status, 'unconfirmed')
    when 'verified' then 10
    when 'candidate' then 4
    when 'changed' then -8
    when 'expired' then -20
    else 0
  end;

  score := score + case coalesce(s.cycle_status, 'unknown')
    when 'open' then 10
    when 'rolling' then 8
    when 'upcoming' then 5
    when 'closed' then -15
    when 'discontinued' then -30
    else 0
  end;

  score := score - least(20, greatest(0, coalesce(s.audit_failure_count, 0) * 5));

  if s.source_changed_at is not null
     and s.source_changed_at >= now() - interval '7 days' then
    score := score - 5;
  end if;

  return greatest(0, least(100, score));
end;
$$;

create or replace function public.set_scholarship_reliability_score()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.reliability_score :=
    public.calculate_scholarship_reliability_score(new);
  return new;
end;
$$;

drop trigger if exists trg_set_scholarship_reliability_score
on public.scholarships;

create trigger trg_set_scholarship_reliability_score
before insert or update of
  source_authority_score,
  verification_status,
  link_status,
  last_successful_check_at,
  deadline_verification_status,
  cycle_status,
  audit_failure_count,
  source_changed_at
on public.scholarships
for each row
execute function public.set_scholarship_reliability_score();

create or replace function public.refresh_scholarship_reliability_scores()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  touched integer;
begin
  update public.scholarships s
  set reliability_score = public.calculate_scholarship_reliability_score(s)
  where reliability_score is distinct from
    public.calculate_scholarship_reliability_score(s);

  get diagnostics touched = row_count;
  return touched;
end;
$$;

revoke execute on function public.refresh_scholarship_reliability_scores()
from public, anon, authenticated;
grant execute on function public.refresh_scholarship_reliability_scores()
to postgres;

select public.refresh_scholarship_reliability_scores();

create index if not exists scholarships_reliability_score_idx
  on public.scholarships(reliability_score desc)
  where status = 'published';

create or replace function public.scholarship_is_discoverable(
  s public.scholarships
)
returns boolean
language sql
stable
security invoker
set search_path = public
as $$
  select
    s.status = 'published'
    and coalesce(s.verification_status, 'verified') <> 'needs_review'
    and coalesce(s.link_status, 'unchecked') not in ('dead', 'generic')
    and coalesce(s.cycle_status, 'unknown') not in ('closed', 'discontinued')
    and (
      s.deadline is null
      or s.deadline >= current_date
    )
    and coalesce(s.deadline_verification_status, 'unconfirmed') <> 'expired'
    and coalesce(s.reliability_score, 0) >= 40;
$$;

revoke execute on function public.scholarship_is_discoverable(public.scholarships)
from public;
grant execute on function public.scholarship_is_discoverable(public.scholarships)
to anon, authenticated;

select cron.unschedule(jobid)
from cron.job
where jobname = 'grantly-reliability-score-refresh';

select cron.schedule(
  'grantly-reliability-score-refresh',
  '53 * * * *',
  $$select public.refresh_scholarship_reliability_scores();$$
);

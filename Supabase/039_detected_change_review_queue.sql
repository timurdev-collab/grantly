-- Data reliability step 3: detected-change review queue.
-- Important source changes are recorded separately and never silently
-- overwrite confirmed scholarship fields.

create table if not exists public.scholarship_detected_changes (
  id uuid primary key default gen_random_uuid(),
  scholarship_id uuid not null references public.scholarships(id) on delete cascade,
  field_name text not null check (
    field_name in (
      'deadline',
      'application_cycle',
      'cycle_status',
      'official_url',
      'source_content'
    )
  ),
  old_value text,
  detected_value text,
  confidence integer check (confidence is null or confidence between 0 and 100),
  source_url text not null,
  source_fingerprint text,
  status text not null default 'pending'
    check (status in ('pending','accepted','rejected','superseded')),
  first_detected_at timestamptz not null default now(),
  last_detected_at timestamptz not null default now(),
  reviewed_at timestamptz,
  reviewed_by uuid references auth.users(id) on delete set null,
  review_note text
);

alter table public.scholarship_detected_changes enable row level security;
revoke all on public.scholarship_detected_changes from anon, authenticated;
grant select, update on public.scholarship_detected_changes to authenticated;

drop policy if exists "admins read detected scholarship changes"
on public.scholarship_detected_changes;
create policy "admins read detected scholarship changes"
on public.scholarship_detected_changes
for select to authenticated
using (public.is_admin());

drop policy if exists "admins review detected scholarship changes"
on public.scholarship_detected_changes;
create policy "admins review detected scholarship changes"
on public.scholarship_detected_changes
for update to authenticated
using (public.is_admin())
with check (public.is_admin());

create unique index if not exists scholarship_detected_changes_pending_unique
  on public.scholarship_detected_changes(
    scholarship_id,
    field_name,
    coalesce(detected_value, '')
  )
  where status = 'pending';

create index if not exists scholarship_detected_changes_queue_idx
  on public.scholarship_detected_changes(status, last_detected_at desc);

create index if not exists scholarship_detected_changes_scholarship_idx
  on public.scholarship_detected_changes(scholarship_id, last_detected_at desc);

create or replace function public.accept_detected_scholarship_change(
  p_change_id uuid,
  p_note text default null
)
returns public.scholarship_detected_changes
language plpgsql
security invoker
set search_path = public
as $$
declare
  c public.scholarship_detected_changes%rowtype;
begin
  if not public.is_admin() then
    raise exception 'Admin access required';
  end if;

  select * into c
  from public.scholarship_detected_changes
  where id = p_change_id
    and status = 'pending'
  for update;

  if not found then
    raise exception 'Pending detected change not found';
  end if;

  if c.field_name = 'deadline' then
    update public.scholarships
    set deadline = nullif(c.detected_value, '')::date,
        deadline_verification_status = 'verified',
        verified_at = now()
    where id = c.scholarship_id;
  elsif c.field_name = 'application_cycle' then
    update public.scholarships
    set application_cycle = nullif(c.detected_value, ''),
        verified_at = now()
    where id = c.scholarship_id;
  elsif c.field_name = 'cycle_status' then
    update public.scholarships
    set cycle_status = coalesce(nullif(c.detected_value, ''), 'unknown')
    where id = c.scholarship_id;
  elsif c.field_name = 'official_url' then
    update public.scholarships
    set official_url = coalesce(nullif(c.detected_value, ''), official_url),
        final_url = coalesce(nullif(c.detected_value, ''), final_url),
        verified_at = now()
    where id = c.scholarship_id;
  end if;

  update public.scholarship_detected_changes
  set status = 'accepted',
      reviewed_at = now(),
      reviewed_by = auth.uid(),
      review_note = nullif(btrim(p_note), '')
  where id = p_change_id
  returning * into c;

  update public.scholarship_detected_changes
  set status = 'superseded',
      reviewed_at = now(),
      review_note = coalesce(review_note, 'Superseded by accepted change')
  where scholarship_id = c.scholarship_id
    and field_name = c.field_name
    and status = 'pending'
    and id <> c.id;

  return c;
end;
$$;

revoke execute on function public.accept_detected_scholarship_change(uuid,text)
from public, anon;
grant execute on function public.accept_detected_scholarship_change(uuid,text)
to authenticated;

create or replace function public.reject_detected_scholarship_change(
  p_change_id uuid,
  p_note text default null
)
returns public.scholarship_detected_changes
language plpgsql
security invoker
set search_path = public
as $$
declare
  c public.scholarship_detected_changes%rowtype;
begin
  if not public.is_admin() then
    raise exception 'Admin access required';
  end if;

  update public.scholarship_detected_changes
  set status = 'rejected',
      reviewed_at = now(),
      reviewed_by = auth.uid(),
      review_note = nullif(btrim(p_note), '')
  where id = p_change_id
    and status = 'pending'
  returning * into c;

  if c.id is null then
    raise exception 'Pending detected change not found';
  end if;

  return c;
end;
$$;

revoke execute on function public.reject_detected_scholarship_change(uuid,text)
from public, anon;
grant execute on function public.reject_detected_scholarship_change(uuid,text)
to authenticated;

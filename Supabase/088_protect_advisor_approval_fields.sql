-- Protect advisor approval and ranking fields from direct client writes.

create or replace function public.protect_advisor_profile_admin_fields()
returns trigger
language plpgsql
set search_path = public, private
as $$
declare
  privileged boolean :=
    current_user in ('postgres', 'service_role', 'supabase_admin')
    or coalesce(auth.role(), '') = 'service_role'
    or public.is_admin();
begin
  if privileged then
    return new;
  end if;

  if tg_op = 'INSERT' then
    if new.id is distinct from auth.uid()
       or new.approval_status is distinct from 'pending'
       or new.is_active is distinct from false
       or new.reviewed_at is not null
       or new.reviewed_by is not null
       or new.review_note is not null
       or new.is_featured is distinct from false
       or new.display_order is not null
       or new.application_version is distinct from 1 then
      raise exception 'Advisor approval fields are managed by administrators'
        using errcode = '42501';
    end if;

    return new;
  end if;

  if new.approval_status is distinct from old.approval_status
     or new.is_active is distinct from old.is_active
     or new.reviewed_at is distinct from old.reviewed_at
     or new.reviewed_by is distinct from old.reviewed_by
     or new.review_note is distinct from old.review_note
     or new.is_featured is distinct from old.is_featured
     or new.display_order is distinct from old.display_order
     or new.application_version is distinct from old.application_version then
    raise exception 'Advisor approval fields are managed by administrators'
      using errcode = '42501';
  end if;

  return new;
end;
$$;

drop trigger if exists advisor_profiles_protect_admin_fields
on public.advisor_profiles;

create trigger advisor_profiles_protect_admin_fields
before insert or update on public.advisor_profiles
for each row
execute function public.protect_advisor_profile_admin_fields();

drop policy if exists "advisor self insert"
on public.advisor_profiles;

create policy "advisor self insert"
on public.advisor_profiles
for insert
to authenticated
with check (
  id = (select auth.uid())
  and approval_status = 'pending'
  and is_active = false
  and reviewed_at is null
  and reviewed_by is null
  and review_note is null
  and is_featured = false
  and display_order is null
  and application_version = 1
);

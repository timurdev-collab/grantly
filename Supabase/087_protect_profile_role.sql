-- Prevent users from promoting themselves by editing student_profiles.role.

create or replace function public.protect_student_profile_role()
returns trigger
language plpgsql
set search_path = public, private
as $$
begin
  if new.role is distinct from old.role then
    if current_user in ('postgres', 'service_role', 'supabase_admin')
       or coalesce(auth.role(), '') = 'service_role'
       or public.is_admin() then
      return new;
    end if;

    raise exception 'Role changes require administrator access'
      using errcode = '42501';
  end if;

  return new;
end;
$$;

drop trigger if exists student_profiles_protect_role
on public.student_profiles;

create trigger student_profiles_protect_role
before update on public.student_profiles
for each row
execute function public.protect_student_profile_role();

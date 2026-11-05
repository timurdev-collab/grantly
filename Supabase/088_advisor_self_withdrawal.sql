-- Self-service withdrawal without deleting the student's EduT account.
alter table public.advisor_profiles drop constraint if exists advisor_profiles_approval_status_check;
alter table public.advisor_profiles add constraint advisor_profiles_approval_status_check
  check (approval_status in ('pending','changes_requested','approved','rejected','suspended','withdrawn'));

create or replace function public.withdraw_my_advisor_role()
returns void language plpgsql security definer set search_path = ''
as $$
declare v_uid uuid := auth.uid();
begin
  if v_uid is null then raise exception 'Authentication required'; end if;
  if exists (
    select 1 from public.advisor_student_assignments
    where advisor_id=v_uid and status in ('active','requested')
  ) then
    raise exception 'End or decline all student assignments before withdrawing';
  end if;
  if exists (
    select 1 from public.advisor_consultation_requests
    where advisor_id=v_uid and status not in ('completed','cancelled')
  ) then
    raise exception 'Resolve all consultation requests before withdrawing';
  end if;
  update public.advisor_profiles
     set approval_status='withdrawn',is_active=false,updated_at=now()
   where id=v_uid and approval_status='approved';
  if not found then raise exception 'Only approved advisors can withdraw'; end if;
  update public.student_profiles set role='student'
    where id=v_uid and role='advisor';
end;
$$;

revoke all on function public.withdraw_my_advisor_role() from public, anon;
grant execute on function public.withdraw_my_advisor_role() to authenticated;

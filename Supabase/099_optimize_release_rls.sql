-- Tighten and optimize the remaining hot-path RLS policies.

drop policy if exists "admins create action logs"
on public.admin_action_logs;

create policy "admins create action logs"
on public.admin_action_logs
for insert
to authenticated
with check (
  (select public.is_admin())
  and admin_user_id = (select auth.uid())
);

drop policy if exists "call participants select"
on public.advisor_call_sessions;

create policy "call participants select"
on public.advisor_call_sessions
for select
to authenticated
using (
  (select public.is_admin())
  or exists (
    select 1
    from public.advisor_student_assignments a
    where a.id = advisor_call_sessions.assignment_id
      and (
        (select auth.uid()) = a.student_id
        or (select auth.uid()) = a.advisor_id
      )
  )
);

-- Advisor workflow security hardening: remove anonymous RPC execution and optimize RLS lookups.

revoke execute on function public.admin_advisor_applications() from public, anon;
grant execute on function public.admin_advisor_applications() to authenticated;

revoke execute on function public.admin_advisor_assignments() from public, anon;
grant execute on function public.admin_advisor_assignments() to authenticated;

revoke execute on function public.admin_review_advisor(uuid,text,text) from public, anon;
grant execute on function public.admin_review_advisor(uuid,text,text) to authenticated;

revoke execute on function public.admin_set_account_suspended(uuid,boolean) from public, anon;
grant execute on function public.admin_set_account_suspended(uuid,boolean) to authenticated;

revoke execute on function public.admin_user_accounts() from public, anon;
grant execute on function public.admin_user_accounts() to authenticated;

revoke execute on function public.advisor_manage_student(uuid,text) from public, anon;
grant execute on function public.advisor_manage_student(uuid,text) to authenticated;

revoke execute on function public.advisor_my_students() from public, anon;
grant execute on function public.advisor_my_students() to authenticated;

revoke execute on function public.available_advisors() from public, anon;
grant execute on function public.available_advisors() to authenticated;

revoke execute on function public.create_advisor_call_session(uuid,boolean) from public, anon;
grant execute on function public.create_advisor_call_session(uuid,boolean) to authenticated;

revoke execute on function public.ensure_advisor_conversation(uuid) from public, anon;
grant execute on function public.ensure_advisor_conversation(uuid) to authenticated;

revoke execute on function public.my_advisor_registration() from public, anon;
grant execute on function public.my_advisor_registration() to authenticated;

revoke execute on function public.request_advisor(uuid) from public, anon;
grant execute on function public.request_advisor(uuid) to authenticated;

revoke execute on function public.request_advisor_access(
  text,text,text,text[],text[],text[]
) from public, anon;
grant execute on function public.request_advisor_access(
  text,text,text,text[],text[],text[]
) to authenticated;

revoke execute on function public.set_advisor_call_recording_consent(uuid,boolean)
from public, anon;
grant execute on function public.set_advisor_call_recording_consent(uuid,boolean)
to authenticated;

revoke execute on function public.submit_advisor_application(
  text,text,text,text,text,text,integer,text[],text[],text[],
  text,text,text,text,text
) from public, anon;
grant execute on function public.submit_advisor_application(
  text,text,text,text,text,text,integer,text[],text[],text[],
  text,text,text,text,text
) to authenticated;

revoke execute on function public.my_advisor_application() from public, anon;
grant execute on function public.my_advisor_application() to authenticated;

revoke execute on function public.create_advisor_conversation_on_accept()
from public, anon, authenticated;

drop policy if exists "approved advisors visible" on public.advisor_profiles;
create policy "approved advisors visible"
on public.advisor_profiles
for select
to authenticated
using (
  (approval_status = 'approved' and is_active = true)
  or id = (select auth.uid())
  or (select public.is_admin())
);

drop policy if exists "advisor self insert" on public.advisor_profiles;
create policy "advisor self insert"
on public.advisor_profiles
for insert
to authenticated
with check (id = (select auth.uid()));

drop policy if exists "advisor self update pending" on public.advisor_profiles;
create policy "advisor self update pending"
on public.advisor_profiles
for update
to authenticated
using (
  id = (select auth.uid())
  or (select public.is_admin())
)
with check (
  (select public.is_admin())
  or (
    id = (select auth.uid())
    and approval_status in (
      'pending',
      'changes_requested',
      'rejected'
    )
    and is_active = false
  )
);

drop policy if exists "assignment participants select"
on public.advisor_student_assignments;
create policy "assignment participants select"
on public.advisor_student_assignments
for select
to authenticated
using (
  student_id = (select auth.uid())
  or advisor_id = (select auth.uid())
  or (select public.is_admin())
);

drop policy if exists "students request advisor"
on public.advisor_student_assignments;
create policy "students request advisor"
on public.advisor_student_assignments
for insert
to authenticated
with check (
  student_id = (select auth.uid())
  and exists (
    select 1
    from public.student_profiles sp
    where sp.id = (select auth.uid())
      and sp.role = 'student'
  )
  and exists (
    select 1
    from public.advisor_profiles ap
    where ap.id = advisor_id
      and ap.approval_status = 'approved'
      and ap.is_active = true
  )
);

drop policy if exists "advisor assignment update"
on public.advisor_student_assignments;
create policy "advisor assignment update"
on public.advisor_student_assignments
for update
to authenticated
using (
  advisor_id = (select auth.uid())
  or (select public.is_admin())
)
with check (
  advisor_id = (select auth.uid())
  or (select public.is_admin())
);

drop policy if exists "advisor review history visible to owner and admin"
on public.advisor_review_events;
create policy "advisor review history visible to owner and admin"
on public.advisor_review_events
for select
to authenticated
using (
  advisor_id = (select auth.uid())
  or (select public.is_admin())
);

-- Avoid reusing an advisor conversation that is tied to an inactive assignment.
-- Profile messaging is independent from advisor assignment status.

create or replace function public.ensure_advisor_direct_conversation(
  p_advisor_id uuid
)
returns uuid
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_student_id uuid := auth.uid();
  v_conversation uuid;
begin
  if v_student_id is null then
    raise exception 'Authentication required';
  end if;

  if not exists (
    select 1
    from public.student_profiles sp
    where sp.id = v_student_id
      and sp.role = 'student'
  ) then
    raise exception 'Only student accounts can message advisors from advisor profiles';
  end if;

  if not exists (
    select 1
    from public.advisor_profiles ap
    where ap.id = p_advisor_id
      and ap.approval_status = 'approved'
      and ap.is_active = true
  ) then
    raise exception 'Advisor is not available';
  end if;

  if p_advisor_id = v_student_id then
    raise exception 'You cannot message yourself';
  end if;

  select c.id into v_conversation
  from public.conversations c
  where c.is_direct = true
    and exists (
      select 1
      from public.conversation_members cm
      where cm.conversation_id = c.id
        and cm.user_id = v_student_id
    )
    and exists (
      select 1
      from public.conversation_members cm
      where cm.conversation_id = c.id
        and cm.user_id = p_advisor_id
    )
    and (
      select count(*)
      from public.conversation_members cm
      where cm.conversation_id = c.id
    ) = 2
    and (
      not exists (
        select 1
        from public.advisor_student_assignments a
        where a.conversation_id = c.id
      )
      or exists (
        select 1
        from public.advisor_student_assignments a
        where a.conversation_id = c.id
          and a.status = 'active'
          and a.student_id = v_student_id
          and a.advisor_id = p_advisor_id
      )
    )
  order by c.created_at
  limit 1;

  if v_conversation is null then
    insert into public.conversations(is_direct)
    values (true)
    returning id into v_conversation;

    insert into public.conversation_members(conversation_id,user_id)
    values
      (v_conversation,v_student_id),
      (v_conversation,p_advisor_id);
  end if;

  return v_conversation;
end;
$$;

revoke execute on function public.ensure_advisor_direct_conversation(uuid)
from public, anon;

grant execute on function public.ensure_advisor_direct_conversation(uuid)
to authenticated;

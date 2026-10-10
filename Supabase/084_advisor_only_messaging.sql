-- Restrict private messaging to student/advisor relationships for the 1.0 release.
create or replace function public.can_message_conversation(conversation_uuid uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select
    public.is_conversation_member(conversation_uuid)
    and exists (
      select 1
      from public.conversation_members cm
      join public.advisor_profiles ap on ap.id = cm.user_id
      where cm.conversation_id = conversation_uuid
        and ap.approval_status = 'approved'
        and ap.is_active = true
    )
    and not exists (
      select 1
      from public.conversation_members other_member
      join public.user_blocks b
        on (
          (b.blocker_id = (select auth.uid()) and b.blocked_id = other_member.user_id)
          or
          (b.blocked_id = (select auth.uid()) and b.blocker_id = other_member.user_id)
        )
      where other_member.conversation_id = conversation_uuid
        and other_member.user_id <> (select auth.uid())
    )
    and (
      select count(*)
      from public.messages recent
      where recent.sender_id = (select auth.uid())
        and recent.created_at > now() - interval '60 seconds'
    ) < 20;
$$;

revoke execute on function public.can_message_conversation(uuid)
from public, anon;
grant execute on function public.can_message_conversation(uuid)
to authenticated;

drop policy if exists "members send messages" on public.messages;
create policy "members send messages"
on public.messages for insert to authenticated
with check (
  sender_id = (select auth.uid())
  and public.can_message_conversation(messages.conversation_id)
);

create or replace function public.start_direct_conversation(other_user uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
begin
  raise exception 'Student Community messaging is not available. Use Advisor messaging.';
end;
$$;

revoke execute on function public.start_direct_conversation(uuid)
from public, anon;
grant execute on function public.start_direct_conversation(uuid)
to authenticated;

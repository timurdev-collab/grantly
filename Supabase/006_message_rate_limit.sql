-- Prevent basic message flooding while preserving normal chat use.
-- A user may send at most 20 messages in any rolling 60-second window.

create or replace function public.can_message_conversation(conversation_uuid uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select
    public.is_conversation_member(conversation_uuid)
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

revoke execute on function public.can_message_conversation(uuid) from public, anon;
grant execute on function public.can_message_conversation(uuid) to authenticated;

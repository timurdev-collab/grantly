-- Keep the conversation list aligned with the message-send authorization rule.
-- Conversations attached to advisor assignments are visible only while that
-- assignment is active. Direct advisor-profile conversations remain visible.

create or replace function public.get_my_conversation_summaries()
returns table (
  conversation_id uuid,
  other_user_id uuid,
  display_name text,
  last_message text,
  last_message_at timestamptz,
  last_message_sender_id uuid,
  unread_count bigint,
  last_read_at timestamptz
)
language sql
stable
security invoker
set search_path = public
as $$
  with mine as (
    select cm.conversation_id, cm.last_read_at
    from public.conversation_members cm
    where cm.user_id = auth.uid()
      and (
        not exists (
          select 1
          from public.advisor_student_assignments a
          where a.conversation_id = cm.conversation_id
        )
        or exists (
          select 1
          from public.advisor_student_assignments a
          where a.conversation_id = cm.conversation_id
            and a.status = 'active'
            and auth.uid() in (a.student_id, a.advisor_id)
        )
      )
  ),
  other_members as (
    select
      m.conversation_id,
      max(cm.user_id::text)::uuid as other_user_id
    from mine m
    join public.conversation_members cm
      on cm.conversation_id = m.conversation_id
     and cm.user_id <> auth.uid()
    group by m.conversation_id
    having count(*) = 1
  ),
  latest as (
    select distinct on (msg.conversation_id)
      msg.conversation_id,
      msg.body,
      msg.created_at,
      msg.sender_id
    from public.messages msg
    join mine m on m.conversation_id = msg.conversation_id
    order by msg.conversation_id, msg.created_at desc, msg.id desc
  )
  select
    m.conversation_id,
    om.other_user_id,
    coalesce(
      nullif(btrim(cp.display_name), ''),
      'Student'
    ) as display_name,
    l.body as last_message,
    l.created_at as last_message_at,
    l.sender_id as last_message_sender_id,
    (
      select count(*)
      from public.messages unread
      where unread.conversation_id = m.conversation_id
        and unread.sender_id <> auth.uid()
        and unread.created_at > coalesce(
          m.last_read_at,
          '-infinity'::timestamptz
        )
    ) as unread_count,
    m.last_read_at
  from mine m
  join other_members om
    on om.conversation_id = m.conversation_id
  left join public.community_profiles cp
    on cp.id = om.other_user_id
  left join latest l
    on l.conversation_id = m.conversation_id
  order by l.created_at desc nulls last, m.conversation_id;
$$;

revoke execute on function public.get_my_conversation_summaries()
from public, anon;
grant execute on function public.get_my_conversation_summaries()
to authenticated;

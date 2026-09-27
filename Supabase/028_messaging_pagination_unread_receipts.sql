-- Backend step 6: scalable conversation summaries, unread counts,
-- paginated messages, read receipts and realtime-friendly indexes.

alter table public.conversation_members
  add column if not exists last_read_at timestamptz;

update public.conversation_members cm
set last_read_at = cm.joined_at
where cm.last_read_at is null;

create index if not exists conversation_members_user_read_idx
  on public.conversation_members(user_id, last_read_at);

create index if not exists messages_conversation_created_desc_idx
  on public.messages(conversation_id, created_at desc, id desc);

grant update(last_read_at) on public.conversation_members to authenticated;
grant update(read_at) on public.messages to authenticated;

drop policy if exists "members update own read cursor" on public.conversation_members;
create policy "members update own read cursor"
on public.conversation_members
for update
to authenticated
using (user_id = (select auth.uid()))
with check (user_id = (select auth.uid()));

drop policy if exists "recipients mark messages read" on public.messages;
create policy "recipients mark messages read"
on public.messages
for update
to authenticated
using (
  sender_id <> (select auth.uid())
  and public.is_conversation_member(conversation_id)
)
with check (
  sender_id <> (select auth.uid())
  and public.is_conversation_member(conversation_id)
);

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
  ),
  other_members as (
    select
      m.conversation_id,
      cm.user_id as other_user_id
    from mine m
    join public.conversation_members cm
      on cm.conversation_id = m.conversation_id
     and cm.user_id <> auth.uid()
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
    coalesce(nullif(btrim(cp.display_name), ''), 'Student') as display_name,
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
  left join other_members om
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

create or replace function public.get_messages_page(
  p_conversation_id uuid,
  p_before timestamptz default null,
  p_limit integer default 40
)
returns setof public.messages
language sql
stable
security invoker
set search_path = public
as $$
  select m.*
  from public.messages m
  where m.conversation_id = p_conversation_id
    and public.is_conversation_member(p_conversation_id)
    and (
      p_before is null
      or m.created_at < p_before
    )
  order by m.created_at desc, m.id desc
  limit greatest(1, least(coalesce(p_limit, 40), 100));
$$;

revoke execute on function public.get_messages_page(uuid, timestamptz, integer)
  from public, anon;
grant execute on function public.get_messages_page(uuid, timestamptz, integer)
  to authenticated;

create or replace function public.mark_conversation_read(
  p_conversation_id uuid
)
returns timestamptz
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_now timestamptz := now();
begin
  if not public.is_conversation_member(p_conversation_id) then
    raise exception 'Conversation access denied';
  end if;

  update public.conversation_members
  set last_read_at = v_now
  where conversation_id = p_conversation_id
    and user_id = auth.uid();

  update public.messages
  set read_at = coalesce(read_at, v_now)
  where conversation_id = p_conversation_id
    and sender_id <> auth.uid()
    and read_at is null;

  return v_now;
end;
$$;

revoke execute on function public.mark_conversation_read(uuid)
  from public, anon;
grant execute on function public.mark_conversation_read(uuid)
  to authenticated;

update public.conversation_members cm
set last_read_at = greatest(
  coalesce(cm.last_read_at, cm.joined_at),
  coalesce((
    select max(m.created_at)
    from public.messages m
    where m.conversation_id = cm.conversation_id
      and m.sender_id = cm.user_id
  ), cm.joined_at)
);

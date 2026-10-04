-- Prevent message/member row tampering by routing read-receipt writes through
-- the constrained mark_conversation_read RPC.

create or replace function public.mark_conversation_read(
  p_conversation_id uuid
)
returns timestamptz
language plpgsql
security definer
set search_path = public
as $$
declare
  v_now timestamptz := now();
begin
  if auth.uid() is null
     or not public.is_conversation_member(p_conversation_id) then
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

drop policy if exists "members update own read cursor"
on public.conversation_members;

drop policy if exists "recipients mark messages read"
on public.messages;

-- Grantly user blocking for community safety

create table if not exists public.user_blocks (
  blocker_id uuid not null references auth.users(id) on delete cascade,
  blocked_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  check (blocker_id <> blocked_id)
);

alter table public.user_blocks enable row level security;

revoke all on public.user_blocks from anon, authenticated;
grant select, insert, delete on public.user_blocks to authenticated;

drop policy if exists "users view own blocks" on public.user_blocks;
create policy "users view own blocks"
on public.user_blocks for select to authenticated
using (blocker_id = (select auth.uid()));

drop policy if exists "users create own blocks" on public.user_blocks;
create policy "users create own blocks"
on public.user_blocks for insert to authenticated
with check (blocker_id = (select auth.uid()));

drop policy if exists "users delete own blocks" on public.user_blocks;
create policy "users delete own blocks"
on public.user_blocks for delete to authenticated
using (blocker_id = (select auth.uid()));

create index if not exists user_blocks_blocked_idx
  on public.user_blocks(blocked_id);

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
    );
$$;

revoke execute on function public.can_message_conversation(uuid) from public, anon;
grant execute on function public.can_message_conversation(uuid) to authenticated;

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
declare
  me uuid := auth.uid();
  existing_id uuid;
  new_id uuid;
begin
  if me is null then raise exception 'Not authenticated'; end if;
  if other_user = me then raise exception 'Cannot message yourself'; end if;

  if exists (
    select 1
    from public.user_blocks
    where (blocker_id = me and blocked_id = other_user)
       or (blocker_id = other_user and blocked_id = me)
  ) then
    raise exception 'Messaging is unavailable between these accounts';
  end if;

  if not exists(
    select 1 from public.community_profiles
    where id = other_user and is_visible = true
  ) then
    raise exception 'User is not available for community messaging';
  end if;

  select c.id into existing_id
  from public.conversations c
  where c.is_direct = true
    and exists(select 1 from public.conversation_members cm where cm.conversation_id=c.id and cm.user_id=me)
    and exists(select 1 from public.conversation_members cm where cm.conversation_id=c.id and cm.user_id=other_user)
    and 2 = (select count(*) from public.conversation_members cm where cm.conversation_id=c.id)
  limit 1;

  if existing_id is not null then return existing_id; end if;

  insert into public.conversations(is_direct) values(true) returning id into new_id;
  insert into public.conversation_members(conversation_id,user_id)
  values(new_id,me),(new_id,other_user);
  return new_id;
end;
$$;

revoke execute on function public.start_direct_conversation(uuid) from public, anon;
grant execute on function public.start_direct_conversation(uuid) to authenticated;

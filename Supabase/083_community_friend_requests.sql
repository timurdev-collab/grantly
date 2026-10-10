-- Community friend requests and accepted friends.
create table if not exists public.community_friendships (
  id uuid primary key default gen_random_uuid(),
  requester_id uuid not null references auth.users(id) on delete cascade,
  addressee_id uuid not null references auth.users(id) on delete cascade,
  status text not null default 'pending'
    check (status in ('pending','accepted','declined')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  accepted_at timestamptz,
  check (requester_id <> addressee_id)
);

create unique index if not exists community_friendships_pair_key
on public.community_friendships (
  least(requester_id, addressee_id),
  greatest(requester_id, addressee_id)
);

alter table public.community_friendships enable row level security;
revoke all on public.community_friendships from anon, authenticated;
grant select on public.community_friendships to authenticated;

drop policy if exists "friendship participants can view"
on public.community_friendships;
create policy "friendship participants can view"
on public.community_friendships for select to authenticated
using (
  requester_id = (select auth.uid())
  or addressee_id = (select auth.uid())
);

create or replace function public.community_friendship_status(other_user uuid)
returns text
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  me uuid := auth.uid();
  row_record public.community_friendships%rowtype;
begin
  if me is null then return 'none'; end if;
  if other_user = me then return 'self'; end if;

  if exists (
    select 1 from public.user_blocks
    where (blocker_id = me and blocked_id = other_user)
       or (blocker_id = other_user and blocked_id = me)
  ) then
    return 'blocked';
  end if;

  select * into row_record
  from public.community_friendships
  where (requester_id = me and addressee_id = other_user)
     or (requester_id = other_user and addressee_id = me)
  limit 1;

  if row_record.id is null then return 'none'; end if;
  if row_record.status = 'accepted' then return 'friends'; end if;
  if row_record.status = 'pending' and row_record.requester_id = me then
    return 'outgoing';
  end if;
  if row_record.status = 'pending' and row_record.addressee_id = me then
    return 'incoming';
  end if;
  return 'none';
end;
$$;

create or replace function public.send_community_friend_request(other_user uuid)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  me uuid := auth.uid();
  row_record public.community_friendships%rowtype;
begin
  if me is null then raise exception 'Not authenticated'; end if;
  if other_user = me then raise exception 'Cannot add yourself'; end if;

  if exists (
    select 1 from public.user_blocks
    where (blocker_id = me and blocked_id = other_user)
       or (blocker_id = other_user and blocked_id = me)
  ) then
    raise exception 'Friend request unavailable between these accounts';
  end if;

  select * into row_record
  from public.community_friendships
  where (requester_id = me and addressee_id = other_user)
     or (requester_id = other_user and addressee_id = me)
  for update
  limit 1;

  if row_record.id is null then
    insert into public.community_friendships(requester_id, addressee_id)
    values(me, other_user);
    return 'outgoing';
  end if;

  if row_record.status = 'accepted' then return 'friends'; end if;

  if row_record.status = 'pending' then
    if row_record.addressee_id = me then
      update public.community_friendships
      set status='accepted', accepted_at=now(), updated_at=now()
      where id=row_record.id;
      return 'friends';
    end if;
    return 'outgoing';
  end if;

  update public.community_friendships
  set requester_id=me,
      addressee_id=other_user,
      status='pending',
      accepted_at=null,
      updated_at=now()
  where id=row_record.id;
  return 'outgoing';
end;
$$;

create or replace function public.respond_community_friend_request(
  request_id uuid,
  accept_request boolean
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.community_friendships
  set status = case when accept_request then 'accepted' else 'declined' end,
      accepted_at = case when accept_request then now() else null end,
      updated_at = now()
  where id = request_id
    and addressee_id = auth.uid()
    and status = 'pending';

  if not found then
    raise exception 'Friend request is no longer available';
  end if;
end;
$$;

create or replace function public.cancel_community_friend_request(other_user uuid)
returns void
language sql
security definer
set search_path = public
as $$
  delete from public.community_friendships
  where requester_id = auth.uid()
    and addressee_id = other_user
    and status = 'pending';
$$;

create or replace function public.remove_community_friend(other_user uuid)
returns void
language sql
security definer
set search_path = public
as $$
  delete from public.community_friendships
  where status = 'accepted'
    and (
      (requester_id = auth.uid() and addressee_id = other_user)
      or (requester_id = other_user and addressee_id = auth.uid())
    );
$$;

create or replace function public.my_community_friend_requests()
returns table(
  request_id uuid,
  user_id uuid,
  display_name text,
  community_code text,
  avatar_url text,
  created_at timestamptz
)
language sql
stable
security definer
set search_path = public
as $$
  select f.id, f.requester_id, cp.display_name, cp.community_code,
         cp.avatar_url, f.created_at
  from public.community_friendships f
  join public.community_profiles cp on cp.id = f.requester_id
  where f.addressee_id = auth.uid()
    and f.status = 'pending'
  order by f.created_at desc;
$$;

create or replace function public.my_community_friends()
returns table(
  user_id uuid,
  display_name text,
  community_code text,
  avatar_url text,
  nationality text,
  major text
)
language sql
stable
security definer
set search_path = public
as $$
  select cp.id, cp.display_name, cp.community_code, cp.avatar_url,
         cp.nationality, cp.major
  from public.community_friendships f
  join public.community_profiles cp
    on cp.id = case
      when f.requester_id = auth.uid() then f.addressee_id
      else f.requester_id
    end
  where f.status = 'accepted'
    and (f.requester_id = auth.uid() or f.addressee_id = auth.uid())
  order by lower(coalesce(cp.display_name, ''));
$$;

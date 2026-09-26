-- Grantly core schema
create extension if not exists pgcrypto;

create type public.user_role as enum ('student','admin');

create table public.student_profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text,
  nationality text,
  residence_country text,
  graduation_year integer,
  gpa_value numeric(5,2),
  gpa_scale numeric(5,2),
  ielts numeric(3,1),
  intended_major text,
  degree_level text,
  target_regions text[] default '{}',
  target_countries text[] default '{}',
  family_income_usd numeric(12,2),
  role public.user_role not null default 'student',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Deliberately separate from private academic/financial data.
create table public.community_profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  avatar_url text,
  nationality text,
  major text,
  target_regions text[] default '{}',
  target_countries text[] default '{}',
  bio text,
  is_visible boolean not null default true,
  updated_at timestamptz not null default now()
);

create table public.scholarships (
  id uuid primary key default gen_random_uuid(),
  slug text unique not null,
  title text not null,
  provider text not null,
  country text not null,
  region text not null,
  degree_levels text[] not null default '{}',
  fields text[] not null default '{"All fields"}',
  funding_type text not null,
  tuition_coverage text,
  stipend text,
  airfare boolean not null default false,
  accommodation boolean not null default false,
  health_insurance boolean not null default false,
  min_gpa_percent numeric(5,2),
  min_ielts numeric(3,1),
  sat_required boolean not null default false,
  eligible_nationalities text[] not null default '{"ALL"}',
  deadline date,
  official_url text not null,
  status text not null default 'draft' check (status in ('draft','published','archived')),
  verified_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.saved_scholarships (
  user_id uuid not null references auth.users(id) on delete cascade,
  scholarship_id uuid not null references public.scholarships(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key(user_id, scholarship_id)
);

create table public.conversations (
  id uuid primary key default gen_random_uuid(),
  is_direct boolean not null default true,
  created_at timestamptz not null default now()
);

create table public.conversation_members (
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  joined_at timestamptz not null default now(),
  primary key(conversation_id, user_id)
);

create table public.messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  sender_id uuid not null references auth.users(id) on delete cascade,
  body text not null check (char_length(body) between 1 and 5000),
  created_at timestamptz not null default now(),
  read_at timestamptz
);

create index messages_conversation_created_idx on public.messages(conversation_id, created_at);
create index scholarships_status_region_idx on public.scholarships(status, region);
create index scholarships_deadline_idx on public.scholarships(deadline);

-- Create profile rows when Auth creates a user.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.student_profiles(id, full_name)
  values (new.id, coalesce(new.raw_user_meta_data->>'full_name',''));

  insert into public.community_profiles(id, display_name)
  values (new.id, coalesce(new.raw_user_meta_data->>'full_name',''));

  return new;
end;
$$;

create trigger on_auth_user_created
after insert on auth.users
for each row execute procedure public.handle_new_user();

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists(
    select 1 from public.student_profiles
    where id = auth.uid() and role = 'admin'
  );
$$;


create or replace function public.is_conversation_member(conversation_uuid uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists(
    select 1
    from public.conversation_members
    where conversation_id = conversation_uuid
      and user_id = auth.uid()
  );
$$;

grant execute on function public.is_conversation_member(uuid) to authenticated;

-- Direct conversation helper. Prevents clients from arbitrarily adding people
-- to existing conversations.
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
  if not exists(select 1 from public.community_profiles where id=other_user and is_visible=true)
    then raise exception 'User is not available for community messaging';
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

grant execute on function public.start_direct_conversation(uuid) to authenticated;

-- RLS
alter table public.student_profiles enable row level security;
alter table public.community_profiles enable row level security;
alter table public.scholarships enable row level security;
alter table public.saved_scholarships enable row level security;
alter table public.conversations enable row level security;
alter table public.conversation_members enable row level security;
alter table public.messages enable row level security;

-- Least-privilege grants
revoke all on public.student_profiles, public.community_profiles, public.scholarships,
  public.saved_scholarships, public.conversations, public.conversation_members, public.messages
  from anon, authenticated;

grant select on public.scholarships to anon, authenticated;
grant insert, update, delete on public.scholarships to authenticated;

grant select, update on public.student_profiles to authenticated;
grant select, insert, update, delete on public.community_profiles to authenticated;
grant select, insert, delete on public.saved_scholarships to authenticated;
grant select on public.conversations to authenticated;
grant select on public.conversation_members to authenticated;
grant select, insert on public.messages to authenticated;

-- Private profile: self or admin only.
create policy "student profile self select"
on public.student_profiles for select to authenticated
using ((select auth.uid()) = id or public.is_admin());

create policy "student profile self update"
on public.student_profiles for update to authenticated
using ((select auth.uid()) = id or public.is_admin())
with check ((select auth.uid()) = id or public.is_admin());

-- Community profiles expose only intentionally public-safe fields in this separate table.
create policy "visible community profiles"
on public.community_profiles for select to authenticated
using (is_visible = true or (select auth.uid()) = id or public.is_admin());

create policy "community profile self insert"
on public.community_profiles for insert to authenticated
with check ((select auth.uid()) = id);

create policy "community profile self update"
on public.community_profiles for update to authenticated
using ((select auth.uid()) = id or public.is_admin())
with check ((select auth.uid()) = id or public.is_admin());

create policy "community profile self delete"
on public.community_profiles for delete to authenticated
using ((select auth.uid()) = id or public.is_admin());

-- Public can read only published scholarships; admins can read every status.
create policy "public reads published scholarships"
on public.scholarships for select
using (status = 'published' or public.is_admin());

create policy "admins insert scholarships"
on public.scholarships for insert to authenticated
with check (public.is_admin());

create policy "admins update scholarships"
on public.scholarships for update to authenticated
using (public.is_admin()) with check (public.is_admin());

create policy "admins delete scholarships"
on public.scholarships for delete to authenticated
using (public.is_admin());

-- Saves belong to the current user.
create policy "users read own saves"
on public.saved_scholarships for select to authenticated
using ((select auth.uid()) = user_id);

create policy "users create own saves"
on public.saved_scholarships for insert to authenticated
with check ((select auth.uid()) = user_id);

create policy "users delete own saves"
on public.saved_scholarships for delete to authenticated
using ((select auth.uid()) = user_id);

-- Conversation access only for members.
create policy "members read conversations"
on public.conversations for select to authenticated
using (public.is_conversation_member(id));

create policy "members read memberships"
on public.conversation_members for select to authenticated
using (public.is_conversation_member(conversation_id));

create policy "members read messages"
on public.messages for select to authenticated
using (public.is_conversation_member(messages.conversation_id));

create policy "members send messages"
on public.messages for insert to authenticated
with check (
  sender_id=(select auth.uid())
  and public.is_conversation_member(messages.conversation_id)
);

-- Realtime messages
alter publication supabase_realtime add table public.messages;

-- Social engagement for Grantly posts: likes, comments and post reports.

create or replace function public.can_view_social_post(p_post_id uuid)
returns boolean
language sql
stable
security invoker
set search_path = ''
as $$
  select exists (
    select 1
    from public.social_posts p
    where p.id = p_post_id
  );
$$;

revoke all on function public.can_view_social_post(uuid) from public, anon;
grant execute on function public.can_view_social_post(uuid) to authenticated;

create table if not exists public.social_post_likes (
  post_id uuid not null
    references public.social_posts(id) on delete cascade,
  user_id uuid not null
    references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (post_id, user_id)
);

create index if not exists social_post_likes_user_idx
  on public.social_post_likes(user_id, created_at desc);

alter table public.social_post_likes enable row level security;

revoke all on public.social_post_likes from anon, authenticated;
grant select, insert, delete on public.social_post_likes to authenticated;

drop policy if exists "users view likes on visible social posts"
  on public.social_post_likes;
create policy "users view likes on visible social posts"
on public.social_post_likes
for select to authenticated
using (public.can_view_social_post(post_id));

drop policy if exists "users like visible social posts"
  on public.social_post_likes;
create policy "users like visible social posts"
on public.social_post_likes
for insert to authenticated
with check (
  user_id = (select auth.uid())
  and public.can_view_social_post(post_id)
);

drop policy if exists "users remove own social likes"
  on public.social_post_likes;
create policy "users remove own social likes"
on public.social_post_likes
for delete to authenticated
using (user_id = (select auth.uid()));

create table if not exists public.social_post_comments (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null
    references public.social_posts(id) on delete cascade,
  author_id uuid not null
    references auth.users(id) on delete cascade,
  body text not null,
  created_at timestamptz not null default now(),
  is_active boolean not null default true,
  constraint social_post_comments_body_check
    check (
      char_length(btrim(body)) between 1 and 1000
    )
);

create index if not exists social_post_comments_post_idx
  on public.social_post_comments(post_id, created_at asc);

create index if not exists social_post_comments_author_idx
  on public.social_post_comments(author_id, created_at desc);

alter table public.social_post_comments enable row level security;

revoke all on public.social_post_comments from anon, authenticated;
grant select, insert, update, delete
  on public.social_post_comments to authenticated;

drop policy if exists "users view comments on visible social posts"
  on public.social_post_comments;
create policy "users view comments on visible social posts"
on public.social_post_comments
for select to authenticated
using (
  is_active = true
  and public.can_view_social_post(post_id)
);

drop policy if exists "users comment on visible social posts"
  on public.social_post_comments;
create policy "users comment on visible social posts"
on public.social_post_comments
for insert to authenticated
with check (
  author_id = (select auth.uid())
  and is_active = true
  and char_length(btrim(body)) between 1 and 1000
  and public.can_view_social_post(post_id)
);

drop policy if exists "users update own social comments"
  on public.social_post_comments;
create policy "users update own social comments"
on public.social_post_comments
for update to authenticated
using (author_id = (select auth.uid()))
with check (
  author_id = (select auth.uid())
  and char_length(btrim(body)) between 1 and 1000
);

drop policy if exists "users delete own social comments"
  on public.social_post_comments;
create policy "users delete own social comments"
on public.social_post_comments
for delete to authenticated
using (author_id = (select auth.uid()));

create table if not exists public.social_post_reports (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null
    references public.social_posts(id) on delete cascade,
  reporter_id uuid not null
    references auth.users(id) on delete cascade,
  reported_user_id uuid not null
    references auth.users(id) on delete cascade,
  reason text not null,
  details text not null default '',
  status text not null default 'open'
    check (status in ('open', 'reviewing', 'resolved', 'dismissed')),
  created_at timestamptz not null default now(),
  resolved_at timestamptz,
  unique (post_id, reporter_id)
);

create index if not exists social_post_reports_status_idx
  on public.social_post_reports(status, created_at desc);

alter table public.social_post_reports enable row level security;

revoke all on public.social_post_reports from anon, authenticated;
grant select, insert on public.social_post_reports to authenticated;

drop policy if exists "users view own social post reports"
  on public.social_post_reports;
create policy "users view own social post reports"
on public.social_post_reports
for select to authenticated
using (reporter_id = (select auth.uid()));

drop policy if exists "users report visible social posts"
  on public.social_post_reports;
create policy "users report visible social posts"
on public.social_post_reports
for insert to authenticated
with check (
  reporter_id = (select auth.uid())
  and reported_user_id <> (select auth.uid())
  and public.can_view_social_post(post_id)
  and exists (
    select 1
    from public.social_posts p
    where p.id = post_id
      and p.author_id = reported_user_id
  )
);

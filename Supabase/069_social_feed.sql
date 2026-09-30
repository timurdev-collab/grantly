-- Grantly social feed: posts, stories and short videos

create table if not exists public.social_posts (
  id uuid primary key default gen_random_uuid(),
  author_id uuid not null references auth.users(id) on delete cascade,
  kind text not null check (kind in ('post','story','short')),
  caption text not null default '',
  media_url text,
  media_path text,
  media_type text check (media_type in ('image','video')),
  created_at timestamptz not null default now(),
  expires_at timestamptz,
  is_active boolean not null default true,
  check (
    (kind = 'story' and expires_at is not null)
    or (kind <> 'story')
  )
);

create index if not exists social_posts_feed_idx
  on public.social_posts(is_active, created_at desc);

create index if not exists social_posts_story_idx
  on public.social_posts(kind, expires_at)
  where kind = 'story';

alter table public.social_posts enable row level security;

revoke all on public.social_posts from anon, authenticated;
grant select, insert, update, delete on public.social_posts to authenticated;

drop policy if exists "authenticated users view social posts" on public.social_posts;
create policy "authenticated users view social posts"
on public.social_posts for select to authenticated
using (
  author_id = (select auth.uid())
  or (
    is_active = true
    and (expires_at is null or expires_at > now())
    and exists (
      select 1
      from public.community_profiles cp
      where cp.id = social_posts.author_id
        and cp.is_visible = true
    )
    and not exists (
      select 1
      from public.user_blocks b
      where
        (b.blocker_id = (select auth.uid()) and b.blocked_id = social_posts.author_id)
        or
        (b.blocked_id = (select auth.uid()) and b.blocker_id = social_posts.author_id)
    )
  )
);

drop policy if exists "users create own social posts" on public.social_posts;
create policy "users create own social posts"
on public.social_posts for insert to authenticated
with check (
  author_id = (select auth.uid())
  and exists (
    select 1
    from public.community_profiles cp
    where cp.id = (select auth.uid())
      and cp.is_visible = true
  )
);

drop policy if exists "users update own social posts" on public.social_posts;
create policy "users update own social posts"
on public.social_posts for update to authenticated
using (author_id = (select auth.uid()))
with check (author_id = (select auth.uid()));

drop policy if exists "users delete own social posts" on public.social_posts;
create policy "users delete own social posts"
on public.social_posts for delete to authenticated
using (author_id = (select auth.uid()));

insert into storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
)
values (
  'social-media',
  'social-media',
  false,
  209715200,
  array[
    'image/jpeg',
    'image/png',
    'image/heic',
    'image/heif',
    'video/mp4',
    'video/quicktime'
  ]
)
on conflict (id) do update
set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;



drop policy if exists "authenticated users read visible social media" on storage.objects;
create policy "authenticated users read visible social media"
on storage.objects for select to authenticated
using (
  bucket_id = 'social-media'
  and exists (
    select 1
    from public.social_posts p
    left join public.community_profiles cp
      on cp.id = p.author_id
    where p.media_path = storage.objects.name
      and (
        p.author_id = (select auth.uid())
        or (
          p.is_active = true
          and (p.expires_at is null or p.expires_at > now())
          and cp.is_visible = true
          and not exists (
            select 1
            from public.user_blocks b
            where
              (b.blocker_id = (select auth.uid()) and b.blocked_id = p.author_id)
              or
              (b.blocked_id = (select auth.uid()) and b.blocker_id = p.author_id)
          )
        )
      )
  )
);

drop policy if exists "users upload own social media" on storage.objects;
create policy "users upload own social media"
on storage.objects for insert to authenticated
with check (
  bucket_id = 'social-media'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

drop policy if exists "users update own social media" on storage.objects;
create policy "users update own social media"
on storage.objects for update to authenticated
using (
  bucket_id = 'social-media'
  and owner_id = (select auth.uid())::text
)
with check (
  bucket_id = 'social-media'
  and owner_id = (select auth.uid())::text
);

drop policy if exists "users delete own social media" on storage.objects;
create policy "users delete own social media"
on storage.objects for delete to authenticated
using (
  bucket_id = 'social-media'
  and owner_id = (select auth.uid())::text
);

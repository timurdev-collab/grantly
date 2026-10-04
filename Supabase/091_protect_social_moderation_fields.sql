-- Prevent users from undoing moderation or changing immutable social ownership/media fields.

create or replace function public.protect_social_content_system_fields()
returns trigger
language plpgsql
set search_path = public, private
as $$
declare
  privileged boolean :=
    current_user in ('postgres', 'service_role', 'supabase_admin')
    or coalesce(auth.role(), '') = 'service_role'
    or public.is_admin();
begin
  if privileged then
    return new;
  end if;

  if tg_table_name = 'social_posts' then
    if new.author_id is distinct from old.author_id
       or new.kind is distinct from old.kind
       or new.media_url is distinct from old.media_url
       or new.media_path is distinct from old.media_path
       or new.media_type is distinct from old.media_type
       or new.created_at is distinct from old.created_at
       or new.expires_at is distinct from old.expires_at
       or new.is_active is distinct from old.is_active then
      raise exception 'Only the post caption can be edited'
        using errcode = '42501';
    end if;
  elsif tg_table_name = 'social_post_comments' then
    if new.post_id is distinct from old.post_id
       or new.author_id is distinct from old.author_id
       or new.created_at is distinct from old.created_at
       or new.is_active is distinct from old.is_active then
      raise exception 'Only the comment text can be edited'
        using errcode = '42501';
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists social_posts_protect_system_fields
on public.social_posts;
create trigger social_posts_protect_system_fields
before update on public.social_posts
for each row
execute function public.protect_social_content_system_fields();

drop trigger if exists social_comments_protect_system_fields
on public.social_post_comments;
create trigger social_comments_protect_system_fields
before update on public.social_post_comments
for each row
execute function public.protect_social_content_system_fields();

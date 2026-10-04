-- Ensure moderation trigger evaluates the caller's role instead of the
-- function owner's role. The pattern lookup helper remains SECURITY DEFINER.

create or replace function public.enforce_user_content_moderation()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
declare
  candidate text := '';
begin
  if current_user in ('postgres', 'service_role', 'supabase_admin')
     or coalesce(auth.role(), '') = 'service_role'
     or public.is_admin() then
    return new;
  end if;

  if tg_table_name = 'messages' then
    candidate := new.body;
  elsif tg_table_name = 'social_posts' then
    candidate := new.caption;
  elsif tg_table_name = 'social_post_comments' then
    candidate := new.body;
  elsif tg_table_name = 'community_profiles' then
    candidate := concat_ws(' ', new.display_name, new.bio);
  else
    return new;
  end if;

  if not public.user_content_is_allowed(candidate) then
    raise exception 'Content blocked by the community safety filter'
      using errcode = 'P0001';
  end if;

  return new;
end;
$$;

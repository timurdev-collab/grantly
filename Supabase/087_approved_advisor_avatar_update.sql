-- Applied to production on 2026-10-29; this file records the change for repeatable deployments.
-- Do not allow the client to update advisor approval or other protected fields.
create or replace function public.update_my_advisor_avatar(p_avatar_storage_path text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
begin
  if v_user is null then
    raise exception 'Authentication required' using errcode = '28000';
  end if;

  if p_avatar_storage_path !~
     ('^' || lower(v_user::text) || '/avatar/[0-9a-f-]{36}[.]jpg$') then
    raise exception 'Invalid advisor avatar path' using errcode = '22023';
  end if;

  if not exists (
    select 1 from storage.objects
    where bucket_id = 'advisor-media' and name = p_avatar_storage_path
  ) then
    raise exception 'Uploaded advisor photo not found' using errcode = '22023';
  end if;

  update public.advisor_profiles
     set avatar_storage_path = p_avatar_storage_path,
         avatar_url = null,
         updated_at = now()
   where id = v_user
     and approval_status = 'approved'
     and is_active = true;

  if not found then
    raise exception 'Approved advisor profile required' using errcode = '42501';
  end if;
end;
$$;

revoke all on function public.update_my_advisor_avatar(text) from public, anon;
grant execute on function public.update_my_advisor_avatar(text) to authenticated;

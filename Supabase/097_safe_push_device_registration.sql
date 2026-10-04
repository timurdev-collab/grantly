-- Register APNs device tokens through a constrained RPC so the same physical
-- device can safely move between accounts after logout/re-login, even if a
-- previous best-effort unregister did not reach the server.

create or replace function public.register_push_device(
  p_token text,
  p_environment text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  if p_token is null
     or p_token !~ '^[0-9a-fA-F]{64}$' then
    raise exception 'Invalid APNs device token';
  end if;

  if p_environment not in ('development', 'production') then
    raise exception 'Invalid APNs environment';
  end if;

  insert into public.push_devices(
    user_id,
    platform,
    token,
    environment,
    updated_at
  )
  values(
    auth.uid(),
    'ios',
    lower(p_token),
    p_environment,
    now()
  )
  on conflict (token)
  do update set
    user_id = excluded.user_id,
    platform = excluded.platform,
    environment = excluded.environment,
    updated_at = now();
end;
$$;

revoke execute on function public.register_push_device(text, text)
from public, anon;
grant execute on function public.register_push_device(text, text)
to authenticated;

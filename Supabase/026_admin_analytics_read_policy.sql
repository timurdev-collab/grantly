-- Allow admin analytics RPC to read product events through RLS.

grant select on public.product_events to authenticated;

drop policy if exists "admins read product analytics" on public.product_events;
create policy "admins read product analytics"
on public.product_events
for select
to authenticated
using (public.is_admin());

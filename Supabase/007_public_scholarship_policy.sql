-- Keep published scholarships readable by anonymous users without
-- requiring access to the admin helper function.

drop policy if exists "public reads published scholarships" on public.scholarships;
create policy "public reads published scholarships"
on public.scholarships for select
to public
using (status = 'published');

drop policy if exists "admins read all scholarships" on public.scholarships;
create policy "admins read all scholarships"
on public.scholarships for select
to authenticated
using (public.is_admin());

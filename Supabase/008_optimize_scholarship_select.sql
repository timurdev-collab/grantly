-- Avoid overlapping permissive SELECT policies while preserving
-- anonymous access to published scholarships and admin access to all rows.

drop policy if exists "public reads published scholarships" on public.scholarships;
drop policy if exists "admins read all scholarships" on public.scholarships;
drop policy if exists "anonymous reads published scholarships" on public.scholarships;
drop policy if exists "authenticated reads scholarships" on public.scholarships;

create policy "anonymous reads published scholarships"
on public.scholarships for select
to anon
using (status = 'published');

create policy "authenticated reads scholarships"
on public.scholarships for select
to authenticated
using (status = 'published' or public.is_admin());

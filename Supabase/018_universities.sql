-- Backend step 2: normalized university directory.

create table if not exists public.universities (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  country text not null,
  city text,
  website_url text,
  logo_url text,
  campus_image_url text,
  description text,
  is_verified boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (name, country)
);

alter table public.universities enable row level security;

revoke all on public.universities from anon, authenticated;
grant select on public.universities to anon, authenticated;
grant insert, update, delete on public.universities to authenticated;

drop policy if exists "public reads universities" on public.universities;
create policy "public reads universities"
on public.universities for select
to anon, authenticated
using (true);

drop policy if exists "admins insert universities" on public.universities;
create policy "admins insert universities"
on public.universities for insert
to authenticated
with check (public.is_admin());

drop policy if exists "admins update universities" on public.universities;
create policy "admins update universities"
on public.universities for update
to authenticated
using (public.is_admin())
with check (public.is_admin());

drop policy if exists "admins delete universities" on public.universities;
create policy "admins delete universities"
on public.universities for delete
to authenticated
using (public.is_admin());

alter table public.scholarships
  add column if not exists university_id uuid
  references public.universities(id)
  on delete set null;

insert into public.universities (name, country)
select distinct btrim(provider), btrim(country)
from public.scholarships
where nullif(btrim(provider), '') is not null
  and nullif(btrim(country), '') is not null
on conflict (name, country) do nothing;

update public.scholarships s
set university_id = u.id
from public.universities u
where s.university_id is null
  and lower(btrim(s.provider)) = lower(btrim(u.name))
  and lower(btrim(s.country)) = lower(btrim(u.country));

create index if not exists scholarships_university_id_idx
  on public.scholarships(university_id);

create index if not exists universities_country_name_idx
  on public.universities(country, name);

create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists universities_set_updated_at on public.universities;
create trigger universities_set_updated_at
before update on public.universities
for each row execute function public.set_updated_at();

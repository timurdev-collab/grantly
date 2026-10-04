-- Introductory advisor pricing and six-month support package.
-- Scholarship consultation remains at its regular USD 25 price.
-- Application strategy and mock interview receive a 40% launch discount.
-- The six-month guidance package launches at its regular USD 399 price.

alter table public.advisor_services
  add column if not exists list_price_cents integer,
  add column if not exists discount_percent integer not null default 0;

update public.advisor_services
set list_price_cents = coalesce(list_price_cents, price_cents)
where list_price_cents is null;

alter table public.advisor_services
  alter column list_price_cents set not null;

alter table public.advisor_services
  drop constraint if exists advisor_services_discount_percent_check;

alter table public.advisor_services
  add constraint advisor_services_discount_percent_check
  check (discount_percent between 0 and 100);

alter table public.advisor_services
  drop constraint if exists advisor_services_type_check;

alter table public.advisor_services
  add constraint advisor_services_type_check check (
    service_type in (
      'scholarship_consultation',
      'application_strategy',
      'mock_interview',
      'six_month_package',
      'other'
    )
  );

alter table public.advisor_services
  drop constraint if exists advisor_services_duration_check;

alter table public.advisor_services
  add constraint advisor_services_duration_check check (
    duration_minutes between 0 and 180
  );

update public.advisor_services
set
  list_price_cents = 2500,
  price_cents = 2500,
  discount_percent = 0
where service_type = 'scholarship_consultation';

update public.advisor_services
set
  list_price_cents = 4500,
  price_cents = 2700,
  discount_percent = 40
where service_type = 'application_strategy';

update public.advisor_services
set
  list_price_cents = 3500,
  price_cents = 2100,
  discount_percent = 40
where service_type = 'mock_interview';

insert into public.advisor_services(
  advisor_id,
  title,
  service_type,
  duration_minutes,
  price_cents,
  list_price_cents,
  discount_percent,
  currency,
  sort_order
)
select
  ap.id,
  '6-month guidance package',
  'six_month_package',
  0,
  39900,
  66500,
  40,
  'USD',
  40
from public.advisor_profiles ap
where ap.approval_status = 'approved'
  and ap.is_active = true
  and not exists (
    select 1
    from public.advisor_services s
    where s.advisor_id = ap.id
      and s.service_type = 'six_month_package'
      and s.is_active = true
  );

create or replace function public.ensure_default_advisor_services()
returns trigger
language plpgsql
security definer
set search_path = 'public'
as $$
begin
  if new.approval_status = 'approved' and new.is_active = true then
    insert into public.advisor_services(
      advisor_id,
      title,
      service_type,
      duration_minutes,
      price_cents,
      list_price_cents,
      discount_percent,
      currency,
      sort_order
    )
    values
      (
        new.id,
        'Scholarship consultation',
        'scholarship_consultation',
        30,
        2500,
        2500,
        0,
        'USD',
        10
      ),
      (
        new.id,
        'Application strategy',
        'application_strategy',
        60,
        2700,
        4500,
        40,
        'USD',
        20
      ),
      (
        new.id,
        'Mock interview',
        'mock_interview',
        45,
        2100,
        3500,
        40,
        'USD',
        30
      ),
      (
        new.id,
        '6-month guidance package',
        'six_month_package',
        0,
        39900,
        66500,
        40,
        'USD',
        40
      )
    on conflict do nothing;
  end if;

  return new;
end;
$$;

revoke execute on function public.ensure_default_advisor_services()
from public, anon, authenticated;

drop function if exists public.available_advisor_services(uuid);

create function public.available_advisor_services(
  p_advisor_id uuid
)
returns table(
  id uuid,
  advisor_id uuid,
  title text,
  service_type text,
  duration_minutes integer,
  price_cents integer,
  list_price_cents integer,
  discount_percent integer,
  currency text
)
language sql
stable
security definer
set search_path = 'public'
as $$
  select
    s.id,
    s.advisor_id,
    s.title,
    s.service_type,
    s.duration_minutes,
    s.price_cents,
    s.list_price_cents,
    s.discount_percent,
    s.currency
  from public.advisor_services s
  join public.advisor_profiles ap on ap.id = s.advisor_id
  where s.advisor_id = p_advisor_id
    and s.is_active = true
    and ap.approval_status = 'approved'
    and ap.is_active = true
  order by s.sort_order, s.duration_minutes, s.price_cents;
$$;

revoke execute on function public.available_advisor_services(uuid)
from public, anon;
grant execute on function public.available_advisor_services(uuid)
to authenticated;

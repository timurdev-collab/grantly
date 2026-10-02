-- Keep default live-consultation services available for newly approved advisors.

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
        'USD',
        10
      ),
      (
        new.id,
        'Application strategy',
        'application_strategy',
        60,
        4500,
        'USD',
        20
      ),
      (
        new.id,
        'Mock interview',
        'mock_interview',
        45,
        3500,
        'USD',
        30
      )
    on conflict do nothing;
  end if;

  return new;
end;
$$;

revoke execute on function public.ensure_default_advisor_services()
from public, anon, authenticated;

drop trigger if exists advisor_default_services_after_approval
on public.advisor_profiles;

create trigger advisor_default_services_after_approval
after insert or update of approval_status, is_active
on public.advisor_profiles
for each row
execute function public.ensure_default_advisor_services();

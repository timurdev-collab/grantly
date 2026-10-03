-- Hide student consultation contact details from advisors until payment is recorded.

drop policy if exists "students view own consultation requests"
on public.advisor_consultation_requests;

create policy "students and admins view consultation requests"
on public.advisor_consultation_requests
for select
to authenticated
using (
  student_id = (select auth.uid())
  or (select public.is_admin())
);

create or replace function public.advisor_consultation_requests_for_me()
returns table(
  id uuid,
  student_id uuid,
  student_name text,
  advisor_id uuid,
  service_id uuid,
  service_title text,
  duration_minutes integer,
  contact_email text,
  whatsapp_number text,
  preferred_start timestamptz,
  timezone text,
  topic text,
  notes text,
  quoted_price_cents integer,
  currency text,
  status text,
  created_at timestamptz
)
language plpgsql
stable
security definer
set search_path = 'public'
as $$
begin
  if not exists (
    select 1
    from public.advisor_profiles ap
    where ap.id = auth.uid()
      and ap.approval_status = 'approved'
      and ap.is_active = true
  ) then
    raise exception 'Advisor access required';
  end if;

  return query
  select
    r.id,
    r.student_id,
    coalesce(sp.full_name, 'Student'),
    r.advisor_id,
    r.service_id,
    s.title,
    s.duration_minutes,
    case
      when r.status in ('paid', 'confirmed', 'completed')
        then r.contact_email
      else null
    end,
    case
      when r.status in ('paid', 'confirmed', 'completed')
        then r.whatsapp_number
      else null
    end,
    r.preferred_start,
    r.timezone,
    r.topic,
    r.notes,
    r.quoted_price_cents,
    r.currency,
    r.status,
    r.created_at
  from public.advisor_consultation_requests r
  join public.advisor_services s on s.id = r.service_id
  left join public.student_profiles sp on sp.id = r.student_id
  where r.advisor_id = auth.uid()
  order by
    case r.status
      when 'requested' then 0
      when 'contacted' then 1
      when 'awaiting_payment' then 2
      when 'paid' then 3
      when 'confirmed' then 4
      else 5
    end,
    r.created_at desc;
end;
$$;

revoke execute on function public.advisor_consultation_requests_for_me()
from public, anon;
grant execute on function public.advisor_consultation_requests_for_me()
to authenticated;

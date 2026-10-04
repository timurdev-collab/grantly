-- Update user-facing consultation payment messages after the EduT rename.

create or replace function public.advisor_update_consultation_request(
  p_request_id uuid,
  p_status text
)
returns public.advisor_consultation_requests
language plpgsql
security definer
set search_path = 'public'
as $$
declare
  result public.advisor_consultation_requests%rowtype;
  existing public.advisor_consultation_requests%rowtype;
  admin_user boolean := public.is_admin();
begin
  if p_status not in (
    'awaiting_payment',
    'paid',
    'confirmed',
    'completed',
    'cancelled'
  ) then
    raise exception 'Unsupported consultation status';
  end if;

  select *
  into existing
  from public.advisor_consultation_requests
  where id = p_request_id;

  if not found then
    raise exception 'Consultation request not found';
  end if;

  if not admin_user and existing.advisor_id <> auth.uid() then
    raise exception 'Consultation request not found or access denied';
  end if;

  if p_status = 'paid' and not admin_user then
    raise exception 'Only EduT administrators can mark a consultation as paid';
  end if;

  if not admin_user and p_status = 'confirmed'
     and existing.status <> 'paid' then
    raise exception 'Payment must be verified by EduT before confirmation';
  end if;

  if not admin_user and p_status = 'completed'
     and existing.status <> 'confirmed' then
    raise exception 'Confirm the consultation before marking it completed';
  end if;

  update public.advisor_consultation_requests r
  set
    status = p_status,
    updated_at = now()
  where r.id = p_request_id
  returning r.* into result;

  insert into public.app_notifications(
    user_id,
    kind,
    title,
    body
  )
  values(
    result.student_id,
    'system',
    'Consultation request updated',
    'Your advisor consultation status is now: ' ||
      replace(result.status, '_', ' ') || '.'
  );

  return result;
end;
$$;

revoke execute on function public.advisor_update_consultation_request(
  uuid,text
) from public, anon;
grant execute on function public.advisor_update_consultation_request(
  uuid,text
) to authenticated;

create or replace function public.admin_consultation_requests()
returns table(
  id uuid,
  student_id uuid,
  student_name text,
  advisor_id uuid,
  advisor_name text,
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
  if not public.is_admin() then
    raise exception 'Admin access required';
  end if;

  return query
  select
    r.id,
    r.student_id,
    coalesce(sp.full_name, 'Student'),
    r.advisor_id,
    coalesce(ap.display_name, 'EduT Advisor'),
    r.service_id,
    s.title,
    s.duration_minutes,
    r.contact_email,
    r.whatsapp_number,
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
  join public.advisor_profiles ap on ap.id = r.advisor_id
  left join public.student_profiles sp on sp.id = r.student_id
  order by
    case r.status
      when 'awaiting_payment' then 0
      when 'requested' then 1
      when 'paid' then 2
      when 'confirmed' then 3
      else 4
    end,
    r.created_at desc;
end;
$$;

revoke execute on function public.admin_consultation_requests()
from public, anon;
grant execute on function public.admin_consultation_requests()
to authenticated;

create or replace function public.my_advisor_consultation_requests()
returns table(
  id uuid,
  student_id uuid,
  advisor_id uuid,
  advisor_name text,
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
language sql
stable
security definer
set search_path = 'public'
as $$
  select
    r.id,
    r.student_id,
    r.advisor_id,
    coalesce(ap.display_name, 'EduT Advisor'),
    r.service_id,
    s.title,
    s.duration_minutes,
    r.contact_email,
    r.whatsapp_number,
    r.preferred_start,
    r.timezone,
    r.topic,
    r.notes,
    r.quoted_price_cents,
    r.currency,
    r.status,
    r.created_at
  from public.advisor_consultation_requests r
  join public.advisor_profiles ap on ap.id = r.advisor_id
  join public.advisor_services s on s.id = r.service_id
  where r.student_id = auth.uid()
  order by r.created_at desc;
$$;

revoke execute on function public.my_advisor_consultation_requests()
from public, anon;
grant execute on function public.my_advisor_consultation_requests()
to authenticated;


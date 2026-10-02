-- Consultation request integrity and privacy hardening.

create index if not exists advisor_consultation_service_idx
on public.advisor_consultation_requests(service_id);

drop function if exists public.submit_advisor_consultation_request(
  uuid,uuid,text,text,timestamptz,text,text,text
);

create or replace function public.submit_advisor_consultation_request(
  p_advisor_id uuid,
  p_service_id uuid,
  p_contact_email text,
  p_whatsapp_number text,
  p_preferred_start timestamptz,
  p_timezone text,
  p_topic text,
  p_notes text default '',
  p_contact_consent boolean default false
)
returns public.advisor_consultation_requests
language plpgsql
security definer
set search_path = 'public'
as $$
declare
  selected_service public.advisor_services%rowtype;
  result public.advisor_consultation_requests%rowtype;
  whatsapp_digits text;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  if not exists (
    select 1
    from public.student_profiles sp
    where sp.id = auth.uid()
      and sp.role = 'student'
  ) then
    raise exception 'Only student accounts can request consultations';
  end if;

  if p_contact_consent is not true then
    raise exception 'Contact consent is required';
  end if;

  if nullif(btrim(p_contact_email), '') is null
     or p_contact_email !~* '^[^[:space:]@]+@[^[:space:]@]+[.][^[:space:]@]+$' then
    raise exception 'Enter a valid email address';
  end if;

  whatsapp_digits := regexp_replace(
    coalesce(p_whatsapp_number, ''),
    '[^0-9]',
    '',
    'g'
  );

  if char_length(whatsapp_digits) < 7
     or char_length(whatsapp_digits) > 15 then
    raise exception 'Enter a valid WhatsApp number with country code';
  end if;

  if nullif(btrim(p_timezone), '') is null then
    raise exception 'Time zone is required';
  end if;

  if nullif(btrim(p_topic), '') is null
     or char_length(btrim(p_topic)) < 3
     or char_length(btrim(p_topic)) > 240 then
    raise exception 'Tell the advisor what you need help with';
  end if;

  if char_length(coalesce(p_notes, '')) > 2000 then
    raise exception 'Notes are too long';
  end if;

  if p_preferred_start is not null
     and p_preferred_start < now() - interval '5 minutes' then
    raise exception 'Preferred consultation time must be in the future';
  end if;

  select s.*
  into selected_service
  from public.advisor_services s
  join public.advisor_profiles ap on ap.id = s.advisor_id
  where s.id = p_service_id
    and s.advisor_id = p_advisor_id
    and s.is_active = true
    and ap.approval_status = 'approved'
    and ap.is_active = true;

  if not found then
    raise exception 'This consultation service is no longer available';
  end if;

  if exists (
    select 1
    from public.advisor_consultation_requests r
    where r.student_id = auth.uid()
      and r.advisor_id = p_advisor_id
      and r.service_id = p_service_id
      and r.status in (
        'requested',
        'contacted',
        'awaiting_payment',
        'paid',
        'confirmed'
      )
  ) then
    raise exception 'You already have an active request for this service';
  end if;

  insert into public.advisor_consultation_requests(
    student_id,
    advisor_id,
    service_id,
    contact_email,
    whatsapp_number,
    preferred_start,
    timezone,
    topic,
    notes,
    quoted_price_cents,
    currency,
    status,
    contact_consent_at
  )
  values(
    auth.uid(),
    p_advisor_id,
    p_service_id,
    lower(btrim(p_contact_email)),
    btrim(p_whatsapp_number),
    p_preferred_start,
    btrim(p_timezone),
    btrim(p_topic),
    btrim(coalesce(p_notes, '')),
    selected_service.price_cents,
    selected_service.currency,
    'requested',
    now()
  )
  returning * into result;

  insert into public.app_notifications(
    user_id,
    kind,
    title,
    body
  )
  values(
    p_advisor_id,
    'system',
    'New consultation request',
    'A student requested a live one-to-one consultation.'
  );

  return result;
end;
$$;

revoke execute on function public.submit_advisor_consultation_request(
  uuid,uuid,text,text,timestamptz,text,text,text,boolean
) from public, anon;

grant execute on function public.submit_advisor_consultation_request(
  uuid,uuid,text,text,timestamptz,text,text,text,boolean
) to authenticated;

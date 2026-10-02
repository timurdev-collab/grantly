-- Advisor live-consultation MVP.
-- Supports real-time one-to-one advisor services with manual external payment coordination.

create table if not exists public.advisor_services (
  id uuid primary key default gen_random_uuid(),
  advisor_id uuid not null
    references public.advisor_profiles(id) on delete cascade,
  title text not null,
  service_type text not null,
  duration_minutes integer not null,
  price_cents integer not null,
  currency text not null default 'USD',
  is_active boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint advisor_services_type_check check (
    service_type in (
      'scholarship_consultation',
      'application_strategy',
      'mock_interview',
      'other'
    )
  ),
  constraint advisor_services_duration_check check (
    duration_minutes between 15 and 180
  ),
  constraint advisor_services_price_check check (
    price_cents between 100 and 100000
  ),
  constraint advisor_services_currency_check check (
    currency ~ '^[A-Z]{3}$'
  )
);

create unique index if not exists advisor_services_unique_default
on public.advisor_services(advisor_id, service_type, duration_minutes)
where is_active = true;

create index if not exists advisor_services_advisor_idx
on public.advisor_services(advisor_id, is_active, sort_order);

alter table public.advisor_services enable row level security;

revoke all on public.advisor_services from anon, authenticated;
grant select on public.advisor_services to authenticated;

drop policy if exists "active advisor services visible"
on public.advisor_services;
create policy "active advisor services visible"
on public.advisor_services
for select
to authenticated
using (
  is_active = true
  and exists (
    select 1
    from public.advisor_profiles ap
    where ap.id = advisor_id
      and ap.approval_status = 'approved'
      and ap.is_active = true
  )
);

insert into public.advisor_services(
  advisor_id,
  title,
  service_type,
  duration_minutes,
  price_cents,
  currency,
  sort_order
)
select
  ap.id,
  seed.title,
  seed.service_type,
  seed.duration_minutes,
  seed.price_cents,
  'USD',
  seed.sort_order
from public.advisor_profiles ap
cross join (
  values
    (
      'Scholarship consultation',
      'scholarship_consultation',
      30,
      2500,
      10
    ),
    (
      'Application strategy',
      'application_strategy',
      60,
      4500,
      20
    ),
    (
      'Mock interview',
      'mock_interview',
      45,
      3500,
      30
    )
) as seed(
  title,
  service_type,
  duration_minutes,
  price_cents,
  sort_order
)
where ap.approval_status = 'approved'
  and ap.is_active = true
  and not exists (
    select 1
    from public.advisor_services existing
    where existing.advisor_id = ap.id
      and existing.service_type = seed.service_type
      and existing.duration_minutes = seed.duration_minutes
      and existing.is_active = true
  );

create table if not exists public.advisor_consultation_requests (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null
    references auth.users(id) on delete cascade,
  advisor_id uuid not null
    references public.advisor_profiles(id) on delete cascade,
  service_id uuid not null
    references public.advisor_services(id) on delete restrict,
  contact_email text not null,
  whatsapp_number text not null,
  preferred_start timestamptz,
  timezone text not null,
  topic text not null,
  notes text not null default '',
  quoted_price_cents integer not null,
  currency text not null,
  status text not null default 'requested',
  contact_consent_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint advisor_consultation_status_check check (
    status in (
      'requested',
      'contacted',
      'awaiting_payment',
      'paid',
      'confirmed',
      'completed',
      'cancelled'
    )
  ),
  constraint advisor_consultation_email_check check (
    char_length(contact_email) between 5 and 254
  ),
  constraint advisor_consultation_whatsapp_check check (
    char_length(whatsapp_number) between 7 and 40
  ),
  constraint advisor_consultation_topic_check check (
    char_length(btrim(topic)) between 3 and 240
  ),
  constraint advisor_consultation_notes_check check (
    char_length(notes) <= 2000
  )
);

create index if not exists advisor_consultation_student_idx
on public.advisor_consultation_requests(student_id, created_at desc);

create index if not exists advisor_consultation_advisor_idx
on public.advisor_consultation_requests(advisor_id, status, created_at desc);

alter table public.advisor_consultation_requests enable row level security;

revoke all on public.advisor_consultation_requests from anon, authenticated;
grant select on public.advisor_consultation_requests to authenticated;

drop policy if exists "students view own consultation requests"
on public.advisor_consultation_requests;
create policy "students view own consultation requests"
on public.advisor_consultation_requests
for select
to authenticated
using (
  student_id = (select auth.uid())
  or advisor_id = (select auth.uid())
  or (select public.is_admin())
);

create or replace function public.available_advisor_services(
  p_advisor_id uuid
)
returns table(
  id uuid,
  advisor_id uuid,
  title text,
  service_type text,
  duration_minutes integer,
  price_cents integer,
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

create or replace function public.submit_advisor_consultation_request(
  p_advisor_id uuid,
  p_service_id uuid,
  p_contact_email text,
  p_whatsapp_number text,
  p_preferred_start timestamptz,
  p_timezone text,
  p_topic text,
  p_notes text default ''
)
returns public.advisor_consultation_requests
language plpgsql
security definer
set search_path = 'public'
as $$
declare
  selected_service public.advisor_services%rowtype;
  result public.advisor_consultation_requests%rowtype;
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

  if nullif(btrim(p_contact_email), '') is null
     or p_contact_email !~* '^[^[:space:]@]+@[^[:space:]@]+[.][^[:space:]@]+$' then
    raise exception 'Enter a valid email address';
  end if;

  if nullif(btrim(p_whatsapp_number), '') is null
     or char_length(btrim(p_whatsapp_number)) < 7
     or char_length(btrim(p_whatsapp_number)) > 40 then
    raise exception 'Enter a valid WhatsApp number';
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
    status
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
    'requested'
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
  uuid,uuid,text,text,timestamptz,text,text,text
) from public, anon;
grant execute on function public.submit_advisor_consultation_request(
  uuid,uuid,text,text,timestamptz,text,text,text
) to authenticated;

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
    coalesce(ap.display_name, 'Grantly Advisor'),
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
begin
  if p_status not in (
    'contacted',
    'awaiting_payment',
    'paid',
    'confirmed',
    'completed',
    'cancelled'
  ) then
    raise exception 'Unsupported consultation status';
  end if;

  update public.advisor_consultation_requests r
  set
    status = p_status,
    updated_at = now()
  where r.id = p_request_id
    and (
      r.advisor_id = auth.uid()
      or public.is_admin()
    )
  returning r.* into result;

  if result.id is null then
    raise exception 'Consultation request not found or access denied';
  end if;

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

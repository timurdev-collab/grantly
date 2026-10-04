-- Versioned clickwrap consent for advisor bookings.
-- Records affirmative acceptance before plan selection and snapshots the accepted
-- policy versions and selected service terms on each consultation request.

create table if not exists public.advisor_terms_acceptances (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  advisor_id uuid not null references public.advisor_profiles(id) on delete cascade,
  terms_version text not null,
  privacy_version text not null,
  refund_policy_version text not null,
  accepted_at timestamptz not null default now()
);

create index if not exists advisor_terms_acceptances_user_idx
on public.advisor_terms_acceptances(user_id, accepted_at desc);

create index if not exists advisor_terms_acceptances_advisor_idx
on public.advisor_terms_acceptances(advisor_id, accepted_at desc);

alter table public.advisor_terms_acceptances enable row level security;

revoke all on public.advisor_terms_acceptances from anon, authenticated;
grant select on public.advisor_terms_acceptances to authenticated;

drop policy if exists "users view own advisor terms acceptances"
on public.advisor_terms_acceptances;

create policy "users view own advisor terms acceptances"
on public.advisor_terms_acceptances
for select
to authenticated
using (
  user_id = (select auth.uid())
  or (select public.is_admin())
);

alter table public.advisor_consultation_requests
  add column if not exists terms_acceptance_id uuid
    references public.advisor_terms_acceptances(id) on delete restrict,
  add column if not exists terms_version text,
  add column if not exists privacy_version text,
  add column if not exists refund_policy_version text,
  add column if not exists legal_accepted_at timestamptz,
  add column if not exists service_title_snapshot text,
  add column if not exists service_type_snapshot text,
  add column if not exists list_price_cents_snapshot integer,
  add column if not exists discount_percent_snapshot integer;

create or replace function public.accept_advisor_booking_terms(
  p_advisor_id uuid,
  p_terms_version text,
  p_privacy_version text,
  p_refund_policy_version text
)
returns table(acceptance_id uuid)
language plpgsql
security definer
set search_path = 'public'
as $$
declare
  result_id uuid;
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
    raise exception 'Only student accounts can accept advisor booking terms';
  end if;

  if not exists (
    select 1
    from public.advisor_profiles ap
    where ap.id = p_advisor_id
      and ap.approval_status = 'approved'
      and ap.is_active = true
  ) then
    raise exception 'Advisor is not available';
  end if;

  if p_terms_version <> '2026-10-04.v1'
     or p_privacy_version <> '2026-10-04.v1'
     or p_refund_policy_version <> '2026-10-04.v1' then
    raise exception 'Please review the latest booking policies before continuing';
  end if;

  insert into public.advisor_terms_acceptances(
    user_id,
    advisor_id,
    terms_version,
    privacy_version,
    refund_policy_version
  )
  values(
    auth.uid(),
    p_advisor_id,
    p_terms_version,
    p_privacy_version,
    p_refund_policy_version
  )
  returning id into result_id;

  return query select result_id;
end;
$$;

revoke execute on function public.accept_advisor_booking_terms(
  uuid,text,text,text
) from public, anon;

grant execute on function public.accept_advisor_booking_terms(
  uuid,text,text,text
) to authenticated;

drop function if exists public.submit_advisor_consultation_request(
  uuid,uuid,text,text,timestamptz,text,text,text,boolean
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
  p_contact_consent boolean default false,
  p_terms_acceptance_id uuid default null,
  p_terms_version text default '',
  p_privacy_version text default '',
  p_refund_policy_version text default ''
)
returns public.advisor_consultation_requests
language plpgsql
security definer
set search_path = 'public'
as $$
declare
  selected_service public.advisor_services%rowtype;
  accepted_terms public.advisor_terms_acceptances%rowtype;
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

  select *
  into accepted_terms
  from public.advisor_terms_acceptances a
  where a.id = p_terms_acceptance_id
    and a.user_id = auth.uid()
    and a.advisor_id = p_advisor_id;

  if not found then
    raise exception 'Please accept the booking terms before choosing a plan';
  end if;

  if accepted_terms.terms_version <> p_terms_version
     or accepted_terms.privacy_version <> p_privacy_version
     or accepted_terms.refund_policy_version <> p_refund_policy_version
     or p_terms_version <> '2026-10-04.v1'
     or p_privacy_version <> '2026-10-04.v1'
     or p_refund_policy_version <> '2026-10-04.v1' then
    raise exception 'Your booking policy acceptance is no longer current';
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
    contact_consent_at,
    terms_acceptance_id,
    terms_version,
    privacy_version,
    refund_policy_version,
    legal_accepted_at,
    service_title_snapshot,
    service_type_snapshot,
    list_price_cents_snapshot,
    discount_percent_snapshot
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
    now(),
    accepted_terms.id,
    accepted_terms.terms_version,
    accepted_terms.privacy_version,
    accepted_terms.refund_policy_version,
    accepted_terms.accepted_at,
    selected_service.title,
    selected_service.service_type,
    selected_service.list_price_cents,
    selected_service.discount_percent
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
  uuid,uuid,text,text,timestamptz,text,text,text,boolean,uuid,text,text,text
) from public, anon;

grant execute on function public.submit_advisor_consultation_request(
  uuid,uuid,text,text,timestamptz,text,text,text,boolean,uuid,text,text,text
) to authenticated;

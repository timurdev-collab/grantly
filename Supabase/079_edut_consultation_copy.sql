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

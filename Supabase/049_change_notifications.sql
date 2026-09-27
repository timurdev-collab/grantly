-- Data reliability step 16: notify users when reviewed scholarship facts change.
-- Notifications are created only after an admin accepts a detected change.

create or replace function public.accept_detected_scholarship_change(
  p_change_id uuid,
  p_note text default null
)
returns public.scholarship_detected_changes
language plpgsql
security invoker
set search_path = public
as $$
declare
  c public.scholarship_detected_changes%rowtype;
  scholarship_title text;
begin
  if not public.is_admin() then
    raise exception 'Admin access required';
  end if;

  select * into c
  from public.scholarship_detected_changes
  where id = p_change_id
    and status = 'pending'
  for update;

  if not found then
    raise exception 'Pending detected change not found';
  end if;

  select title into scholarship_title
  from public.scholarships
  where id = c.scholarship_id;

  if c.field_name = 'deadline' then
    update public.scholarships
    set deadline = nullif(c.detected_value, '')::date,
        deadline_verification_status = 'verified',
        verified_at = now()
    where id = c.scholarship_id;

    update public.saved_scholarships
    set application_deadline = nullif(c.detected_value, '')::date,
        updated_at = now()
    where scholarship_id = c.scholarship_id
      and (
        application_deadline is null
        or application_deadline is not distinct from
          nullif(c.old_value, '')::date
      );

    insert into public.app_notifications(
      user_id,
      kind,
      title,
      body,
      scholarship_id,
      scheduled_for
    )
    select
      ss.user_id,
      'deadline',
      'Scholarship deadline updated',
      coalesce(scholarship_title, 'A saved scholarship') ||
        ' now has a confirmed deadline of ' ||
        coalesce(c.detected_value, 'not announced') || '.',
      c.scholarship_id,
      now()
    from public.saved_scholarships ss
    left join public.notification_preferences np
      on np.user_id = ss.user_id
    where ss.scholarship_id = c.scholarship_id
      and ss.reminder_enabled = true
      and coalesce(np.deadline_reminders, true) = true;

  elsif c.field_name = 'application_cycle' then
    update public.scholarships
    set application_cycle = nullif(c.detected_value, ''),
        verified_at = now()
    where id = c.scholarship_id;

    insert into public.app_notifications(
      user_id,
      kind,
      title,
      body,
      scholarship_id,
      scheduled_for
    )
    select
      ss.user_id,
      'scholarship_update',
      'New scholarship cycle confirmed',
      coalesce(scholarship_title, 'A saved scholarship') ||
        ' now shows application cycle ' ||
        coalesce(c.detected_value, 'updated') || '.',
      c.scholarship_id,
      now()
    from public.saved_scholarships ss
    where ss.scholarship_id = c.scholarship_id;

  elsif c.field_name = 'cycle_status' then
    update public.scholarships
    set cycle_status = coalesce(nullif(c.detected_value, ''), 'unknown')
    where id = c.scholarship_id;

    insert into public.app_notifications(
      user_id,
      kind,
      title,
      body,
      scholarship_id,
      scheduled_for
    )
    select
      ss.user_id,
      'scholarship_update',
      case
        when c.detected_value = 'closed'
          then 'Scholarship cycle closed'
        when c.detected_value = 'discontinued'
          then 'Scholarship status changed'
        else 'Scholarship cycle updated'
      end,
      coalesce(scholarship_title, 'A saved scholarship') ||
        ' is now marked as ' ||
        coalesce(c.detected_value, 'updated') || '.',
      c.scholarship_id,
      now()
    from public.saved_scholarships ss
    where ss.scholarship_id = c.scholarship_id;

  elsif c.field_name = 'official_url' then
    update public.scholarships
    set official_url = coalesce(nullif(c.detected_value, ''), official_url),
        final_url = coalesce(nullif(c.detected_value, ''), final_url),
        verified_at = now()
    where id = c.scholarship_id;
  end if;

  update public.scholarship_detected_changes
  set status = 'accepted',
      reviewed_at = now(),
      reviewed_by = auth.uid(),
      review_note = nullif(btrim(p_note), '')
  where id = p_change_id
  returning * into c;

  update public.scholarship_detected_changes
  set status = 'superseded',
      reviewed_at = now(),
      review_note = coalesce(review_note, 'Superseded by accepted change')
  where scholarship_id = c.scholarship_id
    and field_name = c.field_name
    and status = 'pending'
    and id <> c.id;

  return c;
end;
$$;

revoke execute on function public.accept_detected_scholarship_change(uuid,text)
from public, anon;
grant execute on function public.accept_detected_scholarship_change(uuid,text)
to authenticated;

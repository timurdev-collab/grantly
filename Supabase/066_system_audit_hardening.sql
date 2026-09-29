-- System audit hardening: scholarship publication and advisor messaging boundaries.

drop policy if exists "anonymous reads published scholarships"
on public.scholarships;

create policy "anonymous reads discoverable scholarships"
on public.scholarships
for select
to anon
using (
  public.scholarship_is_discoverable(scholarships)
);

drop policy if exists "authenticated reads scholarships"
on public.scholarships;

create policy "authenticated reads scholarships"
on public.scholarships
for select
to authenticated
using (
  public.is_admin()
  or public.scholarship_is_discoverable(scholarships)
);

create or replace function private.can_message_conversation(
  conversation_uuid uuid
)
returns boolean
language sql
stable
security definer
set search_path to 'public'
as $$
  select
    private.is_conversation_member(conversation_uuid)
    and not exists (
      select 1
      from public.conversation_members other_member
      join public.user_blocks b
        on (
          (b.blocker_id = auth.uid() and b.blocked_id = other_member.user_id)
          or
          (b.blocked_id = auth.uid() and b.blocker_id = other_member.user_id)
        )
      where other_member.conversation_id = conversation_uuid
        and other_member.user_id <> auth.uid()
    )
    and (
      not exists (
        select 1
        from public.advisor_student_assignments a
        where a.conversation_id = conversation_uuid
      )
      or exists (
        select 1
        from public.advisor_student_assignments a
        where a.conversation_id = conversation_uuid
          and a.status = 'active'
          and auth.uid() in (a.student_id, a.advisor_id)
      )
    )
    and (
      select count(*)
      from public.messages recent
      where recent.sender_id = auth.uid()
        and recent.created_at > now() - interval '60 seconds'
    ) < 20;
$$;

create or replace function public.get_my_conversation_summaries()
returns table(
  conversation_id uuid,
  other_user_id uuid,
  display_name text,
  last_message text,
  last_message_at timestamptz,
  last_message_sender_id uuid,
  unread_count bigint,
  last_read_at timestamptz
)
language sql
stable
set search_path to 'public'
as $$
  with mine as (
    select cm.conversation_id, cm.last_read_at
    from public.conversation_members cm
    where cm.user_id = auth.uid()
      and (
        not exists (
          select 1
          from public.student_profiles sp
          where sp.id = auth.uid()
            and sp.role = 'advisor'
        )
        or exists (
          select 1
          from public.advisor_student_assignments a
          where a.advisor_id = auth.uid()
            and a.conversation_id = cm.conversation_id
            and a.status = 'active'
        )
      )
  ),
  other_members as (
    select
      m.conversation_id,
      cm.user_id as other_user_id
    from mine m
    join public.conversation_members cm
      on cm.conversation_id = m.conversation_id
     and cm.user_id <> auth.uid()
  ),
  latest as (
    select distinct on (msg.conversation_id)
      msg.conversation_id,
      msg.body,
      msg.created_at,
      msg.sender_id
    from public.messages msg
    join mine m on m.conversation_id = msg.conversation_id
    order by msg.conversation_id, msg.created_at desc, msg.id desc
  )
  select
    m.conversation_id,
    om.other_user_id,
    coalesce(
      nullif(btrim(cp.display_name), ''),
      'Student'
    ) as display_name,
    l.body as last_message,
    l.created_at as last_message_at,
    l.sender_id as last_message_sender_id,
    (
      select count(*)
      from public.messages unread
      where unread.conversation_id = m.conversation_id
        and unread.sender_id <> auth.uid()
        and unread.created_at > coalesce(
          m.last_read_at,
          '-infinity'::timestamptz
        )
    ) as unread_count,
    m.last_read_at
  from mine m
  left join other_members om
    on om.conversation_id = m.conversation_id
  left join public.community_profiles cp
    on cp.id = om.other_user_id
  left join latest l
    on l.conversation_id = m.conversation_id
  order by l.created_at desc nulls last, m.conversation_id;
$$;

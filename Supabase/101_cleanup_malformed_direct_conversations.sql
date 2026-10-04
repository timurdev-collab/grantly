-- Remove legacy malformed direct conversations that no longer have two members.
-- Future account deletion cleanup also removes these cases.

delete from public.conversations c
where c.is_direct = true
  and (
    select count(*)
    from public.conversation_members cm
    where cm.conversation_id = c.id
  ) < 2;

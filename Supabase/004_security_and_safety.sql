-- Grantly production safety and security hardening
-- Safe to run on an existing project.

create table if not exists public.safety_reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid references auth.users(id) on delete set null,
  reported_user_id uuid references auth.users(id) on delete set null,
  message_id uuid references public.messages(id) on delete set null,
  reason text not null check (reason in ('Spam', 'Harassment', 'Inappropriate content', 'Scam or fraud', 'Other')),
  details text not null default '' check (char_length(details) <= 1000),
  status text not null default 'open' check (status in ('open', 'reviewing', 'resolved', 'dismissed')),
  created_at timestamptz not null default now(),
  resolved_at timestamptz,
  check (reported_user_id is not null or message_id is not null)
);

alter table public.safety_reports enable row level security;

revoke all on public.safety_reports from anon, authenticated;
grant select, insert, update on public.safety_reports to authenticated;

drop policy if exists "users create reports" on public.safety_reports;
create policy "users create reports"
on public.safety_reports for insert to authenticated
with check (
  reporter_id = (select auth.uid())
  and (reported_user_id is null or reported_user_id <> (select auth.uid()))
);

drop policy if exists "users view own reports" on public.safety_reports;
create policy "users view own reports"
on public.safety_reports for select to authenticated
using (
  reporter_id = (select auth.uid())
  or public.is_admin()
);

drop policy if exists "admins update reports" on public.safety_reports;
create policy "admins update reports"
on public.safety_reports for update to authenticated
using (public.is_admin())
with check (public.is_admin());

revoke execute on function public.handle_new_user() from public, anon, authenticated;
revoke execute on function public.is_admin() from public, anon;
grant execute on function public.is_admin() to authenticated;
revoke execute on function public.is_conversation_member(uuid) from public, anon;
grant execute on function public.is_conversation_member(uuid) to authenticated;
revoke execute on function public.start_direct_conversation(uuid) from public, anon;
grant execute on function public.start_direct_conversation(uuid) to authenticated;

create index if not exists saved_scholarships_scholarship_idx
  on public.saved_scholarships(scholarship_id);
create index if not exists conversation_members_user_idx
  on public.conversation_members(user_id);
create index if not exists messages_sender_idx
  on public.messages(sender_id);
create index if not exists safety_reports_reporter_idx
  on public.safety_reports(reporter_id, created_at desc);
create index if not exists safety_reports_status_idx
  on public.safety_reports(status, created_at desc);
create index if not exists safety_reports_reported_user_idx
  on public.safety_reports(reported_user_id, created_at desc);
create index if not exists safety_reports_message_idx
  on public.safety_reports(message_id);

-- Grantly saved scholarship application tracker
-- Safe to run more than once.

alter table public.saved_scholarships
  add column if not exists application_status text not null default 'Planning';

alter table public.saved_scholarships
  add column if not exists notes text;

alter table public.saved_scholarships
  add column if not exists updated_at timestamptz not null default now();

alter table public.saved_scholarships
  drop constraint if exists saved_scholarships_application_status_check;

alter table public.saved_scholarships
  add constraint saved_scholarships_application_status_check
  check (application_status in ('Planning', 'Applied', 'Interview', 'Result'));

grant update on table public.saved_scholarships to authenticated;

drop policy if exists "users update own saves" on public.saved_scholarships;
create policy "users update own saves"
on public.saved_scholarships
for update
to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

create index if not exists saved_scholarships_user_updated_idx
  on public.saved_scholarships(user_id, updated_at desc);

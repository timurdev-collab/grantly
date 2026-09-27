alter table public.saved_scholarships
  add column if not exists application_reference text,
  add column if not exists portal_last_checked_at timestamptz;

comment on column public.saved_scholarships.application_reference is
  'User-entered application confirmation or reference number from the official provider portal.';

comment on column public.saved_scholarships.portal_last_checked_at is
  'Last time the user opened the official provider portal from Grantly to check application status.';

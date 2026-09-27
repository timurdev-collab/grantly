create index if not exists scholarship_history_changed_by_idx
  on public.scholarship_change_history(changed_by)
  where changed_by is not null;

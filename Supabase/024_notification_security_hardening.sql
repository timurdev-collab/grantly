-- Harden internal notification/task functions and add foreign-key indexes.

revoke execute on function public.create_default_application_tasks()
  from public, anon, authenticated;

revoke execute on function public.recalculate_application_task_due_dates(uuid, uuid)
  from public, anon, authenticated;

revoke execute on function public.sync_application_deadline_and_tasks()
  from public, anon, authenticated;

revoke execute on function public.enqueue_application_notifications()
  from public, anon, authenticated;

revoke execute on function public.notify_new_message()
  from public, anon, authenticated;

revoke execute on function public.notify_saved_scholarship_deadline_change()
  from public, anon, authenticated;

grant execute on function public.enqueue_application_notifications()
  to postgres;

create index if not exists application_tasks_scholarship_idx
  on public.application_tasks(scholarship_id);

create index if not exists app_notifications_scholarship_idx
  on public.app_notifications(scholarship_id);

create index if not exists app_notifications_task_idx
  on public.app_notifications(task_id);

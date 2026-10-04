-- Add covering indexes for foreign keys flagged by the database linter.

create index if not exists advisor_call_sessions_conversation_id_idx
  on public.advisor_call_sessions(conversation_id);
create index if not exists advisor_call_sessions_started_by_idx
  on public.advisor_call_sessions(started_by);
create index if not exists advisor_profiles_reviewed_by_idx
  on public.advisor_profiles(reviewed_by);
create index if not exists advisor_review_events_admin_id_idx
  on public.advisor_review_events(admin_id);
create index if not exists advisor_student_assignments_conversation_id_idx
  on public.advisor_student_assignments(conversation_id);
create index if not exists application_documents_scholarship_id_idx
  on public.application_documents(scholarship_id);
create index if not exists scholarship_detected_changes_reviewed_by_idx
  on public.scholarship_detected_changes(reviewed_by);
create index if not exists scholarship_field_provenance_accepted_by_idx
  on public.scholarship_field_provenance(accepted_by);
create index if not exists scholarship_field_provenance_source_candidate_id_idx
  on public.scholarship_field_provenance(source_candidate_id);
create index if not exists scholarship_import_batches_created_by_idx
  on public.scholarship_import_batches(created_by);
create index if not exists scholarship_import_rows_applied_scholarship_id_idx
  on public.scholarship_import_rows(applied_scholarship_id);
create index if not exists scholarship_source_candidate_profiles_source_registry_id_idx
  on public.scholarship_source_candidate_profiles(source_registry_id);
create index if not exists scholarship_source_candidates_reviewed_by_idx
  on public.scholarship_source_candidates(reviewed_by);
create index if not exists social_post_reports_reported_user_id_idx
  on public.social_post_reports(reported_user_id);
create index if not exists social_post_reports_reporter_id_idx
  on public.social_post_reports(reporter_id);
create index if not exists social_posts_author_id_idx
  on public.social_posts(author_id);
create index if not exists university_case_documents_requirement_id_idx
  on public.university_case_documents(requirement_id);
create index if not exists university_case_documents_user_id_idx
  on public.university_case_documents(user_id);
create index if not exists university_case_requirements_user_id_idx
  on public.university_case_requirements(user_id);

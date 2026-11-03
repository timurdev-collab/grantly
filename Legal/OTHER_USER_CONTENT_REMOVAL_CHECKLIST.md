# EduT 1.0.1: removal of Other User Content collection

## iOS client changes implemented
- Disable social feed posting, stories, shorts, and comment entry.
- Remove application document upload controls from the scholarship workspace and university case details.
- Remove written application notes from scholarship tracker and application workspace. Workspace saves an empty notes value when saving the record.
- Remove free-form advisor biographies / introductions from the advisor application UI. New advisor profiles use a generic platform-authored explanation alongside structured profile fields.
- Remove free-form consultation topic and additional notes. The consultation is identified by selected service.
- Remove free-text custom scholarship checklist creation.
- Remove the unused student-community bio card and profile bio load.
- Remove `Other User Content` from the **next-version** iOS privacy manifest.

## Data safeguards / rollout not yet completed
- Historical community posts, comments, uploaded files, notes, advisor bios, and attachments **have not been erased**. Preserve existing user data until an explicit, safe retention/deletion decision.
- The production backend may still accept content submitted from **older iOS app versions** through existing Supabase APIs, storage and database policies. Before removing `Other User Content` from the *published App Store privacy label*, deploy and verify server-side safeguards stopping new uploads/posts/comments/notes/bios that fall into that category.
- Review remaining user-generated data flows (especially admin drafting, optional consultation/service records, report forms and any third-party SDKs) for Apple category mapping.
- Confirm in Xcode that no production path still submits unstructured user content except separately categorized messages, photos/videos, and customer-support requests.
- Run iOS CI / Xcode archive, advisor onboarding, case status management, scholarship progress, messaging, and deletion E2E checks.
- Publish new App Store privacy disclosures at the appropriate release cutover; the App Store's *current version 1.0* may still collect content.
- Update the public Privacy Policy when the changed iOS build and backend controls are actually live.

This document records changes made to the development branch; it is **not** an assertion of completed production privacy compliance.

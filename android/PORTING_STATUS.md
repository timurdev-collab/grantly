# EduT Android port status

Updated: 2026-10-23. Source branch: `feature/android-compose-foundation`.
Design and behavior reference (read-only): `design/home-concept-02`.

## Implemented in Android source
- Compose home layout and bottom navigation.
- Read-only scholarship discovery through the existing public Supabase RPC.
- Server-side search, degree/country/field/funding filters, sorting and pagination.
- Scholarship detail tabs for overview, eligibility, benefits and application information.
- Profile-tab email/password sign-in, signup and sign-out through the existing Supabase Auth API.
- Authenticated Applications list showing saved scholarships, status and notes (first 100).
- Authenticated application status and notes editing through existing user-scoped APIs.
- Application task checklist: read, complete/reopen, add custom tasks and delete custom tasks using existing `application_tasks` RLS table (not yet device-tested; first 100 tasks per scholarship).
- Read-only private application document metadata (file names, types and sizes) via existing user-scoped RLS table; no file upload/download/delete yet (not device-tested).
- Save/remove scholarship controls on detail screens using existing user-scoped Supabase RLS policies (not yet device-tested).
- Automatic access-token refresh and Android Keystore AES-GCM encrypted session persistence, including restoration at launch and local token removal on sign-out (not yet device-tested).

## Not yet implemented or verified
- Password recovery, auth deep-link handling and on-device verification of encrypted session restoration.
- Profile loading, editing and student/advisor/admin role routing.
- Application task due-date editing, document uploads/downloads/deletion and notifications.
- Saved-scholarship pagination beyond 100 items.
- Messaging, community, advisor consultations and personalized matching.
- iOS-equivalent styling, accessibility, localization and navigation across all screens.
- Save/remove and task-checklist API behavior, live API testing with a real account and physical-device end-to-end testing.

## Preview safety
Authentication tokens are stored as AES-GCM ciphertext using a non-exportable Android
Keystore key; app backup is disabled. On restart, the app attempts to restore and refresh
the encrypted session. Sign-out clears local credentials before contacting the server.
If Keystore storage is unavailable, the app keeps an in-memory session only. The
persistence flow has not yet been verified on a physical Android device.

A successful `Android Debug APK` GitHub Actions build proves compilation only, not
feature parity, server availability, account behavior or device compatibility.
Do not distribute the debug APK as a production release.

## Build
See `android/README.md` and the `Android Debug APK` GitHub Actions workflow.
Only modify the Android feature branch; do not change iOS, production backend or website.

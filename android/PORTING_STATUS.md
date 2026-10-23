# EduT Android port status

Updated: 2026-10-23. Source branch: `feature/android-compose-foundation`.
Design and behavior reference (read-only): `design/home-concept-02`.

## Implemented in Android source
- Compose home layout and bottom navigation.
- Read-only scholarship discovery through the existing public Supabase RPC.
- Server-side search, degree/country/field/funding filters, sorting and pagination.
- Scholarship detail tabs for overview, eligibility, benefits and application information.
- Profile-tab email/password sign-in, signup and sign-out through the existing Supabase Auth API.

## Not yet implemented or verified
- Authentication session persistence, refresh, password recovery and deep-link handling.
- Profile loading, editing and student/advisor/admin role routing.
- Saved scholarships, application pipeline, tasks, document workspace and notifications.
- Messaging, community, advisor consultations and personalized matching.
- iOS-equivalent styling, accessibility, localization and navigation across all screens.
- Live API testing with a real account and physical-device end-to-end testing.

## Preview safety
The authentication client holds its access token **in memory only**. Signing in does not
unlock unimplemented account features; users must sign in again after the process is
restarted. No credentials are written to local storage. This is intentionally a preview
until secure session persistence and refresh are available.

A successful `Android Debug APK` GitHub Actions build proves compilation only, not
feature parity, server availability, account behavior or device compatibility.
Do not distribute the debug APK as a production release.

## Build
See `android/README.md` and the `Android Debug APK` GitHub Actions workflow.
Only modify the Android feature branch; do not change iOS, production backend or website.

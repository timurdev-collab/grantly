# EduT Android port status

Updated: 2026-10-24. Source branch: `feature/android-compose-foundation`.
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
- Private application document metadata, single-file uploads and confirmed deletion via the existing user-scoped RLS table and private Storage bucket (PDF/JPEG/PNG/HEIC/HEIF, up to 6 MiB). Upload failure attempts storage rollback; all mutations remain unverified on a live account/device.
- Save/remove scholarship controls on detail screens using existing user-scoped Supabase RLS policies (not yet device-tested).
- Automatic access-token refresh and Android Keystore AES-GCM encrypted session persistence, including restoration at launch and local token removal on sign-out (not yet device-tested).
- Password recovery email requests, verified recovery deep links and password update through the existing Supabase Auth API (not yet device-tested).
- Private academic profile summary and validated editing through the existing `student_profiles` RLS table; degree, GPA, IELTS, graduation, residence, nationality, major and study preferences. Role is read-only and never included in update payloads (not yet account/device-tested).
- Read-only approved advisor directory, reachable from the Home guidance card after sign-in. Uses existing authenticated `available_advisors` RPC, with local search and advisor detail summaries (not yet live-account/device-tested).
- Read-only advisor consultation service options (duration, live price and discount) and authenticated consultation-request history (status, advisor, topic and quoted price), using existing `available_advisor_services` and `my_advisor_consultation_requests` RPCs (not yet live-account/device-tested).
- Personalized scholarship recommendations through the existing `get_my_scholarship_matches` RPC, including ranking, explanations and eligibility warnings (not yet live-account/device-tested).
- Advisor consultation booking requests using the existing policy-acceptance and booking RPCs. Displays three policies, records versioned consent, allows service and local preferred date/time selection, and sends the chosen instant in UTC with the device time zone. No in-app payment or guaranteed booking; requires live-account/device testing.
- Read-only authenticated Community feed reachable from Home, loading up to 30 visible non-story posts through existing social_posts RLS with manual refresh, caption and media-presence indicators. No media playback, author cards, likes, comments, posting, stories or community profile editing; hidden community profiles may yield an empty feed. This code has not been account/device-tested.
- Advisor-only Messages tab with authenticated conversation summaries, unread counts, paginated messages, manual refresh, read receipts and explicit message sending. Approved advisor profiles can open or create advisor-direct conversations through the existing role-restricted RPC. Foreground-only inbox polling (30 seconds) and thread polling (20 seconds) now refresh content while visible; thread updates preserve older paginated messages. Android includes user/message safety reports and block/unblock controls through existing RLS-protected tables, including a block confirmation and disabled composer for locally blocked users. Polling is not a realtime subscription or push notification; messaging and safety actions are not live-account/device-tested.

## Not yet implemented or verified
- On-device verification of password recovery deep links and encrypted session restoration.
- Student/advisor/admin role-specific destinations and community profile editing (academic profile read/write and read-only approved advisor discovery are now in Android).
- Application task due-date editing and notifications. Upload, deletion and rollback behavior still need authenticated backend testing.
- Saved-scholarship pagination beyond 100 items.
- Messaging realtime subscriptions/push notifications (foreground polling only), full community interaction and media, administrator moderation queues/tools and full role-specific navigation. Advisor messaging, user/message reporting, blocking, booking and personalized matching now exist in source but remain unverified with real accounts.
- iOS-equivalent styling, accessibility, localization and navigation across all screens.
- Save/remove, task-checklist, recommendations, advisor booking policy acceptance, preferred-time submission, message reports, block/unblock actions, live API testing with a real account and physical-device end-to-end testing.

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

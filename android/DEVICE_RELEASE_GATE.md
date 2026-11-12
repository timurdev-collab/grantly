# Android release gate: authenticated device verification

Status: **not executed**. This is a test protocol, not a claim of feature parity. Android source includes administrator draft review/publishing and advisor-application moderation entry points in Profile, but no authenticated device verification has been recorded.
Branch: `feature/android-compose-foundation`. Never test destructive flows on production accounts.

## Setup
- Install the APK produced by the same commit being evaluated. Record commit SHA, run ID, APK checksum, Android version and device model.
- Use disposable student, approved advisor, unapproved advisor and admin accounts with permission to test. Do not insert or change production backend data outside ordinary test-account operations.
- Record test evidence (pass/fail, timestamp, screenshot or redacted logs) without credentials, access tokens or private documents.
- Ensure the account has a visible Community profile for publishing cases; test hidden-profile denial separately.

## Required gates
| ID | Account | Scenario | Expected result |
| --- | --- | --- | --- |
| AUTH-01 | student | Sign in, force-stop, relaunch, refresh session, sign out | Session restores securely; sign-out prevents reentry |
| AUTH-02 | student | Password recovery deep link and invalid/expired link | Valid recovery succeeds; invalid link fails closed |
| STU-01 | student | Search, filter, save, reopen and remove scholarship | Catalog and saved state agree after relaunch |
| STU-02 | student | Edit academic profile, application notes, tasks and dates | Changes persist; no family-income input or request |
| ADV-01 | approved advisor | Sign in and switch between Advisor Portal and Student View | Correct role-specific destinations, no privilege escalation |
| ADV-02 | unapproved advisor | Open Profile and attempt advisor-only actions | Advisor actions unavailable |
| ADV-03 | approved advisor | Consultation and student status changes on disposable records | Allowed transitions work; stale/invalid transitions fail safely |
| MSG-01 | student and advisor | Send, receive, refresh, report and block | Text messages and safety rules work; no calling UI |
| COM-01 | student | Publish, view, like, comment and report a text post | RLS-protected state persists across relaunch |
| COM-02 | student | Upload JPEG/PNG and MP4 post/story/Short | Media opens; failed insert rolls back private upload |
| COM-03 | student | Interrupt MP4 upload with network loss | In-session HEAD offset reconciliation succeeds without duplicates |
| COM-04 | student | Force-stop during MP4 upload and relaunch | **Expected to fail until durable upload recovery is implemented** |
| COM-05 | student | Hide Community profile and attempt publish | Client denies action and server rejects bypass |
| ADM-01 | admin | Review scholarship drafts, duplicate checks, publication and advisor application moderation | **Implemented in Android source, not authenticated/device-verified**; block release until tested |
| DEL-01 | disposable account | Confirm account deletion, relaunch | Server confirms deletion before local credentials are cleared |
| SAFE-01 | all | Inspect permissions, dependencies and navigation | No LiveKit SDK, camera/microphone permissions, calls, tokens or call UI |
| SAFE-02 | advisor | Open biography and YouTube introduction | Both remain available without calling features |

## Release decision
A green JVM test, emulator smoke test or downloadable debug APK is **preview-only** evidence. Full release requires all applicable gates passing on a physical Android device, no unresolved high-severity defects, signed release AAB verification and explicit product acceptance. Record failures as issues rather than marking them passed. Do not stop hourly development until functionality and device verification are complete.

# EduT Android — Kotlin / Jetpack Compose development preview

Development branch: `feature/android-compose-foundation`. Read-only iOS reference: `design/home-concept-02`.

**This is not a production-ready Android release or an iOS-equivalent replica.** The current source includes scholarship discovery, sign-in and account management, saved applications, a student profile, Community features, advisor workflows, partial admin tools, and text messaging. LiveKit video/audio calling has been permanently discontinued and removed from the Android app. Many features have not been exercised with authenticated test accounts or on a physical Android device. See [PORTING_STATUS.md](PORTING_STATUS.md) for the detailed implemented/unverified inventory.

## Build and test

Open `android/` in Android Studio with JDK 17, or use Gradle 8.10.2:

```sh
cd android
gradle :app:testDebugUnitTest
gradle :app:assembleDebug
```

The debug APK is written to `android/app/build/outputs/apk/debug/app-debug.apk`. The GitHub Actions **Android Debug APK** workflow runs JVM tests and builds this file. The **Android Emulator Smoke** workflow runs guest/navigation instrumentation tests on an API 34 emulator. A green workflow proves those checks passed for its specific commit, **not** that authentication, messaging, uploads, or account deletion work end to end.

## Install a development preview

1. Open the successful **Android Debug APK** workflow run for the exact commit you want to test.
2. Under **Artifacts**, download `edut-android-debug-apk` and extract `app-debug.apk`.
3. On a test Android device, open the APK and permit installation from that source when Android asks. Alternatively, with Android Debug Bridge connected, run `adb install -r app-debug.apk`.
4. Use a disposable test account. Never rely on the preview for real payments, personal records, or account deletion. If installation fails because an existing EduT package is signed with a different key, do **not** uninstall an app with important local data merely to install this preview.

GitHub Actions artifacts expire after 14 days; the artifact for the newest successful commit is the authoritative downloadable CI build. Debug builds are not signed production bundles for Google Play.

## Permanent product scope

LiveKit video/audio calling is discontinued. Do not add call sessions, call rooms, call-token requests, camera/microphone permissions, or LiveKit dependencies. Preserve text messaging, advisor biographies, and advisor YouTube introduction links. The legacy server endpoint is outside the Android release workflow; its deployed state must be assessed separately, without modifying production infrastructure.

## Authenticated parity verification (disposable accounts only)

The green debug-APK and guest emulator workflows are **not** evidence that these flows work.
Use separate disposable student and approved-advisor accounts, plus a disposable account
reserved for deletion. Never use a production person's records or real payments. Record
the APK commit SHA, Android OS/device, account role, steps, expected result, actual result,
and a redacted screenshot/log for every test. Do not paste credentials or access tokens
into issues, screenshots or CI logs.

| Journey | Verification steps | Pass criteria |
| --- | --- | --- |
| Authentication | Sign up, sign in, force-stop/relaunch, refresh an expired session, sign out, request password reset | Correct session restoration and recovery; no private content after sign-out |
| Scholarships | Search, filter, inspect eligibility, save/unsave, compare profile-based matches | Consistent results, correct account-scoped saves and clear match caveats |
| Applications | Update status/notes, tasks/due dates, upload/delete a disposable document | Changes persist after relaunch; no other user's private records are visible |
| Community | Create/edit/delete text post, like/comment/report, publish photo and MP4, interrupt upload | Visibility/RLS respected; no orphaned public posts; interruption and rollback behavior recorded |
| Messaging | Send and receive text between disposable users, refresh/relaunch, block/report where offered | Correct recipient isolation; no audio/video calling entry points |
| Advisors | View biography and YouTube introduction, request consultation, inspect approved-advisor portal, test permitted student/consultation transitions | Role and approval gates respected; status changes match server responses; no call UI |
| Account deletion | Delete the deletion-only disposable account and attempt to sign in again | Server confirms deletion before local credentials are cleared; account cannot authenticate |
| Privacy and permissions | Inspect public Community profile vs private academic profile; inspect installed app permissions | No private GPA/IELTS/income exposure; no camera/microphone/calling permissions |

Repeat critical journeys on a physical Android device. Mark each row **not tested** until
there is actual evidence; distinguish a failed test from an untested feature. Approved-advisor
profile editing and server-side atomic status enforcement cannot be fixed by bypassing
backend authorization in the Android client. Preserve text messaging, advisor biographies
and YouTube links; do not restore LiveKit or any audio/video calling features.

## Required release gates

- Compare student, advisor and administrator screens and navigation with iOS; close remaining visual, accessibility, localization and functional gaps.
- Verify sign-in, session restoration, scholarships, saved applications, messages, Community media, account deletion and advisor workflows using disposable authenticated accounts.
- Verify text messaging, advisor biographies, and advisor YouTube introduction links with authenticated test accounts; do not reintroduce video/audio calling or media permissions.
- Repeat end-to-end checks on at least one physical Android device; then produce a release-signed Android App Bundle and complete Play policy and Data safety reviews.

Do not modify the iOS branch, production backend, or website as part of this Android port. Do not release the already-approved iOS app early just because an Android debug APK compiles.

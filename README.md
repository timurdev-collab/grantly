# Grantly for iOS

A native iPhone app version of Grantly built with SwiftUI and the official Supabase Swift SDK.

## What is included

- Native SwiftUI interface
- Email/password signup and sign-in
- Student profile
- Private academic/financial fields
- Public-safe community profile
- Scholarship directory with 500+ published opportunities
- Profile-based scholarship matching
- Match explanations and blockers
- Saved scholarships
- Student community
- 1-to-1 messaging
- Admin screen for publishing scholarships
- Same Supabase backend and Row Level Security as the Grantly web application

The match percentage is an **eligibility/profile-fit score**, not a prediction of admission.

## Requirements

- macOS
- Xcode 16+ recommended
- iOS 17+ deployment target
- A Supabase project
- XcodeGen (recommended to generate the `.xcodeproj` from `project.yml`)

## 1. Use the same backend as the web app

If you already ran the Grantly web migrations, do not create a second database.

If starting from scratch, run:

1. `Supabase/001_initial.sql`
2. `Supabase/002_seed.sql`

inside the Supabase SQL editor.

## 2. Add Supabase credentials

Edit:

`Grantly/Core/AppConfig.swift`

Replace:

```swift
static let supabaseURL = URL(string: "https://YOUR_PROJECT.supabase.co")!
static let supabasePublishableKey = "YOUR_SUPABASE_PUBLISHABLE_KEY"
```

Use the **publishable key**, never a service-role/secret key in an iOS app.

## 3. Generate the Xcode project

Install XcodeGen once:

```bash
brew install xcodegen
```

Then, inside this folder:

```bash
xcodegen generate
open Grantly.xcodeproj
```

Xcode will resolve the `supabase-swift` Swift Package automatically.

You can also create an iOS App project manually in Xcode and copy the `Grantly` source folder into it, then add `https://github.com/supabase/supabase-swift` with Swift Package Manager.

## 4. Supabase Auth settings

For this starter, email/password authentication is enabled.

Recommended for production:
- Keep email confirmation enabled
- Keep `grantly://login-callback` in the allowed redirect URLs for signup confirmation and password recovery
- Optionally add native Sign in with Apple
- Consider moving from a custom URL scheme to Universal Links before a large public launch

## 5. Run

Choose an iPhone simulator and press **Cmd + R**.

## Admin access

Admin rights are stored in `student_profiles.role`.

After creating your own account, promote it from the Supabase SQL editor:

```sql
update public.student_profiles
set role='admin'
where id=(select id from auth.users where email='YOUR_EMAIL@example.com');
```

Sign out and back in. The Admin Dashboard appears inside Profile.

## Messaging

The app uses the same secured conversations/messages tables as the web platform.

The app loads messages from the database and refreshes:
- when a chat opens
- after sending
- on pull-to-refresh
- every few seconds while the chat is open

The backend is already compatible with Supabase Realtime, so the polling refresh can later be replaced with native realtime subscriptions without changing the database.

## App Store production checklist

Before submitting publicly:

1. Add a proper App Icon and App Store screenshots.
2. Publish Privacy Policy and Terms pages and add their public URLs to App Store Connect.
3. Decide on an under-18 safety model before allowing high-school students to message freely.
4. Add abuse/rate-limit controls around messaging.
5. Add notification permissions only when push notifications are implemented.
6. Add crash/error monitoring.
7. Test Row Level Security policies against unauthorized access.
8. Add accessibility labels and Dynamic Type QA.
9. Configure an Apple Developer Team and production bundle ID.
10. Complete App Privacy answers in App Store Connect based on the data actually collected.
11. Archive in Xcode and distribute through TestFlight before App Store submission.

Already implemented in the app/backend: email confirmation, password recovery, in-app account deletion, reporting, blocking, moderation queue and privacy/safety guidance.

## Important privacy design choice

The app intentionally keeps `student_profiles` and `community_profiles` separate.

Private:
- GPA
- IELTS
- family income
- residence details

Community-visible:
- display name
- nationality
- intended major
- target destinations
- bio

That separation should be preserved.


## Application tracker migration

Existing Supabase projects created before the application tracker was added should run:

```text
Supabase/003_saved_tracker.sql
```

Fresh projects can run `001_initial.sql` directly; it already contains the tracker columns, permissions and RLS policy.

The iOS app uses the custom URL scheme `grantly://login-callback` for Supabase email verification. Add the same URL to Supabase Authentication → URL Configuration → Redirect URLs.


## Password recovery

The iOS app uses the same native deep link as signup confirmation:

```text
grantly://login-callback
```

Keep this URL in Supabase Authentication → URL Configuration → Redirect URLs.

The app stores a local recovery-pending flag after a successful reset-email request. When the user opens the recovery link on the same iPhone, Grantly exchanges the PKCE code for a session and presents the new-password screen.

## Community safety

Grantly includes:
- student and message reporting
- user blocking and unblocking
- server-enforced prevention of new messages between blocked accounts
- an admin safety-report queue
- in-app account deletion
- in-app privacy and community-safety guidance

The production database migrations for these features are in `Supabase/004_security_and_safety.sql` and `Supabase/005_user_blocking.sql`.


## Expanded scholarship catalog

The production catalog currently contains 532 published scholarship records across 60 countries / destination labels and 8 regions.

Catalog records have a source-quality status:
- `verified`: reviewed directly by Grantly against the linked source
- `curated`: imported from a curated dataset and shown with a reminder to verify current details
- `needs_review`: reserved for records that should not be treated as current until reviewed

The 468 catalog expansion records were transformed from the MIT-licensed ScholarFinder Bot scholarship dataset. See `THIRD_PARTY_NOTICES.md`.

For an existing database, run:
- `Supabase/009_catalog_source_metadata.sql`
- `Supabase/010_expand_scholarship_catalog.sql`

The live Grantly Supabase project already contains these changes.

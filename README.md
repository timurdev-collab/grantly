# Grantly for iOS

A native iPhone app version of Grantly built with SwiftUI and the official Supabase Swift SDK.

## What is included

- Native SwiftUI interface
- Email/password signup and sign-in
- Student profile
- Private academic/financial fields
- Public-safe community profile
- Scholarship directory
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
- Add password reset
- Optionally add native Sign in with Apple
- Configure app deep links for email verification/reset flows if you want them to return directly to the app

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

This starter loads messages from the database and refreshes:
- when a chat opens
- after sending
- on pull-to-refresh

The backend is already compatible with Supabase Realtime, so live subscription delivery can be added without changing the database.

## App Store production checklist

Before submitting publicly:

1. Add a proper App Icon and screenshots.
2. Add password reset and account deletion.
3. Add Privacy Policy and Terms.
4. Add reporting, blocking and moderation.
5. Add abuse/rate-limit controls around messaging.
6. Decide on an under-18 safety model before allowing high-school students to message freely.
7. Add notification permissions only when push notifications are implemented.
8. Add crash/error monitoring.
9. Test Row Level Security policies against unauthorized access.
10. Add accessibility labels and Dynamic Type QA.
11. Configure an Apple Developer Team and production bundle ID.
12. Archive in Xcode and upload to App Store Connect / TestFlight.

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

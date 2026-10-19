# EduT Android — Native replica foundation

Development branch: `feature/android-compose-foundation`.

This is the **first Android project scaffold**, NOT a complete Android release. It uses Kotlin + Jetpack Compose and establishes EduT's forest/ivory/sage/gold theme, Home screen foundation and identical five primary tabs: Home, Discover, Applications, Messages, Profile. The other screens are explicitly marked incomplete.

## Build locally
Open the `android/` directory in Android Studio (JDK 17) and allow Gradle to sync. Run the `app` configuration on an Android emulator or a physical device.

## Next phases
1. Compare the actual SwiftUI screens on the iOS implementation branch against each Compose screen; replace foundation placeholders with faithful layouts.
2. Add Supabase Android SDK and environment-aware configuration for staging and production. Never embed a service-role key.
3. Port auth, scholarship discovery and application models/queries, advisor relationships and messaging with server policies intact.
4. Implement account deletion, reporting and moderation flows, deep links, notifications, and test coverage.
5. Produce a signed Android App Bundle, verify Google Play Data safety and content requirements, and run device/Play testing.

This branch does not modify any iOS app file or the existing website.

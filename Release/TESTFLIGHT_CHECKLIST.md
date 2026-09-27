# Grantly Release Readiness

## Automated gates

Every pull request now runs:

- release configuration validation
- XcodeGen project generation
- Swift package resolution
- simulator build
- unit tests

A release should not be tagged unless CI is green.

## Environments

The project supports separate Debug and Release environments through build settings:

- Debug: `APP_ENVIRONMENT=staging`
- Release: `APP_ENVIRONMENT=production`

Both currently point to the existing Supabase project so development remains functional. Before external beta testing, replace the Debug Supabase URL and publishable key with a dedicated staging project. Do not put a service-role key in the iOS app.

## TestFlight checklist

Before the first external TestFlight build:

- create/configure a dedicated staging Supabase project for Debug builds
- configure Apple Push Notification credentials in Supabase Edge Function secrets
- enable leaked-password protection in Supabase Auth
- confirm Sign in / Sign out / password-reset flows on a physical device
- test saving, application tracking, reminders and notifications
- test Community messaging, block and report flows
- test scholarship import, commit and rollback with a small batch
- verify all production cron jobs are active
- confirm PrivacyInfo.xcprivacy is included in the archive
- add/verify the production App Icon asset and launch presentation
- complete App Store privacy disclosures based on actual data collection
- configure App Store Connect app record, screenshots, support URL and privacy-policy URL
- archive with Release configuration and upload to TestFlight

## Versioning

Current release:

- Marketing version: 1.0.0
- Build number: 1

Increase the build number for every TestFlight upload.

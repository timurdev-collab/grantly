# Environment configuration

EduT reads backend configuration from Info.plist values populated by Xcode build settings.

Required values:

- `APP_ENVIRONMENT`
- `SUPABASE_URL`
- `SUPABASE_PUBLISHABLE_KEY`

The publishable key is safe for a client application when database access is protected by RLS. Never add a Supabase service-role key or APNs private key to the iOS target or repository.

For local/staging work, set the Debug values in `project.yml`. Production values belong to the Release configuration.

After editing `project.yml`, regenerate the Xcode project:

```sh
xcodegen generate
```

CI regenerates the project automatically, so `project.yml` is the source of truth for release settings.


## Active Supabase environments

- Staging project ref: `cbzriyarlvpmtfbjgede`
- Staging URL: `https://cbzriyarlvpmtfbjgede.supabase.co`
- Production project ref: `bvcabjwriszghmizbwji`
- Production URL: `https://bvcabjwriszghmizbwji.supabase.co`

Debug builds now use the staging project. Release builds continue to use production.

The staging project has the core schema, seed catalog and deployed Edge Functions for account deletion, scholarship auditing, university media enrichment, APNs dispatch and scholarship imports. Production-only credentials such as APNs private keys must be configured separately in Supabase secrets and are intentionally not stored in this repository.

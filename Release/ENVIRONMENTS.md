# Environment configuration

Grantly reads backend configuration from Info.plist values populated by Xcode build settings.

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

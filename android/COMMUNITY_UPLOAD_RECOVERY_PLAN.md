# Android Community TUS upload recovery — implementation checklist

Status: design only; **not implemented or device-verified**. Scope: Android feature branch only. No backend/schema changes, and no LiveKit or calling functionality.

## Safety invariants

1. Store unfinished upload metadata in app-private, account-scoped storage; never persist access tokens, signed upload URLs in logs, or public post records before Storage confirms completion.
2. Persist the selected video bytes in app-private storage before creating a TUS session. Keep a bounded 200 MiB limit and validate the MP4 signature, as the current uploader does.
3. Persist a session record atomically after the server creates it: authenticated account ID, project origin, opaque upload URL, destination object key, local staged-file identifier, file size, optional checksum, creation/expiry timestamp, media kind, and a random local operation ID. Do not persist caption or private profile fields unless necessary.
4. On relaunch, recover only after an authenticated session is restored and the account ID matches. Never resume across sign-out or account switching; quarantine and delete stale records and staged bytes.
5. Revalidate the upload URL against the configured Supabase Storage origin, expected path and allowed scheme before every HEAD/PATCH. Reject redirects, foreign hosts, expired sessions, malformed offsets and offsets beyond the staged file size.
6. Reconcile offsets using authenticated HEAD; never trust a locally stored offset as the source of truth. If the server session is gone or expired, start a new upload to a fresh private object key and schedule best-effort cleanup of the abandoned key.
7. Keep a single serialized worker per operation ID. A retry must not start a second concurrent upload or publish twice.
8. Before inserting the Community post, persist a durable **upload-complete, publish-pending** state. Publish at most once per operation. After an uncertain insert response, query the signed-in user's posts for the exact private media object key before retrying; do not assume a timeout means failure. If existing schema cannot enforce idempotency atomically, treat this as best-effort and explicitly document the remaining race rather than claiming exactly-once publication.
9. On explicit cancellation, failed publish or account sign-out, attempt authenticated Storage cleanup and delete staged files and local state only after the cleanup outcome is recorded. Never delete a media object already referenced by a successfully published post.
10. Ensure no calling SDKs, call screens, microphone/camera permissions or call-token code enter this workflow. Text messaging, advisor biographies and YouTube introduction links remain unaffected.

## Tests to implement before enabling recovery

- JVM tests: account mismatch, expired/malformed/foreign upload URL, file missing/changed, HEAD 404/410, offset 0/partial/full/greater-than-size, duplicate worker, crash between upload completion and insert, uncertain insert response, failed cleanup, sign-out during transfer.
- Emulator integration: force-stop mid-MP4 transfer; relaunch and resume; retry after network loss; cancel; switch between disposable student and advisor accounts; verify no cross-account content or leaked tokens.
- Authenticated physical-device test: publish a disposable video and story, force-stop mid-upload, relaunch, inspect Storage for orphan objects and Community for duplicate posts. Record commit SHA, device/OS, steps, redacted logs and result.
- CI: run new JVM tests and guest emulator smoke on the exact commit; archive a matching debug APK. A green build is **preview only**, not feature parity.

## Implementation boundary

Prefer a small Android-only state store and coordinator around the existing TUS uploader; preserve current 6 MiB chunks and server HEAD reconciliation. Do not modify the iOS reference, website, Supabase production schema, Edge Functions or RLS. Do not claim process-death recovery or exactly-once publishing until the code and tests demonstrate it.

## Crash-boundary recovery decisions (implementation contract)

| Last durable phase | On authenticated relaunch | Publication safety |
| --- | --- | --- |
| `STAGED` | Validate account and staged bytes; create a fresh TUS session only if the file is intact | No post insertion has begun |
| `SESSION_CREATED` / `UPLOADING` | Validate URL, expiry and object key; use authenticated HEAD to obtain the server offset before PATCH | Do not infer completion from the local offset |
| `UPLOAD_COMPLETE_PUBLISH_PENDING` | Verify the uploaded object exists and belongs to the signed-in account before proceeding | Atomically persist `INSERT_ATTEMPTED` **before** the insert request |
| `INSERT_ATTEMPTED` | Query the current account's posts for the exact media object key; if inconclusive, enter `RECONCILIATION_REQUIRED` | Never automatically issue a second insert |
| `RECONCILIATION_REQUIRED` | Show an explicit unresolved state and retain the media/checkpoint for safe reconciliation | No retry or destructive cleanup without evidence |
| `PUBLISHED` | Verify the post reference before any optional staged-byte cleanup | Never delete referenced remote media |
| `CANCELLED` | Finish recorded best-effort remote cleanup and remove unreferenced staged bytes | Terminal; never resume |

A checkpoint write must be crash-safe (write a temporary file, flush file contents, atomically replace, and where supported synchronize the parent directory so the rename survives sudden power loss) and serialized with the corresponding network operation. Test recovery after process death separately from power-loss durability; atomic rename alone does not prove the latter. Treat persisted TUS URLs as sensitive bearer-capable metadata: restrict them to app-private storage, never expose them in logs or backups, and consider encryption at rest before enabling restoration. Do not assume that a successful local write proves a remote mutation succeeded. If the account is unavailable, keep the operation paused without contacting Storage; after confirmed account mismatch, quarantine and safely discard the old account's local data without using the new account's credentials to delete remote objects. These are design requirements, **not implemented behavior**.

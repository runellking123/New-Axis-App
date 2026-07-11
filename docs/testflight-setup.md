# TestFlight deployment

AXIS ships to TestFlight via GitHub Actions on `macos-15` runners using Fastlane.

## Required GitHub secrets

Add these in **Settings → Secrets and variables → Actions** for `runellking123/New-Axis-App`:

| Secret | Description |
|--------|-------------|
| `APP_STORE_CONNECT_KEY_ID` | App Store Connect API key ID (e.g. `ABCD123456`) |
| `APP_STORE_CONNECT_ISSUER_ID` | Issuer ID from App Store Connect → Users and Access → Integrations |
| `APP_STORE_CONNECT_API_KEY` | Base64-encoded contents of the `.p8` API key file |
| `ANTHROPIC_API_KEY` | *(Optional)* Anthropic API key baked into the build as a fallback |

### Create the App Store Connect API key

1. Open [App Store Connect](https://appstoreconnect.apple.com) → **Users and Access** → **Integrations** → **App Store Connect API**.
2. Generate a key with **App Manager** or **Admin** access.
3. Download the `.p8` file once.
4. Base64-encode it for the secret:

```bash
base64 -i AuthKey_XXXXXXXXXX.p8 | pbcopy
```

Paste the result into `APP_STORE_CONNECT_API_KEY`.

## Trigger a deploy

**Automatic:** Push to `main` (excluding docs-only changes).

**Manual:** Actions → **TestFlight** → **Run workflow**.

Each run sets `CFBundleVersion` to the GitHub run number and uploads to TestFlight for bundle ID `com.runellking.axis`.

## Local release dry run

Requires macOS with Xcode and valid signing credentials:

```bash
export APP_STORE_CONNECT_KEY_ID=...
export APP_STORE_CONNECT_ISSUER_ID=...
export APP_STORE_CONNECT_API_KEY=$(base64 -i AuthKey_XXXX.p8)
bundle install
bundle exec fastlane beta
```

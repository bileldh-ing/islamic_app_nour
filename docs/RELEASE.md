# CI/CD — Noor

## Pipelines
| Workflow | Trigger | What it does |
|---|---|---|
| `ci.yml` | every push to `main` and every PR | `flutter analyze` → unit & widget tests (+coverage) → Android release APK artifact → iOS release build (no codesign) |
| `release.yml` | push a tag `vX.Y.Z` (or run manually) | tests → signed AAB + APK → GitHub Release → Google Play **internal** track (draft) → signed IPA → **TestFlight** |

Each store step runs only when its secrets exist, so the pipeline stays green before you add them.

## Ship a version
```bash
git tag v1.0.0 && git push origin v1.0.0
```

## Secrets (Settings → Secrets and variables → Actions)

### Android / Google Play
| Secret | How to get it |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | `keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload` then `base64 -w0 upload-keystore.jks` |
| `ANDROID_KEYSTORE_PASSWORD` | keystore password |
| `ANDROID_KEY_PASSWORD` | key password |
| `ANDROID_KEY_ALIAS` | `upload` |
| `PLAY_SERVICE_ACCOUNT_JSON` | Play Console → Setup → API access → service account JSON (grant "Release manager"). The app `com.bileldh.noor` must exist in Play Console and the **first** AAB must be uploaded manually once. |

### iOS / App Store Connect
| Secret | How to get it |
|---|---|
| `APPLE_TEAM_ID` | developer.apple.com → Membership |
| `IOS_DIST_CERT_P12_BASE64` | Apple Distribution certificate exported from Keychain as .p12, then `base64 -i cert.p12` |
| `IOS_DIST_CERT_PASSWORD` | password of the .p12 |
| `IOS_PROVISION_PROFILE_BASE64` | App Store provisioning profile for `com.bileldh.noor`, `base64 -i profile.mobileprovision` |
| `APPSTORE_ISSUER_ID` | App Store Connect → Users and Access → Integrations → API keys |
| `APPSTORE_API_KEY_ID` | same page (key with App Manager role) |
| `APPSTORE_API_PRIVATE_KEY` | contents of the downloaded `AuthKey_XXXX.p8` |

Create the app record in App Store Connect with bundle ID `com.bileldh.noor` before the first upload.

## Store checklist
- Bundle/Application ID: `com.bileldh.noor` · Display name: نور
- Permissions declared: location (prayer times & Qibla), notifications + exact alarms (adhan), internet (recitation, translations, map tiles)
- `ITSAppUsesNonExemptEncryption = false` (no export-compliance prompt)
- Privacy: no accounts, no tracking, data stays on device → "Data Not Collected" on both stores
- Exact alarms: on Play, declare the `SCHEDULE_EXACT_ALARM` use as "alarm/clock — prayer-time adhan"
- Screenshots: 6.7" and 6.5" iPhone, Android phone; feature graphic 1024×500 for Play

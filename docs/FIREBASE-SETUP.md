# Firebase Setup Guide — Lab 03 (Android)

Step-by-step to wire this Flutter app to Firebase. Windows-oriented; the app's
Android package is **`com.prm393.journal_trend_analyzer`**. Do these once; then
the code phases (Auth, Storage, FCM, Analytics, Crashlytics, Remote Config) work.

> You run these (they need your Google account + Firebase Console). Everything in
> code (services, ViewModels, screens, Patrol tests) I implement afterward.

---

## 0. Install the CLIs (once)

```powershell
npm install -g firebase-tools          # Firebase CLI (Node is already installed)
dart pub global activate flutterfire_cli
firebase --version
```
Make sure Dart global bin is on PATH so `flutterfire` is found:
`%LOCALAPPDATA%\Pub\Cache\bin` (add to PATH if `flutterfire` is "not recognized").

```powershell
firebase login        # opens browser → sign in with your Google account
```

## 1. Create the Firebase project

- Web: https://console.firebase.google.com → **Add project** → name e.g.
  `prm393-journal-analyzer` → (Analytics: **Enable**) → Create.
- Or CLI: `firebase projects:create prm393-journal-analyzer`

## 2. Connect the Flutter app (auto-registers the Android app)

From the project root (`d:\PRM393\Lab2`):
```powershell
flutterfire configure
```
- Pick your Firebase project.
- Platforms: select **Android** (tick others only if needed).
- It auto-detects the package, **registers the Android app**, downloads
  `android/app/google-services.json`, and generates `lib/firebase_options.dart`.

This also wires the `google-services` Gradle plugin. Verify
`android/app/google-services.json` exists.

## 3. Add the Firebase dependencies (Phase 0.3)

```powershell
flutter pub add firebase_core firebase_auth google_sign_in firebase_storage firebase_messaging firebase_analytics firebase_crashlytics firebase_remote_config pdf printing path_provider
flutter pub add --dev patrol integration_test
flutter pub get
```
In `lib/main.dart` (I'll add this): `await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);` before `runApp`.

## 4. Android build config

- `android/app/build.gradle.kts`: set **`minSdk = 23`** (firebase_auth requires 23).
  If build complains about method count, enable `multiDexEnabled = true`.
- **Crashlytics Gradle plugin** (flutterfire does NOT add this):
  - `android/settings.gradle.kts` plugins block:
    `id("com.google.firebase.crashlytics") version "3.0.2" apply false`
  - `android/app/build.gradle.kts` plugins block:
    `id("com.google.firebase.crashlytics")`
  - (the `com.google.gms.google-services` plugin should already be added by flutterfire)

## 5. Enable Google Sign-In  ← the fiddly one

1. Console → **Authentication** → Get started → **Sign-in method** → enable **Google** → Save.
2. Add the app's **SHA-1** (and SHA-256) fingerprint so Google Sign-In works on Android.
   Get the debug SHA-1:
   ```powershell
   cd d:\PRM393\Lab2\android
   .\gradlew signingReport
   ```
   Copy the **SHA1** under `Variant: debug` (Config: debug). (Alternative:
   `keytool -list -v -keystore "$env:USERPROFILE\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android`)
3. Console → **Project settings** → your Android app → **Add fingerprint** → paste SHA-1 (and SHA-256) → Save.
4. **Re-download** `google-services.json` (Project settings → your app → download) and replace `android/app/google-services.json`, or re-run `flutterfire configure`.

> For a release build later, add the release keystore's SHA-1 too.

## 6. Enable the other services (Console)

| Service | Where | Notes |
|---|---|---|
| **Storage** | Build → Storage → Get started | Start in test mode for dev, or rules allowing authed users. Used for PDF reports. |
| **Cloud Messaging (FCM)** | Engage → Messaging | Enabled with the project. Send a test push from here later. |
| **Analytics** | Already enabled in step 1 | Use **DebugView** to see events while testing. |
| **Crashlytics** | Release & Monitor → Crashlytics → Enable | Needs the Gradle plugin from step 4. |
| **Remote Config** | Engage → Remote Config | Create params: `max_journals` (e.g. 10), `max_keywords` (e.g. 20) → Publish. |

### Enable Analytics DebugView (to capture event evidence for the report)
```powershell
& "D:\Android\Sdk\platform-tools\adb.exe" shell setprop debug.firebase.analytics.app com.prm393.journal_trend_analyzer
```
Then events appear in Console → Analytics → DebugView in near real-time.

## 7. Verify

```powershell
cd d:\PRM393\Lab2
flutter run -d emulator-5554
```
App should start without Firebase init errors. (Real Google Sign-In + FCM push are
best verified on a real device, but emulator works for most.)

---

## What you hand back to me

Once `flutterfire configure` is done and services are enabled, just tell me — the
generated `lib/firebase_options.dart` + `android/app/google-services.json` are
enough for me to implement Auth, Storage, FCM, Analytics, Crashlytics and Remote
Config in code.

## Committing config (note)
`google-services.json` and `firebase_options.dart` contain client API keys (not
secret server keys) and are normally committed so graders can build. Do **not**
commit any service-account JSON (private keys) — none are needed for this lab.

## Troubleshooting
- `flutterfire: not recognized` → add `%LOCALAPPDATA%\Pub\Cache\bin` to PATH.
- Google Sign-In returns `ApiException 10` → SHA-1 missing/incorrect or
  `google-services.json` not re-downloaded after adding SHA-1 (redo step 5.2–5.4).
- Build fails on minSdk → set `minSdk = 23` (step 4).
- Crashlytics not receiving → Gradle plugin missing (step 4) or app not force-closed after the test crash.

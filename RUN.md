# Running Journal Trend Analyzer on Android

This app fetches live data from the OpenAlex API, so the device/emulator needs
an internet connection. No API key or login is required.

## Build artifacts (already produced)

- Debug APK:   `build/app/outputs/flutter-apk/app-debug.apk`
- Release APK: `build/app/outputs/flutter-apk/app-release.apk` (~47 MB)

---

## Option A — Real Android device (recommended for the report)

1. On the phone: **Settings → About phone → tap "Build number" 7×** to enable
   Developer options, then **Settings → Developer options → enable USB debugging**.
2. Connect the phone via USB and accept the "Allow USB debugging?" prompt.
3. Verify it is detected:
   ```bash
   flutter devices
   ```
4. Run in release mode (smooth for the demo video):
   ```bash
   cd Lab2
   flutter run --release
   ```
   …or just install the prebuilt APK:
   ```bash
   flutter install --use-application-binary build/app/outputs/flutter-apk/app-release.apk
   ```
   (or copy `app-release.apk` to the phone and tap to install — allow
   "Install from unknown sources").

## Option B — Android emulator

1. List / create an AVD (needs a system image from Android Studio's SDK Manager):
   ```bash
   flutter emulators
   flutter emulators --create --name pixel
   flutter emulators --launch pixel
   ```
2. Once it boots:
   ```bash
   cd Lab2
   flutter run
   ```

---

## Smoke checklist (matches the acceptance criteria)

Walk through these for the demo video and screenshots:

1. **Search** — type a topic (e.g. `Machine Learning`) → results list shows
   title, year, citations, journal. Try a nonsense topic → empty state.
   Toggle airplane mode briefly → error state + Retry.
2. **Detail** — tap a result → authors, year, journal, citations, **decoded
   abstract**, and a tappable **DOI** link (opens the browser).
3. **Trends tab** — year bar chart, top journals, top authors, top-cited papers.
4. **Dashboard tab** — 6 insight cards (total, avg citations, most active year,
   top journal, top author, most influential paper).

## Suggested screenshots for the PDF report

- Search results (success), empty state, error state
- Publication detail with abstract + DOI
- Trend chart + ranked lists
- Dashboard cards
- AI code-review tool findings (Task 4.4)

> Tip: capture screenshots with `flutter screenshot` while the app runs, or the
> device's native screenshot shortcut.

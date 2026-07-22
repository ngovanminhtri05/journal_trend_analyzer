# Journal Trend Analyzer

A Flutter app (course **PRM393**) that explores research publications using the
free **[OpenAlex](https://openalex.org) API**. Publication data is fetched
**directly from the client** — no backend server to run. **Firebase** adds
sign-in, analytics, crash reporting, cloud report storage, push notifications
and server-tunable settings.

> **Two data planes.** OpenAlex (the papers) needs no setup — it is a public
> API. Firebase (accounts, analytics, config, notifications) needs a project;
> see [Firebase setup](#firebase-setup). The app degrades gracefully: with no
> network the UI shows friendly errors and Retry.

## Architecture

A layered **MVVM** architecture (Model · View · ViewModel) on top of the
**`provider`** package. Views (screens/widgets) hold no business logic — they
only bind to a ViewModel and render its `ViewState`; all fetching, mapping, and
state transitions live in the ViewModel layer.

| Layer | Folder | Responsibility |
|-------|--------|----------------|
| Models | `lib/models/` | Immutable OpenAlex models with manual `fromJson`. |
| Services | `lib/services/` | `OpenAlexService` (HTTP + JSON), typed errors, `BookmarkService`, report/PDF builders, pure `trend_classifier`. |
| Firebase | `lib/firebase/` | Thin wrappers around the Firebase SDKs (Auth · Analytics · Crashlytics · Storage · Messaging · Remote Config). ViewModels depend on these wrappers behind interfaces, never on the SDKs directly. |
| ViewModels | `lib/viewmodels/` | `ChangeNotifier` ViewModels + a shared `ViewState { idle, loading, success, empty, error }`. |
| Screens (Views) | `lib/screens/` | One screen per tab + pushed detail screens; bind to ViewModels only. |
| Widgets | `lib/widgets/` | Reusable UI (cards, charts, badges, filter panel). |
| Utils / Theme | `lib/utils/`, `lib/theme/` | Pure helpers; app theme. |

A single `OpenAlexService` and the Firebase wrappers are created once at the root
([`lib/main.dart`](lib/main.dart)) and injected into the ViewModels. Every Firebase
wrapper sits behind an interface (e.g. `RemoteConfigApi`, `AnalyticsApi`) with a
Firebase-free fake for tests. Charts use **`fl_chart`**; local persistence uses
**`shared_preferences`**.

### Data is always live

Publications, counts, citations and subfields are fetched from OpenAlex at
runtime. The only baked-in values are the **4 Domains / 26 Fields** of the
OpenAlex taxonomy (fixed reference IDs) and the user's own on-device bookmarks.

## Navigation

Bottom `NavigationBar` with 4 tabs — **Home · Journals · Keywords · Profile** —
kept alive by an `IndexedStack`. Publication / Journal / Keyword detail screens
are pushed on top. Signed-out users hit the auth gate first.

- **Home** — a cursor-paginated discovery feed (Rising / Newest sort, free-text
  search, subfield filter, PDF export). Newest is scoped to the journals you follow.
- **Journals** — search publication venues and browse a venue's recent works.
- **Keywords** — publication counts per keyword, with per-keyword detail.
- **Profile** — account, notification center, and the live Remote Config status.

## Feature highlights

- **4-tier taxonomy filter** — cascading Domain → Field → Subfield
  (`/subfields` loaded live, cached) applied across the feed and charts.
- **Compare 2–3 topics** — concurrent `group_by=publication_year`, one multi-line
  chart + comparison table; topics resolve independently.
- **Automatic trend classification** — pure least-squares slope over ~6 years,
  normalized by mean count, shown as a colored badge (Rising / Saturating / Declining).
- **Offline bookmarks** — Publications / Journals / Authors saved in
  `shared_preferences`; a journal/author bookmark doubles as a follow.
- **Export citation** — BibTeX / RIS / APA-7 computed from `Work` fields; single
  or bulk export via the OS share sheet.
- **Citation network** — lazy References / Cited-by lists and an expanding
  citation tree to trace related work and spot research gaps.
- **Firebase layer** — Google Sign-In, Analytics events, Crashlytics, PDF reports
  uploaded to Storage, FCM push + a local Notification Center, and Remote Config
  tunables (`home_page_size`, `max_journals`, `max_keywords`).

## Dependencies

`http`, `provider`, `fl_chart`, `url_launcher`, `google_fonts`,
`shared_preferences`, `share_plus`, `pdf`, `path_provider`,
`flutter_local_notifications`, and the Firebase SDKs (`firebase_core`,
`firebase_auth`, `google_sign_in`, `firebase_analytics`, `firebase_crashlytics`,
`firebase_storage`, `firebase_messaging`, `firebase_remote_config`).

## Setup

### 1. Prerequisites

- **Flutter SDK** 3.41+ (Dart 3.11+) — https://docs.flutter.dev/get-started/install
- **Android toolchain** (Android Studio or SDK + platform-tools) and an emulator
  or a physical device with USB debugging
- **Git** and an internet connection

```bash
flutter doctor          # resolve anything not ticked under Flutter / Android
```

### 2. Get the code and dependencies

```bash
git clone https://github.com/ngovanminhtri05/journal_trend_analyzer.git
cd journal_trend_analyzer
flutter pub get
```

### 3. Firebase setup

This fork ships the author's Firebase client config
(`android/app/google-services.json`, `lib/firebase_options.dart`) — these hold
**client** API keys (not secret server keys), so the app builds and runs as-is
against the author's Firebase project.

To point it at **your own** Firebase project (recommended if you publish), run:

```bash
dart pub global activate flutterfire_cli
flutterfire configure          # regenerates the two config files for your project
```

Then enable the services you use (Auth → Google, Storage, Remote Config, …).
Full step-by-step, including the Google Sign-In SHA-1 gotcha, is in
[`docs/FIREBASE-SETUP.md`](docs/FIREBASE-SETUP.md).

### 4. Run

```bash
flutter emulators --launch <id>   # or start a device from Android Studio
flutter run                       # r = hot reload
```

### 5. Build a release APK (optional)

```bash
flutter build apk --release --split-per-abi
# output: build/app/outputs/flutter-apk/
```

### 6. Verify quality (optional)

```bash
flutter analyze     # expected: No issues found!
flutter test        # unit / widget tests
```

## Configuration knobs

- **OpenAlex polite-pool email** — set once in [`lib/main.dart`](lib/main.dart)
  (`JournalTrendApp.mailto`); change it to your own if you fork. No API key needed.
- **Runtime tunables** — `home_page_size`, `max_journals`, `max_keywords` are read
  from Firebase Remote Config and applied live (no restart). Defaults live in
  [`lib/firebase/remote_config_service.dart`](lib/firebase/remote_config_service.dart).

## Troubleshooting

- **No results / network errors** → no internet or OpenAlex rate-limiting; the
  screen shows a friendly error with **Retry**.
- **Google Sign-In `ApiException 10`** → SHA-1 missing/incorrect; see
  [`docs/FIREBASE-SETUP.md`](docs/FIREBASE-SETUP.md) step 5.
- **Plugin errors after adding a dependency** → stop and re-run `flutter run`
  (hot reload cannot load new native plugins).

## Testing

A full manual test script (UAT) is in
[`docs/UAT-test-flow.md`](docs/UAT-test-flow.md). AI code-review evidence
(CodeRabbit) is in [`docs/coderabbit-review-log.md`](docs/coderabbit-review-log.md).

## License

MIT — see [`LICENSE`](LICENSE).

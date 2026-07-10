# PRM393 Lab 03 — Firebase-Powered Journal Trend Analyzer

**Course:** PRM393 (Cross-Platform Mobile Development, Flutter)
**Student:** _<Full name — StudentID>_
**Repository:** `journal_trend_analyzer` (branch `feat/lab03-firebase`, PR #3)
**Package id:** `com.prm393.journal_trend_analyzer`
**Firebase project:** `journal-analyzer-3c319`

> Draft report (Markdown). Export to PDF and drop the screenshots into the marked
> slots before submission. Screenshots referenced here already exist in the repo
> root (`screen_*.png`, `search_res.png`, `trend_fix*.png`) or should be captured
> from the running app / Firebase console where noted.

---

## 1. Overview

The app analyses academic publication trends for a user-supplied topic using the
public **OpenAlex API**, called **directly from the Flutter client** (no custom
backend). Lab 03 extends the Lab 02 analyzer with a full **Firebase** layer and an
**MVVM** restructure:

- **Google Sign-In** gate (Login → app shell).
- **4-tab navigation**: Home · Journals · Keywords · Profile, plus pushed detail
  screens (Publication / Journal / Keyword).
- **Firebase**: Authentication, Analytics (7 events), Remote Config, Crashlytics,
  Cloud Storage (PDF report upload), Cloud Messaging (push + Notification Center).

All application code and comments are in English. The app runs on the Android
emulator and on a physical Android device; Google Sign-In, sign-out and the
Profile screen were verified on-device.

## 2. Architecture & Design (MVVM)

Mandatory layered structure under `lib/`:

```
models/       immutable data + manual fromJson (Work, Author, Source, GroupByItem, …)
services/     OpenAlexService (the ONLY HTTP client) + pure helpers
              (citation_formatter, trend_classifier, report_builder, …)
firebase/     thin SDK wrappers behind interfaces (see below)
viewmodels/   ChangeNotifier + Provider; one per screen; ViewState enum
screens/      Views only — no business logic
widgets/      reusable UI (charts, cards, state views, LogScreenView)
utils/        pure aggregation helpers
main.dart     composition root (Firebase init + MultiProvider)
```

**Key design principle — every Firebase SDK sits behind an interface**, so
ViewModels/Views depend on abstractions and stay unit-testable:

| Interface | Firebase impl | Test double |
|---|---|---|
| `AuthApi` | `AuthService` (firebase_auth + google_sign_in) | fake stream |
| `AnalyticsApi` | `AnalyticsService` | `NoopAnalytics` / recording fake |
| `RemoteConfigApi` | `RemoteConfigService` | `StaticRemoteConfig` |
| `CrashReporterApi` | `CrashlyticsService` | `NoopCrashReporter` |
| `ReportStorageApi` | `StorageService` | recording fake |
| `MessagingApi` | `MessagingService` | in-memory fake |

State management is **Provider**; every data screen exposes
`loading / success / error / empty` via the shared `ViewState` enum. The single
`OpenAlexService` is reused for all network access — no second HTTP client was
introduced.

_[Screenshot slot: project structure in the IDE.]_

## 3. Implementation Highlights

### 3.1 Authentication (Google Sign-In)
`AuthService` wraps `google_sign_in` v7 (with a cached one-shot `initialize()` to
avoid a double-init race) and `firebase_auth`. `AuthViewModel` mirrors
`authStateChanges` into a simple `AuthStatus`. `AuthGate` routes signed-out users
to `LoginScreen` and signed-in users to the tab shell. The web OAuth client id is
passed as `serverClientId` so Android receives an ID token.

_[Screenshot slots: Login screen; Home after sign-in.]_

### 3.2 Home / Journals / Keywords (live OpenAlex)
Each tab has a ViewModel that fans a topic query out to OpenAlex:

- Home: `Future.wait` over count + three `group_by` aggregations + top-cited →
  a `DashboardSummary` (total, avg citations, most active year, top journal, top
  author, most influential) + the per-year trend chart.
- Journals: `group_by=primary_location.source.id`; detail via
  `filter=primary_location.source.id:<id>`.
- Keywords: `group_by=keywords.id`; detail adds a ranked author list via
  `group_by=authorships.author.id`.

_[Screenshot slots: Home overview; Journals list; Keyword detail with author ranking.]_

### 3.3 Analytics — the 7 required events
Logged the MVVM way (Views/ViewModels call `AnalyticsApi`, never the SDK):

| Event | Parameters | Fired from |
|---|---|---|
| `login` | method=google | `AuthViewModel` |
| `search_topic` | keyword | `HomeViewModel.search` |
| `view_publication` | publication_title, publication_year | detail (via `LogScreenView`) |
| `view_journal` | journal_name | journal detail |
| `view_keyword` | keyword | keyword detail |
| `export_pdf` | topic | `HomeViewModel.exportReport` |
| `logout` | — | `AuthViewModel` |

String params are clipped to Firebase's 100-char limit. `LogScreenView` is a
reusable one-shot "screen view" logger so detail screens stay stateless.

_[Screenshot slot: Firebase Analytics DebugView showing the events.]_

### 3.4 Remote Config
`RemoteConfigService.initialize()` sets in-code defaults (`max_journals=15`,
`max_keywords=20`), `fetchAndActivate()`s the server values, and caches them to
plain ints (so reads never touch the SDK). The two values drive the Journals /
Keywords list lengths and are shown on a Profile "Remote Config" card.

_[Screenshot slots: Remote Config console params; Profile card reflecting them.]_

### 3.5 Crashlytics
Global handlers route `FlutterError.onError` and `PlatformDispatcher.onError` to
Crashlytics. A Profile "Crashlytics" card offers **Log handled error**
(non-fatal `recordError`) and **Force test crash** (`crash()`, behind a confirm
dialog). Required the Crashlytics Gradle plugin (3.0.2) and google-services 4.4.2.

_[Screenshot slots: Crashlytics card; a crash/non-fatal in the console.]_

### 3.6 Storage — PDF report export
`report_builder.dart` renders the overview (metrics table, most-influential paper,
per-year table) to ASCII-safe PDF bytes (built-in Helvetica font).
`HomeViewModel.exportReport` **saves the PDF locally and opens the OS share sheet**
(`share_plus` + `path_provider`) — so the feature works with no backend — and
**best-effort uploads** to `reports/{uid}/<file>.pdf` via `StorageService`,
showing the download URL when Storage is available. Owner-only access is enforced
by `storage.rules` (`allow read, write: if request.auth.uid == uid`).

> **Note:** Firebase now requires the **Blaze** (pay-as-you-go) plan to enable
> Cloud Storage. On the free **Spark** plan the local-save + share path still
> demonstrates the export end to end; the cloud upload lights up automatically
> once Storage is enabled.

_[Screenshot slots: Export button; "Report uploaded" dialog; the file in Storage.]_

### 3.7 Cloud Messaging + Notification Center
`MessagingService` requests permission, exposes the FCM token, maps foreground
`RemoteMessage`s to `AppNotification`, and a top-level background handler is
registered in `main()`. `NotificationsViewModel` persists received notifications
to `shared_preferences` (subscribing only after the persisted list loads, to avoid
a clobber race). The Notification Center lists them and shows/copies the token.

_[Screenshot slots: Notification Center with token; a received push.]_

## 4. API Integration (OpenAlex)

- Base: `https://api.openalex.org/works`, polite pool via `&mailto=`, no API key.
- Search `?search=<kw>&per-page=`; sort `&sort=cited_by_count:desc`.
- Aggregations `&group_by=publication_year | primary_location.source.id |
  authorships.author.id | keywords.id`.
- Abstracts arrive as `abstract_inverted_index` and are reconstructed into text.
- Every call is wrapped in try/catch distinguishing **network / parse / rate-limit**
  errors (typed exceptions), surfaced as retry/error/empty states.

## 5. Trend Results (sample)

_[Screenshot slots: year trend chart for a topic (e.g. "machine learning");
the Dashboard's six insights; the Emerging/Mature/Declining trend badge.]_

Discussion: summarise what the charts show for 1–2 example topics (growth over
time, dominant journals, most-cited paper, trend classification).

## 6. Testing

- **Unit / widget tests:** **117 passing** (`flutter test`) — models, OpenAlex URL
  building + error mapping, providers/ViewModels, analytics wiring, remote config,
  crash reporter demo, PDF builder + export flow, notifications
  (collect/order/clear/persist), Profile UI.
- **Static analysis:** `flutter analyze` clean (0 issues).
- **Patrol E2E:** 11 cases written across 6 files (auth, publication, journal,
  keyword, profile, export). Feature tests bypass the auth gate for determinism;
  auth/export drive the real Google flow.
  - _Known issue:_ `patrol test` fails to **build** on the dev Windows machine with
    `StandardFileSystem only supports file:* URIs` / `Invalid depfile` (bare
    lowercase `d:/` paths) — a patrol_cli 4.4.0 + Flutter 3.41 Windows toolchain
    bug, independent of app code. The suite runs from Android Studio instrumentation
    or a machine without the lowercase-drive path issue.

_[Screenshot slots: `flutter test` all-green; `flutter analyze` clean; Patrol run output.]_

## 7. AI Code Review (CodeRabbit)

PR #3 was reviewed by **CodeRabbit** (`.coderabbit.yaml`, profile ASSERTIVE) —
**15 actionable comments**. Addressed **6 correctness/stability findings** plus a
security response (commit `29ec3c4`):

1. Clip `search_topic` keyword to Firebase's 100-char limit.
2. Fix a TOCTOU race in Google Sign-In init (cache the init `Future`).
3. Log `logout` only after `signOut()` succeeds.
4. Subscribe to FCM messages only after the persisted list loads (no clobber race).
5. `.ignore()` fire-and-forget analytics futures (no unhandled async errors).
6. Correct the `mostActiveYear` doc comment.
7. Added `storage.rules` (owner-only) + wired into `firebase.json`, responding to
   the client-key security notes with real access control.

Acknowledged-but-not-changed items (with reasons) were posted as a PR comment.

_[Screenshot slots: CodeRabbit review summary on PR #3; the resolution comment.]_

## 8. Challenges & Solutions

- **Google Sign-In on Android (ID token):** needed SHA-1 in Firebase and the web
  OAuth client id as `serverClientId`; pulled the refreshed `google-services.json`
  via the Firebase CLI.
- **Crashlytics Gradle plugin:** flutterfire doesn't add it; required plugin 3.0.2
  and bumping google-services to 4.4.2.
- **PDF fonts:** the built-in Helvetica is ASCII-only — non-ASCII values are
  transliterated to keep glyphs from breaking.
- **Testability without Firebase:** every SDK wrapper resolves its `*.instance`
  lazily and hides behind an interface, so unit tests never boot Firebase.
- **Patrol on Windows:** the toolchain path bug above blocks local `patrol test`
  execution; documented with a workaround.

## 9. Lessons Learned

- Interface-first Firebase wrappers make an otherwise hard-to-test integration
  fully unit-testable and keep the MVVM boundary clean.
- Small reusable primitives (`LogScreenView`, `ViewState`) remove a lot of
  repetition across screens.
- Fire-and-forget side effects (analytics, persistence) need explicit error
  handling to avoid unhandled async errors — surfaced by the AI review.

## 10. Deliverables checklist

- [x] Source repo + PR #3 (CodeRabbit reviewed)
- [x] MVVM structure; Provider; live OpenAlex; 4 screens + details
- [x] All 6 Firebase services + 7 analytics events
- [x] 117 unit/widget tests green; analyze clean
- [x] 11 Patrol E2E cases written
- [ ] Screenshots inserted; exported to PDF (5–10 pp)
- [ ] Demo video (5–10 min)
- [ ] Repo renamed `PRM393_Lab03_<StudentID>` (needs StudentID)

## Appendix — grading map

| Criterion | Weight | Evidence |
|---|---:|---|
| Functional | 30% | Home/Journals/Keywords/details on live OpenAlex |
| Firebase | 25% | Auth, Analytics(7), Remote Config, Crashlytics, Storage, FCM |
| MVVM | 10% | models/services/firebase/viewmodels/screens/widgets/utils |
| UI | 10% | 4-tab shell, consistent state views, responsive |
| Patrol | 15% | 11 E2E cases (§6) |
| AI review | 5% | CodeRabbit PR #3, 6 findings fixed (§7) |
| Report | 5% | this document |

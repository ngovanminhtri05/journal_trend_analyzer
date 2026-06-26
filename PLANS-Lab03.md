# Plans — PRM393 Lab 03: Firebase-Powered Journal Trend Analyzer

> **Builds on** Lab 02 (this Flutter app). **Product contract**: this file (Lab 03 delta).
> **Created**: 2026-06-18 · **Reuse**: OpenAlexService, models, fl_chart widgets,
> trend_classifier from Lab 02. **No new HTTP client.**

## Spec delta (vs Lab 02)

Lab 03 changes the product significantly:

- **Auth gate**: app starts at a **Login screen**; Google Sign-In required before the main shell.
- **New 4-tab navigation** (replaces Lab 02's 5 tabs): **Home · Journals · Keywords · Profile** (+ pushed detail screens: Publication / Journal / Keyword).
- **MVVM mandatory**: `models / services / firebase / viewmodels / screens / widgets / utils`; no business logic in Views; Provider (keep) — `state/` ChangeNotifiers become `viewmodels/`.
- **Firebase**: Auth (Google), Storage (PDF reports), FCM (push), Analytics (7 events), Crashlytics, Remote Config.
- **New analysis**: Journals + Journal Detail; Keywords + Keyword Detail (incl. author ranking).
- **Profile**: user info, sign out, notification center, PDF report export→upload, Remote Config demo, Crashlytics demo.
- **Patrol E2E** tests (11 cases) + **AI code review** (CodeRabbit, already configured) + report + demo video.
- Lab 02 extras (Compare / Saved / Citation tree / Export citation / taxonomy filter) are **NOT required** by Lab 03 → keep as optional bonus or move out of the required 4 tabs.

## Risk Gates (need the user / cannot be automated)

- **R1 — Firebase project**: user creates the Firebase project, registers the Android app, runs `flutterfire configure` (produces `google-services.json` + `firebase_options.dart`). Credentials are user-owned.
- **R2 — Google Sign-In**: user adds the app **SHA-1/SHA-256** (debug + release keystore) to Firebase and enables Google as a sign-in provider; needs a real Google account to sign in.
- **R3 — FCM push**: sending a notification needs the Firebase console / a server + a **real device** (emulator works for receive but push from console needs setup).
- **R4 — StudentID**: final repo name `PRM393_Lab03_<StudentID>` — blocked until supplied.
- **R5 — Deliverables**: demo video (5–10 min) and report are manual (I can draft the report).

---

## Phase 0: Project & Firebase setup

| Task | 内容 | DoD | Depends | Status |
|------|------|-----|---------|--------|
| 0.1 | Create Lab 03 working copy (new repo `PRM393_Lab03_<StudentID>` or branch off Lab 02 code) `[tdd:skip:config]` | Repo/branch builds the Lab 02 app as baseline | - | cc:todo |
| 0.2 | **R1** Firebase project + `flutterfire configure` (firebase_core, firebase_options.dart, google-services.json) `[tdd:skip:config]` | `Firebase.initializeApp` succeeds on Android | 0.1 | cc:todo |
| 0.3 | Add deps: firebase_auth, google_sign_in, firebase_storage, firebase_messaging, firebase_analytics, firebase_crashlytics, firebase_remote_config, pdf, printing, path_provider; dev: patrol, integration_test `[tdd:skip:config]` | `flutter pub get` ok; `flutter analyze` clean | 0.2 | cc:todo |
| 0.4 | **R2** Android Gradle: google-services plugin, minSdk≥23, NDK if needed, SHA-1 added in Firebase `[tdd:skip:config]` | Debug build runs with Firebase | 0.2 | cc:todo |

## Phase 1: MVVM refactor

| Task | 内容 | DoD | Depends | Status |
|------|------|-----|---------|--------|
| 1.1 | Restructure to MVVM: rename `state/`→`viewmodels/`, add `firebase/` + `utils/`; keep models/services/screens/widgets; fix barrels/imports `[tdd:skip:refactor]` | `flutter analyze` clean; app builds; existing tests pass | 0.3 | cc:done [a0da8da] |
| 1.2 | Ensure no business logic in Views (move into ViewModels); document MVVM layering in README `[tdd:required]` | A representative ViewModel unit-tested against a mocked service | 1.1 | cc:done [bcffde9] |

## Phase 2: Authentication (Google Sign-In)

| Task | 内容 | DoD | Depends | Status |
|------|------|-----|---------|--------|
| 2.1 | `firebase/auth_service.dart`: signInWithGoogle / signOut / authStateChanges / currentUser `[tdd:required]` | Unit test with mocked FirebaseAuth/GoogleSignIn | 1.1 | cc:todo |
| 2.2 | `AuthViewModel` + **LoginScreen** (Google button, loading/error) `[tdd:skip:ui]` | Tapping sign-in triggers flow; errors shown | 2.1 | cc:todo |
| 2.3 | **R2** Auth gate: signed-out→Login, signed-in→main shell via authStateChanges `[tdd:skip:ui]` | Real Google account signs in → Home; restart keeps session | 2.2 | cc:todo |

## Phase 3: Navigation (4 tabs)

| Task | 内容 | DoD | Depends | Status |
|------|------|-----|---------|--------|
| 3.1 | BottomNavigationBar **Home · Journals · Keywords · Profile**; detail screens pushed `[tdd:skip:ui]` | 4 tabs switch; back-stack works | 2.3 | cc:done [1d830da] |

## Phase 4: Home (overview dashboard)

| Task | 内容 | DoD | Depends | Status |
|------|------|-----|---------|--------|
| 4.1 | `HomeViewModel` + HomeScreen: search topic, trend chart (reuse fl_chart), total pubs, avg citations, most-active year, top author, top journal, most-influential pub; tap pub→detail `[tdd:required]` | All 7 metrics + chart from live data; loading/empty/error | 3.1 | cc:done [1d830da] |

## Phase 5: Publication Detail (reuse Lab 02)

| Task | 内容 | DoD | Depends | Status |
|------|------|-----|---------|--------|
| 5.1 | PublicationDetailScreen: title/authors/year/journal/citations/DOI(link)/abstract `[tdd:skip:ui]` | All fields shown; DOI opens browser | 4.1 | cc:done [1d830da] |

## Phase 6: Journals

| Task | 内容 | DoD | Depends | Status |
|------|------|-----|---------|--------|
| 6.1 | `JournalsViewModel` + JournalsScreen: top journals by count, per-journal stats, contribution chart, citation stats (`group_by=primary_location.source.id`) `[tdd:required]` | Ranked list + chart from live data; tap→detail | 4.1 | cc:done [1d830da] |
| 6.2 | JournalDetailScreen: name, total pubs, total citations, avg citations/pub, related pubs (`filter=primary_location.source.id:`) `[tdd:skip:ui]` | All fields + related list shown | 6.1 | cc:done [1d830da] |

## Phase 7: Keywords

| Task | 内容 | DoD | Depends | Status |
|------|------|-----|---------|--------|
| 7.1 | `KeywordsViewModel` + KeywordsScreen: most frequent + trending keywords, frequency stats, trend chart (`group_by=keywords.id` / concepts) `[tdd:required]` | Keyword list + chart from live data; tap→detail | 4.1 | cc:done [1d830da] |
| 7.2 | KeywordDetailScreen: trends over time, related journals/pubs, **top authors ranked desc** + author chart (`filter=keywords.id:` + `group_by=authorships.author.id`) `[tdd:skip:ui]` | Author ranking correct (desc by count) | 7.1 | cc:done [1d830da] |

## Phase 8: Profile + Firebase demos

| Task | 内容 | DoD | Depends | Status |
|------|------|-----|---------|--------|
| 8.1 | ProfileScreen: profile pic/name/email + Sign Out `[tdd:skip:ui]` | Shows Google user; sign out → Login | 2.3 | cc:todo |
| 8.2 | Notification Center: list FCM-received messages (local store) `[tdd:skip:ui]` | Received notifications listed | 9.3 | cc:todo |
| 8.3 | Report Export: build dashboard PDF (`pdf`) → upload Firebase Storage → show URL `[tdd:skip:ui]` | PDF uploads; download URL shown | 0.3, 4.1 | cc:todo |
| 8.4 | Remote Config demo: fetch+apply ≥2 values (maxJournals, maxKeywords) `[tdd:required]` | Values fetched, displayed, and applied to lists | 9.4 | cc:todo |
| 8.5 | Crashlytics demo: handled-exception + test-crash buttons `[tdd:skip:ui]` | Both appear in Crashlytics console | 9.2 | cc:todo |

## Phase 9: Firebase cross-cutting

| Task | 内容 | DoD | Depends | Status |
|------|------|-----|---------|--------|
| 9.1 | `firebase/analytics_service.dart` + log events: login, search_topic(keyword), view_publication(title,year), view_journal(name), view_keyword(keyword), export_pdf(topic), logout `[tdd:skip:integration]` | All 7 events visible in Analytics DebugView | 1.1 | cc:todo |
| 9.2 | Crashlytics init: FlutterError + PlatformDispatcher.onError handlers in `main` `[tdd:skip:config]` | Forced crash reported to console | 0.2 | cc:todo |
| 9.3 | **R3** FCM: permission + token + foreground/background handlers → Notification Center `[tdd:skip:integration]` | Console push received on device | 0.2 | cc:todo |
| 9.4 | Remote Config: defaults + fetchAndActivate at startup `[tdd:skip:config]` | Config available app-wide | 0.2 | cc:todo |

## Phase 10: Patrol E2E (11 cases)

| Task | 内容 | DoD | Depends | Status |
|------|------|-----|---------|--------|
| 10.1 | Patrol setup (patrol CLI + integration_test + android config) `[tdd:skip:config]` | `patrol test` runs a smoke test | 3.1 | cc:todo |
| 10.2 | TC1 Google Sign-In; TC11 Logout (`authentication_test.dart`) `[tdd:required]` | Sign-in→Home; logout→Login | 10.1, 2.3 | cc:todo |
| 10.3 | TC2 Search; TC3 Publication detail (`publication_test.dart`) `[tdd:required]` | Results shown; detail fields shown | 10.1, 5.1 | cc:todo |
| 10.4 | TC4 Journals nav; TC5 Journal detail (`journal_test.dart`) `[tdd:required]` | Lists/stats shown; detail shown | 10.1, 6.2 | cc:todo |
| 10.5 | TC6 Keywords nav; TC7 Keyword detail (`keyword_test.dart`) `[tdd:required]` | Lists/stats shown; analysis shown | 10.1, 7.2 | cc:todo |
| 10.6 | TC8 Profile nav; TC9 PDF export+upload; TC10 Remote Config (`profile_test.dart`/`export_test.dart`/`remote_config_test.dart`) `[tdd:required]` | Each verifies its screen/result | 10.1, 8.3, 8.4 | cc:todo |

## Phase 11: AI code review

| Task | 内容 | DoD | Depends | Status |
|------|------|-----|---------|--------|
| 11.1 | CodeRabbit review on PR → fix ≥3 findings → document with screenshots `[tdd:skip:review]` | ≥3 findings addressed; evidence captured | Phase 2–9 | cc:todo |

## Phase 12: Deliverables

| Task | 内容 | DoD | Depends | Status |
|------|------|-----|---------|--------|
| 12.1 | Report 5–10 pages (overview, architecture/MVVM, Firebase design, screenshots, analytics events, crashlytics, remote config, patrol results, AI review, challenges, lessons) `[tdd:skip:docs]` | Report covers all rubric sections | Phase 10, 11 | cc:todo |
| 12.2 | **R5** Demo video 5–10 min (all features) `[tdd:skip:docs]` | Video covers the required list | Phase 8–10 | cc:todo |
| 12.3 | **R4** Repo finalize: rename `PRM393_Lab03_<StudentID>`, include firebase config + patrol scripts + assets `[tdd:skip:config]` | Repo matches deliverable structure | all | cc:todo |

---

## Status legend
`cc:todo` not started · `cc:wip` in progress · `cc:done` completed · `blocked` (reason required)

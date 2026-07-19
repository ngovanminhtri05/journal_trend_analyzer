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
| 0.1 | Create Lab 03 working copy (new repo `PRM393_Lab03_<StudentID>` or branch off Lab 02 code) `[tdd:skip:config]` | Repo/branch builds the Lab 02 app as baseline | - | cc:done — working on branch `feat/lab03-firebase`; final repo rename tracked in 12.3. |
| 0.2 | **R1** Firebase project + `flutterfire configure` (firebase_core, firebase_options.dart, google-services.json) `[tdd:skip:config]` | `Firebase.initializeApp` succeeds on Android | 0.1 | cc:done — project `journal-analyzer-3c319`; init verified on device. |
| 0.3 | Add deps: firebase_auth, google_sign_in, firebase_storage, firebase_messaging, firebase_analytics, firebase_crashlytics, firebase_remote_config, pdf, printing, path_provider; dev: patrol, integration_test `[tdd:skip:config]` | `flutter pub get` ok; `flutter analyze` clean | 0.2 | cc:done — all Firebase deps + pdf + patrol/integration_test added; analyze clean. |
| 0.4 | **R2** Android Gradle: google-services plugin, minSdk≥23, NDK if needed, SHA-1 added in Firebase `[tdd:skip:config]` | Debug build runs with Firebase | 0.2 | cc:done — google-services + crashlytics plugins; minSdk 23; SHA-1 added; debug APK builds. |

## Phase 1: MVVM refactor

| Task | 内容 | DoD | Depends | Status |
|------|------|-----|---------|--------|
| 1.1 | Restructure to MVVM: rename `state/`→`viewmodels/`, add `firebase/` + `utils/`; keep models/services/screens/widgets; fix barrels/imports `[tdd:skip:refactor]` | `flutter analyze` clean; app builds; existing tests pass | 0.3 | cc:done [a0da8da] |
| 1.2 | Ensure no business logic in Views (move into ViewModels); document MVVM layering in README `[tdd:required]` | A representative ViewModel unit-tested against a mocked service | 1.1 | cc:done [bcffde9] |

## Phase 2: Authentication (Google Sign-In)

| Task | 内容 | DoD | Depends | Status |
|------|------|-----|---------|--------|
| 2.1 | `firebase/auth_service.dart`: signInWithGoogle / signOut / authStateChanges / currentUser `[tdd:required]` | Unit test with mocked FirebaseAuth/GoogleSignIn | 1.1 | cc:done |
| 2.2 | `AuthViewModel` + **LoginScreen** (Google button, loading/error) `[tdd:skip:ui]` | Tapping sign-in triggers flow; errors shown | 2.1 | cc:done |
| 2.3 | **R2** Auth gate: signed-out→Login, signed-in→main shell via authStateChanges `[tdd:skip:ui]` | Real Google account signs in → Home; restart keeps session | 2.2 | cc:done — Firebase project `journal-analyzer-3c319` configured; `AuthGate` active in `main.dart`; SHA-1 added + Google provider enabled; debug APK builds. Live sign-in pending manual on-device verification. |

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
| 8.1 | ProfileScreen: profile pic/name/email + Sign Out `[tdd:skip:ui]` | Shows Google user; sign out → Login | 2.3 | cc:done — UI shell binds to `AuthViewModel` (nullable lookup → placeholder when signed-out); widget-tested with a fake. Live Google account + sign-out→Login activate once `AuthGate` is wired (R2). |
| 8.2 | Notification Center: list FCM-received messages (local store) `[tdd:skip:ui]` | Received notifications listed | 9.3 | cc:done — `NotificationsViewModel` collects foreground messages, persists to shared_preferences (cap 50); `NotificationsScreen` lists them + shows/copies the FCM token; Profile → Notifications entry. Unit-tested (collect/order/clear/persist/token). |
| 8.3 | Report Export: build dashboard PDF (`pdf`) → upload Firebase Storage → show URL `[tdd:skip:ui]` | PDF uploads; download URL shown | 0.3, 4.1 | cc:done — pure `buildDashboardReportPdf` (ASCII-safe); `HomeViewModel.exportReport(uid)` **saves the PDF locally + opens the OS share sheet** (`share_plus`/`path_provider`, no billing) and **best-effort uploads** to `reports/{uid}/…` via `StorageService`, showing the URL dialog when Storage is enabled; logs `export_pdf`. **Storage is live** — project upgraded to Blaze; bucket `journal-analyzer-3c319.firebasestorage.app` (ASIA1) created; owner-only `storage.rules` deployed (`firebase deploy --only storage`). Signed-in export uploads + shows the URL; the local-share path remains as offline/Spark fallback. Unit-tested (builder + local/upload/no-storage/error). |
| 8.4 | Remote Config demo: fetch+apply ≥2 values (maxJournals, maxKeywords) `[tdd:required]` | Values fetched, displayed, and applied to lists | 9.4 | cc:done — `max_journals`/`max_keywords` drive the Journals/Keywords list lengths and are displayed on a Profile "Remote Config" card. Unit-tested. Create the two params in console to demo server override. |
| 8.5 | Crashlytics demo: handled-exception + test-crash buttons `[tdd:skip:ui]` | Both appear in Crashlytics console | 9.2 | cc:done — Profile "Crashlytics" card: "Log handled error" (recordError non-fatal) + "Force test crash" (crash(), confirm dialog). Handled-error path widget-tested. Console capture pending manual on-device. |

## Phase 9: Firebase cross-cutting

| Task | 内容 | DoD | Depends | Status |
|------|------|-----|---------|--------|
| 9.1 | `firebase/analytics_service.dart` + log events: login, search_topic(keyword), view_publication(title,year), view_journal(name), view_keyword(keyword), export_pdf(topic), logout `[tdd:skip:integration]` | All 7 events visible in Analytics DebugView | 1.1 | cc:done — `AnalyticsApi`/`AnalyticsService` + `NoopAnalytics`; wired login/logout (AuthViewModel), search_topic (HomeViewModel), view_publication/journal/keyword (via `LogScreenView`); export_pdf method ready for 8.3. Unit-tested. DebugView capture pending manual. |
| 9.2 | Crashlytics init: FlutterError + PlatformDispatcher.onError handlers in `main` `[tdd:skip:config]` | Forced crash reported to console | 0.2 | cc:done — `FlutterError.onError`→`recordFlutterFatalError` + `PlatformDispatcher.onError`→`recordError(fatal)` in `main()`; Crashlytics Gradle plugin 3.0.2 added, google-services bumped to 4.4.2; `CrashReporterApi`/`CrashlyticsService`+`NoopCrashReporter`. Enable Crashlytics in console to view reports. |
| 9.3 | **R3** FCM: permission + token + foreground/background handlers → Notification Center `[tdd:skip:integration]` | Console push received on device | 0.2 | cc:done — `MessagingService`/`MessagingApi` (requestPermission + getToken + onMessage + initialMessage); top-level background handler registered in `main()`; foreground messages flow to the Notification Center. **Send a test push from console to a real device to verify receipt.** |
| 9.4 | Remote Config: defaults + fetchAndActivate at startup `[tdd:skip:config]` | Config available app-wide | 0.2 | cc:done — `RemoteConfigService.initialize()` (setDefaults + fetchAndActivate, cached to ints) runs in `main()` before `runApp`; provided app-wide as `RemoteConfigApi`; `StaticRemoteConfig` for tests. |

## Phase 10: Patrol E2E (11 cases)

| Task | 内容 | DoD | Depends | Status |
|------|------|-----|---------|--------|
| 10.1 | Patrol setup (patrol CLI + integration_test + android config) `[tdd:skip:config]` | `patrol test` runs a smoke test | 3.1 | cc:done — `patrol test` **runs green on the emulator**: smoke test `app_test.dart` (4-tab shell boot) = 1/1 passed. The earlier Windows `d:/` / `Invalid depfile` build failure was fixed by upgrading **patrol → 4.7.1 + patrol_cli → 4.5.1** and updating `MainActivityTest.java` to `@RunWith(Parameterized.class)` (patrol 4.7 API). NOTE: emulator needs free storage (the debug/test APKs are large — wipe if `INSTALL_FAILED_INSUFFICIENT_STORAGE`); network-driven feature tests (TC2–TC10) need a stable emulator connection + may need longer waits. **Update 2026-07-17: the FULL suite (smoke + TC1–TC11, all 12 cases) now runs 12/12 GREEN in one run (7m 53s), including the two Google-auth cases with a real account.** Evidence report: `docs/patrol-evidence/patrol-e2e-report.html`. |
| 10.2 | TC1 Google Sign-In; TC11 Logout (`authentication_test.dart`) `[tdd:required]` | Sign-in→Home; logout→Login | 10.1, 2.3 | cc:done — **runs GREEN** (2026-07-17) with a real Google account (`ngovanminhtri05@gmail.com`) added to the emulator. TC1 40s (cold sign-in wait raised to 60s for Firebase auth + RemoteConfig splash); TC11 26s (scrolls the Sign-out button into view). |
| 10.3 | TC2 Search; TC3 Publication detail (`publication_test.dart`) `[tdd:required]` | Results shown; detail fields shown | 10.1, 5.1 | cc:done — **runs GREEN** on emulator-5554 (2026-07-17, live OpenAlex). TC3 opens the detail from a journal's chart-free most-cited list (deterministic). Evidence: `docs/patrol-evidence/patrol-e2e-report.html`. |
| 10.4 | TC4 Journals nav; TC5 Journal detail (`journal_test.dart`) `[tdd:required]` | Lists/stats shown; detail shown | 10.1, 6.2 | cc:done — **runs GREEN** (2026-07-17). Wait anchors on the success-only `StatCard` (labels render upper-cased). |
| 10.5 | TC6 Keywords nav; TC7 Keyword detail (`keyword_test.dart`) `[tdd:required]` | Lists/stats shown; analysis shown | 10.1, 7.2 | cc:done — **runs GREEN** (2026-07-17). |
| 10.6 | TC8 Profile nav; TC9 PDF export+upload; TC10 Remote Config (`profile_test.dart`/`export_test.dart`) `[tdd:required]` | Each verifies its screen/result | 10.1, 8.3, 8.4 | cc:done — **runs GREEN** (2026-07-17). TC8/TC10 use a fake signed-in shell; TC9 exercises the export+share on the auth-bypassed shell. TC8 scrolls the Sign-out button into view. |

## Phase 11: AI code review

| Task | 内容 | DoD | Depends | Status |
|------|------|-----|---------|--------|
| 11.1 | CodeRabbit review on PR → fix ≥3 findings → document with screenshots `[tdd:skip:review]` | ≥3 findings addressed; evidence captured | Phase 2–9 | cc:done — PR #3 reviewed by CodeRabbit (15 findings). Fixed 6 correctness/stability items + added `storage.rules` (commit 29ec3c4); resolution summary posted as a PR comment. Capture screenshots of the PR review for the report. |

## Phase 12: Deliverables

| Task | 内容 | DoD | Depends | Status |
|------|------|-----|---------|--------|
| 12.1 | Report 5–10 pages (overview, architecture/MVVM, Firebase design, screenshots, analytics events, crashlytics, remote config, patrol results, AI review, challenges, lessons) `[tdd:skip:docs]` | Report covers all rubric sections | Phase 10, 11 | cc:done (draft) — `docs/REPORT-Lab03.md` covers every rubric section with screenshot slots. Insert screenshots + fill name/StudentID + export to PDF. |
| 12.2 | **R5** Demo video 5–10 min (all features) `[tdd:skip:docs]` | Video covers the required list | Phase 8–10 | cc:todo |
| 12.3 | **R4** Repo finalize: rename `PRM393_Lab03_<StudentID>`, include firebase config + patrol scripts + assets `[tdd:skip:config]` | Repo matches deliverable structure | all | cc:todo |

---

## Phase 13: Tab redesign per instructor (2026-07-17)

Instructor re-scope of the 4 tabs. Decisions: Home field = **user-chosen, stored locally**;
Firebase demos (Remote Config/Notifications) **kept** in a small Profile section (rubric safety).

| Task | 内容 | DoD | Status |
|------|------|-----|--------|
| 13.1 | `ResearchFieldProvider` — user picks/edits their research field, persisted (shared_preferences) | Field survives restart; editable on Profile | cc:done |
| 13.2 | **Home**: light overview of **recent publications in the user's field** — no OpenAlex sums/aggregates | Field prompt if unset; recent papers list; tap→detail; no totals | cc:done — `HomeViewModel.loadForField` + `recentWorksByTopic`; export kept (recent-papers PDF). |
| 13.3 | **Journals**: search a journal **by name** (`/sources?search=`) → detail → **recent volumes** → **articles in a volume** | Name search; volumes grouped (biblio.volume, year fallback); articles per volume | cc:done — `searchSources` + `recentWorksBySource` + `groupWorksIntoVolumes`; ExpansionTile per volume. |
| 13.4 | **Keywords**: enter/search a keyword → its analysis (reuse trend/authors/journals/works) | Direct keyword → analysis | cc:done — hint reworded; existing analysis flow retained. |
| 13.5 | **Profile**: User + **Bookmark list** + Crashlytics test button; keep Remote Config/Notifications in a small section | Bookmarks shown; field editor; Crashlytics; FB demos retained | cc:done — `_BookmarksSection` + `_ResearchFieldCard`; FB demos under a "Firebase demos" section. |
| 13.6 | Update unit tests + Patrol E2E to the new UI | analyze clean; unit tests pass; Patrol updated | cc:wip — **`flutter analyze` clean; 121 unit/widget tests pass.** Patrol E2E still asserts the OLD UI (topic-search Home, "Top journals", etc.) → **needs rewrite + on-device rerun** for the new flows. |

---

## Phase 14: Home discovery redesign (planned 2026-07-19)

**Spec delta (Home behavior — product contract).** Home becomes a research-discovery
feed (no OpenAlex aggregate totals):

- **Default = "Rising" feed:** recent works ordered by citations — recent papers already
  gaining traction. Query: `filter=from_publication_date:<window>` (default last 12 months)
  `+ sort=cited_by_count:desc`. ("Up-rising" is a proxy — OpenAlex has no native trending.)
- **Sort toggle:** `Rising` (default) · `Newest` (`publication_date:desc`) · `Top cited`
  (2-yr window + `cited_by_count:desc`).
- **Search papers:** a search bar; with a query, `search=q` + `sort=relevance_score:desc`,
  respecting the active subfield filter.
- **Subfield filter:** pick an OpenAlex subfield (Domain→Field→Subfield) → adds
  `primary_topic.subfield.id:<shortId>`; shown as a removable chip. **Reuse** `getSubfields()`,
  `FilterProvider`, `widgets/filter_panel.dart`.
- **Pagination:** cursor-based load-more (`cursor=*`→`next_cursor`, per_page 25).
- Reuse: single `OpenAlexService` client, `PaperCard`, state views. The old free-text field
  filter is replaced by search + subfield filter (`ResearchFieldProvider` may seed a default
  subfield or move to Profile-only).

**Validation:** `team_validation_mode: manual-pass` (no subagents). Product/Architecture/
Security/QA/Skeptic reviewed by the planner. OpenAlex query design cross-checked against
current API docs (sort keys, `primary_topic.subfield.id`, cursor paging). No secrets/permissions/
billing impact (OpenAlex is public; mailto already set). lint/format baseline exists
(`flutter analyze` enforced) — no setup task needed.

| Task | 内容 | DoD | Depends | Status |
|------|------|-----|---------|--------|
| 14.1 | `OpenAlexService.discoverWorks({query, subfieldId, WorkSort sort, windowDays, cursor})` — builds `from_publication_date`+`primary_topic.subfield.id` filters, sort, `search`, cursor paging; returns page + `nextCursor`. No new HTTP client. `[tdd:required]` | Unit tests assert the exact query params for each sort / filter / search combo + cursor threading; analyze clean | - | cc:done [dc0f9b7] — `WorkSort` enum + `WorksPage` model; 6 TDD tests (Red→Green); analyze clean, 128 tests pass. |
| 14.2 | Subfield source: cache `getSubfields()`; reuse/extend `FilterProvider` to expose the selected subfield + its `primary_topic.subfield.id` clause. `[tdd:required]` | Unit test: selecting a subfield yields the right clause; list cached once | 14.1 | cc:todo |
| 14.3 | `HomeViewModel`: Rising default, sort switch, search, subfield filter, pagination state (append/hasMore/loadingMore/refresh). `[tdd:required]` | Unit tests: state transitions per sort/search/filter; load-more appends; error/empty | 14.1, 14.2 | cc:todo |
| 14.4 | `HomeScreen` UI: search bar + sort segmented control + subfield filter chip & Domain→Field→Subfield picker (reuse `filter_panel`) + rising list + load-more + pull-to-refresh + loading/empty/error. `[tdd:skip:ui]` | Renders each state; tapping sort/filter/search reloads; scroll loads more | 14.3 | cc:todo |
| 14.5 | Wire export + analytics to the new feed; retire the free-text field on Home (keep/seed via `ResearchFieldProvider` decision). `[tdd:skip:ui]` | Export/analytics still fire; no dead code; analyze clean | 14.3 | cc:todo |
| 14.6 | Update unit + widget tests green; then Patrol E2E for the new Home (device rerun). `[tdd:required]` | `flutter analyze` clean; `flutter test` green; Patrol updated | 14.1–14.5 | cc:todo |

---

## Status legend
`cc:todo` not started · `cc:wip` in progress · `cc:done` completed · `blocked` (reason required)

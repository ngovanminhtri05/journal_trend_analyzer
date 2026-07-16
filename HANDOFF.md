# HANDOFF — PRM393 Journal Trend Analyzer (Lab 03 in progress)

Paste this into a fresh Claude Code session to continue work. It is the single
source of context: project state, decisions, architecture, environment, and next
steps.

> **Refreshed**: 2026-07-08 · **Branch**: `feat/lab03-firebase` · **Updated by**: Claude Code

---

## 1. What this is

A **Flutter** app (course PRM393) that analyzes research-publication trends using
the **OpenAlex API**, called **directly from the client (no backend)**.

- Code lives in **`d:\PRM393\Lab2`** (this is the Flutter project root — the git
  repo is `Lab2/`, NOT the outer `d:\PRM393` harness folder).
- Git repo: **`journal_trend_analyzer`** (GitHub: `ngovanminhtri05/journal_trend_analyzer`).
- **Lab 02 is DONE and merged to `main`** (FR-1…FR-15). Lab 03 work is on branch
  **`feat/lab03-firebase`** (current branch).

## 2. Current status (what changed since the last handoff)

Lab 03 is **no longer "not started"** — most non-Firebase phases are done and
committed, and Phase 2 (auth) is written but **not yet committed**.

- **Lab 02 shipped** (`main`): Search, Publication detail, Trends, Dashboard, plus
  extras — taxonomy filter (FR-13), Compare topics (FR-8), trend badge (FR-9),
  offline bookmarks (FR-10), citation export BibTeX/RIS/APA (FR-14), citation
  network/tree/research-gap (FR-15). Release APK builds; CodeRabbit review done.
- **Lab 03 committed so far** (see `PLANS-Lab03.md` for the task grid):
  - **Phase 1 MVVM refactor** — `state/` → `viewmodels/`, added `firebase/` +
    `utils/`; README documents the layering. `[a0da8da, bcffde9]` ✅
  - **Phase 3 nav** — 4-tab `BottomNavigationBar` Home · Journals · Keywords ·
    Profile. `[1d830da]` ✅
  - **Phase 4 Home**, **Phase 5 Publication detail (reuse)**, **Phase 6
    Journals + Journal detail**, **Phase 7 Keywords + Keyword detail** — all live
    OpenAlex, ViewModels + widgets. `[1d830da]` ✅
  - **Phase 2 Google Sign-In** — `AuthApi`/`AuthService` (google_sign_in v7,
    lazy `FirebaseAuth`), `AppUser`, `AuthViewModel`, `LoginScreen`, `AuthGate`
    + unit tests (mocktail). `[commit "feat: Lab 03 Google Sign-In auth ..."]` ✅
    (2.1/2.2 done; 2.3 blocked on Firebase — see AuthGate note below.)
  - **Phase 8.1 Profile screen** — binds to `AuthViewModel` (nullable Provider
    lookup → placeholder when signed-out), shows account photo/name/email/uid +
    Sign Out; 3 widget tests. `[commit "feat: Lab 03 Profile screen (8.1) ..."]` ✅
- **`AuthGate` is written but NOT activated** — `main.dart` still shows the main
  shell (`HomeShell`) directly, so the app runs today without Firebase and the
  Profile tab shows its signed-out placeholder. Activating the gate is blocked on
  Firebase config (R1/R2 below): once `firebase_options.dart` exists, add
  `await Firebase.initializeApp(...)` in `main()` and swap `home:` to
  `const AuthGate()` per the comment at `lib/main.dart:73`. That single switch
  makes the Profile tab show the real Google account and the working sign-out.
- **Not started (all Firebase-blocked or manual)**: Phase 8.2–8.5 (Notification
  Center, PDF export→Storage, Remote Config demo, Crashlytics demo), Phase 9
  (Analytics / Crashlytics / FCM / Remote Config cross-cutting), Phase 10 (Patrol
  E2E, 11 cases), Phase 11 (CodeRabbit on the Lab 03 PR), Phase 12 (report + demo
  video + repo rename).

**Verified 2026-07-08** (everything above committed): `flutter pub get` ok ·
`flutter analyze` → **No issues found!** · `flutter test` → **all 98 tests passed**
(95 prior + 3 new Profile widget tests). Working tree is clean.

**First actions in the new session:**
1. `git status` — confirm branch `feat/lab03-firebase`, clean tree.
2. Everything not blocked on Firebase is done. To make progress you now need the
   user's Firebase config (R1/R2) — then activate `AuthGate` (one-line switch
   above) and tackle Phase 9 → the rest of Phase 8 → Phase 10 Patrol → Phase 11
   CodeRabbit → Phase 12 deliverables. Ask the user whether Firebase is configured
   before starting those.

## 3. Decisions already made (do not re-litigate)

1. **Navigation/scope**: Lab 03's required **4 tabs — Home · Journals · Keywords ·
   Profile** (+ Login + pushed detail screens). Lab 02 extras
   (Compare/Saved/Citation tree/Export citation/taxonomy filter) are **bonus**,
   not part of the required 4 tabs. Reuse Lab 02 internals.
2. **Repo**: work on branch **`feat/lab03-firebase`** of the current repo (NOT a
   new repo yet). Final submission repo `PRM393_Lab03_<StudentID>` later (StudentID unknown).
3. **Firebase**: the **user creates the Firebase project themselves** (following
   `docs/FIREBASE-SETUP.md`). Do NOT try to create it. When the user reports
   `lib/firebase_options.dart` + `android/app/google-services.json` exist, wire the
   Firebase code and activate `AuthGate`.

## 4. Lab 03 requirements (from the assignment PDF)

- Firebase: **Auth (Google Sign-In), Storage (PDF reports), FCM (push),
  Analytics, Crashlytics, Remote Config**.
- **MVVM** mandatory: `models / services / firebase / viewmodels / screens /
  widgets / utils`; no business logic in Views; state via **Provider**.
- 7 Analytics events: `login`, `search_topic{keyword}`,
  `view_publication{publication_title,publication_year}`, `view_journal{journal_name}`,
  `view_keyword{keyword}`, `export_pdf{topic}`, `logout`.
- Screens: Login, Home (overview dashboard), Publication Detail, Journals,
  Journal Detail, Keywords, Keyword Detail, Profile.
- **Patrol** E2E tests (11 cases). **AI code review** (CodeRabbit, already
  configured). Report (5–10 pp) + demo video (5–10 min).
- Grading: Functional 30% · Firebase 25% · MVVM 10% · UI 10% · Patrol 15% ·
  AI review 5% · Report 5%.

## 5. Where to resume (next actions, in order)

1. **Commit Phase 2 auth** (see §2) once analyze + tests are green.
2. **Phase 8.1 Profile screen** (profile pic/name/email + Sign Out) — the UI shell
   can be built now against `AuthViewModel`; the live user only populates once
   Firebase is configured.
3. **When the user confirms Firebase is configured** (R1/R2 done): activate
   `AuthGate` in `main.dart`, then do **Phase 9** (Analytics → Crashlytics →
   Remote Config → FCM), then the rest of **Phase 8** (8.2 Notification Center,
   8.3 PDF export→Storage, 8.4 Remote Config demo, 8.5 Crashlytics demo).
4. **Phase 10 Patrol** E2E (11 cases), **Phase 11 CodeRabbit** on the Lab 03 PR,
   **Phase 12** report/video/repo rename.

Drive via harness: `/harness-work <task-id>` (e.g. `/harness-work 8.1`) or
`/harness-work all` for the non-blocked tasks. Tasks are in `PLANS-Lab03.md`.

## 6. Architecture & conventions

- **Structure** (`lib/`): `models/` (immutable + manual `fromJson`), `services/`
  (`OpenAlexService` = the ONLY HTTP layer; `bookmark_service`,
  `citation_formatter`, `trend_classifier`, `research_gap`, `abstract_decoder`),
  `firebase/` (SDK wrappers — `auth_service`, `app_user`; ViewModels depend on
  these, never on the Firebase SDK directly), `viewmodels/` (ChangeNotifier +
  Provider; was `state/` pre-refactor), `screens/`, `widgets/`, `utils/`,
  `theme/`. Each layer has a barrel file (`models.dart`, `services.dart`, etc.).
- **Reuse, don't rewrite**: keep `OpenAlexService` and add methods; **never write
  a new HTTP client**. Reuse fl_chart widgets, `trend_classifier`, models.
- **Conventions**: Flutter 3.41 / Dart 3.11; **Provider**; **code + comments in
  English**; every change keeps **`flutter analyze` clean**; add **unit tests**
  for pure logic/services/viewmodels (`mocktail` for mocks); run **`flutter test`**.
- OpenAlex patterns already used:
  - search: `/works?search=<kw>&per-page=`
  - per-year: `&group_by=publication_year`
  - journals: `&group_by=primary_location.source.id`; per-journal: `&filter=primary_location.source.id:<id>`
  - authors: `&group_by=authorships.author.id`
  - keywords: `&group_by=keywords.id` (and `&filter=keywords.id:<id>`)
  - references: `&filter=openalex:W1|W2|...` (OR, chunk ≤50); cited-by: `&filter=cites:<Wid>`
  - polite pool: `&mailto=` (set in `lib/main.dart` `JournalTrendApp.mailto`); no API key.

## 7. Risk gates (need the user)

- **R1** Firebase project + `google-services.json` + `firebase_options.dart` (user runs `flutterfire configure`).
- **R2** Google Sign-In **SHA-1** added to Firebase (`cd android && .\gradlew signingReport`); re-download `google-services.json`. **AuthGate activation blocks on R1+R2.**
- **R3** FCM push send needs Firebase Console + ideally a real device.
- **R4** **StudentID** for the final repo name `PRM393_Lab03_<StudentID>`.
- **R5** Demo video + report are manual (report can be drafted in-session).

## 8. Environment & tooling gotchas (Windows)

- Flutter SDK: `D:\flutter` (3.41.9). Android SDK: **`D:\Android\Sdk`** (adb at
  `D:\Android\Sdk\platform-tools\adb.exe`, emulator at
  `D:\Android\Sdk\emulator\emulator.exe`). `adb` is NOT on PATH — use full path.
- Emulator AVD: **`prm393_pixel`** (also `Pixel_7`). **Black screen with hardware
  GPU** — launch with software GPU:
  `& "D:\Android\Sdk\emulator\emulator.exe" -avd prm393_pixel -gpu swiftshader_indirect -no-snapshot-load`.
  Device shows **offline** → `adb kill-server; adb start-server`.
- App package id: **`com.prm393.journal_trend_analyzer`**.
- **PowerShell git commit**: multi-line `-m` here-strings get mangled and
  `Out-File -Encoding utf8` adds a BOM. Write the message with
  `[System.IO.File]::WriteAllText($path,$body)` then `git commit -F $path`. Do NOT
  put `Remove-Item` of the temp file in the same block (sandbox blocks it and
  aborts the whole command). `LF will be replaced by CRLF` warnings are harmless.
- Build APK: `flutter build apk --release` → `build/app/outputs/flutter-apk/app-release.apk` (also copied to `dist/`; `dist/` and `*.apk` are gitignored).
- Useful docs in repo: `README.md` (A–Z setup), `docs/UAT-test-flow.md`,
  `docs/coderabbit-review-log.md`, `docs/FIREBASE-SETUP.md`, `PLANS-Lab03.md`,
  `AI_CODE_REVIEW.md`, `REPORT.md`.

## 9. Git workflow

- Current branch: `feat/lab03-firebase` (off `main`). Commit Lab 03 work here.
- Conventional Commits (`feat:`/`fix:`/`docs:`/`refactor:`/`test:`/`chore:`).
- Open a PR to `main` when ready; CodeRabbit auto-reviews (installed; `.coderabbit.yaml`, profile ASSERTIVE).
- Do not commit Firebase service-account private keys (none needed);
  `google-services.json` / `firebase_options.dart` (client keys) are OK to commit.

---

**First thing in the new session:** read `PLANS-Lab03.md`, confirm you are on
branch `feat/lab03-firebase`, run `flutter pub get && flutter analyze && flutter
test`, then **commit the uncommitted Phase 2 auth work** (§2) before moving to
Phase 8.1. Firebase-dependent phases wait for the user's config (R1/R2).

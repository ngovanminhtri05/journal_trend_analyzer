# HANDOFF — PRM393 Journal Trend Analyzer (Lab 03 in progress)

Paste this into a fresh Claude Code session to continue work. It is the single
source of context: project state, decisions, architecture, environment, and next
steps.

---

## 1. What this is

A **Flutter** app (course PRM393) that analyzes research-publication trends using
the **OpenAlex API**, called **directly from the client (no backend)**.

- Code lives in **`d:\PRM393\Lab2`** (this is the Flutter project root).
- Git repo: **`journal_trend_analyzer`** (GitHub: `ngovanminhtri05/journal_trend_analyzer`).
- **Lab 02 is DONE and merged to `main`** (features FR-1…FR-15). Lab 03 work is on
  branch **`feat/lab03-firebase`** (current branch).

## 2. Current status

- **Lab 02 shipped** (on `main`): Search, Publication detail, Trends, Dashboard,
  plus extras — taxonomy filter (FR-13), Compare topics (FR-8), trend
  classification badge (FR-9), offline bookmarks (FR-10), citation export
  BibTeX/RIS/APA (FR-14), citation network + tree + research-gap (FR-15).
  `flutter analyze` clean, `flutter test` green (~68 tests), release APK builds,
  CodeRabbit AI review was run and findings fixed.
- **Lab 03 = Firebase enhancement** — planning done, implementation not started.
  - Full plan: **`PLANS-Lab03.md`** (13 phases, DoD/Depends/TDD tags).
  - Firebase setup guide for the user: **`docs/FIREBASE-SETUP.md`**.

## 3. Decisions already made (do not re-litigate)

1. **Navigation/scope**: follow Lab 03's required **4 tabs — Home · Journals ·
   Keywords · Profile** (+ Login screen + pushed detail screens). Lab 02 extras
   (Compare/Saved/Citation tree/Export citation/taxonomy filter) are **bonus**,
   not part of the required 4 tabs. Reuse Lab 02 internals.
2. **Repo**: work on branch **`feat/lab03-firebase`** of the current repo (NOT a
   new repo yet). Final submission repo `PRM393_Lab03_<StudentID>` later (StudentID unknown).
3. **Firebase**: the **user creates the Firebase project themselves** (following
   `docs/FIREBASE-SETUP.md`). Do NOT try to create it. When the user reports
   `lib/firebase_options.dart` + `android/app/google-services.json` exist, wire
   the Firebase code.

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

## 5. Where to resume (next actions)

Firebase-dependent phases wait for the user's config. **Start with the parts that
need NO Firebase credentials:**

1. **Phase 1 — MVVM refactor**: rename `lib/state/` → `lib/viewmodels/`, add
   `lib/firebase/` and `lib/utils/`; keep models/services/screens/widgets; fix
   barrels/imports; `flutter analyze` clean; tests pass.
2. **Phase 3** nav (4 tabs) + **Phase 4/6/7** Home/Journals/Keywords on OpenAlex
   (ViewModels + unit tests).
3. When the user confirms Firebase is configured → **Phase 2/8/9** (Auth, Profile
   demos, Analytics/Crashlytics/FCM/Remote Config), then **Phase 10** Patrol,
   **Phase 11** CodeRabbit, **Phase 12** report/video.

To drive via harness: `/harness-work 1.1` (or `/harness-work all` for the
non-blocked phases). Plan tasks are in `PLANS-Lab03.md`.

## 6. Architecture & conventions

- **Current structure** (`lib/`): `models/` (immutable + manual `fromJson`),
  `services/` (`OpenAlexService` = the ONLY HTTP layer; `bookmark_service`,
  `citation_formatter`, `trend_classifier`, `research_gap`, `abstract_decoder`),
  `state/` (ChangeNotifier providers — to become `viewmodels/`), `screens/`,
  `widgets/`, `theme/`. Each layer has a barrel file.
- **Reuse, don't rewrite**: keep `OpenAlexService` and add methods; **never write
  a new HTTP client**. Reuse fl_chart widgets, `trend_classifier`, models.
- **Conventions**: Flutter 3.41 / Dart 3.11; **Provider**; **code + comments in
  English**; every change must keep **`flutter analyze` clean**; add **unit tests**
  for pure logic/services/viewmodels; run **`flutter test`**.
- OpenAlex patterns already used (for Journals/Keywords):
  - search: `/works?search=<kw>&per-page=`
  - per-year: `&group_by=publication_year`
  - journals: `&group_by=primary_location.source.id` ; per-journal: `&filter=primary_location.source.id:<id>`
  - authors: `&group_by=authorships.author.id`
  - keywords: `&group_by=keywords.id` (and `&filter=keywords.id:<id>`)
  - references: `&filter=openalex:W1|W2|...` (OR, chunk ≤50) ; cited-by: `&filter=cites:<Wid>`
  - polite pool: `&mailto=` (set in `lib/main.dart` `JournalTrendApp.mailto`); no API key.

## 7. Risk gates (need the user)

- Firebase project + `google-services.json` + `firebase_options.dart` (user runs `flutterfire configure`).
- Google Sign-In **SHA-1** added to Firebase (`cd android && .\gradlew signingReport`); re-download `google-services.json`.
- FCM push send needs Firebase Console + ideally a real device.
- **StudentID** for the final repo name `PRM393_Lab03_<StudentID>`.
- Demo video + report are manual (report can be drafted in-session).

## 8. Environment & tooling gotchas (Windows)

- Flutter SDK: `D:\flutter` (3.41.9). Android SDK: **`D:\Android\Sdk`** (adb at
  `D:\Android\Sdk\platform-tools\adb.exe`, emulator at `D:\Android\Sdk\emulator\emulator.exe`). `adb` is NOT on PATH — use full path.
- Emulator AVD: **`prm393_pixel`** (also `Pixel_7`). It shows a **black screen with
  hardware GPU** — launch with software GPU:
  `& "D:\Android\Sdk\emulator\emulator.exe" -avd prm393_pixel -gpu swiftshader_indirect -no-snapshot-load`.
  If a device shows **offline**: `adb kill-server; adb start-server`.
- App package id: **`com.prm393.journal_trend_analyzer`**.
- **PowerShell git commit**: multi-line `-m` here-strings get mangled and
  `Out-File -Encoding utf8` adds a BOM. Use a message file written with
  `[System.IO.File]::WriteAllText($path,$body)` then `git commit -F $path`.
  Do NOT put `Remove-Item` of a temp file in the same block (sandbox blocks it and
  aborts the whole command). `LF will be replaced by CRLF` warnings are harmless.
- Build APK: `flutter build apk --release` → `build/app/outputs/flutter-apk/app-release.apk` (also copied to `dist/`; `dist/` and `*.apk` are gitignored).
- Useful docs already in repo: `README.md` (A–Z setup), `docs/UAT-test-flow.md`
  (manual test script), `docs/coderabbit-review-log.md` (AI-review evidence),
  `docs/FIREBASE-SETUP.md`, `PLANS-Lab03.md`.

## 9. Git workflow

- Current branch: `feat/lab03-firebase` (off `main`). Commit Lab 03 work here.
- Conventional Commits (`feat:`/`fix:`/`docs:`/`refactor:`/`test:`/`chore:`).
- Open a PR to `main` when ready; CodeRabbit auto-reviews (it is installed and was
  used in Lab 02 — there's a `.coderabbit.yaml`, profile ASSERTIVE).
- Do not commit Firebase service-account private keys (none are needed);
  `google-services.json` / `firebase_options.dart` (client keys) are OK to commit.

---

**First thing to do in the new session:** read `PLANS-Lab03.md`, confirm you are
on branch `feat/lab03-firebase`, then start **Phase 1 (MVVM refactor)** unless the
user says Firebase is already configured.

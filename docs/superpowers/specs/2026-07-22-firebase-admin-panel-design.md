# Design — In-App Firebase Admin Panel (+ Patrol stabilization)

> **Created**: 2026-07-22 · **Branch**: `Assignment-branch` · **Builds on**: Lab 03 (MVVM +
> Firebase, merged to `main`). **Product contract**: this file (delta on top of
> `PLANS-Lab03.md`).

## 1. Goal

Let the app's admin manage the Firebase-backed parts of the product **from the app itself**
instead of opening the Firebase console: users, Remote Config, uploaded reports (Storage),
and a live feed of crash/analytics events. Secondary streams bundled into this same work of
work: stabilize the flaky Patrol E2E cases, and opportunistic bug fixes/cleanup encountered
along the way (not a full separate audit).

## 2. Constraint that shapes everything

The app currently has **no backend** — only Firebase client SDKs, no Cloud Functions, no
Firestore. Client SDKs cannot: list all Auth users, disable/delete a user, edit a Remote
Config template, or list another user's Storage files (rules block it, by design). True
admin operations require the **Firebase Admin SDK**, which only runs server-side. So this
feature adds a small **Cloud Functions (Node/TypeScript, 2nd gen)** backend for the
operations that genuinely need it, and uses **Firestore** for one new purpose: a role claim
plus a lightweight mirror of analytics/crash events for instant, queryable admin viewing
(real Crashlytics/Analytics BigQuery export was explicitly rejected — 24-48h data lag and
extra GCP setup aren't worth it for a course-project demo).

## 3. Access model

**Firebase custom claim** `admin: true` on the Auth user (not a hardcoded email check) —
chosen over a hardcoded-email check because it's the textbook-correct RBAC pattern and
better demonstrates platform understanding. Every Cloud Function checks
`context.auth?.token?.admin === true` before doing anything; the client never asserts its
own admin-ness.

Bootstrapping the first admin is a one-time manual step: a small Node script run locally
with the service account key, invoked once to grant the claim to the developer's own
account. This is a normal, expected part of RBAC bootstrapping — not a UI feature, and not
automatable from inside the app (nothing is admin yet to grant it).

## 4. Architecture additions

- **`functions/`** (new) — Firebase Cloud Functions project (TypeScript, 2nd gen / `onCall`).
  Holds only the operations that require Admin SDK privileges.
- **Firestore** (new to this project) — two purposes:
  1. Custom claim exists on the Auth token, not stored in Firestore, but Firestore security
     rules read `request.auth.token.admin` to gate admin-only reads.
  2. `admin_events` / `admin_crash_reports` collections — dual-written from the existing
     client-side `AnalyticsService` / `CrashlyticsService` alongside their real
     Analytics/Crashlytics calls (which are untouched — Lab03's requirement to fire real
     Analytics/Crashlytics events stays as-is). Pure client writes, no Cloud Function
     involved for this part.
- **`lib/firebase/admin_service.dart`** (new) — wraps `cloud_functions` calls behind an
  `AdminApi` interface, consistent with every other Firebase wrapper in this codebase (so
  ViewModels stay testable against a fake, never touching the SDK directly).
- **New screens/viewmodels**, one pair per capability, following the existing
  list-screen convention (Journals/Keywords):
  - `AdminDashboardScreen` — 4-card entry point, reached from a new tile on
    `ProfileScreen` shown only when the signed-in user's decoded ID token carries
    `admin: true` (checked once at sign-in, cached on `AuthViewModel`).
  - `AdminUsersScreen` + `AdminUsersViewModel`
  - `AdminRemoteConfigScreen` + `AdminRemoteConfigViewModel`
  - `AdminStorageScreen` + `AdminStorageViewModel`
  - `AdminLogsScreen` + `AdminLogsViewModel`

## 5. Capabilities

### 5.1 Users
- `adminListUsers` (Cloud Function, paginated `auth.listUsers()`) → list view: email,
  display name, created date, disabled flag, admin badge.
- `adminSetUserDisabled({uid, disabled})`, `adminDeleteUser({uid})` — both reject
  (`failed-precondition`) if `uid == context.auth.uid` (an admin can't lock themself out or
  self-delete). Destructive actions go through a confirm dialog client-side, matching the
  existing Crashlytics "force test crash" confirm pattern.

### 5.2 Remote Config
- `adminGetRemoteConfigTemplate()` → current parameters (currently `max_journals`,
  `max_keywords`; extensible).
- `adminUpdateRemoteConfigParameter({key, defaultValue})` → validates, then
  `remoteConfig().publishTemplate()`.
- UI: list of existing params with inline edit, plus an "add new parameter" form. This is
  the direct in-app replacement for hand-editing values in the console.

### 5.3 Storage (reports)
- `adminListReports()` — Admin SDK bucket walk of the `reports/` prefix across all UIDs
  (bypasses the owner-only rule that restricts the client SDK to `reports/{ownUid}/…`).
  Returns path/size/uploaded-at per file, grouped by user in the UI.
- `adminGetReportUrl({path})` → signed URL for download.
- `adminDeleteReport({path})` → delete.

### 5.4 Crash/Analytics logs
- No Cloud Function needed. `AnalyticsService`/`CrashlyticsService` gain a thin dual-write:
  alongside the real `logEvent`/`recordError` call, write a short record to
  `admin_events` / `admin_crash_reports` (event/error name, minimal metadata, uid,
  timestamp).
- Firestore rules: `allow create: if request.auth.uid == request.resource.data.uid` with a
  fixed field allowlist; `allow read: if request.auth.token.admin == true`; no client
  update/delete.
- `AdminLogsScreen` reads both collections directly via `cloud_firestore` client SDK
  (no function hop needed since rules already gate it), ordered by timestamp, filterable by
  type/user.

## 6. Error handling

Every admin screen follows the app's existing `ViewState` convention
(loading/success/error/empty) — a Cloud Function failure (permission-denied, not-found,
network) surfaces as a normal error state, never a crash. No silent catches: failures are
shown to the user with enough detail to retry or report.

## 7. Testing

- Unit tests for each new ViewModel against a mocked `AdminApi` / fake Firestore, following
  the existing `lab03_viewmodels_test.dart` pattern.
- New Jest test suite under `functions/` (Admin SDK mocked) — first Cloud Functions tests in
  this repo.
- Widget test for the admin tile's conditional visibility on `ProfileScreen`, similar to
  `profile_screen_test.dart`.
- Patrol E2E: extend an existing profile test case to assert tile visibility rather than
  add a new heavyweight E2E flow — destructive admin actions (delete user/report) are too
  risky to run against real data in CI.

## 8. Patrol flakiness (parallel, independent stream)

Debugged separately via systematic-debugging once implementation starts, not part of this
design's architecture. HANDOFF.md already names the likely causes (emulator
storage/network, not code bugs): emulator wipe-clean step, longer network-wait timeouts on
OpenAlex-calling cases, possible retry/backoff around post-boot DNS flakiness. Root cause
will be confirmed per failing case before any fix is applied — no blind timeout bumps.

## 9. Explicitly out of scope

- A full separate audit/optimization sweep of the entire app — only opportunistic fixes to
  code touched by this work (`flutter analyze`, simplification, obvious bugs tripped over).
  A dedicated audit is a future, separate task if wanted.
- Real Crashlytics/Analytics dashboard data via BigQuery export or the GA4 Data API —
  rejected in favor of the Firestore mirror (see §2).
- Any UI for granting the *first* admin claim — that bootstrap step is a one-time manual
  script, not a feature.

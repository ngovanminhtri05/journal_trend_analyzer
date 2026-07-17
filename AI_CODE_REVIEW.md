# AI-Assisted Code Review — Journal Trend Analyzer

This document records the code-review findings for the Lab2 deliverable
(requirement §7: ≥3 issues found and addressed).

> **External AI reviewer:** CodeRabbit AI reviewed PR #1
> (`ngovanminhtri05/journal_trend_analyzer`, profile **assertive**) and posted
> **14 inline findings**. The genuine `lib/` findings were fixed (see
> "CodeRabbit findings" below); the rest were in Flutter-generated boilerplate
> (`web/`, `windows/`) outside the Android delivery scope. Screenshots of the
> CodeRabbit run accompany this document in the report.

## Method

A structured review of the `lib/` tree across five lenses: correctness/bugs,
resource management, reliability, maintainability, and security/robustness.
Every fix was verified with `flutter analyze` (0 issues) and `flutter test`
(34/34 passing).

---

## Findings

### 1. No network timeout — request could hang forever  *(Reliability · High)*
**Where:** `lib/services/openalex_service.dart` → `_getJson`
**Problem:** `_client.get(uri)` had no timeout. On a stalled connection the
`Future` never completes, so every screen stays stuck on the loading spinner
with no way to recover except killing the app.
**Fix:** added a 15 s timeout (`_client.get(uri).timeout(_timeout)`); the timeout
is caught and surfaced as a `NetworkException`, so the existing error+retry UI
kicks in.

### 2. Service & HTTP client leaked on every rebuild  *(Resource management · Medium)*
**Where:** `lib/main.dart`
**Problem:** `OpenAlexService` (which owns an `http.Client`) was created inside
`build()` (`service ?? OpenAlexService(...)`). Every rebuild of the root widget
created a new client, and none were ever closed — a resource leak.
**Fix:** converted `JournalTrendApp` to a `StatefulWidget`; the service is
created once in the state, and `dispose()` closes it (only when the app owns it,
not when a test injects one).

### 3. Internal exception details leaked into user-facing messages  *(Robustness/UX · Medium)*
**Where:** `openalex_service.dart` and the three providers
**Problem:** error strings such as `'Invalid JSON: $e'`,
`'Network request failed: $e'`, and `'Unexpected error: $e'` dumped raw
exception/stack text (e.g. `SocketException`) straight onto the screen — noisy
for users and a minor information-leak smell.
**Fix:** technical detail is kept out of the message; users now see friendly,
actionable text (e.g. *"Could not reach OpenAlex. Please check your connection
and retry."*, *"Something went wrong. Please try again."*).

### 4. Duplicated shared-topic auto-load logic  *(Maintainability/DRY · Low)*
**Where:** `lib/screens/trend_screen.dart` and `lib/screens/dashboard_screen.dart`
**Problem:** both screens contained the same `addPostFrameCallback` +
`context.mounted` block to sync the searched topic — copy-pasted logic that
could drift out of sync.
**Fix:** extracted `syncSharedTopic(...)` into `lib/screens/topic_sync.dart`;
both screens now call the single helper.

---

## Result

| # | Finding | Severity | Status |
|---|---------|----------|--------|
| 1 | Missing network timeout | High | Fixed |
| 2 | Service/HTTP client leak | Medium | Fixed |
| 3 | Leaked exception detail in UI | Medium | Fixed |
| 4 | Duplicated auto-load logic | Low | Fixed |

`flutter analyze` → **No issues found** · `flutter test` → **34/34 passing**.

---

## CodeRabbit findings (external AI reviewer)

CodeRabbit (profile **assertive**) posted **14 inline comments** on PR #1. The
findings in first-party app code (`lib/`) were addressed:

| # | Finding (CodeRabbit) | Where | Status |
|---|----------------------|-------|--------|
| C1 | Stale async response can overwrite newer state (race condition) | `lib/state/search_provider.dart` | **Fixed** — added a monotonic `_requestId`; superseded responses are discarded |
| C2 | `launchUrl()` not wrapped in exception handling | `lib/screens/detail_screen.dart` | **Fixed** — wrapped in `try/catch`, falls back to the "Could not open" snackbar |
| C3 | `RankedCountList` calls `top.first` without guarding `limit ≤ 0` | `lib/widgets/ranked_count_list.dart` | **Fixed** — guard `top.isEmpty` after `take(limit)` |
| C4 | `_groupBy` silently drops malformed list items | `lib/services/openalex_service.dart` | **By design** — defensive `whereType` filtering preferred over crashing on a flaky external API |
| C5 | Hard-coded contact email in source | `lib/main.dart` | **By design** — this is the OpenAlex *polite-pool* `mailto` (public, required by API etiquette), not a secret |

Remaining CodeRabbit comments targeted Flutter-generated boilerplate (`web/index.html`,
`web/manifest.json`, `windows/runner/*.cpp`) and docs (`RUN.md`) — outside the
Android delivery scope, so they were acknowledged but not changed.

`flutter test` after the CodeRabbit fixes → **34/34 passing**.

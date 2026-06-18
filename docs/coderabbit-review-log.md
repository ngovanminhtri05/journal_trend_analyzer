# CodeRabbit AI Code Review — Evidence Log

**Project:** Journal Trend Analyzer (PRM393 Lab2)
**Repository:** https://github.com/ngovanminhtri05/journal_trend_analyzer
**Reviewer:** CodeRabbit (`coderabbitai[bot]`) — automated AI PR review
**Plan / profile:** Pro Plus, review profile **ASSERTIVE** (see `.coderabbit.yaml`)

This project uses CodeRabbit for automated AI code review on every Pull Request.
The evidence below is permanently visible on GitHub (PR conversation, commit
history) and summarized here for the report.

## 1. Proof that CodeRabbit is configured

| Evidence | Where |
|----------|-------|
| `.coderabbit.yaml` config committed to the repo | repo root (271 bytes) |
| Config commit | `830a404 chore: add CodeRabbit configuration` |
| Profile tuned for thoroughness | `7ecaded chore: switch CodeRabbit profile to assertive for thorough review` |
| CodeRabbit bot reviews on PRs | `coderabbitai[bot]` comments on PR #2 (and PR #1) |

## 2. Where to see the reviews on GitHub

- **Main PR:** https://github.com/ngovanminhtri05/journal_trend_analyzer/pull/2
  - The **Conversation** tab shows the CodeRabbit *summary / walkthrough*
    comment and a per-commit review for each push.
  - The **Files changed** tab shows the **inline review comments** (each with a
    severity tag: Critical / Major / Minor / Nitpick).
- CodeRabbit summary comment (permalink):
  https://github.com/ngovanminhtri05/journal_trend_analyzer/pull/2#issuecomment-4725719258

## 3. Review rounds

CodeRabbit re-reviews automatically on every push, so the PR captured several
rounds:

| Round | Date | Scope | Fixes committed in |
|-------|------|-------|--------------------|
| 1 | 2026-06-17 | FR-9 trend + FR-10 bookmarks | `0060ab2 fix: address CodeRabbit findings` |
| 1b | 2026-06-17 | re-review of round-1 fixes | `20cdf8d` (race condition) |
| 2 | 2026-06-18 | FR-14 export citation + FR-15 citation network | `20cdf8d fix: address CodeRabbit findings (FR-14/FR-15 review)` |

(An earlier full-app review PR also produced `fb3aac1 fix: address CodeRabbit
findings (async race, launchUrl guard, empty-list guard)`.)

## 4. Findings and how they were addressed

13 inline findings on PR #2. 12 were fixed; 1 was a debatable nitpick that was
intentionally deferred with a documented reason.

| # | Severity | File:line | Finding | Status |
|---|----------|-----------|---------|--------|
| 1 | 🟠 Major | `lib/state/bookmark_provider.dart` | `toggle()` swallowed save failure | Fixed — try/catch + rollback (`0060ab2`) |
| 2 | 🟠 Major | `lib/state/bookmark_provider.dart` | `remove()` swallowed save failure | Fixed — try/catch + rollback (`0060ab2`) |
| 3 | 🔵 Nitpick | `lib/widgets/ranked_count_list.dart` | `_toBookmark` unguarded `BookmarkType` | Fixed — exhaustive switch + guard (`0060ab2`) |
| 4 | 🟡 Minor | `lib/models/bookmark.dart` | empty-id bookmark from corrupt JSON | Fixed — drop empty-id on load (`0060ab2`) |
| 5 | 🟠 Major | `lib/services/trend_classifier.dart` | no unit tests for slope/classify | Fixed — added `trend_classifier_test.dart` (`0060ab2`) |
| 6 | 🔵 Nitpick | `lib/services/trend_classifier.dart` | exclude incomplete current year | Deferred — documented caveat (keeps function pure) |
| 7 | 🟠 Major | `lib/state/bookmark_provider.dart` | concurrent-write race in rollback | Fixed — snapshot + identity check (`20cdf8d`) |
| 8 | 🔵 Nitpick | `lib/models/work.dart` | duplicated `_shortId` | Fixed — reuse `shortOpenAlexId` (`20cdf8d`) |
| 9 | 🔵 Nitpick | `lib/services/openalex_service.dart` | duplicated `_shortId` | Fixed — reuse `shortOpenAlexId` (`20cdf8d`) |
| 10 | 🟡 Minor | `lib/widgets/comparison_chart.dart` | long legend label | Fixed — tooltip + width cap (`20cdf8d`) |
| 11 | 🔴 **Critical** | `lib/services/openalex_service.dart` | comma in `title.search` → HTTP 403 | Fixed — strip `,`/`\|` before query (`20cdf8d`) |
| 12 | 🟠 Major | `lib/screens/comparison_screen.dart` | `dataRowMaxHeight` clips under text scaling | Fixed — removed height cap (`20cdf8d`) |
| 13 | 🔵 Nitpick | `lib/services/citation_formatter.dart` | `title.trim()` computed twice | Fixed — local variable (`20cdf8d`) |

## 5. How to verify (and capture screenshots for the report)

1. Open the PR: https://github.com/ngovanminhtri05/journal_trend_analyzer/pull/2
2. **Conversation tab** → screenshot the `coderabbitai[bot]` summary/walkthrough
   comment (shows files reviewed + a high-level summary).
3. **Files changed tab** → screenshot a few inline comments, e.g. the 🔴 Critical
   `title.search` finding and a 🟠 Major one — each shows CodeRabbit's reasoning
   and a suggested fix.
4. **Commits tab** → screenshot the `fix: address CodeRabbit findings` commits to
   show the findings were acted on.
5. Optional CLI proof (reproducible):
   ```bash
   gh pr view 2 --repo ngovanminhtri05/journal_trend_analyzer --comments
   gh api repos/ngovanminhtri05/journal_trend_analyzer/pulls/2/comments \
     --jq '.[] | "\(.path):\(.line)  \((.body|split("\n"))[0])"'
   ```

## 6. Outcome

CodeRabbit caught a real **Critical** bug (a comma in a paper title would have
made citation-export metadata lookups fail with HTTP 403) plus several Major
correctness issues (a bookmark save-failure data-loss race, a layout clip under
large text scaling). All were fixed and pushed, then re-reviewed by CodeRabbit.
`flutter analyze` is clean and the unit-test suite passes.

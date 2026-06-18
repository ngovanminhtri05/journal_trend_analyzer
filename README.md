# Journal Trend Analyzer

A Flutter app (course **PRM393**) that explores research publications using the
free **[OpenAlex](https://openalex.org) API**. All data is fetched **directly
from the client** — there is **no backend and no cloud**.

## Architecture

A small, layered, Provider-based architecture:

| Layer | Folder | Responsibility |
|-------|--------|----------------|
| Models | `lib/models/` | Immutable OpenAlex models with manual `fromJson`. |
| Services | `lib/services/` | `OpenAlexService` (HTTP + JSON), typed errors, abstract decoder, `BookmarkService`, pure `trend_classifier`. |
| State | `lib/state/` | `ChangeNotifier` providers + a shared `ViewState { idle, loading, success, empty, error }`. |
| Screens | `lib/screens/` | One screen per tab + the detail screen. |
| Widgets | `lib/widgets/` | Reusable UI (cards, charts, badges, filter panel). |
| Theme | `lib/theme/` | App theme. |

State management uses the **`provider`** package: a single `OpenAlexService` and
one `BookmarkService` are created at the root and injected into the
`ChangeNotifier` providers. Charts use **`fl_chart`**; offline storage uses
**`shared_preferences`**.

### Data is always live

Every result (publications, counts, citations, subfields) is fetched dynamically
from OpenAlex at runtime. The **only** values baked into the app are:

- the **4 Domains** and **26 Fields** of the OpenAlex taxonomy — fixed reference
  IDs used to build filters (these never change), and
- bookmarks — **user-generated** data the user explicitly saves on the device.

Subfields, topics, works and aggregations are never hard-coded.

## Standalone features

These features extend the base requirements (FR-1…FR-7).

### FR-13 — 4-tier taxonomy filter

A cascading filter on the Search screen using OpenAlex's
**Domain → Field → Subfield** classification:

- **Domain** (4) and **Field** (26) dropdowns are hard-coded reference data;
  Field is filtered by the selected Domain.
- **Subfield** is loaded live from `GET /subfields` (cached after first use) and
  filtered by the selected Field.
- Changing a level **cascades a reset** to the levels below it.
- The selected level is appended to the `/works` query as
  `filter=primary_topic.{level}.id:{id}` (numeric short id), combined with the
  keyword search and joined by commas.
- The same active filter is applied to the **Search results, the Trend chart,
  the Dashboard, and the Comparison** screen.

### FR-8 — Compare 2–3 topics

A **Compare** tab that charts several topics side by side:

- Enter 2–3 keywords (add/remove fields, max 3) and tap **Compare**.
- Each topic is fetched concurrently (`Future.wait`) with
  `group_by=publication_year`; the active FR-13 filter is applied to each.
- A single **multi-line chart** (`fl_chart`) draws one colored line per topic
  with a legend, plus a **comparison table** (Total publications, Average
  citations, Peak year).
- Each topic resolves **independently** — one failing/empty topic does not break
  the others.

### FR-9 — Automatic trend classification

Classifies a topic's trajectory as **Đang lên / Bão hòa / Đang giảm**
(Emerging / Mature / Declining):

- A pure helper (`trend_classifier.dart`) computes the **least-squares slope** of
  publications over the most recent ~6 years.
- The slope is **normalized by the mean count** (scale-independent) and compared
  to a ±5%/year threshold, so a niche topic and a huge topic are judged fairly.
- Shown as a colored **badge with a tooltip** (explaining the verdict) on the
  **Search** and **Dashboard** screens, and **per topic** in the Comparison
  table.

### FR-10 — Personal collection (offline bookmarks)

Save items for offline access, stored **locally** with `shared_preferences`
(JSON), **no backend**:

- Bookmark three entity types: **Publication**, **Journal**, **Author**.
- Toggle the bookmark icon on the **Publication detail** screen and on each
  **Top Journals / Top Authors** row.
- A **Saved** tab lists bookmarks grouped by type, lets you remove them, and
  re-opens publications in the detail screen.
- Bookmarks **persist** across restarts; all persistence is encapsulated in
  `BookmarkService` (the UI never touches `shared_preferences` directly).

### FR-14 — Export citation

Export a paper's metadata in standard reference formats for Zotero / Mendeley /
LaTeX, computed entirely from existing `Work` fields (no extra API call):

- Pure `CitationFormatter`: **BibTeX**, **RIS**, and **APA-7** (plain text);
  citation key is `<firstAuthorSurname><year>` (e.g. `vaswani2017`); null fields
  are omitted (never prints "null").
- **Export Citation** on the detail screen → bottom sheet with a format selector
  + **Copy** (clipboard) and **Share** (`share_plus`, text only — no backend).
- **Export All** on the Saved tab → re-fetches the bookmarked publications by id
  to recover authors/biblio and emits one multi-entry BibTeX string (the main
  workflow for a researcher: bookmark over time, export the whole list at once).
  Falls back to stored fields when offline.
- **Improve metadata**: when a record is missing its journal (OpenAlex often
  holds duplicate variants), the export sheet can look up the most-cited record
  with the same title and swap it in (user-triggered, never silent).

### FR-15 — Citation network

"Follow the citation trail" to discover related work, using two tappable lists
(no heavy graph):

- On the detail screen, lazy **References (N)** and **Cited by (N)** sections
  (fetched only on expand). References use `filter=openalex:` (OR-joined ids,
  chunked); cited-by uses `filter=cites:<id>&sort=publication_date:desc`.
- Each item shows title / first author + year / cited-by count; tapping opens
  that paper's detail recursively (`Navigator.push`, back-stack preserved), and
  every item can be bookmarked (FR-10) and exported (FR-14).
- Independent loading / empty / error per section; empty references show
  "No reference data available".
- **Citation tree** (from the detail screen): an inline, lazily-expanding tree
  of the citation network (References or Cited-by direction) so several levels
  can be traced at once to spot clusters and sparse branches (research gaps).
  Depth- and child-capped, cycle-guarded, one request per expand.

## Navigation

Bottom navigation with 5 tabs: **Search · Trends · Compare · Dashboard · Saved**.
The Publication detail screen is pushed on top.

## Dependencies

`http`, `provider`, `fl_chart`, `url_launcher`, `google_fonts`,
`shared_preferences`, `share_plus`.

## Setup (A–Z)

The app talks to OpenAlex directly, so you only need Flutter and an
internet-connected Android device/emulator — there is no server to run.

### Option A — Just install the app (no coding)

1. Get the APK: `dist/journal_trend_analyzer-release.apk` (or build it, Option B).
2. Copy it to an Android phone and open it to install (allow "Install from
   unknown sources" if prompted), **or** with a device/emulator connected:
   ```bash
   adb install -r dist/journal_trend_analyzer-release.apk
   ```
3. Open the app. Make sure the device has internet — the first search loads data
   live from OpenAlex.

### Option B — Run from source (developers)

**1. Prerequisites**

- **Flutter SDK** 3.41+ (Dart 3.11+) — https://docs.flutter.dev/get-started/install
- **Android toolchain**: Android Studio (or just the Android SDK + platform-tools)
- An **Android emulator** or a physical device with USB debugging
- **Git**, and an internet connection

Check your setup:
```bash
flutter doctor
```
Resolve anything not ticked under "Flutter" and "Android toolchain".

**2. Get the code**
```bash
git clone https://github.com/ngovanminhtri05/journal_trend_analyzer.git
cd journal_trend_analyzer
```

**3. Install dependencies**
```bash
flutter pub get
```

**4. Start a device**
```bash
flutter emulators                 # list installed emulators
flutter emulators --launch <id>   # e.g. Pixel_7  (or start one from Android Studio)
flutter devices                   # confirm it is connected
```

**5. Run the app**
```bash
flutter run                       # builds, installs, runs (press r = hot reload)
```

**6. (Optional) build a release APK**
```bash
flutter build apk --release
# output: build/app/outputs/flutter-apk/app-release.apk
# smaller per-ABI builds:
flutter build apk --release --split-per-abi
```

**7. (Optional) verify quality**
```bash
flutter analyze   # static analysis (expected: No issues found!)
flutter test      # unit/widget tests
```

### Configuration

OpenAlex's "polite pool" wants a contact email. It is set once in
[`lib/main.dart`](lib/main.dart) (`JournalTrendApp.mailto`) — change it to your
own email if you fork the project. No API key is required.

### Troubleshooting

- **No results / network errors** → the device has no internet, or OpenAlex is
  rate-limiting; the screen shows a friendly error with a **Retry** button.
- **Plugin errors right after adding a dependency** → stop the app and run
  `flutter run` again (hot reload cannot load new native plugins).
- **Emulator won't start** → enable hardware virtualization (VT-x/Hyper-V) in
  BIOS, or launch the emulator from Android Studio's Device Manager.

### Testing

A full manual test script (UAT) covering every feature is in
[`docs/UAT-test-flow.md`](docs/UAT-test-flow.md). Automated AI code-review
evidence (CodeRabbit) is in [`docs/coderabbit-review-log.md`](docs/coderabbit-review-log.md).

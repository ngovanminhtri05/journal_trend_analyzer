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

## Navigation

Bottom navigation with 5 tabs: **Search · Trends · Compare · Dashboard · Saved**.
The Publication detail screen is pushed on top.

## Dependencies

`http`, `provider`, `fl_chart`, `url_launcher`, `google_fonts`,
`shared_preferences`.

## Run

```bash
flutter pub get
flutter run
```

Requires the Flutter SDK and a connected device/emulator.

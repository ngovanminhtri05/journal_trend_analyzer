/// How the Home discovery feed orders results (Phase 14).
enum WorkSort {
  /// Recent works ordered by citations — recent papers already gaining traction.
  rising,

  /// Newest works first, by publication date (no recency window).
  newest,

  /// Most-cited works within the recency window.
  topCited;

  /// Short label for the sort toggle UI (kept compact so the three segments fit
  /// on a phone without wrapping).
  String get label => switch (this) {
    WorkSort.rising => 'Rising',
    WorkSort.newest => 'Newest',
    WorkSort.topCited => 'Cited',
  };
}

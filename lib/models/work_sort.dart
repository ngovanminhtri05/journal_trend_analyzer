/// How the Home discovery feed orders results (Phase 14).
enum WorkSort {
  /// Recent works ordered by citations — recent papers already gaining traction.
  rising,

  /// Newest works first, by publication date. Scoped to the journals the user
  /// follows when there are any.
  newest;

  /// Short label for the sort toggle UI.
  String get label => switch (this) {
    WorkSort.rising => 'Rising',
    WorkSort.newest => 'Newest',
  };
}

import 'work.dart';

/// A cursor-paginated page of works (Phase 14).
///
/// Wraps a page of [Work]s with the OpenAlex cursor for the next page. Used by
/// the Home discovery feed to append results as the user scrolls.
class WorksPage {
  const WorksPage({required this.works, this.nextCursor});

  final List<Work> works;

  /// OpenAlex `meta.next_cursor` for the following page; null when the result
  /// set is exhausted.
  final String? nextCursor;

  /// Whether another page can be requested.
  bool get hasMore => nextCursor != null;
}

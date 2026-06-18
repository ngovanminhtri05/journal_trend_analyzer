import 'package:flutter/foundation.dart';

import '../models/models.dart';
import '../services/bookmark_service.dart';

/// Reactive store for the user's offline bookmark collection (FR-10).
///
/// Loads the persisted collection on creation and notifies listeners so any UI
/// (detail button, ranked-list icons, the collection screen) stays in sync. All
/// persistence goes through [BookmarkService]; this class never touches
/// `shared_preferences` directly.
class BookmarkProvider extends ChangeNotifier {
  BookmarkProvider(this._service) {
    _init();
  }

  final BookmarkService _service;

  List<Bookmark> _bookmarks = const [];

  /// Whether the initial load has finished (UI can show a spinner until then).
  bool ready = false;

  /// Set when the last persistence attempt failed (UI may surface it).
  String? lastError;

  List<Bookmark> get bookmarks => _bookmarks;

  List<Bookmark> byType(BookmarkType type) =>
      _bookmarks.where((b) => b.type == type).toList();

  bool isBookmarked(BookmarkType type, String id) =>
      _bookmarks.any((b) => b.type == type && b.id == id);

  Future<void> _init() async {
    try {
      await _service.init();
      _bookmarks = _service.load();
    } catch (_) {
      // Storage unavailable (e.g. a widget test without the plugin) — start
      // empty rather than crashing.
      _bookmarks = const [];
    }
    ready = true;
    notifyListeners();
  }

  /// Adds the bookmark if absent, removes it if already saved. Updates the UI
  /// immediately, then persists (rolling back on failure).
  Future<void> toggle(Bookmark bookmark) async {
    final previous = _bookmarks;
    final index = previous.indexWhere(
      (b) => b.type == bookmark.type && b.id == bookmark.id,
    );
    final next = [...previous];
    if (index >= 0) {
      next.removeAt(index);
    } else {
      next.insert(0, bookmark); // newest first
    }
    _bookmarks = next;
    lastError = null;
    notifyListeners();
    await _persist(previous, next);
  }

  /// Removes a bookmark by identity (used by the collection screen).
  Future<void> remove(BookmarkType type, String id) async {
    final previous = _bookmarks;
    final next = previous.where((b) => !(b.type == type && b.id == id)).toList();
    if (next.length == previous.length) return;
    _bookmarks = next;
    lastError = null;
    notifyListeners();
    await _persist(previous, next);
  }

  /// Persists [attempted] (the snapshot we optimistically applied). If saving
  /// throws, rolls back to [previous] — but only when [attempted] is still the
  /// current state, so a newer operation that already superseded it is not
  /// clobbered (prevents a concurrent-write data loss race).
  Future<void> _persist(
    List<Bookmark> previous,
    List<Bookmark> attempted,
  ) async {
    try {
      await _service.save(attempted);
    } catch (_) {
      if (!identical(_bookmarks, attempted)) return; // superseded — leave it
      _bookmarks = previous;
      lastError = 'Could not save your bookmark. Please try again.';
      notifyListeners();
    }
  }
}

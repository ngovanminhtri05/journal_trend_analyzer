import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';

/// Local, offline persistence for bookmarks (FR-10).
///
/// The single place that touches `shared_preferences`: the rest of the app goes
/// through `BookmarkProvider`. The whole collection is stored as one JSON string
/// under [_storageKey]. No backend / cloud is involved.
class BookmarkService {
  BookmarkService({SharedPreferences? prefs}) : _prefs = prefs;

  /// Versioned key so the storage format can evolve without clashing.
  static const String _storageKey = 'bookmarks_v1';

  SharedPreferences? _prefs;

  /// Lazily resolves the shared-preferences instance. Safe to call repeatedly.
  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// Reads the persisted bookmarks. Returns an empty list before [init] has
  /// completed or when nothing is stored / the payload is corrupt.
  List<Bookmark> load() {
    final raw = _prefs?.getString(_storageKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(Bookmark.fromJson)
          // Drop orphaned entries (empty id) that corrupt or hand-edited JSON
          // could produce — they would never match an isBookmarked() check.
          .where((b) => b.id.isNotEmpty)
          .toList();
    } catch (_) {
      // Corrupt payload — fail soft with an empty collection.
      return const [];
    }
  }

  /// Persists the full collection as a JSON string.
  Future<void> save(List<Bookmark> bookmarks) async {
    await init();
    final raw = jsonEncode(bookmarks.map((b) => b.toJson()).toList());
    await _prefs!.setString(_storageKey, raw);
  }
}

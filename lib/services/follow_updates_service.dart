import 'package:shared_preferences/shared_preferences.dart';

import '../firebase/messaging_service.dart';
import '../models/models.dart';
import 'openalex_service.dart';

/// New-paper alerts for followed authors / journals (local "push", plan A).
///
/// On each check it fetches the most recent work for every followed entity
/// (a bookmark of type author or journal) and compares it to the last work id
/// seen for that entity. When it differs — including the first time an entity is
/// checked — it emits an [AppNotification]. Runs entirely client-side: no
/// backend, so alerts are produced when the app runs the check (e.g. on open).
class FollowUpdatesService {
  FollowUpdatesService(this._service, {SharedPreferences? prefs})
    : _prefs = prefs;

  final OpenAlexService _service;
  SharedPreferences? _prefs;

  static const String _keyPrefix = 'follow_seen_';

  Future<SharedPreferences> get _preferences async =>
      _prefs ??= await SharedPreferences.getInstance();

  /// Returns one [AppNotification] per followed entity that has a newer latest
  /// work than last seen, and records the new "seen" ids.
  Future<List<AppNotification>> checkForNewPapers(
    List<Bookmark> follows,
  ) async {
    final prefs = await _preferences;
    final out = <AppNotification>[];

    for (final follow in follows) {
      final field = switch (follow.type) {
        BookmarkType.author => 'authorships.author.id',
        BookmarkType.journal => 'primary_location.source.id',
        BookmarkType.work => null,
      };
      if (field == null) continue;

      List<Work> works;
      try {
        works = await _service.recentWorksByEntity(
          field,
          follow.id,
          perPage: 1,
        );
      } catch (_) {
        continue; // network/parse error for one follow shouldn't abort the rest
      }
      if (works.isEmpty) continue;

      final latest = works.first;
      final latestId = latest.id ?? latest.title;
      final key = '$_keyPrefix${follow.type.name}_${follow.id}';
      if (prefs.getString(key) == latestId) continue; // nothing new

      await prefs.setString(key, latestId);
      out.add(
        AppNotification(
          title: 'New paper — ${follow.displayName}',
          body: latest.title,
          receivedAt: DateTime.now(),
        ),
      );
    }
    return out;
  }
}

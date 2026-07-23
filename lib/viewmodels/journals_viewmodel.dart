import 'package:flutter/foundation.dart';

import '../models/models.dart';
import '../services/openalex_service.dart';
import 'view_state.dart';

/// Drives the Journals tab (Phase 13.3): find a publication venue by **name**
/// (`/sources?search=`). The View binds to this; ordering lives here.
class JournalsViewModel extends ChangeNotifier {
  JournalsViewModel(this._service);

  final OpenAlexService _service;

  ViewState state = ViewState.idle;
  String? errorMessage;
  String lastQuery = '';

  /// Matching sources, journals first (then repositories/conferences).
  List<SourceHit> sources = const [];

  Future<void> search(String name) async {
    final query = name.trim();
    if (query.isEmpty) return;

    lastQuery = query;
    state = ViewState.loading;
    errorMessage = null;
    notifyListeners();

    try {
      final hits = await _service.searchSources(query, perPage: 25);
      // Surface journals before other source types, keeping API order within.
      sources = [
        ...hits.where((s) => s.type == 'journal'),
        ...hits.where((s) => s.type != 'journal'),
      ];
      state = sources.isEmpty ? ViewState.empty : ViewState.success;
    } on OpenAlexException catch (e) {
      errorMessage = e.message;
      state = ViewState.error;
    } catch (_) {
      errorMessage = 'Something went wrong. Please try again.';
      state = ViewState.error;
    }
    notifyListeners();
  }

  Future<void> retry() => search(lastQuery);
}

/// Drives the Journal Detail screen (Phase 13.3): the venue's **recent volumes**
/// (its recent works grouped by `biblio.volume`, year fallback) so the user can
/// browse the articles inside each volume. Owns a scoped instance.
class JournalDetailViewModel extends ChangeNotifier {
  JournalDetailViewModel(this._service);

  final OpenAlexService _service;

  ViewState state = ViewState.idle;
  String? errorMessage;
  String _lastSourceId = '';

  /// Recent volumes, newest first.
  List<JournalVolume> volumes = const [];

  /// Number of recent works fetched (a recent-output sample, not a global sum).
  int recentWorkCount = 0;

  /// Active in-journal search term (empty = browsing volumes).
  String query = '';

  /// Articles in this journal matching [query], newest first.
  List<Work> searchResults = const [];

  bool get isSearching => query.isNotEmpty;

  Future<void> load(String sourceId) async {
    _lastSourceId = sourceId;
    query = '';
    searchResults = const [];
    state = ViewState.loading;
    errorMessage = null;
    notifyListeners();

    try {
      final works = await _service.recentWorksBySource(sourceId, perPage: 150);
      recentWorkCount = works.length;
      volumes = groupWorksIntoVolumes(works);
      state = volumes.isEmpty ? ViewState.empty : ViewState.success;
    } on OpenAlexException catch (e) {
      errorMessage = e.message;
      state = ViewState.error;
    } catch (_) {
      errorMessage = 'Something went wrong. Please try again.';
      state = ViewState.error;
    }
    notifyListeners();
  }

  /// Searches this journal for articles matching [q] (a field/topic within the
  /// journal). An empty query clears the search and returns to the volumes view.
  Future<void> search(String q) async {
    query = q.trim();
    if (query.isEmpty) {
      clearSearch();
      return;
    }
    state = ViewState.loading;
    errorMessage = null;
    notifyListeners();

    try {
      searchResults = await _service.worksInSource(
        _lastSourceId,
        query: query,
        perPage: 50,
      );
      state = searchResults.isEmpty ? ViewState.empty : ViewState.success;
    } on OpenAlexException catch (e) {
      errorMessage = e.message;
      state = ViewState.error;
    } catch (_) {
      errorMessage = 'Something went wrong. Please try again.';
      state = ViewState.error;
    }
    notifyListeners();
  }

  void clearSearch() {
    query = '';
    searchResults = const [];
    state = volumes.isEmpty ? ViewState.empty : ViewState.success;
    notifyListeners();
  }

  Future<void> retry() =>
      isSearching ? search(query) : load(_lastSourceId);
}

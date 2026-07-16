import 'package:flutter/foundation.dart';

import '../models/models.dart';
import '../services/openalex_service.dart';
import '../utils/utils.dart';
import 'view_state.dart';

/// Drives the Journals screen (Lab 03): ranks the publishing venues for a topic
/// by publication count (`group_by=primary_location.source.id`). The View binds
/// to this; the ranking/sorting lives here.
class JournalsViewModel extends ChangeNotifier {
  JournalsViewModel(this._service);

  final OpenAlexService _service;

  ViewState state = ViewState.idle;
  String? errorMessage;
  String lastQuery = '';

  /// Top journals for the topic, sorted by count descending.
  List<GroupByItem> journals = const [];

  /// Combined publication count across the listed journals (a contribution
  /// stat for the screen).
  int get totalInTopJournals => journals.fold(0, (acc, j) => acc + j.count);

  Future<void> load(String keyword) async {
    final query = keyword.trim();
    if (query.isEmpty) return;

    lastQuery = query;
    state = ViewState.loading;
    errorMessage = null;
    notifyListeners();

    try {
      final groups = await _service.groupByJournal(query);
      journals = [...groups]..sort((a, b) => b.count.compareTo(a.count));
      state = journals.isEmpty ? ViewState.empty : ViewState.success;
    } on OpenAlexException catch (e) {
      errorMessage = e.message;
      state = ViewState.error;
    } catch (_) {
      errorMessage = 'Something went wrong. Please try again.';
      state = ViewState.error;
    }
    notifyListeners();
  }

  Future<void> retry() => load(lastQuery);
}

/// Drives the Journal Detail screen (Lab 03): a journal's true publication
/// count plus its most-cited publications (`filter=primary_location.source.id`).
/// Citation figures are reported over the fetched top publications.
class JournalDetailViewModel extends ChangeNotifier {
  JournalDetailViewModel(this._service);

  final OpenAlexService _service;

  ViewState state = ViewState.idle;
  String? errorMessage;
  String _lastSourceId = '';

  /// True number of works published in this venue (`meta.count`).
  int totalPublications = 0;

  /// The journal's most-cited publications (a fetched sample, cited-desc).
  List<Work> relatedWorks = const [];

  /// Total citations across the fetched top publications.
  int get topCitations => relatedWorks.fold(0, (acc, w) => acc + w.citedByCount);

  /// Mean citations across the fetched top publications.
  double get averageTopCitations => averageCitations(relatedWorks);

  Future<void> load(String sourceId) async {
    final id = shortOpenAlexId(sourceId);
    if (id.isEmpty) return;

    _lastSourceId = sourceId;
    state = ViewState.loading;
    errorMessage = null;
    notifyListeners();

    try {
      final filter = ['primary_location.source.id:$id'];
      final results = await Future.wait([
        _service.getCountByFilter(filter),
        _service.getWorksByFilter(filter, perPage: 25),
      ]);
      totalPublications = results[0] as int;
      relatedWorks = results[1] as List<Work>;
      state = (totalPublications == 0 && relatedWorks.isEmpty)
          ? ViewState.empty
          : ViewState.success;
    } on OpenAlexException catch (e) {
      errorMessage = e.message;
      state = ViewState.error;
    } catch (_) {
      errorMessage = 'Something went wrong. Please try again.';
      state = ViewState.error;
    }
    notifyListeners();
  }

  Future<void> retry() => load(_lastSourceId);
}

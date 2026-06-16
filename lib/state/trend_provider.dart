import 'package:flutter/foundation.dart';

import '../models/models.dart';
import '../services/openalex_service.dart';
import 'view_state.dart';

/// Drives the Trend screen (FR-3/4/5/6): year trend, top journals, top authors,
/// and top-cited papers for a topic, fetched concurrently.
class TrendProvider extends ChangeNotifier {
  TrendProvider(this._service);

  final OpenAlexService _service;

  ViewState state = ViewState.idle;
  String? errorMessage;
  String lastQuery = '';

  /// Taxonomy filter clauses (FR-13) applied to the last load; replayed by
  /// [retry].
  List<String> lastFilters = const [];

  List<GroupByItem> yearCounts = const [];
  List<GroupByItem> topJournals = const [];
  List<GroupByItem> topAuthors = const [];
  List<Work> topPapers = const [];

  Future<void> load(String keyword, {List<String> filters = const []}) async {
    final query = keyword.trim();
    if (query.isEmpty) return;

    lastQuery = query;
    lastFilters = filters;
    state = ViewState.loading;
    errorMessage = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _service.groupByYear(query, filters: filters),
        _service.groupByJournal(query, filters: filters),
        _service.groupByAuthor(query, filters: filters),
        _service.getTopCited(query, filters: filters),
      ]);
      yearCounts = results[0] as List<GroupByItem>;
      topJournals = results[1] as List<GroupByItem>;
      topAuthors = results[2] as List<GroupByItem>;
      topPapers = results[3] as List<Work>;

      final isEmpty =
          yearCounts.isEmpty &&
          topJournals.isEmpty &&
          topAuthors.isEmpty &&
          topPapers.isEmpty;
      state = isEmpty ? ViewState.empty : ViewState.success;
    } on OpenAlexException catch (e) {
      errorMessage = e.message;
      state = ViewState.error;
    } catch (_) {
      errorMessage = 'Something went wrong. Please try again.';
      state = ViewState.error;
    }
    notifyListeners();
  }

  Future<void> retry() => load(lastQuery, filters: lastFilters);
}

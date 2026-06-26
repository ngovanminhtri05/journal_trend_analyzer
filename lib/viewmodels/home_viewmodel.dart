import 'package:flutter/foundation.dart';

import '../models/models.dart';
import '../services/openalex_service.dart';
import '../services/trend_classifier.dart';
import '../utils/utils.dart';
import 'dashboard_provider.dart' show DashboardSummary;
import 'view_state.dart';

/// Drives the Home overview screen (Lab 03).
///
/// A single topic search fans out — via `Future.wait` — to a count query, three
/// `group_by` aggregations, and the top-cited list, then combines them into a
/// [DashboardSummary] plus the per-year buckets that feed the trend chart.
/// The View binds to this; it holds no business logic of its own.
class HomeViewModel extends ChangeNotifier {
  HomeViewModel(this._service);

  final OpenAlexService _service;

  ViewState state = ViewState.idle;
  String? errorMessage;
  String lastQuery = '';

  /// The six aggregate insights (total / avg citations / most-active year /
  /// top journal / top author / most-influential paper).
  DashboardSummary? summary;

  /// Raw `group_by=publication_year` buckets, kept for the trend chart and the
  /// FR-9 trend verdict.
  List<GroupByItem> yearCounts = const [];

  /// FR-9 trend verdict derived from [yearCounts] (null when too little data).
  TrendClassification? get trendClassification => classifyTrend(yearCounts);

  Future<void> search(String keyword) async {
    final query = keyword.trim();
    if (query.isEmpty) return;

    lastQuery = query;
    state = ViewState.loading;
    errorMessage = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _service.getTotalCount(query),
        _service.groupByYear(query),
        _service.groupByJournal(query),
        _service.groupByAuthor(query),
        _service.getTopCited(query),
      ]);

      final total = results[0] as int;
      final years = results[1] as List<GroupByItem>;
      final journals = results[2] as List<GroupByItem>;
      final authors = results[3] as List<GroupByItem>;
      final topCited = results[4] as List<Work>;

      yearCounts = years;

      if (total == 0) {
        summary = null;
        state = ViewState.empty;
      } else {
        summary = DashboardSummary(
          totalPublications: total,
          averageCitations: averageCitations(topCited),
          mostActiveYear: mostActiveYear(years),
          topJournal: topDisplayName(journals),
          topAuthor: topDisplayName(authors),
          mostInfluential: topCited.isEmpty ? null : topCited.first,
        );
        state = ViewState.success;
      }
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

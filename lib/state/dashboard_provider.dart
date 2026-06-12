import 'package:flutter/foundation.dart';

import '../models/models.dart';
import '../services/openalex_service.dart';
import 'view_state.dart';

/// The six aggregate insights shown on the Research Dashboard (FR-7).
class DashboardSummary {
  const DashboardSummary({
    required this.totalPublications,
    required this.averageCitations,
    required this.mostActiveYear,
    required this.topJournal,
    required this.topAuthor,
    required this.mostInfluential,
  });

  final int totalPublications;
  final double averageCitations;
  final int? mostActiveYear;
  final String? topJournal;
  final String? topAuthor;
  final Work? mostInfluential;
}

/// Drives the Research Dashboard (FR-7) by combining a count query, three
/// `group_by` aggregations, and the top-cited list into a [DashboardSummary].
class DashboardProvider extends ChangeNotifier {
  DashboardProvider(this._service);

  final OpenAlexService _service;

  ViewState state = ViewState.idle;
  String? errorMessage;
  String lastQuery = '';
  DashboardSummary? summary;

  Future<void> load(String keyword) async {
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

      if (total == 0) {
        summary = null;
        state = ViewState.empty;
      } else {
        summary = DashboardSummary(
          totalPublications: total,
          averageCitations: _average(topCited),
          mostActiveYear: _mostActiveYear(years),
          topJournal: _topName(journals),
          topAuthor: _topName(authors),
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

  Future<void> retry() => load(lastQuery);

  double _average(List<Work> works) {
    if (works.isEmpty) return 0;
    final sum = works.fold<int>(0, (acc, w) => acc + w.citedByCount);
    return sum / works.length;
  }

  int? _mostActiveYear(List<GroupByItem> years) {
    if (years.isEmpty) return null;
    final top = years.reduce((a, b) => a.count >= b.count ? a : b);
    return int.tryParse(top.key);
  }

  String? _topName(List<GroupByItem> items) {
    if (items.isEmpty) return null;
    final top = items.reduce((a, b) => a.count >= b.count ? a : b);
    return top.keyDisplayName;
  }
}

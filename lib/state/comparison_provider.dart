import 'package:flutter/foundation.dart';

import '../models/models.dart';
import '../services/openalex_service.dart';
import '../services/trend_classifier.dart';
import 'view_state.dart';

/// Per-topic outcome of a comparison run (FR-8).
///
/// Each topic resolves independently, so one failing topic still produces a
/// row (with [TopicStatus.error]) instead of sinking the whole comparison.
enum TopicStatus { success, empty, error }

class TopicComparison {
  const TopicComparison({
    required this.topic,
    required this.status,
    this.errorMessage,
    this.yearCounts = const [],
    this.totalPublications = 0,
    this.averageCitations = 0,
    this.peakYear,
    this.classification,
  });

  final String topic;
  final TopicStatus status;
  final String? errorMessage;

  /// FR-9: per-topic trend verdict (null for empty/error topics).
  final TrendClassification? classification;

  /// Raw `group_by=publication_year` buckets (drives the line chart).
  final List<GroupByItem> yearCounts;

  /// `meta.count` — total works matching the topic.
  final int totalPublications;

  /// Mean citations across the topic's top-cited papers.
  final double averageCitations;

  /// Year with the most publications.
  final int? peakYear;

  /// Whether this topic contributes a line to the chart.
  bool get hasChartData =>
      status == TopicStatus.success && yearCounts.isNotEmpty;
}

/// Drives the Comparison screen (FR-8): fetches the year trend + headline stats
/// for 2–3 topics concurrently and exposes them as a list of independent
/// [TopicComparison] results.
class ComparisonProvider extends ChangeNotifier {
  ComparisonProvider(this._service);

  final OpenAlexService _service;

  static const int minTopics = 2;
  static const int maxTopics = 3;

  ViewState state = ViewState.idle;
  List<String> lastTopics = const [];

  /// Taxonomy filter clauses (FR-13) applied to the last run; replayed by
  /// [retry].
  List<String> lastFilters = const [];
  List<TopicComparison> results = const [];

  /// Runs the comparison. Topics are trimmed, de-duplicated, and capped at
  /// [maxTopics]; fewer than [minTopics] is a no-op.
  Future<void> compare(
    List<String> topics, {
    List<String> filters = const [],
  }) async {
    final cleaned = <String>[];
    for (final t in topics) {
      final q = t.trim();
      if (q.isNotEmpty && !cleaned.contains(q)) cleaned.add(q);
    }
    if (cleaned.length < minTopics) return;
    final limited = cleaned.take(maxTopics).toList();

    lastTopics = limited;
    lastFilters = filters;
    state = ViewState.loading;
    results = const [];
    notifyListeners();

    // Each topic loads independently and never throws, so one failure cannot
    // sink the whole comparison (FR-8 #6).
    results = await Future.wait(limited.map((t) => _loadOne(t, filters)));
    state = ViewState.success;
    notifyListeners();
  }

  Future<void> retry() => compare(lastTopics, filters: lastFilters);

  /// Loads one topic. Catches everything and maps it to a [TopicComparison] so
  /// the enclosing `Future.wait` always resolves.
  Future<TopicComparison> _loadOne(String topic, List<String> filters) async {
    try {
      final res = await Future.wait([
        _service.groupByYear(topic, filters: filters),
        _service.getTotalCount(topic, filters: filters),
        _service.getTopCited(topic, filters: filters),
      ]);
      final years = res[0] as List<GroupByItem>;
      final total = res[1] as int;
      final topCited = res[2] as List<Work>;

      if (total == 0 && years.isEmpty) {
        return TopicComparison(topic: topic, status: TopicStatus.empty);
      }
      return TopicComparison(
        topic: topic,
        status: TopicStatus.success,
        yearCounts: years,
        totalPublications: total,
        averageCitations: _average(topCited),
        peakYear: _peakYear(years),
        classification: classifyTrend(years),
      );
    } on OpenAlexException catch (e) {
      return TopicComparison(
        topic: topic,
        status: TopicStatus.error,
        errorMessage: e.message,
      );
    } catch (_) {
      return TopicComparison(
        topic: topic,
        status: TopicStatus.error,
        errorMessage: 'Something went wrong. Please try again.',
      );
    }
  }

  double _average(List<Work> works) {
    if (works.isEmpty) return 0;
    final sum = works.fold<int>(0, (acc, w) => acc + w.citedByCount);
    return sum / works.length;
  }

  int? _peakYear(List<GroupByItem> years) {
    if (years.isEmpty) return null;
    final top = years.reduce((a, b) => a.count >= b.count ? a : b);
    return int.tryParse(top.key);
  }
}

import 'package:flutter/foundation.dart';

import '../models/models.dart';
import '../services/openalex_service.dart';
import '../services/trend_classifier.dart';
import 'view_state.dart';

/// Drives the Keywords screen (Lab 03): ranks the most frequent keywords for a
/// topic (`group_by=keywords.id`). The View binds to this; ranking lives here.
class KeywordsViewModel extends ChangeNotifier {
  KeywordsViewModel(this._service);

  final OpenAlexService _service;

  ViewState state = ViewState.idle;
  String? errorMessage;
  String lastQuery = '';

  /// Most frequent keywords for the topic, sorted by count descending.
  List<GroupByItem> keywords = const [];

  Future<void> load(String keyword) async {
    final query = keyword.trim();
    if (query.isEmpty) return;

    lastQuery = query;
    state = ViewState.loading;
    errorMessage = null;
    notifyListeners();

    try {
      final groups = await _service.groupByKeyword(query);
      keywords = [...groups]..sort((a, b) => b.count.compareTo(a.count));
      state = keywords.isEmpty ? ViewState.empty : ViewState.success;
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

/// Drives the Keyword Detail screen (Lab 03): for one keyword it loads the
/// year trend, the top contributing authors (ranked desc), related journals,
/// and the most-cited related publications — all scoped with `keywords.id`.
class KeywordDetailViewModel extends ChangeNotifier {
  KeywordDetailViewModel(this._service);

  final OpenAlexService _service;

  ViewState state = ViewState.idle;
  String? errorMessage;
  String _lastKeywordId = '';

  /// `group_by=publication_year` buckets for the keyword (year trend chart).
  List<GroupByItem> yearCounts = const [];

  /// Top contributing authors for the keyword, sorted by count descending.
  List<GroupByItem> topAuthors = const [];

  /// Journals most associated with the keyword, sorted by count descending.
  List<GroupByItem> relatedJournals = const [];

  /// Top publications **tagged with this keyword**, most-cited first.
  ///
  /// Scoped with `keywords.id` rather than a free-text search: a text search for
  /// e.g. "Computer science" pulls in loosely-matching papers (a crystallography
  /// tool topped that list), while the tag filter returns works OpenAlex
  /// actually classified under the keyword.
  List<Work> relatedWorks = const [];

  /// FR-9 trend verdict derived from [yearCounts] (null when too little data).
  TrendClassification? get trendClassification => classifyTrend(yearCounts);

  Future<void> load(String keywordId) async {
    final id = shortOpenAlexId(keywordId);
    if (id.isEmpty) return;

    _lastKeywordId = keywordId;
    state = ViewState.loading;
    errorMessage = null;
    notifyListeners();

    try {
      final filter = ['keywords.id:$id'];
      final results = await Future.wait([
        _service.groupByFilter('publication_year', filter),
        _service.groupByFilter('authorships.author.id', filter),
        _service.groupByFilter('primary_location.source.id', filter),
        // Top papers tagged with this keyword, most-cited first.
        _service.getWorksByFilter(filter, perPage: 25),
      ]);
      yearCounts = results[0] as List<GroupByItem>;
      topAuthors = [...results[1] as List<GroupByItem>]
        ..sort((a, b) => b.count.compareTo(a.count));
      relatedJournals = [...results[2] as List<GroupByItem>]
        ..sort((a, b) => b.count.compareTo(a.count));
      relatedWorks = results[3] as List<Work>;

      final hasData =
          yearCounts.isNotEmpty ||
          topAuthors.isNotEmpty ||
          relatedJournals.isNotEmpty ||
          relatedWorks.isNotEmpty;
      state = hasData ? ViewState.success : ViewState.empty;
    } on OpenAlexException catch (e) {
      errorMessage = e.message;
      state = ViewState.error;
    } catch (_) {
      errorMessage = 'Something went wrong. Please try again.';
      state = ViewState.error;
    }
    notifyListeners();
  }

  Future<void> retry() => load(_lastKeywordId);
}

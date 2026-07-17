import 'package:flutter/foundation.dart';

import '../models/models.dart';
import '../services/openalex_service.dart';
import 'view_state.dart';

/// Drives the Search screen (FR-1): runs a topic search and exposes the result
/// list with loading / success / empty / error states.
class SearchProvider extends ChangeNotifier {
  SearchProvider(this._service);

  final OpenAlexService _service;

  ViewState state = ViewState.idle;
  String? errorMessage;
  String lastQuery = '';

  /// Taxonomy filter clauses (FR-13) applied to the last search; replayed by
  /// [retry].
  List<String> lastFilters = const [];
  List<Work> results = const [];

  /// Monotonic token used to discard responses from superseded requests, so a
  /// slow earlier search cannot overwrite the result of a newer one.
  int _requestId = 0;

  Future<void> search(String keyword, {List<String> filters = const []}) async {
    final query = keyword.trim();
    if (query.isEmpty) return;

    final requestId = ++_requestId;
    lastQuery = query;
    lastFilters = filters;
    state = ViewState.loading;
    errorMessage = null;
    notifyListeners();

    try {
      final works = await _service.searchWorks(query, filters: filters);
      if (requestId != _requestId) return; // a newer search has taken over
      results = works;
      state = works.isEmpty ? ViewState.empty : ViewState.success;
    } on OpenAlexException catch (e) {
      if (requestId != _requestId) return;
      errorMessage = e.message;
      state = ViewState.error;
    } catch (_) {
      if (requestId != _requestId) return;
      errorMessage = 'Something went wrong. Please try again.';
      state = ViewState.error;
    }
    notifyListeners();
  }

  Future<void> retry() => search(lastQuery, filters: lastFilters);
}

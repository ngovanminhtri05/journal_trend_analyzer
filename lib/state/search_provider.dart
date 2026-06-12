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
  List<Work> results = const [];

  Future<void> search(String keyword) async {
    final query = keyword.trim();
    if (query.isEmpty) return;

    lastQuery = query;
    state = ViewState.loading;
    errorMessage = null;
    notifyListeners();

    try {
      final works = await _service.searchWorks(query);
      results = works;
      state = works.isEmpty ? ViewState.empty : ViewState.success;
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

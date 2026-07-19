import 'package:flutter/foundation.dart';

import '../firebase/analytics_service.dart';
import '../firebase/remote_config_service.dart';
import '../firebase/storage_service.dart';
import '../models/models.dart';
import '../services/openalex_service.dart';
import '../services/report_builder.dart';
import '../services/report_file_saver.dart';
import 'view_state.dart';

/// Drives the Home discovery feed (Phase 14.3).
///
/// A cursor-paginated feed of works with a [sort] toggle (rising / newest /
/// top-cited), an optional free-text [query] (relevance search) and an optional
/// [subfieldId] filter. No OpenAlex aggregate totals. The PDF export
/// (Storage/Analytics demo, task 8.3) is kept, producing a report from the
/// current feed.
class HomeViewModel extends ChangeNotifier {
  HomeViewModel(
    this._service, {
    AnalyticsApi? analytics,
    ReportStorageApi? storage,
    ReportFileSaver? saveReport,
    RemoteConfigApi? remoteConfig,
  }) : _analytics = analytics,
       _storage = storage,
       _saveReport = saveReport ?? saveReportToTemp,
       _remoteConfig = remoteConfig {
    // Real-time Remote Config: reload when the server changes the page size.
    _remoteConfig?.addListener(_onRemoteConfigChanged);
  }

  final OpenAlexService _service;
  final AnalyticsApi? _analytics;
  final ReportStorageApi? _storage;
  final ReportFileSaver _saveReport;
  final RemoteConfigApi? _remoteConfig;

  /// How many works to fetch per page — server-tunable via Remote Config
  /// (`home_page_size`), falling back to the in-code default.
  int get pageSize =>
      _remoteConfig?.homePageSize ?? RemoteConfigService.defaultHomePageSize;

  /// The page size the current feed was loaded with (to detect config changes).
  int? _appliedPageSize;

  void _onRemoteConfigChanged() {
    // Only refetch when the size actually changed and we're not mid-load.
    if (_appliedPageSize == null || pageSize == _appliedPageSize) return;
    if (state == ViewState.loading || loadingMore) return;
    load();
  }

  @override
  void dispose() {
    _remoteConfig?.removeListener(_onRemoteConfigChanged);
    super.dispose();
  }

  ViewState state = ViewState.idle;
  String? errorMessage;

  /// Current ordering of the feed.
  WorkSort sort = WorkSort.rising;

  /// Free-text search term (empty = browse feed).
  String query = '';

  /// Selected subfield filter (short OpenAlex id), or null when unfiltered.
  String? subfieldId;

  /// The loaded page(s) of works.
  List<Work> works = const [];

  String? _nextCursor;
  bool loadingMore = false;

  /// Whether another page can be loaded.
  bool get hasMore => _nextCursor != null;

  /// PDF-report export state (task 8.3).
  bool isExporting = false;
  String? reportFilePath;
  String? reportUrl;
  String? exportError;

  bool get canExport => state == ViewState.success && works.isNotEmpty;

  /// Recency window (days) for the browse feed: a longer window for "top cited".
  int get _windowDays => sort == WorkSort.topCited ? 730 : 365;

  /// Loads the first page for the current [sort] / [query] / [subfieldId].
  Future<void> load() async {
    state = ViewState.loading;
    errorMessage = null;
    works = const [];
    _nextCursor = null;
    notifyListeners();

    // Analytics: log a topic search when the feed is a query search.
    if (query.isNotEmpty) _analytics?.logSearchTopic(query).ignore();

    _appliedPageSize = pageSize;
    try {
      final page = await _service.discoverWorks(
        query: query.isEmpty ? null : query,
        subfieldId: subfieldId,
        sort: sort,
        windowDays: _windowDays,
        perPage: pageSize,
      );
      works = page.works;
      _nextCursor = page.nextCursor;
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

  Future<void> refresh() => load();

  Future<void> retry() => load();

  Future<void> setSort(WorkSort value) async {
    if (value == sort) return;
    sort = value;
    await load();
  }

  Future<void> search(String value) async {
    final q = value.trim();
    if (q == query && state != ViewState.idle) return;
    query = q;
    await load();
  }

  Future<void> clearSearch() async {
    if (query.isEmpty) return;
    query = '';
    await load();
  }

  Future<void> setSubfield(String? id) async {
    final next = (id == null || id.isEmpty) ? null : id;
    if (next == subfieldId && state != ViewState.idle) return;
    subfieldId = next;
    await load();
  }

  /// Appends the next page, threading the OpenAlex cursor. No-op when a load is
  /// in flight, when the feed is exhausted, or before the first page.
  Future<void> loadMore() async {
    if (loadingMore || !hasMore || state != ViewState.success) return;
    loadingMore = true;
    notifyListeners();

    try {
      final page = await _service.discoverWorks(
        query: query.isEmpty ? null : query,
        subfieldId: subfieldId,
        sort: sort,
        windowDays: _windowDays,
        perPage: pageSize,
        cursor: _nextCursor,
      );
      works = [...works, ...page.works];
      _nextCursor = page.nextCursor;
    } catch (_) {
      // Keep the pages already loaded; the next scroll can retry.
    }

    loadingMore = false;
    notifyListeners();
  }

  /// Builds a report PDF of the current feed, saves it locally (share sheet, no
  /// backend needed) and best-effort uploads it to Firebase Storage under [uid].
  /// Fires the `export_pdf` analytics event. Task 8.3.
  Future<void> exportReport({required String uid}) async {
    if (!canExport || isExporting) return;

    isExporting = true;
    exportError = null;
    reportUrl = null;
    reportFilePath = null;
    notifyListeners();

    try {
      final label = query.isEmpty ? 'Discover feed' : query;
      final bytes = await buildRecentPapersReportPdf(field: label, works: works);
      final slug = query.isEmpty
          ? 'discover'
          : query.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_');
      final fileName =
          'report_${slug}_${DateTime.now().millisecondsSinceEpoch}.pdf';

      reportFilePath = await _saveReport(bytes, fileName);

      final storage = _storage;
      if (storage != null) {
        try {
          reportUrl = await storage.uploadReport(
            uid: uid,
            bytes: bytes,
            fileName: fileName,
          );
        } catch (_) {
          reportUrl = null;
        }
      }

      _analytics?.logExportPdf(label).ignore();
    } catch (_) {
      exportError = 'Failed to export the report. Please try again.';
    }

    isExporting = false;
    notifyListeners();
  }
}

import 'package:flutter/foundation.dart';

import '../firebase/analytics_service.dart';
import '../firebase/storage_service.dart';
import '../models/models.dart';
import '../services/openalex_service.dart';
import '../services/report_builder.dart';
import '../services/report_file_saver.dart';
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
  HomeViewModel(
    this._service, {
    AnalyticsApi? analytics,
    ReportStorageApi? storage,
    ReportFileSaver? saveReport,
  }) : _analytics = analytics,
       _storage = storage,
       _saveReport = saveReport ?? saveReportToTemp;

  final OpenAlexService _service;
  final AnalyticsApi? _analytics;
  final ReportStorageApi? _storage;
  final ReportFileSaver _saveReport;

  ViewState state = ViewState.idle;
  String? errorMessage;
  String lastQuery = '';

  /// PDF-report export state (task 8.3). [reportFilePath] is the locally-saved
  /// PDF (always produced, no backend needed); [reportUrl] is the Storage
  /// download URL when the best-effort cloud upload succeeds (needs Storage
  /// enabled); [exportError] is a user-facing failure message.
  bool isExporting = false;
  String? reportFilePath;
  String? reportUrl;
  String? exportError;

  /// Whether a report can be exported right now (a successful overview loaded
  /// and no export already running). Local export needs no Storage.
  bool get canExport => state == ViewState.success && summary != null;

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

    // Analytics: search_topic{keyword}. Fire-and-forget; never blocks the fetch
    // and never surfaces as an unhandled async error.
    _analytics?.logSearchTopic(query).ignore();

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

  /// Builds the dashboard PDF for the current overview, saves it locally (so it
  /// can be shared with no backend), and best-effort uploads it to Firebase
  /// Storage under [uid] (populating [reportUrl] when Storage is available).
  /// Fires the `export_pdf` analytics event. Task 8.3.
  Future<void> exportReport({required String uid}) async {
    final s = summary;
    if (s == null || isExporting) return;

    isExporting = true;
    exportError = null;
    reportUrl = null;
    reportFilePath = null;
    notifyListeners();

    try {
      final bytes = await buildDashboardReportPdf(
        topic: lastQuery,
        totalPublications: s.totalPublications,
        averageCitations: s.averageCitations,
        mostActiveYear: s.mostActiveYear,
        topJournal: s.topJournal,
        topAuthor: s.topAuthor,
        mostInfluentialTitle: s.mostInfluential?.title,
        years: yearCounts,
        trendLabel: trendClassification?.category.name,
      );
      final slug = lastQuery.isEmpty
          ? 'report'
          : lastQuery.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_');
      final fileName =
          'report_${slug}_${DateTime.now().millisecondsSinceEpoch}.pdf';

      // Primary path: save locally for the OS share sheet (no billing needed).
      reportFilePath = await _saveReport(bytes, fileName);

      // Bonus path: upload to Storage if it's configured/enabled. Failures here
      // (e.g. Storage not provisioned) never fail the export.
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

      _analytics?.logExportPdf(lastQuery).ignore();
    } catch (_) {
      exportError = 'Failed to export the report. Please try again.';
    }

    isExporting = false;
    notifyListeners();
  }
}

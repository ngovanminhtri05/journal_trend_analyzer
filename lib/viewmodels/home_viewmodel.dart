import 'package:flutter/foundation.dart';

import '../firebase/analytics_service.dart';
import '../firebase/storage_service.dart';
import '../models/models.dart';
import '../services/openalex_service.dart';
import '../services/report_builder.dart';
import '../services/report_file_saver.dart';
import 'view_state.dart';

/// Drives the Home overview (Phase 13.2).
///
/// Instead of OpenAlex aggregate totals, Home shows a light, per-paper feed of
/// the **most recent publications in the user's own research field** (chosen on
/// the Profile tab). No `group_by`, no counts — just recent work to skim. The
/// PDF export (Storage/Analytics demo, task 8.3) is kept, now producing a
/// "recent publications" report from this list.
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

  /// The field currently displayed (mirrors the user's chosen research field).
  String field = '';

  /// Recent publications in [field], newest first.
  List<Work> recentWorks = const [];

  /// PDF-report export state (task 8.3). [reportFilePath] is the locally-saved
  /// PDF; [reportUrl] is the Storage download URL when the best-effort upload
  /// succeeds; [exportError] is a user-facing failure message.
  bool isExporting = false;
  String? reportFilePath;
  String? reportUrl;
  String? exportError;

  /// Whether a report can be exported right now.
  bool get canExport => state == ViewState.success && recentWorks.isNotEmpty;

  /// Loads the most recent publications for [value] (the user's field). An empty
  /// field resets to the idle "pick a field" state.
  Future<void> loadForField(String value) async {
    final f = value.trim();
    if (f.isEmpty) {
      field = '';
      recentWorks = const [];
      state = ViewState.idle;
      notifyListeners();
      return;
    }

    field = f;
    state = ViewState.loading;
    errorMessage = null;
    notifyListeners();

    // Analytics: reuse search_topic{keyword} for the field load. Fire-and-forget.
    _analytics?.logSearchTopic(f).ignore();

    try {
      final works = await _service.recentWorksByTopic(f, perPage: 25);
      recentWorks = works;
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

  Future<void> retry() => loadForField(field);

  /// Builds a "recent publications in my field" PDF, saves it locally (share
  /// sheet, no backend needed) and best-effort uploads it to Firebase Storage
  /// under [uid]. Fires the `export_pdf` analytics event. Task 8.3 / Phase 13.2.
  Future<void> exportReport({required String uid}) async {
    if (!canExport || isExporting) return;

    isExporting = true;
    exportError = null;
    reportUrl = null;
    reportFilePath = null;
    notifyListeners();

    try {
      final bytes = await buildRecentPapersReportPdf(
        field: field,
        works: recentWorks,
      );
      final slug = field.isEmpty
          ? 'report'
          : field.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_');
      final fileName =
          'report_${slug}_${DateTime.now().millisecondsSinceEpoch}.pdf';

      // Primary path: save locally for the OS share sheet (no billing needed).
      reportFilePath = await _saveReport(bytes, fileName);

      // Bonus path: upload to Storage if configured. Failures never fail export.
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

      _analytics?.logExportPdf(field).ignore();
    } catch (_) {
      exportError = 'Failed to export the report. Please try again.';
    }

    isExporting = false;
    notifyListeners();
  }
}

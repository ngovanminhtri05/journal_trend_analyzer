import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'package:journal_trend_analyzer/firebase/analytics_service.dart';
import 'package:journal_trend_analyzer/firebase/storage_service.dart';
import 'package:journal_trend_analyzer/models/models.dart';
import 'package:journal_trend_analyzer/services/openalex_service.dart';
import 'package:journal_trend_analyzer/services/report_builder.dart';
import 'package:journal_trend_analyzer/viewmodels/dashboard_provider.dart';
import 'package:journal_trend_analyzer/viewmodels/home_viewmodel.dart';

class _FakeStorage implements ReportStorageApi {
  String? uploadedUid;
  String? uploadedFileName;
  int uploadedBytes = 0;
  Object? error;

  @override
  Future<String> uploadReport({
    required String uid,
    required Uint8List bytes,
    required String fileName,
  }) async {
    if (error != null) throw error!;
    uploadedUid = uid;
    uploadedFileName = fileName;
    uploadedBytes = bytes.length;
    return 'https://storage.example/reports/$uid/$fileName';
  }
}

class _RecordingAnalytics implements AnalyticsApi {
  final List<String> exportPdfTopics = [];
  @override
  Future<void> logExportPdf(String topic) async => exportPdfTopics.add(topic);
  @override
  Future<void> logLogin() async {}
  @override
  Future<void> logLogout() async {}
  @override
  Future<void> logSearchTopic(String keyword) async {}
  @override
  Future<void> logViewPublication({required String title, int? year}) async {}
  @override
  Future<void> logViewJournal(String name) async {}
  @override
  Future<void> logViewKeyword(String keyword) async {}
}

const _summary = DashboardSummary(
  totalPublications: 120,
  averageCitations: 8.5,
  mostActiveYear: 2021,
  topJournal: 'Nature',
  topAuthor: 'Ada Lovelace',
  mostInfluential: null,
);

OpenAlexService _unusedService() => OpenAlexService(
  client: MockClient((_) async => http.Response('{}', 200)),
  mailto: 't@e.com',
);

void main() {
  group('buildDashboardReportPdf', () {
    test('produces non-empty PDF bytes with the %PDF header', () async {
      final bytes = await buildDashboardReportPdf(
        topic: 'quantum computing',
        totalPublications: 120,
        averageCitations: 8.5,
        mostActiveYear: 2021,
        topJournal: 'Nature',
        topAuthor: 'Ada Lovelace',
        mostInfluentialTitle: 'A great paper',
        years: const [
          GroupByItem(key: '2021', keyDisplayName: '2021', count: 40),
          GroupByItem(key: '2020', keyDisplayName: '2020', count: 30),
        ],
        trendLabel: 'emerging',
        generatedAt: DateTime(2026, 7, 9, 10, 30),
      );

      expect(bytes.length, greaterThan(500));
      // "%PDF" magic number.
      expect(bytes.sublist(0, 4), [0x25, 0x50, 0x44, 0x46]);
    });
  });

  group('HomeViewModel.exportReport', () {
    test('uploads the report and exposes the URL + logs export_pdf', () async {
      final storage = _FakeStorage();
      final analytics = _RecordingAnalytics();
      final vm = HomeViewModel(
        _unusedService(),
        analytics: analytics,
        storage: storage,
      )
        ..lastQuery = 'quantum'
        ..summary = _summary;

      await vm.exportReport(uid: 'user-1');

      expect(vm.isExporting, isFalse);
      expect(vm.exportError, isNull);
      expect(vm.reportUrl, contains('reports/user-1/'));
      expect(storage.uploadedUid, 'user-1');
      expect(storage.uploadedBytes, greaterThan(0));
      expect(storage.uploadedFileName, startsWith('report_quantum_'));
      expect(analytics.exportPdfTopics, ['quantum']);
    });

    test('is a no-op when there is no summary', () async {
      final storage = _FakeStorage();
      final vm = HomeViewModel(_unusedService(), storage: storage);

      await vm.exportReport(uid: 'user-1');

      expect(vm.reportUrl, isNull);
      expect(storage.uploadedUid, isNull);
    });

    test('surfaces an error message when the upload fails', () async {
      final storage = _FakeStorage()..error = Exception('network down');
      final vm = HomeViewModel(_unusedService(), storage: storage)
        ..lastQuery = 'quantum'
        ..summary = _summary;

      await vm.exportReport(uid: 'user-1');

      expect(vm.reportUrl, isNull);
      expect(vm.exportError, isNotNull);
      expect(vm.isExporting, isFalse);
    });
  });
}

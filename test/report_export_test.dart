import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'package:journal_trend_analyzer/firebase/analytics_service.dart';
import 'package:journal_trend_analyzer/firebase/storage_service.dart';
import 'package:journal_trend_analyzer/models/models.dart';
import 'package:journal_trend_analyzer/services/openalex_service.dart';
import 'package:journal_trend_analyzer/services/report_builder.dart';
import 'package:journal_trend_analyzer/viewmodels/home_viewmodel.dart';
import 'package:journal_trend_analyzer/viewmodels/view_state.dart';

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

final _works = <Work>[
  const Work(
    id: 'W1',
    title: 'A great paper',
    publicationYear: 2021,
    citedByCount: 40,
    authors: <Author>[],
  ),
  const Work(
    id: 'W2',
    title: 'Another paper',
    publicationYear: 2020,
    citedByCount: 30,
    authors: <Author>[],
  ),
];

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
    // Fake saver so tests never touch path_provider; returns a deterministic path.
    Future<String> fakeSaver(Uint8List bytes, String fileName) async =>
        '/tmp/$fileName';

    test('saves locally, uploads, exposes URL + logs export_pdf', () async {
      final storage = _FakeStorage();
      final analytics = _RecordingAnalytics();
      final vm =
          HomeViewModel(
              _unusedService(),
              analytics: analytics,
              storage: storage,
              saveReport: fakeSaver,
            )
            ..query = 'quantum'
            ..works = _works
            ..state = ViewState.success;

      await vm.exportReport(uid: 'user-1');

      expect(vm.isExporting, isFalse);
      expect(vm.exportError, isNull);
      expect(vm.reportFilePath, startsWith('/tmp/report_quantum_'));
      expect(vm.reportUrl, contains('reports/user-1/'));
      expect(storage.uploadedUid, 'user-1');
      expect(storage.uploadedBytes, greaterThan(0));
      expect(storage.uploadedFileName, startsWith('report_quantum_'));
      expect(analytics.exportPdfTopics, ['quantum']);
    });

    test('is a no-op when there is no summary', () async {
      final storage = _FakeStorage();
      final vm = HomeViewModel(
        _unusedService(),
        storage: storage,
        saveReport: fakeSaver,
      );

      await vm.exportReport(uid: 'user-1');

      expect(vm.reportFilePath, isNull);
      expect(vm.reportUrl, isNull);
      expect(storage.uploadedUid, isNull);
    });

    test('still saves locally (no error) when the upload fails', () async {
      // Storage disabled / offline: cloud upload throws, local export succeeds.
      final storage = _FakeStorage()..error = Exception('storage not enabled');
      final analytics = _RecordingAnalytics();
      final vm =
          HomeViewModel(
              _unusedService(),
              analytics: analytics,
              storage: storage,
              saveReport: fakeSaver,
            )
            ..query = 'quantum'
            ..works = _works
            ..state = ViewState.success;

      await vm.exportReport(uid: 'user-1');

      expect(vm.exportError, isNull);
      expect(vm.reportFilePath, startsWith('/tmp/report_quantum_'));
      expect(vm.reportUrl, isNull);
      expect(analytics.exportPdfTopics, ['quantum']);
    });

    test('exports locally with no Storage configured at all', () async {
      final vm = HomeViewModel(_unusedService(), saveReport: fakeSaver)
        ..query = 'quantum'
        ..works = _works
        ..state = ViewState.success;

      await vm.exportReport(uid: 'anonymous');

      expect(vm.reportFilePath, isNotNull);
      expect(vm.reportUrl, isNull);
      expect(vm.exportError, isNull);
    });

    test('surfaces an error when the PDF cannot be saved', () async {
      final vm =
          HomeViewModel(
              _unusedService(),
              saveReport: (bytes, name) async => throw Exception('disk full'),
            )
            ..query = 'quantum'
            ..works = _works
            ..state = ViewState.success;

      await vm.exportReport(uid: 'user-1');

      expect(vm.exportError, isNotNull);
      expect(vm.reportFilePath, isNull);
      expect(vm.isExporting, isFalse);
    });
  });
}

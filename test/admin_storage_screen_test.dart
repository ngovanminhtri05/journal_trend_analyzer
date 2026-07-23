import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:journal_trend_analyzer/firebase/admin_storage_service.dart';
import 'package:journal_trend_analyzer/screens/admin_storage_screen.dart';
import 'package:journal_trend_analyzer/viewmodels/admin_storage_viewmodel.dart';

/// Fake backing the Storage admin screen without Cloud Functions.
class _FakeApi implements AdminStorageApi {
  _FakeApi(this._reports);

  List<AdminReportFile> _reports;
  final deleted = <String>[];

  @override
  Future<List<AdminReportFile>> listReports() async => _reports;

  @override
  Future<String> getReportUrl(String path) async => 'https://example/$path';

  @override
  Future<void> deleteReport(String path) async {
    deleted.add(path);
    _reports = _reports.where((r) => r.path != path).toList();
  }
}

void main() {
  testWidgets('lists each uploaded report', (tester) async {
    final vm = AdminStorageViewModel(
      _FakeApi([
        const AdminReportFile(
          path: 'reports/u1/report_a.pdf',
          size: 2048,
          uid: 'u1',
        ),
      ]),
    );

    await tester.pumpWidget(
      MaterialApp(home: AdminStorageScreen(viewModel: vm)),
    );
    await tester.pumpAndSettle();

    expect(find.text('report_a.pdf'), findsOneWidget);
    expect(find.textContaining('u1'), findsOneWidget);
  });

  testWidgets('deleting a report confirms then removes it', (tester) async {
    final api = _FakeApi([
      const AdminReportFile(
        path: 'reports/u1/report_a.pdf',
        size: 2048,
        uid: 'u1',
      ),
    ]);
    final vm = AdminStorageViewModel(api);

    await tester.pumpWidget(
      MaterialApp(home: AdminStorageScreen(viewModel: vm)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();

    // Confirm dialog → Delete.
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(api.deleted, ['reports/u1/report_a.pdf']);
    expect(find.text('No reports uploaded yet.'), findsOneWidget);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:journal_trend_analyzer/firebase/admin_storage_service.dart';
import 'package:journal_trend_analyzer/viewmodels/admin_storage_viewmodel.dart';
import 'package:journal_trend_analyzer/viewmodels/view_state.dart';

class _FakeAdminStorageApi implements AdminStorageApi {
  List<AdminReportFile> reports = const [];
  Object? error;
  final List<String> deleted = [];

  @override
  Future<List<AdminReportFile>> listReports() async {
    if (error != null) throw error!;
    return reports;
  }

  @override
  Future<String> getReportUrl(String path) async {
    if (error != null) throw error!;
    return 'https://signed.example/$path';
  }

  @override
  Future<void> deleteReport(String path) async {
    if (error != null) throw error!;
    deleted.add(path);
  }
}

const _report = AdminReportFile(
  path: 'reports/u1/2026-report.pdf',
  size: 1024,
  uid: 'u1',
);

void main() {
  group('AdminStorageViewModel', () {
    test('loads reports', () async {
      final api = _FakeAdminStorageApi()..reports = [_report];
      final vm = AdminStorageViewModel(api);

      await vm.load();

      expect(vm.state, ViewState.success);
      expect(vm.reports.single.path, _report.path);
    });

    test('reports empty when there are no reports', () async {
      final vm = AdminStorageViewModel(_FakeAdminStorageApi());

      await vm.load();

      expect(vm.state, ViewState.empty);
    });

    test('openReport returns a signed URL', () async {
      final vm = AdminStorageViewModel(_FakeAdminStorageApi());

      final url = await vm.openReport(_report.path);

      expect(url, 'https://signed.example/${_report.path}');
    });

    test('delete removes the report from the local list', () async {
      final api = _FakeAdminStorageApi()..reports = [_report];
      final vm = AdminStorageViewModel(api);
      await vm.load();

      await vm.delete(_report.path);

      expect(api.deleted, [_report.path]);
      expect(vm.reports, isEmpty);
      expect(vm.state, ViewState.empty);
    });
  });
}

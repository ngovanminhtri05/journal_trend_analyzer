import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:journal_trend_analyzer/firebase/admin_logs_service.dart';
import 'package:journal_trend_analyzer/viewmodels/admin_logs_viewmodel.dart';
import 'package:journal_trend_analyzer/viewmodels/view_state.dart';

class _FakeAdminLogsApi implements AdminLogsApi {
  List<AdminEventLog> events = const [];
  Object? error;

  @override
  Future<List<AdminEventLog>> recentEvents({int limit = 100}) async {
    if (error != null) throw error!;
    return events;
  }
}

void main() {
  group('AdminLogsViewModel', () {
    test('loads the recent events', () async {
      final api = _FakeAdminLogsApi()
        ..events = [
          AdminEventLog(uid: 'u1', name: 'login', timestamp: DateTime(2026)),
        ];
      final vm = AdminLogsViewModel(api);

      await vm.load();

      expect(vm.state, ViewState.success);
      expect(vm.events, hasLength(1));
    });

    test('reports empty when there are no events', () async {
      final vm = AdminLogsViewModel(_FakeAdminLogsApi());

      await vm.load();

      expect(vm.state, ViewState.empty);
    });

    test('reports an error and retry reloads', () async {
      final api = _FakeAdminLogsApi()..error = Exception('offline');
      final vm = AdminLogsViewModel(api);

      await vm.load();
      expect(vm.state, ViewState.error);

      api.error = null;
      api.events = [
        AdminEventLog(uid: 'u1', name: 'login', timestamp: DateTime(2026)),
      ];
      await vm.retry();
      expect(vm.state, ViewState.success);
    });

    test('a missing Firestore database yields an actionable message', () async {
      final api = _FakeAdminLogsApi()
        ..error = FirebaseException(plugin: 'cloud_firestore', code: 'not-found');
      final vm = AdminLogsViewModel(api);

      await vm.load();

      expect(vm.state, ViewState.error);
      expect(vm.errorMessage, contains('Firestore database'));
    });
  });
}

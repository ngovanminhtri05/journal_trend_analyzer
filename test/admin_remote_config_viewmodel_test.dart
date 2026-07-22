import 'package:flutter_test/flutter_test.dart';
import 'package:journal_trend_analyzer/firebase/admin_remote_config_service.dart';
import 'package:journal_trend_analyzer/firebase/admin_users_service.dart'
    show AdminException;
import 'package:journal_trend_analyzer/viewmodels/admin_remote_config_viewmodel.dart';
import 'package:journal_trend_analyzer/viewmodels/view_state.dart';

class _FakeAdminRemoteConfigApi implements AdminRemoteConfigApi {
  List<RemoteConfigParam> parameters = const [];
  Object? error;
  final List<RemoteConfigParam> updated = [];

  @override
  Future<List<RemoteConfigParam>> getTemplate() async {
    if (error != null) throw error!;
    return parameters;
  }

  @override
  Future<void> updateParameter({
    required String key,
    required String defaultValue,
  }) async {
    if (error != null) throw error!;
    updated.add(RemoteConfigParam(key: key, defaultValue: defaultValue));
  }
}

void main() {
  group('AdminRemoteConfigViewModel', () {
    test('loads parameters', () async {
      final api = _FakeAdminRemoteConfigApi()
        ..parameters = [
          const RemoteConfigParam(key: 'max_journals', defaultValue: '15'),
        ];
      final vm = AdminRemoteConfigViewModel(api);

      await vm.load();

      expect(vm.state, ViewState.success);
      expect(vm.parameters.single.key, 'max_journals');
    });

    test('reports empty when there are no parameters', () async {
      final vm = AdminRemoteConfigViewModel(_FakeAdminRemoteConfigApi());

      await vm.load();

      expect(vm.state, ViewState.empty);
    });

    test('updateParameter refreshes the local list on success', () async {
      final api = _FakeAdminRemoteConfigApi()
        ..parameters = [
          const RemoteConfigParam(key: 'max_journals', defaultValue: '15'),
        ];
      final vm = AdminRemoteConfigViewModel(api);
      await vm.load();

      await vm.updateParameter('max_journals', '25');

      expect(api.updated.single.defaultValue, '25');
      expect(vm.parameters.single.defaultValue, '25');
    });

    test('an update failure surfaces via errorMessage', () async {
      final api = _FakeAdminRemoteConfigApi()
        ..parameters = [
          const RemoteConfigParam(key: 'max_journals', defaultValue: '15'),
        ];
      final vm = AdminRemoteConfigViewModel(api);
      await vm.load();
      api.error = const AdminException('publish failed');

      await vm.updateParameter('max_journals', '25');

      expect(vm.errorMessage, 'publish failed');
      // The optimistic value is not applied when the call failed.
      expect(vm.parameters.single.defaultValue, '15');
    });
  });
}

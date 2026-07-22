import 'package:flutter_test/flutter_test.dart';
import 'package:journal_trend_analyzer/firebase/admin_users_service.dart';
import 'package:journal_trend_analyzer/viewmodels/admin_users_viewmodel.dart';
import 'package:journal_trend_analyzer/viewmodels/view_state.dart';

class _FakeAdminUsersApi implements AdminUsersApi {
  List<AdminUserSummary> users = const [];
  Object? error;
  final List<String> disabledCalls = [];
  final List<String> deletedCalls = [];

  @override
  Future<AdminUsersPage> listUsers({String? pageToken}) async {
    if (error != null) throw error!;
    return AdminUsersPage(users: users);
  }

  @override
  Future<void> setUserDisabled({
    required String uid,
    required bool disabled,
  }) async {
    if (error != null) throw error!;
    disabledCalls.add(uid);
  }

  @override
  Future<void> deleteUser(String uid) async {
    if (error != null) throw error!;
    deletedCalls.add(uid);
  }
}

const _ada = AdminUserSummary(
  uid: 'u1',
  email: 'ada@example.com',
  displayName: 'Ada',
  disabled: false,
  isAdmin: false,
);

void main() {
  group('AdminUsersViewModel', () {
    test('loads users', () async {
      final api = _FakeAdminUsersApi()..users = [_ada];
      final vm = AdminUsersViewModel(api);

      await vm.load();

      expect(vm.state, ViewState.success);
      expect(vm.users, [_ada]);
    });

    test('reports empty when there are no users', () async {
      final vm = AdminUsersViewModel(_FakeAdminUsersApi());

      await vm.load();

      expect(vm.state, ViewState.empty);
    });

    test('reports an error via AdminException message', () async {
      final api = _FakeAdminUsersApi()..error = const AdminException('nope');
      final vm = AdminUsersViewModel(api);

      await vm.load();

      expect(vm.state, ViewState.error);
      expect(vm.errorMessage, 'nope');
    });

    test('setDisabled updates the local user and clears busy state', () async {
      final api = _FakeAdminUsersApi()..users = [_ada];
      final vm = AdminUsersViewModel(api);
      await vm.load();

      await vm.setDisabled('u1', true);

      expect(api.disabledCalls, ['u1']);
      expect(vm.users.single.disabled, isTrue);
      expect(vm.isBusy('u1'), isFalse);
    });

    test('delete removes the user from the local list', () async {
      final api = _FakeAdminUsersApi()..users = [_ada];
      final vm = AdminUsersViewModel(api);
      await vm.load();

      await vm.delete('u1');

      expect(api.deletedCalls, ['u1']);
      expect(vm.users, isEmpty);
    });
  });
}

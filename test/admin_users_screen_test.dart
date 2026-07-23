import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:journal_trend_analyzer/firebase/admin_users_service.dart';
import 'package:journal_trend_analyzer/screens/admin_users_screen.dart';
import 'package:journal_trend_analyzer/viewmodels/admin_users_viewmodel.dart';

/// Fake backing the Users admin screen without Cloud Functions.
class _FakeApi implements AdminUsersApi {
  _FakeApi(this._users);

  List<AdminUserSummary> _users;
  final disabledCalls = <(String, bool)>[];
  final deleted = <String>[];

  @override
  Future<AdminUsersPage> listUsers({String? pageToken}) async =>
      AdminUsersPage(users: _users);

  @override
  Future<void> setUserDisabled({
    required String uid,
    required bool disabled,
  }) async {
    disabledCalls.add((uid, disabled));
  }

  @override
  Future<void> deleteUser(String uid) async {
    deleted.add(uid);
    _users = _users.where((u) => u.uid != uid).toList();
  }
}

const _active = AdminUserSummary(
  uid: 'u1',
  email: 'ada@example.com',
  disabled: false,
  isAdmin: false,
);

void main() {
  testWidgets('lists each account with its status', (tester) async {
    final vm = AdminUsersViewModel(_FakeApi([_active]));

    await tester.pumpWidget(MaterialApp(home: AdminUsersScreen(viewModel: vm)));
    await tester.pumpAndSettle();

    expect(find.text('ada@example.com'), findsOneWidget);
    expect(find.text('Active'), findsOneWidget);
  });

  testWidgets('disabling an account confirms then calls setUserDisabled', (
    tester,
  ) async {
    final api = _FakeApi([_active]);
    final vm = AdminUsersViewModel(api);

    await tester.pumpWidget(MaterialApp(home: AdminUsersScreen(viewModel: vm)));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Disable'));
    await tester.pumpAndSettle();

    // Confirm dialog → Disable.
    await tester.tap(find.widgetWithText(FilledButton, 'Disable'));
    await tester.pumpAndSettle();

    expect(api.disabledCalls, [('u1', true)]);
  });

  testWidgets('deleting the last account shows the empty state', (tester) async {
    final api = _FakeApi([_active]);
    final vm = AdminUsersViewModel(api);

    await tester.pumpWidget(MaterialApp(home: AdminUsersScreen(viewModel: vm)));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(api.deleted, ['u1']);
    expect(find.text('No users found.'), findsOneWidget);
  });
}

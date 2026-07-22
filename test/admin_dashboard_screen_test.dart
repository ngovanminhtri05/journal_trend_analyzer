import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:journal_trend_analyzer/firebase/app_user.dart';
import 'package:journal_trend_analyzer/firebase/auth_service.dart';
import 'package:journal_trend_analyzer/screens/profile_screen.dart';
import 'package:journal_trend_analyzer/viewmodels/auth_viewmodel.dart';
import 'package:provider/provider.dart';

class _FakeAuthApi implements AuthApi {
  final _controller = StreamController<AppUser?>.broadcast();

  void emit(AppUser? user) => _controller.add(user);

  @override
  Stream<AppUser?> get authStateChanges => _controller.stream;
  @override
  AppUser? currentUser;
  @override
  Future<AppUser?> signInWithGoogle() async => null;
  @override
  Future<void> signOut() async {}

  void dispose() => _controller.close();
}

const _ada = AppUser(uid: 'u1', displayName: 'Ada', email: 'ada@example.com');

void main() {
  group('ProfileScreen admin tile', () {
    testWidgets('hidden for a non-admin user', (tester) async {
      final api = _FakeAuthApi();
      final vm = AuthViewModel(api);
      addTearDown(() {
        vm.dispose();
        api.dispose();
      });

      api.emit(_ada);
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<AuthViewModel>.value(
            value: vm,
            child: const Scaffold(body: ProfileScreen()),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Admin Dashboard'), findsNothing);
    });

    testWidgets('shown for an admin user', (tester) async {
      final api = _FakeAuthApi();
      final vm = AuthViewModel(api);
      addTearDown(() {
        vm.dispose();
        api.dispose();
      });

      api.emit(_ada);
      await tester.pump();
      vm.isAdmin = true;
      vm.notifyListeners();

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<AuthViewModel>.value(
            value: vm,
            child: const Scaffold(body: ProfileScreen()),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Admin Dashboard'), findsOneWidget);
    });
  });
}

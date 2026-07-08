import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:journal_trend_analyzer/firebase/app_user.dart';
import 'package:journal_trend_analyzer/firebase/auth_service.dart';
import 'package:journal_trend_analyzer/screens/profile_screen.dart';
import 'package:journal_trend_analyzer/viewmodels/auth_viewmodel.dart';
import 'package:provider/provider.dart';

/// In-memory [AuthApi] so the screen can be pumped with no Firebase.
class _FakeAuthApi implements AuthApi {
  final _controller = StreamController<AppUser?>.broadcast();
  bool didSignOut = false;

  void emit(AppUser? user) => _controller.add(user);

  @override
  Stream<AppUser?> get authStateChanges => _controller.stream;

  @override
  AppUser? currentUser;

  @override
  Future<AppUser?> signInWithGoogle() async => null;

  @override
  Future<void> signOut() async => didSignOut = true;

  void dispose() => _controller.close();
}

// No photoUrl so the widget shows the initial and never hits the network in tests.
const _ada = AppUser(uid: 'u1', displayName: 'Ada', email: 'ada@example.com');

void main() {
  group('ProfileScreen', () {
    testWidgets('shows the placeholder when no AuthViewModel is provided', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: ProfileScreen())),
      );

      expect(find.text('Firebase not configured yet'), findsOneWidget);
      expect(find.text('Sign out'), findsNothing);
    });

    testWidgets('shows account info and Sign out when signed in', (
      tester,
    ) async {
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
      await tester.pump(); // let the emitted user propagate

      expect(find.text('Ada'), findsWidgets);
      expect(find.text('ada@example.com'), findsWidgets);
      expect(find.text('u1'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Sign out'), findsOneWidget);
    });

    testWidgets('tapping Sign out delegates to the ViewModel', (tester) async {
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

      await tester.tap(find.widgetWithText(FilledButton, 'Sign out'));
      await tester.pump();

      expect(api.didSignOut, isTrue);
    });
  });
}

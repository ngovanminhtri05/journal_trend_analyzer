import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:journal_trend_analyzer/firebase/admin_access_service.dart';
import 'package:journal_trend_analyzer/firebase/app_user.dart';
import 'package:journal_trend_analyzer/firebase/auth_service.dart';
import 'package:journal_trend_analyzer/viewmodels/auth_viewmodel.dart';

/// In-memory [AuthApi] so the ViewModel can be tested with no Firebase.
class _FakeAuthApi implements AuthApi {
  final _controller = StreamController<AppUser?>.broadcast();

  AppUser? signInResult;
  Object? signInError;
  bool didSignOut = false;

  /// Pushes an auth-state change to subscribers.
  void emit(AppUser? user) => _controller.add(user);

  @override
  Stream<AppUser?> get authStateChanges => _controller.stream;

  @override
  AppUser? currentUser;

  @override
  Future<AppUser?> signInWithGoogle() async {
    if (signInError != null) throw signInError!;
    return signInResult;
  }

  @override
  Future<void> signOut() async => didSignOut = true;

  void dispose() => _controller.close();
}

const _ada = AppUser(uid: 'u1', displayName: 'Ada', email: 'ada@example.com');

void main() {
  group('AuthViewModel', () {
    late _FakeAuthApi api;
    late AuthViewModel vm;

    setUp(() {
      api = _FakeAuthApi();
      vm = AuthViewModel(api);
    });

    tearDown(() {
      vm.dispose();
      api.dispose();
    });

    test('starts in unknown state', () {
      expect(vm.status, AuthStatus.unknown);
      expect(vm.user, isNull);
    });

    test('becomes signedIn when a user is emitted', () async {
      api.emit(_ada);
      await Future<void>.delayed(Duration.zero);

      expect(vm.status, AuthStatus.signedIn);
      expect(vm.user, _ada);
    });

    test('becomes signedOut when null is emitted', () async {
      api.emit(_ada);
      await Future<void>.delayed(Duration.zero);
      api.emit(null);
      await Future<void>.delayed(Duration.zero);

      expect(vm.status, AuthStatus.signedOut);
      expect(vm.user, isNull);
    });

    test('signInWithGoogle toggles isSigningIn and clears on success', () async {
      api.signInResult = _ada;

      final future = vm.signInWithGoogle();
      expect(vm.isSigningIn, isTrue);
      await future;

      expect(vm.isSigningIn, isFalse);
      expect(vm.errorMessage, isNull);
    });

    test('surfaces AuthException message', () async {
      api.signInError = const AuthException('Account exists.');

      await vm.signInWithGoogle();

      expect(vm.isSigningIn, isFalse);
      expect(vm.errorMessage, 'Account exists.');
    });

    test('shows a generic message for unexpected errors', () async {
      api.signInError = StateError('boom');

      await vm.signInWithGoogle();

      expect(vm.errorMessage, 'Sign-in failed. Please try again.');
    });

    test('ignores a second concurrent sign-in attempt', () async {
      api.signInResult = _ada;
      final first = vm.signInWithGoogle();
      // Second call while the first is in flight is a no-op.
      final second = vm.signInWithGoogle();
      await Future.wait([first, second]);
      expect(vm.isSigningIn, isFalse);
    });

    test('signOut delegates to the api', () async {
      await vm.signOut();
      expect(api.didSignOut, isTrue);
    });
  });

  group('AuthViewModel admin status', () {
    test('defaults isAdmin to false with no AdminAccessApi supplied', () async {
      final api = _FakeAuthApi()..signInResult = _ada;
      final vm = AuthViewModel(api);
      addTearDown(() {
        vm.dispose();
        api.dispose();
      });
      api.emit(_ada);
      await Future<void>.delayed(Duration.zero);

      expect(vm.isAdmin, isFalse);
    });

    test('refreshes isAdmin from AdminAccessApi when a user signs in', () async {
      final api = _FakeAuthApi();
      final vm = AuthViewModel(
        api,
        adminAccess: const StaticAdminAccess(isAdmin: true),
      );
      addTearDown(() {
        vm.dispose();
        api.dispose();
      });

      api.emit(_ada);
      await Future<void>.delayed(Duration.zero);

      expect(vm.isAdmin, isTrue);
    });

    test('resets isAdmin to false on sign-out', () async {
      final api = _FakeAuthApi();
      final vm = AuthViewModel(
        api,
        adminAccess: const StaticAdminAccess(isAdmin: true),
      );
      addTearDown(() {
        vm.dispose();
        api.dispose();
      });

      api.emit(_ada);
      await Future<void>.delayed(Duration.zero);
      expect(vm.isAdmin, isTrue);

      api.emit(null);
      await Future<void>.delayed(Duration.zero);
      expect(vm.isAdmin, isFalse);
    });
  });
}

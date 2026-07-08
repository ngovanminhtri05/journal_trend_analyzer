import 'dart:async';

import 'package:flutter/foundation.dart';

import '../firebase/auth_service.dart';
import '../firebase/app_user.dart';

/// High-level auth state the router (auth gate) switches on.
///
/// `unknown` covers the brief window before the first `authStateChanges` event
/// arrives, so the app can show a splash instead of flashing the login screen.
enum AuthStatus { unknown, signedOut, signedIn }

/// Drives the Login screen and the auth gate.
///
/// Subscribes to [AuthApi.authStateChanges] and mirrors it into [status] /
/// [user]. Holds the transient sign-in progress + error for the View. Contains
/// no Firebase types — it depends only on [AuthApi], so it is fully unit
/// testable with a fake.
class AuthViewModel extends ChangeNotifier {
  AuthViewModel(this._auth) {
    _sub = _auth.authStateChanges.listen(_onUserChanged);
  }

  final AuthApi _auth;
  late final StreamSubscription<AppUser?> _sub;

  AuthStatus status = AuthStatus.unknown;
  AppUser? user;

  /// True while the Google chooser / Firebase exchange is in flight.
  bool isSigningIn = false;

  /// Last sign-in error message, or null. Cleared on a new attempt.
  String? errorMessage;

  Future<void> signInWithGoogle() async {
    if (isSigningIn) return;
    isSigningIn = true;
    errorMessage = null;
    notifyListeners();

    try {
      await _auth.signInWithGoogle();
      // A successful sign-in flows back through authStateChanges → _onUserChanged.
    } on AuthException catch (e) {
      errorMessage = e.message;
    } catch (_) {
      errorMessage = 'Sign-in failed. Please try again.';
    } finally {
      isSigningIn = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } on AuthException catch (e) {
      errorMessage = e.message;
      notifyListeners();
    }
    // Sign-out likewise propagates via authStateChanges.
  }

  void _onUserChanged(AppUser? next) {
    user = next;
    status = next == null ? AuthStatus.signedOut : AuthStatus.signedIn;
    notifyListeners();
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

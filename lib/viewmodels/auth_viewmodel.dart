import 'dart:async';

import 'package:flutter/foundation.dart';

import '../firebase/admin_access_service.dart';
import '../firebase/analytics_service.dart';
import '../firebase/auth_service.dart';
import '../firebase/app_user.dart';
import '../firebase/messaging_service.dart';

/// High-level auth state the router (auth gate) switches on.
///
/// `unknown` covers the brief window before the first `authStateChanges` event
/// arrives, so the app can show a splash instead of flashing the login screen.
enum AuthStatus { unknown, signedOut, signedIn }

/// Drives the Login screen and the auth gate.
///
/// Subscribes to [AuthApi.authStateChanges] and mirrors it into [status] /
/// [user]. Holds the transient sign-in progress + error for the View. Contains
/// no Firebase types — it depends only on [AuthApi] (and optionally
/// [AdminAccessApi]), so it is fully unit testable with fakes.
class AuthViewModel extends ChangeNotifier {
  AuthViewModel(
    this._auth, {
    AnalyticsApi? analytics,
    AdminAccessApi? adminAccess,
    MessagingApi? messaging,
  }) : _analytics = analytics,
       _adminAccess = adminAccess,
       _messaging = messaging {
    _sub = _auth.authStateChanges.listen(_onUserChanged);
  }

  final AuthApi _auth;
  final AnalyticsApi? _analytics;
  final AdminAccessApi? _adminAccess;
  final MessagingApi? _messaging;
  late final StreamSubscription<AppUser?> _sub;

  /// The uid currently subscribed to its per-user push topic, so we can
  /// unsubscribe it when the user changes.
  String? _pushUid;

  AuthStatus status = AuthStatus.unknown;
  AppUser? user;

  /// True while the Google chooser / Firebase exchange is in flight.
  bool isSigningIn = false;

  /// Last sign-in error message, or null. Cleared on a new attempt.
  String? errorMessage;

  /// Whether the signed-in user carries the `admin` custom claim. Always
  /// `false` when signed out or when no [AdminAccessApi] was supplied.
  bool isAdmin = false;

  Future<void> signInWithGoogle() async {
    if (isSigningIn) return;
    isSigningIn = true;
    errorMessage = null;
    notifyListeners();

    try {
      final signedIn = await _auth.signInWithGoogle();
      // A successful sign-in flows back through authStateChanges → _onUserChanged.
      if (signedIn != null) _analytics?.logLogin();
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
      // Only count a logout that actually succeeded.
      _analytics?.logLogout();
    } on AuthException catch (e) {
      errorMessage = e.message;
      notifyListeners();
    }
    // Sign-out likewise propagates via authStateChanges.
  }

  void _onUserChanged(AppUser? next) {
    user = next;
    status = next == null ? AuthStatus.signedOut : AuthStatus.signedIn;
    if (next == null) {
      isAdmin = false;
    } else {
      unawaited(_refreshAdminStatus());
    }
    _syncPushTopic(next?.uid);
    notifyListeners();
  }

  /// Keeps the per-user push topic in sync with the signed-in user: unsubscribe
  /// the old uid, subscribe the new one. No-op without a [MessagingApi].
  void _syncPushTopic(String? uid) {
    final messaging = _messaging;
    if (messaging == null || _pushUid == uid) return;
    if (_pushUid != null) unawaited(messaging.unsubscribeFromUser(_pushUid!));
    if (uid != null) unawaited(messaging.subscribeToUser(uid));
    _pushUid = uid;
  }

  Future<void> _refreshAdminStatus() async {
    final access = _adminAccess;
    if (access == null) return;
    bool admin;
    try {
      admin = await access.isCurrentUserAdmin();
    } catch (_) {
      admin = false;
    }
    isAdmin = admin;
    notifyListeners();
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

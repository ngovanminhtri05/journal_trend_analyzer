import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'app_user.dart';

/// Contract the app depends on for authentication.
///
/// Views bind to an [AuthViewModel] which talks to this interface, never to the
/// Firebase SDK directly. [AuthService] is the production implementation; tests
/// provide a fake.
abstract interface class AuthApi {
  /// Emits the current user (or `null` when signed out) on every auth change.
  Stream<AppUser?> get authStateChanges;

  /// The currently signed-in user, or `null`.
  AppUser? get currentUser;

  /// Starts the Google Sign-In flow and signs the user into Firebase.
  ///
  /// Returns the signed-in [AppUser], or `null` if the user cancelled the
  /// Google chooser. Throws [AuthException] on a real failure.
  Future<AppUser?> signInWithGoogle();

  /// Signs out of both Firebase and Google.
  Future<void> signOut();
}

/// A typed authentication failure surfaced to the UI.
class AuthException implements Exception {
  const AuthException(this.message, {this.code});

  /// Human-readable message safe to show to the user.
  final String message;

  /// Underlying provider code (e.g. Firebase `account-exists-with-different-
  /// credential`), useful for logging.
  final String? code;

  @override
  String toString() => 'AuthException($code): $message';
}

/// Isolates every call into `google_sign_in` (v7) behind a tiny surface so the
/// rest of the code — and the tests — never touch the platform plugin.
abstract interface class GoogleAuthenticator {
  /// Runs the interactive Google chooser and returns a Firebase credential, or
  /// `null` if the user cancelled.
  Future<OAuthCredential?> credential();

  /// Signs the user out of the Google session on the device.
  Future<void> signOut();
}

/// Production [GoogleAuthenticator] backed by `google_sign_in` 7.x.
///
/// v7 changes vs v6: a single [GoogleSignIn.instance] that must be
/// [GoogleSignIn.initialize]d once, `authenticate()` (throws instead of
/// returning null on cancel), and a synchronous `authentication` getter that
/// exposes only the `idToken` — which is all Firebase needs.
class GoogleSignInAuthenticator implements GoogleAuthenticator {
  GoogleSignInAuthenticator({GoogleSignIn? signIn})
    : _signIn = signIn ?? GoogleSignIn.instance;

  final GoogleSignIn _signIn;
  bool _initialized = false;

  /// Web OAuth client id (needed on Android to receive an id token). Wired from
  /// Firebase config in the R2 setup step; safe to leave null for now.
  static String? serverClientId;

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    await _signIn.initialize(serverClientId: serverClientId);
    _initialized = true;
  }

  @override
  Future<OAuthCredential?> credential() async {
    await _ensureInitialized();
    try {
      final GoogleSignInAccount account = await _signIn.authenticate();
      final GoogleSignInAuthentication auth = account.authentication;
      return GoogleAuthProvider.credential(idToken: auth.idToken);
    } on GoogleSignInException catch (e) {
      // A cancelled chooser is a normal, non-error outcome.
      if (e.code == GoogleSignInExceptionCode.canceled) return null;
      throw AuthException(
        e.description ?? 'Google Sign-In failed.',
        code: e.code.name,
      );
    }
  }

  @override
  Future<void> signOut() => _signIn.signOut();
}

/// Firebase-backed authentication service (Google Sign-In).
///
/// Both dependencies are injectable so unit tests can supply a mocked
/// [FirebaseAuth] and a fake [GoogleAuthenticator]. [FirebaseAuth.instance] is
/// resolved lazily, so constructing this service never requires Firebase to be
/// initialised.
class AuthService implements AuthApi {
  AuthService({FirebaseAuth? auth, GoogleAuthenticator? google})
    : _injectedAuth = auth,
      _google = google ?? GoogleSignInAuthenticator();

  final FirebaseAuth? _injectedAuth;
  final GoogleAuthenticator _google;

  FirebaseAuth get _auth => _injectedAuth ?? FirebaseAuth.instance;

  @override
  Stream<AppUser?> get authStateChanges => _auth.authStateChanges().map(
    (user) => user == null ? null : AppUser.fromFirebase(user),
  );

  @override
  AppUser? get currentUser {
    final user = _auth.currentUser;
    return user == null ? null : AppUser.fromFirebase(user);
  }

  @override
  Future<AppUser?> signInWithGoogle() async {
    final credential = await _google.credential();
    if (credential == null) return null; // user cancelled the chooser
    try {
      final result = await _auth.signInWithCredential(credential);
      final user = result.user;
      return user == null ? null : AppUser.fromFirebase(user);
    } on FirebaseAuthException catch (e) {
      throw AuthException(e.message ?? 'Authentication failed.', code: e.code);
    }
  }

  @override
  Future<void> signOut() async {
    // Sign out of Google first so the next sign-in re-prompts the chooser.
    await _google.signOut();
    await _auth.signOut();
  }
}

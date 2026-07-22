import 'package:firebase_auth/firebase_auth.dart';

/// Contract for checking whether the signed-in user is an admin (custom claim).
///
/// ViewModels depend on this, never on `firebase_auth` directly, so the admin
/// gating stays testable ([StaticAdminAccess] for tests/previews).
abstract interface class AdminAccessApi {
  /// Whether the currently signed-in user carries the `admin` custom claim.
  /// Returns `false` (never throws) when nobody is signed in.
  Future<bool> isCurrentUserAdmin();
}

/// Firebase-backed [AdminAccessApi]. [FirebaseAuth.instance] is resolved lazily
/// so constructing this never requires Firebase.
///
/// Custom claims only appear on a *forced* ID token refresh — a claim granted
/// after the user's last sign-in would not show up on the cached token
/// otherwise — so this always calls `getIdTokenResult(true)`.
class AdminAccessService implements AdminAccessApi {
  AdminAccessService({FirebaseAuth? auth}) : _injected = auth;

  final FirebaseAuth? _injected;
  FirebaseAuth get _auth => _injected ?? FirebaseAuth.instance;

  @override
  Future<bool> isCurrentUserAdmin() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    final result = await user.getIdTokenResult(true);
    return result.claims?['admin'] == true;
  }
}

/// Fixed [AdminAccessApi] for tests, previews, or Firebase-free contexts.
class StaticAdminAccess implements AdminAccessApi {
  const StaticAdminAccess({this.isAdmin = false});

  final bool isAdmin;

  @override
  Future<bool> isCurrentUserAdmin() async => isAdmin;
}

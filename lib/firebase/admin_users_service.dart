import 'package:cloud_functions/cloud_functions.dart';

/// One row in the admin Users list.
class AdminUserSummary {
  const AdminUserSummary({
    required this.uid,
    this.email,
    this.displayName,
    required this.disabled,
    this.createdAt,
    required this.isAdmin,
  });

  final String uid;
  final String? email;
  final String? displayName;
  final bool disabled;
  final String? createdAt;
  final bool isAdmin;

  factory AdminUserSummary.fromMap(Map<String, dynamic> map) => AdminUserSummary(
    uid: map['uid'] as String,
    email: map['email'] as String?,
    displayName: map['displayName'] as String?,
    disabled: map['disabled'] as bool? ?? false,
    createdAt: map['createdAt'] as String?,
    isAdmin: map['isAdmin'] as bool? ?? false,
  );

  /// Best-effort human label (name → email → uid), matching [AppUser.label].
  String get label => (displayName?.isNotEmpty ?? false)
      ? displayName!
      : (email?.isNotEmpty ?? false)
      ? email!
      : uid;

  @override
  bool operator ==(Object other) =>
      other is AdminUserSummary &&
      other.uid == uid &&
      other.email == email &&
      other.displayName == displayName &&
      other.disabled == disabled &&
      other.createdAt == createdAt &&
      other.isAdmin == isAdmin;

  @override
  int get hashCode =>
      Object.hash(uid, email, displayName, disabled, createdAt, isAdmin);
}

/// A page of admin users (single page for this app — see plan's Global
/// Constraints; up to 1000 accounts).
class AdminUsersPage {
  const AdminUsersPage({required this.users, this.nextPageToken});

  final List<AdminUserSummary> users;
  final String? nextPageToken;
}

/// A typed admin-operation failure, safe to show to the UI.
class AdminException implements Exception {
  const AdminException(this.message);

  final String message;

  @override
  String toString() => 'AdminException: $message';
}

/// Contract for the admin user-management Cloud Functions.
abstract interface class AdminUsersApi {
  Future<AdminUsersPage> listUsers({String? pageToken});
  Future<void> setUserDisabled({required String uid, required bool disabled});
  Future<void> deleteUser(String uid);
}

/// Calls the `adminListUsers` / `adminSetUserDisabled` / `adminDeleteUser`
/// Cloud Functions (`functions/src/users.ts`). [FirebaseFunctions.instance] is
/// resolved lazily so constructing this never requires Firebase.
class AdminUsersService implements AdminUsersApi {
  AdminUsersService({FirebaseFunctions? functions}) : _injected = functions;

  final FirebaseFunctions? _injected;
  FirebaseFunctions get _functions => _injected ?? FirebaseFunctions.instance;

  @override
  Future<AdminUsersPage> listUsers({String? pageToken}) async {
    try {
      final result = await _functions
          .httpsCallable('adminListUsers')
          .call<dynamic>({'pageToken': ?pageToken});
      final data = Map<String, dynamic>.from(result.data as Map);
      final users = (data['users'] as List)
          .map(
            (u) => AdminUserSummary.fromMap(Map<String, dynamic>.from(u as Map)),
          )
          .toList();
      return AdminUsersPage(
        users: users,
        nextPageToken: data['nextPageToken'] as String?,
      );
    } on FirebaseFunctionsException catch (e) {
      throw AdminException(e.message ?? 'Failed to list users.');
    }
  }

  @override
  Future<void> setUserDisabled({
    required String uid,
    required bool disabled,
  }) async {
    try {
      await _functions.httpsCallable('adminSetUserDisabled').call<dynamic>({
        'uid': uid,
        'disabled': disabled,
      });
    } on FirebaseFunctionsException catch (e) {
      throw AdminException(e.message ?? 'Failed to update the user.');
    }
  }

  @override
  Future<void> deleteUser(String uid) async {
    try {
      await _functions.httpsCallable('adminDeleteUser').call<dynamic>({
        'uid': uid,
      });
    } on FirebaseFunctionsException catch (e) {
      throw AdminException(e.message ?? 'Failed to delete the user.');
    }
  }
}

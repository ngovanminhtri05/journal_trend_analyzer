import 'package:firebase_auth/firebase_auth.dart' show User;

/// Framework-agnostic view of a signed-in user.
///
/// The rest of the app (ViewModels, Views) depends on this immutable value
/// object rather than the Firebase `User`, so no layer above `firebase/` imports
/// the Firebase SDK directly (MVVM decoupling).
class AppUser {
  const AppUser({
    required this.uid,
    this.displayName,
    this.email,
    this.photoUrl,
  });

  final String uid;
  final String? displayName;
  final String? email;
  final String? photoUrl;

  /// Adapts a Firebase [User] into the app's own model.
  factory AppUser.fromFirebase(User user) => AppUser(
    uid: user.uid,
    displayName: user.displayName,
    email: user.email,
    photoUrl: user.photoURL,
  );

  /// Best-effort human label for the account (name → email → uid).
  String get label =>
      (displayName?.isNotEmpty ?? false)
          ? displayName!
          : (email?.isNotEmpty ?? false)
          ? email!
          : uid;

  @override
  bool operator ==(Object other) =>
      other is AppUser &&
      other.uid == uid &&
      other.displayName == displayName &&
      other.email == email &&
      other.photoUrl == photoUrl;

  @override
  int get hashCode => Object.hash(uid, displayName, email, photoUrl);
}

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:journal_trend_analyzer/firebase/app_user.dart';
import 'package:journal_trend_analyzer/firebase/auth_service.dart';
import 'package:mocktail/mocktail.dart';

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

class _MockUserCredential extends Mock implements UserCredential {}

class _MockUser extends Mock implements User {}

/// Fake authenticator: isolates google_sign_in so the service can be tested
/// without the platform plugin. Returns a real (pure-Dart) OAuthCredential.
class _FakeGoogleAuthenticator implements GoogleAuthenticator {
  _FakeGoogleAuthenticator({this.credentialResult, this.throwOnCredential});

  final OAuthCredential? credentialResult;
  final Object? throwOnCredential;
  bool signedOut = false;

  @override
  Future<OAuthCredential?> credential() async {
    if (throwOnCredential != null) throw throwOnCredential!;
    return credentialResult;
  }

  @override
  Future<void> signOut() async => signedOut = true;
}

OAuthCredential _googleCredential() =>
    GoogleAuthProvider.credential(idToken: 'id-token-abc');

void main() {
  setUpAll(() {
    registerFallbackValue(_googleCredential());
  });

  group('AuthService.signInWithGoogle', () {
    test('returns an AppUser on a successful sign-in', () async {
      final auth = _MockFirebaseAuth();
      final user = _MockUser();
      when(() => user.uid).thenReturn('u1');
      when(() => user.displayName).thenReturn('Ada Lovelace');
      when(() => user.email).thenReturn('ada@example.com');
      when(() => user.photoURL).thenReturn('https://img/ada.png');
      final cred = _MockUserCredential();
      when(() => cred.user).thenReturn(user);
      when(
        () => auth.signInWithCredential(any()),
      ).thenAnswer((_) async => cred);

      final service = AuthService(
        auth: auth,
        google: _FakeGoogleAuthenticator(credentialResult: _googleCredential()),
      );

      final result = await service.signInWithGoogle();

      expect(result, isNotNull);
      expect(result!.uid, 'u1');
      expect(result.displayName, 'Ada Lovelace');
      expect(result.email, 'ada@example.com');
      expect(result.photoUrl, 'https://img/ada.png');
      verify(() => auth.signInWithCredential(any())).called(1);
    });

    test('returns null and skips Firebase when the chooser is cancelled',
        () async {
      final auth = _MockFirebaseAuth();
      final service = AuthService(
        auth: auth,
        google: _FakeGoogleAuthenticator(credentialResult: null),
      );

      final result = await service.signInWithGoogle();

      expect(result, isNull);
      verifyNever(() => auth.signInWithCredential(any()));
    });

    test('maps FirebaseAuthException to AuthException', () async {
      final auth = _MockFirebaseAuth();
      when(() => auth.signInWithCredential(any())).thenThrow(
        FirebaseAuthException(
          code: 'account-exists-with-different-credential',
          message: 'Account exists.',
        ),
      );

      final service = AuthService(
        auth: auth,
        google: _FakeGoogleAuthenticator(credentialResult: _googleCredential()),
      );

      expect(
        () => service.signInWithGoogle(),
        throwsA(
          isA<AuthException>()
              .having((e) => e.message, 'message', 'Account exists.')
              .having(
                (e) => e.code,
                'code',
                'account-exists-with-different-credential',
              ),
        ),
      );
    });

    test('propagates an AuthException raised by the Google flow', () async {
      final auth = _MockFirebaseAuth();
      final service = AuthService(
        auth: auth,
        google: _FakeGoogleAuthenticator(
          throwOnCredential: const AuthException('Google Sign-In failed.'),
        ),
      );

      expect(() => service.signInWithGoogle(), throwsA(isA<AuthException>()));
      verifyNever(() => auth.signInWithCredential(any()));
    });
  });

  group('AuthService.signOut', () {
    test('signs out of both Google and Firebase', () async {
      final auth = _MockFirebaseAuth();
      when(() => auth.signOut()).thenAnswer((_) async {});
      final google = _FakeGoogleAuthenticator();

      await AuthService(auth: auth, google: google).signOut();

      expect(google.signedOut, isTrue);
      verify(() => auth.signOut()).called(1);
    });
  });

  group('AuthService.authStateChanges', () {
    test('maps Firebase User to AppUser and null to null', () async {
      final auth = _MockFirebaseAuth();
      final user = _MockUser();
      when(() => user.uid).thenReturn('u9');
      when(() => user.displayName).thenReturn('Grace');
      when(() => user.email).thenReturn(null);
      when(() => user.photoURL).thenReturn(null);
      when(
        () => auth.authStateChanges(),
      ).thenAnswer((_) => Stream.fromIterable([null, user]));

      final service = AuthService(auth: auth, google: _FakeGoogleAuthenticator());

      expect(
        service.authStateChanges,
        emitsInOrder([
          null,
          isA<AppUser>().having((u) => u.uid, 'uid', 'u9'),
        ]),
      );
    });
  });

  group('AuthService.currentUser', () {
    test('adapts the Firebase current user', () {
      final auth = _MockFirebaseAuth();
      final user = _MockUser();
      when(() => user.uid).thenReturn('u3');
      when(() => user.displayName).thenReturn('Alan');
      when(() => user.email).thenReturn('alan@example.com');
      when(() => user.photoURL).thenReturn(null);
      when(() => auth.currentUser).thenReturn(user);

      final service = AuthService(auth: auth, google: _FakeGoogleAuthenticator());

      expect(service.currentUser?.uid, 'u3');
      expect(service.currentUser?.label, 'Alan');
    });

    test('is null when signed out', () {
      final auth = _MockFirebaseAuth();
      when(() => auth.currentUser).thenReturn(null);
      final service = AuthService(auth: auth, google: _FakeGoogleAuthenticator());
      expect(service.currentUser, isNull);
    });
  });
}

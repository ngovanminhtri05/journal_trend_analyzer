import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:journal_trend_analyzer/firebase/admin_access_service.dart';
import 'package:mocktail/mocktail.dart';

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

class _MockUser extends Mock implements User {}

class _MockIdTokenResult extends Mock implements IdTokenResult {}

void main() {
  group('AdminAccessService', () {
    test('returns false when nobody is signed in', () async {
      final auth = _MockFirebaseAuth();
      when(() => auth.currentUser).thenReturn(null);
      final service = AdminAccessService(auth: auth);

      expect(await service.isCurrentUserAdmin(), isFalse);
    });

    test('returns true when the forced-refresh token carries admin: true', () async {
      final auth = _MockFirebaseAuth();
      final user = _MockUser();
      final tokenResult = _MockIdTokenResult();
      when(() => auth.currentUser).thenReturn(user);
      when(() => user.getIdTokenResult(true)).thenAnswer((_) async => tokenResult);
      when(() => tokenResult.claims).thenReturn({'admin': true});
      final service = AdminAccessService(auth: auth);

      expect(await service.isCurrentUserAdmin(), isTrue);
    });

    test('returns false when the claim is absent', () async {
      final auth = _MockFirebaseAuth();
      final user = _MockUser();
      final tokenResult = _MockIdTokenResult();
      when(() => auth.currentUser).thenReturn(user);
      when(() => user.getIdTokenResult(true)).thenAnswer((_) async => tokenResult);
      when(() => tokenResult.claims).thenReturn(<String, dynamic>{});
      final service = AdminAccessService(auth: auth);

      expect(await service.isCurrentUserAdmin(), isFalse);
    });
  });
}

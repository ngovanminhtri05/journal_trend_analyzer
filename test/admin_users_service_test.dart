import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:journal_trend_analyzer/firebase/admin_users_service.dart';
import 'package:mocktail/mocktail.dart';

class _MockFunctions extends Mock implements FirebaseFunctions {}

class _MockCallable extends Mock implements HttpsCallable {}

// ignore: subtype_of_sealed_class
class _MockResult extends Mock implements HttpsCallableResult<dynamic> {}

void main() {
  late _MockFunctions functions;
  late _MockCallable callable;
  late _MockResult result;

  setUp(() {
    functions = _MockFunctions();
    callable = _MockCallable();
    result = _MockResult();
    registerFallbackValue(<String, dynamic>{});
  });

  test('listUsers maps the callable response', () async {
    when(() => functions.httpsCallable('adminListUsers')).thenReturn(callable);
    when(() => callable.call<dynamic>(any())).thenAnswer((_) async => result);
    when(() => result.data).thenReturn({
      'users': [
        {
          'uid': 'u1',
          'email': 'a@example.com',
          'displayName': 'Ada',
          'disabled': false,
          'createdAt': '2026-01-01T00:00:00Z',
          'isAdmin': true,
        },
      ],
      'nextPageToken': null,
    });
    final service = AdminUsersService(functions: functions);

    final page = await service.listUsers();

    expect(page.users, hasLength(1));
    expect(page.users.single.uid, 'u1');
    expect(page.users.single.isAdmin, isTrue);
    expect(page.nextPageToken, isNull);
  });

  test('setUserDisabled calls the callable with uid and disabled', () async {
    when(
      () => functions.httpsCallable('adminSetUserDisabled'),
    ).thenReturn(callable);
    when(() => callable.call<dynamic>(any())).thenAnswer((_) async => result);
    when(() => result.data).thenReturn({'uid': 'u1', 'disabled': true});
    final service = AdminUsersService(functions: functions);

    await service.setUserDisabled(uid: 'u1', disabled: true);

    verify(
      () => callable.call<dynamic>({'uid': 'u1', 'disabled': true}),
    ).called(1);
  });

  test('a FirebaseFunctionsException becomes an AdminException', () async {
    when(() => functions.httpsCallable('adminDeleteUser')).thenReturn(callable);
    when(() => callable.call<dynamic>(any())).thenThrow(
      FirebaseFunctionsException(
        message: 'Admin privileges required.',
        code: 'permission-denied',
      ),
    );
    final service = AdminUsersService(functions: functions);

    expect(() => service.deleteUser('u1'), throwsA(isA<AdminException>()));
  });
}

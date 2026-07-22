import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:journal_trend_analyzer/firebase/admin_remote_config_service.dart';
import 'package:journal_trend_analyzer/firebase/admin_users_service.dart'
    show AdminException;
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

  test('getTemplate maps the callable response', () async {
    when(
      () => functions.httpsCallable('adminGetRemoteConfigTemplate'),
    ).thenReturn(callable);
    when(() => callable.call<dynamic>(any())).thenAnswer((_) async => result);
    when(() => result.data).thenReturn({
      'parameters': [
        {'key': 'max_journals', 'defaultValue': '15'},
      ],
    });
    final service = AdminRemoteConfigService(functions: functions);

    final params = await service.getTemplate();

    expect(params.single.key, 'max_journals');
    expect(params.single.defaultValue, '15');
  });

  test('updateParameter calls the callable with key and defaultValue', () async {
    when(
      () => functions.httpsCallable('adminUpdateRemoteConfigParameter'),
    ).thenReturn(callable);
    when(() => callable.call<dynamic>(any())).thenAnswer((_) async => result);
    when(
      () => result.data,
    ).thenReturn({'key': 'max_journals', 'defaultValue': '25'});
    final service = AdminRemoteConfigService(functions: functions);

    await service.updateParameter(key: 'max_journals', defaultValue: '25');

    verify(
      () => callable.call<dynamic>({
        'key': 'max_journals',
        'defaultValue': '25',
      }),
    ).called(1);
  });

  test('a FirebaseFunctionsException becomes an AdminException', () async {
    when(
      () => functions.httpsCallable('adminGetRemoteConfigTemplate'),
    ).thenReturn(callable);
    when(() => callable.call<dynamic>(any())).thenThrow(
      FirebaseFunctionsException(
        message: 'Admin privileges required.',
        code: 'permission-denied',
      ),
    );
    final service = AdminRemoteConfigService(functions: functions);

    expect(() => service.getTemplate(), throwsA(isA<AdminException>()));
  });
}

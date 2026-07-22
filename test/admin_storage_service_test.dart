import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:journal_trend_analyzer/firebase/admin_storage_service.dart';
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

  test('listReports maps the callable response', () async {
    when(() => functions.httpsCallable('adminListReports')).thenReturn(callable);
    when(() => callable.call<dynamic>(any())).thenAnswer((_) async => result);
    when(() => result.data).thenReturn({
      'reports': [
        {
          'path': 'reports/u1/2026-report.pdf',
          'size': 1024,
          'uploadedAt': '2026-01-01T00:00:00Z',
          'uid': 'u1',
        },
      ],
    });
    final service = AdminStorageService(functions: functions);

    final reports = await service.listReports();

    expect(reports.single.path, 'reports/u1/2026-report.pdf');
    expect(reports.single.size, 1024);
    expect(reports.single.uid, 'u1');
  });

  test('getReportUrl calls the callable with the path', () async {
    when(
      () => functions.httpsCallable('adminGetReportUrl'),
    ).thenReturn(callable);
    when(() => callable.call<dynamic>(any())).thenAnswer((_) async => result);
    when(() => result.data).thenReturn({'url': 'https://signed.example/x'});
    final service = AdminStorageService(functions: functions);

    final url = await service.getReportUrl('reports/u1/2026-report.pdf');

    expect(url, 'https://signed.example/x');
    verify(
      () => callable.call<dynamic>({'path': 'reports/u1/2026-report.pdf'}),
    ).called(1);
  });

  test('a FirebaseFunctionsException becomes an AdminException', () async {
    when(
      () => functions.httpsCallable('adminDeleteReport'),
    ).thenReturn(callable);
    when(() => callable.call<dynamic>(any())).thenThrow(
      FirebaseFunctionsException(
        message: 'Admin privileges required.',
        code: 'permission-denied',
      ),
    );
    final service = AdminStorageService(functions: functions);

    expect(
      () => service.deleteReport('reports/u1/x.pdf'),
      throwsA(isA<AdminException>()),
    );
  });
}

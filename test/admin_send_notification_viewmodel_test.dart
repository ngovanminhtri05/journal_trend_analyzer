import 'package:flutter_test/flutter_test.dart';
import 'package:journal_trend_analyzer/firebase/admin_messaging_service.dart';
import 'package:journal_trend_analyzer/firebase/admin_users_service.dart'
    show AdminException;
import 'package:journal_trend_analyzer/viewmodels/admin_send_notification_viewmodel.dart';

class _FakeApi implements AdminMessagingApi {
  (String, String)? lastSent;
  Object? error;

  @override
  Future<void> sendBroadcast({
    required String title,
    required String body,
  }) async {
    if (error != null) throw error!;
    lastSent = (title, body);
  }
}

void main() {
  group('AdminSendNotificationViewModel', () {
    test('sends a trimmed title/body and marks sent', () async {
      final api = _FakeApi();
      final vm = AdminSendNotificationViewModel(api);

      await vm.send(title: '  Hello  ', body: '  World  ');

      expect(api.lastSent, ('Hello', 'World'));
      expect(vm.sent, isTrue);
      expect(vm.errorMessage, isNull);
      expect(vm.sending, isFalse);
    });

    test('rejects an empty title or body without calling the API', () async {
      final api = _FakeApi();
      final vm = AdminSendNotificationViewModel(api);

      await vm.send(title: '   ', body: 'x');

      expect(api.lastSent, isNull);
      expect(vm.sent, isFalse);
      expect(vm.errorMessage, isNotNull);
    });

    test('surfaces an AdminException message', () async {
      final api = _FakeApi()..error = const AdminException('nope');
      final vm = AdminSendNotificationViewModel(api);

      await vm.send(title: 'a', body: 'b');

      expect(vm.sent, isFalse);
      expect(vm.errorMessage, 'nope');
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:journal_trend_analyzer/firebase/admin_messaging_service.dart';
import 'package:journal_trend_analyzer/screens/admin_send_notification_screen.dart';
import 'package:journal_trend_analyzer/viewmodels/admin_send_notification_viewmodel.dart';

class _FakeApi implements AdminMessagingApi {
  (String, String)? lastSent;

  @override
  Future<void> sendBroadcast({
    required String title,
    required String body,
  }) async {
    lastSent = (title, body);
  }
}

void main() {
  testWidgets('composing and sending broadcasts the message then confirms', (
    tester,
  ) async {
    final api = _FakeApi();
    final vm = AdminSendNotificationViewModel(api);

    await tester.pumpWidget(
      MaterialApp(home: AdminSendNotificationScreen(viewModel: vm)),
    );

    await tester.enterText(find.byType(TextField).at(0), 'Maintenance');
    await tester.enterText(find.byType(TextField).at(1), 'Down at 9pm');
    await tester.tap(find.text('Send to all users'));
    await tester.pumpAndSettle();

    expect(api.lastSent, ('Maintenance', 'Down at 9pm'));
    expect(find.text('Notification sent to all users.'), findsOneWidget);
  });
}

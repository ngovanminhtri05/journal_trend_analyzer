import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:journal_trend_analyzer/firebase/admin_users_service.dart';
import 'package:journal_trend_analyzer/screens/admin_user_detail_screen.dart';

void main() {
  testWidgets('shows the account details and per-user action cards', (
    tester,
  ) async {
    const user = AdminUserSummary(
      uid: 'u1',
      email: 'ada@example.com',
      displayName: 'Ada',
      disabled: false,
      isAdmin: false,
    );

    await tester.pumpWidget(
      const MaterialApp(home: AdminUserDetailScreen(user: user)),
    );

    expect(find.text('ada@example.com'), findsOneWidget);
    expect(find.text('u1'), findsOneWidget);
    // The two per-user shortcuts.
    expect(find.text('Reports'), findsOneWidget);
    expect(find.text('Send notification'), findsOneWidget);
  });
}

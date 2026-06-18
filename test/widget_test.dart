import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'package:journal_trend_analyzer/main.dart';
import 'package:journal_trend_analyzer/services/openalex_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('App boots and shows its title', (tester) async {
    // The app reads bookmarks from shared_preferences at boot.
    SharedPreferences.setMockInitialValues(<String, Object>{});

    // Inject a never-called client so the boot test makes no real network calls.
    final service = OpenAlexService(
      client: MockClient((_) async => http.Response('{}', 200)),
      mailto: 't@e.com',
    );

    await tester.pumpWidget(JournalTrendApp(service: service));

    // The navigation shell renders its three tabs.
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Trends'), findsWidgets);
    expect(find.text('Dashboard'), findsWidgets);
  });
}

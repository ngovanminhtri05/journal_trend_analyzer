import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:journal_trend_analyzer/main.dart';
import 'package:journal_trend_analyzer/services/openalex_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('search flow: type → search → loading → result tile', (
    tester,
  ) async {
    // The app reads bookmarks from shared_preferences at boot; give the test an
    // in-memory store so the collection tab settles instead of hanging.
    SharedPreferences.setMockInitialValues(<String, Object>{});

    final responseBody = jsonEncode({
      'meta': {'count': 1},
      'results': [
        {
          'display_name': 'Quantum Networking Survey',
          'publication_year': 2022,
          'cited_by_count': 314,
          'primary_location': {
            'source': {'display_name': 'Nature Physics'},
          },
        },
      ],
    });

    // Small delay so the loading frame is rendered before the response lands.
    final service = OpenAlexService(
      client: MockClient((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        return http.Response(responseBody, 200);
      }),
      mailto: 't@e.com',
    );

    await tester.pumpWidget(JournalTrendApp(service: service));

    // Idle prompt is shown before any search.
    expect(find.textContaining('Enter a topic'), findsOneWidget);

    // Type a topic and trigger the search.
    await tester.enterText(find.byType(TextField), 'quantum networking');
    await tester.tap(find.byIcon(Icons.arrow_forward));

    // First frame after submit: loading spinner.
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Let the request resolve: the result tile appears.
    await tester.pumpAndSettle();
    expect(find.text('Quantum Networking Survey'), findsOneWidget);
    expect(find.text('Nature Physics'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}

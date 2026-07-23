import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:journal_trend_analyzer/firebase/admin_logs_service.dart';
import 'package:journal_trend_analyzer/screens/admin_logs_screen.dart';
import 'package:journal_trend_analyzer/viewmodels/admin_logs_viewmodel.dart';

/// Fake backing the Logs admin screen without Firestore.
class _FakeApi implements AdminLogsApi {
  _FakeApi({this.events = const [], this.error});

  final List<AdminEventLog> events;
  final Object? error;

  @override
  Future<List<AdminEventLog>> recentEvents({int limit = 100}) async {
    if (error != null) throw error!;
    return events;
  }
}

void main() {
  testWidgets('renders a mirrored event', (tester) async {
    final vm = AdminLogsViewModel(
      _FakeApi(
        events: [
          AdminEventLog(uid: 'u1', name: 'login', timestamp: DateTime(2026)),
        ],
      ),
    );

    await tester.pumpWidget(MaterialApp(home: AdminLogsScreen(viewModel: vm)));
    await tester.pumpAndSettle();

    expect(find.text('login'), findsOneWidget);
  });

  testWidgets('a missing Firestore database shows an actionable error', (
    tester,
  ) async {
    final vm = AdminLogsViewModel(
      _FakeApi(
        error: FirebaseException(plugin: 'cloud_firestore', code: 'not-found'),
      ),
    );

    await tester.pumpWidget(MaterialApp(home: AdminLogsScreen(viewModel: vm)));
    await tester.pumpAndSettle();

    expect(find.textContaining('Firestore database'), findsOneWidget);
  });
}

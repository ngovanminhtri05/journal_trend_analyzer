import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'package:journal_trend_analyzer/firebase/analytics_service.dart';
import 'package:journal_trend_analyzer/firebase/app_user.dart';
import 'package:journal_trend_analyzer/firebase/auth_service.dart';
import 'package:journal_trend_analyzer/services/openalex_service.dart';
import 'package:journal_trend_analyzer/viewmodels/auth_viewmodel.dart';
import 'package:journal_trend_analyzer/viewmodels/home_viewmodel.dart';

/// Records every analytics call so tests can assert on them.
class _RecordingAnalytics implements AnalyticsApi {
  int logins = 0;
  int logouts = 0;
  final List<String> searchTopics = [];

  @override
  Future<void> logLogin() async => logins++;
  @override
  Future<void> logLogout() async => logouts++;
  @override
  Future<void> logSearchTopic(String keyword) async => searchTopics.add(keyword);
  @override
  Future<void> logViewPublication({required String title, int? year}) async {}
  @override
  Future<void> logViewJournal(String name) async {}
  @override
  Future<void> logViewKeyword(String keyword) async {}
  @override
  Future<void> logExportPdf(String topic) async {}
}

class _FakeAuthApi implements AuthApi {
  final _controller = StreamController<AppUser?>.broadcast();
  AppUser? signInResult;

  @override
  Stream<AppUser?> get authStateChanges => _controller.stream;
  @override
  AppUser? currentUser;
  @override
  Future<AppUser?> signInWithGoogle() async => signInResult;
  @override
  Future<void> signOut() async {}
  void dispose() => _controller.close();
}

const _ada = AppUser(uid: 'u1', displayName: 'Ada', email: 'ada@example.com');

void main() {
  group('AuthViewModel analytics', () {
    test('logs login on a successful sign-in', () async {
      final api = _FakeAuthApi()..signInResult = _ada;
      final analytics = _RecordingAnalytics();
      final vm = AuthViewModel(api, analytics: analytics);
      addTearDown(() {
        vm.dispose();
        api.dispose();
      });

      await vm.signInWithGoogle();

      expect(analytics.logins, 1);
    });

    test('does not log login when the user cancels the chooser', () async {
      final api = _FakeAuthApi()..signInResult = null; // cancelled
      final analytics = _RecordingAnalytics();
      final vm = AuthViewModel(api, analytics: analytics);
      addTearDown(() {
        vm.dispose();
        api.dispose();
      });

      await vm.signInWithGoogle();

      expect(analytics.logins, 0);
    });

    test('logs logout on sign-out', () async {
      final api = _FakeAuthApi();
      final analytics = _RecordingAnalytics();
      final vm = AuthViewModel(api, analytics: analytics);
      addTearDown(() {
        vm.dispose();
        api.dispose();
      });

      await vm.signOut();

      expect(analytics.logouts, 1);
    });
  });

  group('HomeViewModel analytics', () {
    test('logs search_topic with the trimmed keyword', () async {
      // The fetch fails, but the event fires before the await, so it is recorded.
      final service = OpenAlexService(
        client: MockClient((_) async => http.Response('{}', 500)),
        mailto: 't@e.com',
      );
      final analytics = _RecordingAnalytics();
      final vm = HomeViewModel(service, analytics: analytics);

      await vm.loadForField('  quantum computing  ');

      expect(analytics.searchTopics, ['quantum computing']);
    });

    test('does not log for a blank query', () async {
      final service = OpenAlexService(
        client: MockClient((_) async => http.Response('{}', 200)),
        mailto: 't@e.com',
      );
      final analytics = _RecordingAnalytics();
      final vm = HomeViewModel(service, analytics: analytics);

      await vm.loadForField('   ');

      expect(analytics.searchTopics, isEmpty);
    });
  });
}

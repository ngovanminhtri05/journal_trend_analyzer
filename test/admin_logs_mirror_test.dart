import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:journal_trend_analyzer/firebase/admin_logs_mirror.dart';
import 'package:journal_trend_analyzer/firebase/analytics_service.dart';
import 'package:mocktail/mocktail.dart';

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

class _MockUser extends Mock implements User {}

class _RecordingAnalytics implements AnalyticsApi {
  int logins = 0;
  final List<String> searches = [];

  @override
  Future<void> logLogin() async => logins++;
  @override
  Future<void> logSearchTopic(String keyword) async => searches.add(keyword);
  @override
  Future<void> logViewPublication({required String title, int? year}) async {}
  @override
  Future<void> logViewJournal(String name) async {}
  @override
  Future<void> logViewKeyword(String keyword) async {}
  @override
  Future<void> logExportPdf(String topic) async {}
  @override
  Future<void> logLogout() async {}
}

void main() {
  group('MirroringAnalytics', () {
    test('forwards to the inner analytics and mirrors when signed in', () async {
      final auth = _MockFirebaseAuth();
      final user = _MockUser();
      when(() => auth.currentUser).thenReturn(user);
      when(() => user.uid).thenReturn('u1');
      final inner = _RecordingAnalytics();
      final written = <MapEntry<String, Map<String, dynamic>>>[];
      final mirroring = MirroringAnalytics(
        inner,
        auth: auth,
        writer: (collection, data) async {
          written.add(MapEntry(collection, data));
        },
      );

      await mirroring.logSearchTopic('robotics');

      expect(inner.searches, ['robotics']);
      expect(written, hasLength(1));
      expect(written.single.key, 'admin_events');
      expect(written.single.value['uid'], 'u1');
      expect(written.single.value['name'], 'search_topic');
      expect(written.single.value['params'], {'keyword': 'robotics'});
    });

    test('still forwards to the inner analytics when signed out (no mirror write)', () async {
      final auth = _MockFirebaseAuth();
      when(() => auth.currentUser).thenReturn(null);
      final inner = _RecordingAnalytics();
      var writes = 0;
      final mirroring = MirroringAnalytics(
        inner,
        auth: auth,
        writer: (_, _) async => writes++,
      );

      await mirroring.logLogin();

      expect(inner.logins, 1);
      expect(writes, 0);
    });

    test('a failing writer never breaks the real analytics call', () async {
      final auth = _MockFirebaseAuth();
      final user = _MockUser();
      when(() => auth.currentUser).thenReturn(user);
      when(() => user.uid).thenReturn('u1');
      final inner = _RecordingAnalytics();
      final mirroring = MirroringAnalytics(
        inner,
        auth: auth,
        writer: (_, _) async => throw Exception('offline'),
      );

      await mirroring.logLogin();

      expect(inner.logins, 1);
    });
  });
}

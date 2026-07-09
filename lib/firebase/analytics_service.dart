import 'package:firebase_analytics/firebase_analytics.dart';

/// Contract for the seven Lab 03 analytics events. Views/ViewModels depend on
/// this interface, never on `firebase_analytics` directly, so the app stays
/// testable (tests inject a fake / [NoopAnalytics]).
abstract interface class AnalyticsApi {
  /// `login` — user finished Google Sign-In.
  Future<void> logLogin();

  /// `search_topic{keyword}` — a topic search was run.
  Future<void> logSearchTopic(String keyword);

  /// `view_publication{publication_title, publication_year}`.
  Future<void> logViewPublication({required String title, int? year});

  /// `view_journal{journal_name}`.
  Future<void> logViewJournal(String name);

  /// `view_keyword{keyword}`.
  Future<void> logViewKeyword(String keyword);

  /// `export_pdf{topic}` — a dashboard PDF report was exported.
  Future<void> logExportPdf(String topic);

  /// `logout` — user signed out.
  Future<void> logLogout();
}

/// Firebase-backed [AnalyticsApi]. [FirebaseAnalytics.instance] is resolved
/// lazily so constructing the service never requires Firebase to be initialised.
class AnalyticsService implements AnalyticsApi {
  AnalyticsService({FirebaseAnalytics? analytics}) : _injected = analytics;

  final FirebaseAnalytics? _injected;
  FirebaseAnalytics get _analytics => _injected ?? FirebaseAnalytics.instance;

  @override
  Future<void> logLogin() => _analytics.logLogin(loginMethod: 'google');

  @override
  Future<void> logSearchTopic(String keyword) => _analytics.logEvent(
    name: 'search_topic',
    parameters: {'keyword': keyword},
  );

  @override
  Future<void> logViewPublication({required String title, int? year}) =>
      _analytics.logEvent(
        name: 'view_publication',
        parameters: {
          // Analytics rejects null / overly long string params.
          'publication_title': _clip(title),
          // Null-aware element: entry is omitted when year is null.
          'publication_year': ?year,
        },
      );

  @override
  Future<void> logViewJournal(String name) => _analytics.logEvent(
    name: 'view_journal',
    parameters: {'journal_name': _clip(name)},
  );

  @override
  Future<void> logViewKeyword(String keyword) => _analytics.logEvent(
    name: 'view_keyword',
    parameters: {'keyword': _clip(keyword)},
  );

  @override
  Future<void> logExportPdf(String topic) => _analytics.logEvent(
    name: 'export_pdf',
    parameters: {'topic': _clip(topic)},
  );

  @override
  Future<void> logLogout() => _analytics.logEvent(name: 'logout');

  /// Firebase caps string parameter values at 100 chars.
  String _clip(String value) =>
      value.length <= 100 ? value : value.substring(0, 100);
}

/// No-op [AnalyticsApi] for tests, previews, or any context without Firebase.
class NoopAnalytics implements AnalyticsApi {
  const NoopAnalytics();

  @override
  Future<void> logLogin() async {}
  @override
  Future<void> logSearchTopic(String keyword) async {}
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

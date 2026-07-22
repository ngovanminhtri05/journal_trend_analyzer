import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'analytics_service.dart';
import 'crash_reporter_service.dart';

/// Writes one mirrored record to a Firestore collection. Overridable in tests;
/// the default targets the real Firestore project.
typedef AdminEventWriter = Future<void> Function(
  String collection,
  Map<String, dynamic> data,
);

Future<void> _defaultWriter(String collection, Map<String, dynamic> data) =>
    FirebaseFirestore.instance.collection(collection).add(data);

/// Decorates an [AnalyticsApi] so every real event also writes a short record
/// to the `admin_events` Firestore collection, purely so the in-app admin Logs
/// screen has instant data (see design §5.4) — the real Analytics call is
/// untouched and always runs first.
///
/// The mirror write is best-effort: a Firestore failure (offline, rules,
/// anything) is swallowed so it can never break the real analytics event it
/// wraps. Nothing is written while signed out — there is no uid to attribute
/// the event to, and the security rules would reject it anyway.
class MirroringAnalytics implements AnalyticsApi {
  MirroringAnalytics(this._inner, {FirebaseAuth? auth, AdminEventWriter? writer})
    : _authInjected = auth,
      _writer = writer ?? _defaultWriter;

  final AnalyticsApi _inner;
  final FirebaseAuth? _authInjected;
  final AdminEventWriter _writer;

  FirebaseAuth get _auth => _authInjected ?? FirebaseAuth.instance;

  Future<void> _mirror(String name, Map<String, dynamic> params) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    try {
      await _writer('admin_events', {
        'uid': uid,
        'name': name,
        'timestamp': FieldValue.serverTimestamp(),
        'params': params,
      });
    } catch (_) {
      // Best-effort mirror only.
    }
  }

  @override
  Future<void> logLogin() async {
    await _inner.logLogin();
    await _mirror('login', const {});
  }

  @override
  Future<void> logSearchTopic(String keyword) async {
    await _inner.logSearchTopic(keyword);
    await _mirror('search_topic', {'keyword': keyword});
  }

  @override
  Future<void> logViewPublication({required String title, int? year}) async {
    await _inner.logViewPublication(title: title, year: year);
    await _mirror('view_publication', {
      'title': title,
      'year': ?year,
    });
  }

  @override
  Future<void> logViewJournal(String name) async {
    await _inner.logViewJournal(name);
    await _mirror('view_journal', {'name': name});
  }

  @override
  Future<void> logViewKeyword(String keyword) async {
    await _inner.logViewKeyword(keyword);
    await _mirror('view_keyword', {'keyword': keyword});
  }

  @override
  Future<void> logExportPdf(String topic) async {
    await _inner.logExportPdf(topic);
    await _mirror('export_pdf', {'topic': topic});
  }

  @override
  Future<void> logLogout() async {
    await _inner.logLogout();
    await _mirror('logout', const {});
  }
}

/// Decorates a [CrashReporterApi] so every non-fatal [recordError] also writes
/// a short record to the `admin_crash_reports` Firestore collection. Same
/// best-effort/offline-safe behavior as [MirroringAnalytics]; [log] and
/// [forceCrash] pass straight through (there is nothing to mirror before a
/// forced crash kills the process).
class MirroringCrashReporter implements CrashReporterApi {
  MirroringCrashReporter(
    this._inner, {
    FirebaseAuth? auth,
    AdminEventWriter? writer,
  }) : _authInjected = auth,
       _writer = writer ?? _defaultWriter;

  final CrashReporterApi _inner;
  final FirebaseAuth? _authInjected;
  final AdminEventWriter _writer;

  FirebaseAuth get _auth => _authInjected ?? FirebaseAuth.instance;

  @override
  Future<void> recordError(
    Object error,
    StackTrace? stack, {
    String? reason,
  }) async {
    await _inner.recordError(error, stack, reason: reason);
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    try {
      await _writer('admin_crash_reports', {
        'uid': uid,
        'message': error.toString(),
        'reason': reason,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Best-effort mirror only.
    }
  }

  @override
  Future<void> log(String message) => _inner.log(message);

  @override
  void forceCrash() => _inner.forceCrash();
}

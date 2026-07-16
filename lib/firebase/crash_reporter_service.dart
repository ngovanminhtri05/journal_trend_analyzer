import 'package:firebase_crashlytics/firebase_crashlytics.dart';

/// Contract for crash / error reporting (Lab 03 tasks 9.2 + 8.5).
///
/// Views/ViewModels depend on this, never on `firebase_crashlytics` directly,
/// so the demo actions stay testable ([NoopCrashReporter]).
abstract interface class CrashReporterApi {
  /// Reports a caught, non-fatal error (the "handled exception" demo).
  Future<void> recordError(Object error, StackTrace? stack, {String? reason});

  /// Leaves a breadcrumb attached to the next crash report.
  Future<void> log(String message);

  /// Forces a native crash to prove reporting works (the "test crash" demo).
  /// The app process is killed and the report uploads on next launch.
  void forceCrash();
}

/// Firebase-backed [CrashReporterApi]. [FirebaseCrashlytics.instance] is
/// resolved lazily so constructing this never requires Firebase.
class CrashlyticsService implements CrashReporterApi {
  CrashlyticsService({FirebaseCrashlytics? crashlytics})
    : _injected = crashlytics;

  final FirebaseCrashlytics? _injected;
  FirebaseCrashlytics get _crashlytics =>
      _injected ?? FirebaseCrashlytics.instance;

  @override
  Future<void> recordError(Object error, StackTrace? stack, {String? reason}) =>
      _crashlytics.recordError(error, stack, reason: reason, fatal: false);

  @override
  Future<void> log(String message) => _crashlytics.log(message);

  @override
  void forceCrash() => _crashlytics.crash();
}

/// No-op [CrashReporterApi] for tests / Firebase-free contexts.
class NoopCrashReporter implements CrashReporterApi {
  const NoopCrashReporter();

  @override
  Future<void> recordError(
    Object error,
    StackTrace? stack, {
    String? reason,
  }) async {}
  @override
  Future<void> log(String message) async {}
  @override
  void forceCrash() {}
}

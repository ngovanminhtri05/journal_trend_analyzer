import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'firebase/analytics_service.dart';
import 'firebase/auth_service.dart';
import 'firebase/crash_reporter_service.dart';
import 'firebase/remote_config_service.dart';
import 'firebase_options.dart';
import 'screens/auth_gate.dart';
import 'services/bookmark_service.dart';
import 'services/openalex_service.dart';
import 'viewmodels/viewmodels.dart';
import 'theme/app_theme.dart';

/// Web OAuth 2.0 client id (google-services.json `oauth_client` type 3). Google
/// Sign-In v7 needs it as `serverClientId` to return the id token Firebase
/// exchanges for a session.
const String _googleServerClientId =
    '61025513530-0a5q3gqj4gfp7rc0iv2cdh2f1m55r8c8.apps.googleusercontent.com';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  GoogleSignInAuthenticator.serverClientId = _googleServerClientId;

  // Crashlytics (task 9.2): route uncaught Flutter + platform errors to
  // Crashlytics so they are reported to the console.
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  // Remote Config: fetch + activate tunables before the first frame so the
  // lists render with the server values (falls back to in-code defaults).
  final remoteConfig = RemoteConfigService();
  await remoteConfig.initialize();

  runApp(JournalTrendApp(remoteConfig: remoteConfig));
}

/// Root app widget.
///
/// Owns a single shared [OpenAlexService] (created once and disposed when the
/// app is torn down) plus the three screen providers. The service can be
/// injected for tests.
class JournalTrendApp extends StatefulWidget {
  const JournalTrendApp({
    super.key,
    this.service,
    this.bookmarkService,
    this.analytics,
    this.remoteConfig,
    this.crashReporter,
    this.home,
  });

  /// Polite-pool contact sent on every OpenAlex request.
  static const String mailto = 'ngovanminhtri05@gmail.com';

  /// Optional injected service (tests). When null, one is created internally.
  final OpenAlexService? service;

  /// Optional injected bookmark service (tests). When null, one is created
  /// internally (it resolves shared-preferences lazily — see [BookmarkService]).
  final BookmarkService? bookmarkService;

  /// Optional injected analytics backend (tests). When null, a Firebase-backed
  /// [AnalyticsService] is used (it resolves FirebaseAnalytics lazily).
  final AnalyticsApi? analytics;

  /// Optional injected Remote Config (tests). When null, an uninitialised
  /// [RemoteConfigService] is used, which simply reports the in-code defaults.
  final RemoteConfigApi? remoteConfig;

  /// Optional injected crash reporter (tests). When null, a Firebase-backed
  /// [CrashlyticsService] is used (it resolves FirebaseCrashlytics lazily).
  final CrashReporterApi? crashReporter;

  /// Optional root screen override. Defaults to [AuthGate] in production; tests
  /// pass a Firebase-free widget (e.g. HomeShell) to skip the auth gate.
  final Widget? home;

  @override
  State<JournalTrendApp> createState() => _JournalTrendAppState();
}

class _JournalTrendAppState extends State<JournalTrendApp> {
  late final OpenAlexService _service =
      widget.service ?? OpenAlexService(mailto: JournalTrendApp.mailto);

  late final BookmarkService _bookmarkService =
      widget.bookmarkService ?? BookmarkService();

  late final AnalyticsApi _analytics = widget.analytics ?? AnalyticsService();

  late final RemoteConfigApi _remoteConfig =
      widget.remoteConfig ?? RemoteConfigService();

  late final CrashReporterApi _crashReporter =
      widget.crashReporter ?? CrashlyticsService();

  /// Only dispose a service we created ourselves; an injected one is owned by
  /// the test that provided it.
  bool get _ownsService => widget.service == null;

  @override
  void dispose() {
    if (_ownsService) _service.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<OpenAlexService>.value(value: _service),
        Provider<AnalyticsApi>.value(value: _analytics),
        Provider<RemoteConfigApi>.value(value: _remoteConfig),
        Provider<CrashReporterApi>.value(value: _crashReporter),
        ChangeNotifierProvider(create: (_) => FilterProvider(_service)),
        ChangeNotifierProvider(create: (_) => SearchProvider(_service)),
        ChangeNotifierProvider(create: (_) => TrendProvider(_service)),
        ChangeNotifierProvider(create: (_) => DashboardProvider(_service)),
        ChangeNotifierProvider(create: (_) => ComparisonProvider(_service)),
        ChangeNotifierProvider(
          create: (_) => BookmarkProvider(_bookmarkService),
        ),
        // Lab 03 tab ViewModels (Home / Journals / Keywords).
        ChangeNotifierProvider(
          create: (_) => HomeViewModel(_service, analytics: _analytics),
        ),
        ChangeNotifierProvider(create: (_) => JournalsViewModel(_service)),
        ChangeNotifierProvider(create: (_) => KeywordsViewModel(_service)),
      ],
      child: MaterialApp(
        title: 'Journal Trend Analyzer',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.build(),
        // PLANS-Lab03 task 2.3 — Google Sign-In gate (active now that Firebase
        // is configured). Signed-out users see LoginScreen; signed-in users the
        // HomeShell. AuthGate owns the AuthViewModel above the tab tree.
        home: widget.home ?? const AuthGate(),
      ),
    );
  }
}

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'firebase/auth_service.dart';
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
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  GoogleSignInAuthenticator.serverClientId = _googleServerClientId;
  runApp(const JournalTrendApp());
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
    this.home,
  });

  /// Polite-pool contact sent on every OpenAlex request.
  static const String mailto = 'ngovanminhtri05@gmail.com';

  /// Optional injected service (tests). When null, one is created internally.
  final OpenAlexService? service;

  /// Optional injected bookmark service (tests). When null, one is created
  /// internally (it resolves shared-preferences lazily — see [BookmarkService]).
  final BookmarkService? bookmarkService;

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
        ChangeNotifierProvider(create: (_) => FilterProvider(_service)),
        ChangeNotifierProvider(create: (_) => SearchProvider(_service)),
        ChangeNotifierProvider(create: (_) => TrendProvider(_service)),
        ChangeNotifierProvider(create: (_) => DashboardProvider(_service)),
        ChangeNotifierProvider(create: (_) => ComparisonProvider(_service)),
        ChangeNotifierProvider(create: (_) => BookmarkProvider(_bookmarkService)),
        // Lab 03 tab ViewModels (Home / Journals / Keywords).
        ChangeNotifierProvider(create: (_) => HomeViewModel(_service)),
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

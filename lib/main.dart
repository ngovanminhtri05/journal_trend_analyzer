import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/home_shell.dart';
import 'services/bookmark_service.dart';
import 'services/openalex_service.dart';
import 'state/state.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const JournalTrendApp());
}

/// Root app widget.
///
/// Owns a single shared [OpenAlexService] (created once and disposed when the
/// app is torn down) plus the three screen providers. The service can be
/// injected for tests.
class JournalTrendApp extends StatefulWidget {
  const JournalTrendApp({super.key, this.service, this.bookmarkService});

  /// Polite-pool contact sent on every OpenAlex request.
  static const String mailto = 'ngovanminhtri05@gmail.com';

  /// Optional injected service (tests). When null, one is created internally.
  final OpenAlexService? service;

  /// Optional injected bookmark service (tests). When null, one is created
  /// internally (it resolves shared-preferences lazily — see [BookmarkService]).
  final BookmarkService? bookmarkService;

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
      ],
      child: MaterialApp(
        title: 'Journal Trend Analyzer',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.build(),
        home: const HomeShell(),
      ),
    );
  }
}

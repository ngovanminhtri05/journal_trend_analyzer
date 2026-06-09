import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'services/openalex_service.dart';
import 'state/state.dart';

void main() {
  runApp(const JournalTrendApp());
}

/// Root app widget.
///
/// Sets up the shared [OpenAlexService] and the three screen providers. The
/// service can be injected for tests. The home screen is a placeholder shell
/// that Task 3.1 replaces with the real BottomNavigationBar navigation.
class JournalTrendApp extends StatelessWidget {
  const JournalTrendApp({super.key, this.service});

  /// Polite-pool contact sent on every OpenAlex request.
  static const String _mailto = 'ngovanminhtri05@gmail.com';

  final OpenAlexService? service;

  @override
  Widget build(BuildContext context) {
    final svc = service ?? OpenAlexService(mailto: _mailto);

    return MultiProvider(
      providers: [
        Provider<OpenAlexService>.value(value: svc),
        ChangeNotifierProvider(create: (_) => SearchProvider(svc)),
        ChangeNotifierProvider(create: (_) => TrendProvider(svc)),
        ChangeNotifierProvider(create: (_) => DashboardProvider(svc)),
      ],
      child: MaterialApp(
        title: 'Journal Trend Analyzer',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorSchemeSeed: Colors.indigo,
          useMaterial3: true,
        ),
        home: const _PlaceholderHome(),
      ),
    );
  }
}

/// Temporary landing screen until the navigation shell lands in Task 3.1.
class _PlaceholderHome extends StatelessWidget {
  const _PlaceholderHome();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Journal Trend Analyzer')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Setup complete. Screens arrive in Phase 3.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../widgets/widgets.dart';
import 'comparison_screen.dart';
import 'dashboard_screen.dart';
import 'search_screen.dart';
import 'trend_screen.dart';

/// Root navigation shell: a [BottomNavigationBar] over the three main tabs.
///
/// An [IndexedStack] keeps each tab's state alive when switching, so a search
/// or a loaded chart is not thrown away on tab change. The Publication Detail
/// screen (FR-2) is pushed on top of this shell, not a tab.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _tabs = <_TabConfig>[
    _TabConfig('Search', Icons.search, SearchScreen()),
    _TabConfig('Trends', Icons.show_chart, TrendScreen()),
    _TabConfig('Compare', Icons.compare_arrows, ComparisonScreen()),
    _TabConfig('Dashboard', Icons.dashboard, DashboardScreen()),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_tabs[_index].label)),
      body: ResponsiveBody(
        child: IndexedStack(
          index: _index,
          children: [for (final tab in _tabs) tab.screen],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          for (final tab in _tabs)
            NavigationDestination(icon: Icon(tab.icon), label: tab.label),
        ],
      ),
    );
  }
}

class _TabConfig {
  const _TabConfig(this.label, this.icon, this.screen);
  final String label;
  final IconData icon;
  final Widget screen;
}

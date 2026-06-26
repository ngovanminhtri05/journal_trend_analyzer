import 'package:flutter/material.dart';

import '../widgets/widgets.dart';
import 'home_screen.dart';
import 'journals_screen.dart';
import 'keywords_screen.dart';
import 'profile_screen.dart';

/// Root navigation shell (Lab 03): a [NavigationBar] over the four required
/// tabs — Home · Journals · Keywords · Profile.
///
/// An [IndexedStack] keeps each tab's state alive when switching, so a search or
/// a loaded chart is not thrown away on tab change. Detail screens (Publication,
/// Journal, Keyword) are pushed on top of this shell, not tabs.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _tabs = <_TabConfig>[
    _TabConfig('Home', Icons.home_outlined, HomeScreen()),
    _TabConfig('Journals', Icons.menu_book_outlined, JournalsScreen()),
    _TabConfig('Keywords', Icons.tag, KeywordsScreen()),
    _TabConfig('Profile', Icons.account_circle_outlined, ProfileScreen()),
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

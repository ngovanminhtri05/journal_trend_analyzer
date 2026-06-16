import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/state.dart';
import '../widgets/widgets.dart';
import 'detail_screen.dart';
import 'topic_sync.dart';

/// Trend analysis screen (FR-3/4/5/6): year chart, top journals, top authors
/// and top-cited papers. Auto-loads the topic searched on the Search tab
/// (`SearchProvider.lastQuery`).
class TrendScreen extends StatelessWidget {
  const TrendScreen({super.key});

  static const int _topPapers = 10;

  @override
  Widget build(BuildContext context) {
    final topic = context.watch<SearchProvider>().lastQuery;
    final filters = context.watch<FilterProvider>().activeFilterClauses;
    final provider = context.watch<TrendProvider>();

    // Keep the analysis in sync with the shared topic and taxonomy filter.
    syncSharedTopic(
      context: context,
      topic: topic,
      filters: filters,
      lastLoadedTopic: provider.lastQuery,
      lastLoadedFilters: provider.lastFilters,
      load: (t, f) => context.read<TrendProvider>().load(t, filters: f),
    );

    if (topic.isEmpty && provider.state == ViewState.idle) {
      return const EmptyView(
        icon: Icons.show_chart,
        message: 'Search a topic first to see its research trends.',
      );
    }

    switch (provider.state) {
      case ViewState.idle:
      case ViewState.loading:
        return const LoadingView(message: 'Analyzing trends…');
      case ViewState.error:
        return ErrorView(
          message: provider.errorMessage ?? 'Failed to load trends.',
          onRetry: provider.retry,
        );
      case ViewState.empty:
        return EmptyView(message: 'No trend data for "${provider.lastQuery}".');
      case ViewState.success:
        return _TrendContent(provider: provider, topPapers: _topPapers);
    }
  }
}

class _TrendContent extends StatelessWidget {
  const _TrendContent({required this.provider, required this.topPapers});

  final TrendProvider provider;
  final int topPapers;

  @override
  Widget build(BuildContext context) {
    final papers = provider.topPapers.take(topPapers).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _Header('Publications per year', Icons.show_chart),
        const SizedBox(height: 8),
        YearBarChart(data: provider.yearCounts),
        const SizedBox(height: 24),
        _Header('Top journals', Icons.menu_book),
        const SizedBox(height: 8),
        RankedCountList(items: provider.topJournals),
        const SizedBox(height: 24),
        _Header('Top authors', Icons.people_outline),
        const SizedBox(height: 8),
        RankedCountList(items: provider.topAuthors),
        const SizedBox(height: 24),
        _Header('Most influential papers', Icons.local_fire_department),
        const SizedBox(height: 8),
        for (var i = 0; i < papers.length; i++)
          PaperCard(
            work: papers[i],
            rank: i + 1,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => DetailScreen(work: papers[i])),
            ),
          ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.title, this.icon);

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 8),
        Text(title, style: Theme.of(context).textTheme.titleMedium),
      ],
    );
  }
}

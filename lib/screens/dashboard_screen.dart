import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/state.dart';
import '../widgets/widgets.dart';
import 'detail_screen.dart';

/// Research dashboard screen (FR-7): six aggregate insights for the topic
/// searched on the Search tab (`SearchProvider.lastQuery`).
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final topic = context.watch<SearchProvider>().lastQuery;
    final provider = context.watch<DashboardProvider>();

    if (topic.isNotEmpty && topic != provider.lastQuery) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.read<DashboardProvider>().load(topic);
      });
    }

    if (topic.isEmpty && provider.state == ViewState.idle) {
      return const EmptyView(
        icon: Icons.dashboard_outlined,
        message: 'Search a topic first to see its research dashboard.',
      );
    }

    switch (provider.state) {
      case ViewState.idle:
      case ViewState.loading:
        return const LoadingView(message: 'Building dashboard…');
      case ViewState.error:
        return ErrorView(
          message: provider.errorMessage ?? 'Failed to load dashboard.',
          onRetry: provider.retry,
        );
      case ViewState.empty:
        return EmptyView(message: 'No data for "${provider.lastQuery}".');
      case ViewState.success:
        return _DashboardContent(
          topic: provider.lastQuery,
          summary: provider.summary!,
        );
    }
  }
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({required this.topic, required this.summary});

  final String topic;
  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    final cards = <Widget>[
      StatCard(
        icon: Icons.library_books,
        label: 'Total publications',
        value: _formatInt(summary.totalPublications),
      ),
      StatCard(
        icon: Icons.format_quote,
        label: 'Avg. citations (top papers)',
        value: summary.averageCitations.toStringAsFixed(1),
      ),
      StatCard(
        icon: Icons.calendar_today,
        label: 'Most active year',
        value: summary.mostActiveYear?.toString() ?? 'n/a',
      ),
      StatCard(
        icon: Icons.menu_book,
        label: 'Top journal',
        value: summary.topJournal ?? 'n/a',
      ),
      StatCard(
        icon: Icons.person,
        label: 'Top author',
        value: summary.topAuthor ?? 'n/a',
      ),
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Topic: $topic', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth > 600 ? 3 : 2;
            const spacing = 12.0;
            final width =
                (constraints.maxWidth - spacing * (columns - 1)) / columns;
            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                for (final card in cards)
                  SizedBox(width: width, child: card),
              ],
            );
          },
        ),
        const SizedBox(height: 24),
        Text('Most influential paper',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (summary.mostInfluential != null)
          PaperCard(
            work: summary.mostInfluential!,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => DetailScreen(work: summary.mostInfluential!),
              ),
            ),
          )
        else
          const Text('n/a'),
      ],
    );
  }

  /// Adds thousands separators (e.g. 1234567 → 1,234,567).
  String _formatInt(int value) {
    final s = value.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buffer.write(',');
      buffer.write(s[i]);
    }
    return buffer.toString();
  }
}

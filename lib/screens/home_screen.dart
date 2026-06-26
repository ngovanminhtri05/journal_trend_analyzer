import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../viewmodels/viewmodels.dart';
import '../widgets/widgets.dart';
import 'detail_screen.dart';

/// Home tab (Lab 03): a topic search that fans out into an overview dashboard —
/// the trend chart, five headline metrics, and the most-influential paper
/// (tappable to its detail). All logic lives in [HomeViewModel]; this View only
/// renders its state.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<HomeViewModel>();

    return Column(
      children: [
        TopicSearchBar(
          hintText: 'Search a research topic (e.g. Machine Learning)',
          onSubmit: (q) => context.read<HomeViewModel>().search(q),
        ),
        Expanded(child: _buildBody(context, vm)),
      ],
    );
  }

  Widget _buildBody(BuildContext context, HomeViewModel vm) {
    switch (vm.state) {
      case ViewState.idle:
        return const EmptyView(
          icon: Icons.insights_outlined,
          message: 'Enter a topic above to see a research overview.',
        );
      case ViewState.loading:
        return const LoadingView(message: 'Building overview…');
      case ViewState.error:
        return ErrorView(
          message: vm.errorMessage ?? 'Something went wrong.',
          onRetry: vm.retry,
        );
      case ViewState.empty:
        return EmptyView(
          message: 'No publications found for "${vm.lastQuery}".',
        );
      case ViewState.success:
        return _Overview(vm: vm);
    }
  }
}

class _Overview extends StatelessWidget {
  const _Overview({required this.vm});

  final HomeViewModel vm;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = vm.summary!;
    final trend = vm.trendClassification;

    final metrics = <_Metric>[
      _Metric(Icons.article_outlined, 'Total publications', '${s.totalPublications}'),
      _Metric(
        Icons.format_quote_outlined,
        'Avg. citations',
        s.averageCitations.toStringAsFixed(1),
      ),
      _Metric(
        Icons.calendar_today_outlined,
        'Most active year',
        s.mostActiveYear?.toString() ?? '—',
      ),
      _Metric(Icons.menu_book_outlined, 'Top journal', s.topJournal ?? '—'),
      _Metric(Icons.person_outline, 'Top author', s.topAuthor ?? '—'),
    ];

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 12),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(vm.lastQuery, style: theme.textTheme.titleMedium),
              ),
              if (trend != null) TrendBadge(classification: trend),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Text('Publications over time', style: theme.textTheme.titleSmall),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: YearBarChart(data: vm.yearCounts),
        ),
        const SizedBox(height: 8),
        _MetricsGrid(metrics: metrics),
        if (s.mostInfluential != null) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(
              'Most influential publication',
              style: theme.textTheme.titleSmall,
            ),
          ),
          PaperCard(
            work: s.mostInfluential!,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => DetailScreen(work: s.mostInfluential!),
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
      ],
    );
  }
}

/// Two-column grid of [StatCard]s sized from the available width.
class _MetricsGrid extends StatelessWidget {
  const _MetricsGrid({required this.metrics});

  final List<_Metric> metrics;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const spacing = 8.0;
          final cardWidth = (constraints.maxWidth - spacing) / 2;
          return Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: [
              for (final m in metrics)
                SizedBox(
                  width: cardWidth,
                  child: StatCard(icon: m.icon, label: m.label, value: m.value),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _Metric {
  const _Metric(this.icon, this.label, this.value);
  final IconData icon;
  final String label;
  final String value;
}

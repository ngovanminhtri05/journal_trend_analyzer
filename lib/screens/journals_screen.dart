import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/openalex_service.dart';
import '../viewmodels/viewmodels.dart';
import '../widgets/widgets.dart';
import 'detail_screen.dart';

/// Journals tab (Lab 03): ranks the venues publishing on a topic by output, with
/// a proportional contribution bar per journal. Tapping a journal opens its
/// detail. Logic lives in [JournalsViewModel].
class JournalsScreen extends StatelessWidget {
  const JournalsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<JournalsViewModel>();

    return Column(
      children: [
        TopicSearchBar(
          hintText: 'Top journals for a topic (e.g. Robotics)',
          onSubmit: (q) => context.read<JournalsViewModel>().load(q),
        ),
        Expanded(child: _buildBody(context, vm)),
      ],
    );
  }

  Widget _buildBody(BuildContext context, JournalsViewModel vm) {
    switch (vm.state) {
      case ViewState.idle:
        return const EmptyView(
          icon: Icons.menu_book_outlined,
          message: 'Enter a topic to see its top publishing journals.',
        );
      case ViewState.loading:
        return const LoadingView(message: 'Ranking journals…');
      case ViewState.error:
        return ErrorView(
          message: vm.errorMessage ?? 'Something went wrong.',
          onRetry: vm.retry,
        );
      case ViewState.empty:
        return EmptyView(message: 'No journals found for "${vm.lastQuery}".');
      case ViewState.success:
        final theme = Theme.of(context);
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            StatCard(
              icon: Icons.summarize_outlined,
              label: 'Publications across top journals',
              value: '${vm.totalInTopJournals}',
            ),
            const SizedBox(height: 16),
            Text('Top journals', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            RankedCountList(
              items: vm.journals,
              bookmarkType: BookmarkType.journal,
              limit: 15,
              onItemTap: (item) => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => JournalDetailScreen(journal: item),
                ),
              ),
            ),
          ],
        );
    }
  }
}

/// Journal Detail (Lab 03): a venue's true publication count plus its most-cited
/// publications. Owns a scoped [JournalDetailViewModel].
class JournalDetailScreen extends StatelessWidget {
  const JournalDetailScreen({super.key, required this.journal});

  final GroupByItem journal;

  @override
  Widget build(BuildContext context) {
    return LogScreenView(
      log: (analytics) => analytics.logViewJournal(journal.keyDisplayName),
      child: ChangeNotifierProvider<JournalDetailViewModel>(
        create: (ctx) =>
            JournalDetailViewModel(ctx.read<OpenAlexService>())
              ..load(journal.key),
        child: Scaffold(
          appBar: AppBar(title: Text(journal.keyDisplayName)),
          body: ResponsiveBody(
            child: Consumer<JournalDetailViewModel>(
              builder: (context, vm, _) => _buildBody(context, vm),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, JournalDetailViewModel vm) {
    switch (vm.state) {
      case ViewState.idle:
      case ViewState.loading:
        return const LoadingView(message: 'Loading journal…');
      case ViewState.error:
        return ErrorView(
          message: vm.errorMessage ?? 'Something went wrong.',
          onRetry: vm.retry,
        );
      case ViewState.empty:
        return const EmptyView(
          message: 'No publications found for this journal.',
        );
      case ViewState.success:
        final theme = Theme.of(context);
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(journal.keyDisplayName, style: theme.textTheme.titleLarge),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: StatCard(
                    icon: Icons.article_outlined,
                    label: 'Total publications',
                    value: '${vm.totalPublications}',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: StatCard(
                    icon: Icons.format_quote_outlined,
                    label: 'Avg. citations (top ${vm.relatedWorks.length})',
                    value: vm.averageTopCitations.toStringAsFixed(1),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text('Most cited publications', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            for (var i = 0; i < vm.relatedWorks.length; i++)
              PaperCard(
                work: vm.relatedWorks[i],
                rank: i + 1,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => DetailScreen(work: vm.relatedWorks[i]),
                  ),
                ),
              ),
          ],
        );
    }
  }
}

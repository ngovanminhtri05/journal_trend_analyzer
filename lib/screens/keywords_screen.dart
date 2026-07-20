import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../firebase/firebase.dart';
import '../models/models.dart';
import '../services/openalex_service.dart';
import '../theme/app_theme.dart';
import '../viewmodels/viewmodels.dart';
import '../widgets/widgets.dart';
import 'detail_screen.dart';
import 'journals_screen.dart';

/// Keywords tab (Lab 03): ranks the most frequent keywords for a topic, with a
/// proportional frequency bar each. Tapping a keyword opens its analysis.
/// Logic lives in [KeywordsViewModel].
class KeywordsScreen extends StatelessWidget {
  const KeywordsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<KeywordsViewModel>();

    return Column(
      children: [
        TopicSearchBar(
          hintText: 'Analyze a research keyword (e.g. Genomics)',
          onSubmit: (q) => context.read<KeywordsViewModel>().load(q),
        ),
        Expanded(child: _buildBody(context, vm)),
      ],
    );
  }

  Widget _buildBody(BuildContext context, KeywordsViewModel vm) {
    switch (vm.state) {
      case ViewState.idle:
        return const EmptyView(
          icon: Icons.tag,
          message: 'Enter a topic to see its most frequent keywords.',
        );
      case ViewState.loading:
        return const LoadingView(message: 'Ranking keywords…');
      case ViewState.error:
        return ErrorView(
          message: vm.errorMessage ?? 'Something went wrong.',
          onRetry: vm.retry,
        );
      case ViewState.empty:
        return EmptyView(message: 'No keywords found for "${vm.lastQuery}".');
      case ViewState.success:
        final theme = Theme.of(context);
        final maxCount = vm.keywords.first.count;
        // Remote Config (task 8.4): the list length is server-tunable.
        // watch (not read) so a real-time Remote Config push re-limits the list.
        final maxKeywords = context.watch<RemoteConfigApi>().maxKeywords;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Most frequent keywords', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            for (var i = 0; i < vm.keywords.length && i < maxKeywords; i++)
              KeywordRankRow(
                rank: i + 1,
                item: vm.keywords[i],
                maxCount: maxCount,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        KeywordDetailScreen(keyword: vm.keywords[i]),
                  ),
                ),
              ),
          ],
        );
    }
  }
}

/// A tappable ranked keyword row: rank, name, proportional frequency bar, count.
/// (Keywords are not a bookmark type, so this is lighter than [RankedCountList].)
class KeywordRankRow extends StatelessWidget {
  const KeywordRankRow({
    super.key,
    required this.rank,
    required this.item,
    required this.maxCount,
    this.onTap,
  });

  final int rank;
  final GroupByItem item;
  final int maxCount;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fraction = maxCount == 0 ? 0.0 : item.count / maxCount;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            SizedBox(
              width: 24,
              child: Text(
                '$rank',
                style: AppTheme.mono(context, size: 13, color: AppTheme.muted),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.keyDisplayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: fraction,
                      minHeight: 6,
                      backgroundColor:
                          theme.colorScheme.surfaceContainerHighest,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '${item.count}',
              style: AppTheme.mono(context, size: 12, color: AppTheme.ink),
            ),
            const Icon(Icons.chevron_right, size: 18, color: AppTheme.muted),
          ],
        ),
      ),
    );
  }
}

/// Keyword Detail (Lab 03): year trend, top contributing authors (ranked desc),
/// related journals, and the most-cited related publications for one keyword.
/// Owns a scoped [KeywordDetailViewModel].
class KeywordDetailScreen extends StatelessWidget {
  const KeywordDetailScreen({super.key, required this.keyword});

  final GroupByItem keyword;

  @override
  Widget build(BuildContext context) {
    return LogScreenView(
      log: (analytics) => analytics.logViewKeyword(keyword.keyDisplayName),
      child: ChangeNotifierProvider<KeywordDetailViewModel>(
        create: (ctx) =>
            KeywordDetailViewModel(ctx.read<OpenAlexService>())
              ..load(keyword.key),
        child: Scaffold(
          appBar: AppBar(title: Text(keyword.keyDisplayName)),
          body: ResponsiveBody(
            child: Consumer<KeywordDetailViewModel>(
              builder: (context, vm, _) => _buildBody(context, vm),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, KeywordDetailViewModel vm) {
    switch (vm.state) {
      case ViewState.idle:
      case ViewState.loading:
        return const LoadingView(message: 'Analyzing keyword…');
      case ViewState.error:
        return ErrorView(
          message: vm.errorMessage ?? 'Something went wrong.',
          onRetry: vm.retry,
        );
      case ViewState.empty:
        return const EmptyView(message: 'No data available for this keyword.');
      case ViewState.success:
        final theme = Theme.of(context);
        final trend = vm.trendClassification;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    keyword.keyDisplayName,
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                if (trend != null) TrendBadge(classification: trend),
              ],
            ),
            const SizedBox(height: 16),
            // Top papers containing the keyword — shown first (Phase 13.4+).
            Text('Top publications', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            if (vm.relatedWorks.isEmpty)
              Text(
                'No publications found for this keyword.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              )
            else
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
            const SizedBox(height: 16),
            Text('Publications over time', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            YearBarChart(data: vm.yearCounts),
            const SizedBox(height: 16),
            Text('Top contributing authors', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            RankedCountList(
              items: vm.topAuthors,
              bookmarkType: BookmarkType.author,
              limit: 10,
            ),
            const SizedBox(height: 16),
            Text('Related journals', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            RankedCountList(
              items: vm.relatedJournals,
              bookmarkType: BookmarkType.journal,
              limit: 10,
              onItemTap: (item) => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => JournalDetailScreen(
                    sourceId: item.key,
                    title: item.keyDisplayName,
                  ),
                ),
              ),
            ),
          ],
        );
    }
  }
}

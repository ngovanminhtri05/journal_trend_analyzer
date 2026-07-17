import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/openalex_service.dart';
import '../viewmodels/viewmodels.dart';
import '../widgets/widgets.dart';
import 'detail_screen.dart';

/// Journals tab (Phase 13.3): search a publication venue by **name**, then open
/// it to browse its recent volumes and the articles inside each. Logic lives in
/// [JournalsViewModel].
class JournalsScreen extends StatelessWidget {
  const JournalsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<JournalsViewModel>();

    return Column(
      children: [
        TopicSearchBar(
          hintText: 'Search a journal by name (e.g. Nature)',
          onSubmit: (q) => context.read<JournalsViewModel>().search(q),
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
          message: 'Search a journal by name to see its recent volumes.',
        );
      case ViewState.loading:
        return const LoadingView(message: 'Finding journals…');
      case ViewState.error:
        return ErrorView(
          message: vm.errorMessage ?? 'Something went wrong.',
          onRetry: vm.retry,
        );
      case ViewState.empty:
        return EmptyView(message: 'No journals found for "${vm.lastQuery}".');
      case ViewState.success:
        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: vm.sources.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, i) => _SourceTile(source: vm.sources[i]),
        );
    }
  }
}

/// One journal search result: name, publisher/type, indexed works count.
class _SourceTile extends StatelessWidget {
  const _SourceTile({required this.source});

  final SourceHit source;

  @override
  Widget build(BuildContext context) {
    final subtitleParts = <String>[
      if (source.publisher != null && source.publisher!.isNotEmpty)
        source.publisher!,
      if (source.type != null && source.type!.isNotEmpty) source.type!,
      '${source.worksCount} works',
    ];
    return ListTile(
      leading: const Icon(Icons.menu_book_outlined),
      title: Text(source.displayName, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        subtitleParts.join(' · '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => JournalDetailScreen(
            sourceId: source.id,
            title: source.displayName,
          ),
        ),
      ),
    );
  }
}

/// Journal Detail (Phase 13.3): recent volumes of a venue; expand a volume to
/// read the articles it contains. Owns a scoped [JournalDetailViewModel].
class JournalDetailScreen extends StatelessWidget {
  const JournalDetailScreen({
    super.key,
    required this.sourceId,
    required this.title,
  });

  /// Full or short OpenAlex source id.
  final String sourceId;
  final String title;

  @override
  Widget build(BuildContext context) {
    return LogScreenView(
      log: (analytics) => analytics.logViewJournal(title),
      child: ChangeNotifierProvider<JournalDetailViewModel>(
        create: (ctx) =>
            JournalDetailViewModel(ctx.read<OpenAlexService>())..load(sourceId),
        child: Scaffold(
          appBar: AppBar(title: Text(title)),
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
        return const LoadingView(message: 'Loading recent volumes…');
      case ViewState.error:
        return ErrorView(
          message: vm.errorMessage ?? 'Something went wrong.',
          onRetry: vm.retry,
        );
      case ViewState.empty:
        return const EmptyView(
          message: 'No recent volumes found for this journal.',
        );
      case ViewState.success:
        final theme = Theme.of(context);
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(title, style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              'Recent volumes (${vm.volumes.length}) · '
              '${vm.recentWorkCount} recent articles',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            const SizedBox(height: 12),
            for (final volume in vm.volumes) _VolumeTile(volume: volume),
          ],
        );
    }
  }
}

/// One recent volume, expandable to reveal the articles it contains.
class _VolumeTile extends StatelessWidget {
  const _VolumeTile({required this.volume});

  final JournalVolume volume;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        title: Text(volume.label),
        subtitle: Text('${volume.count} articles'),
        childrenPadding: const EdgeInsets.only(bottom: 8),
        children: [
          for (final work in volume.works)
            PaperCard(
              work: work,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => DetailScreen(work: work)),
              ),
            ),
        ],
      ),
    );
  }
}

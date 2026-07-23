import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/openalex_service.dart';
import '../viewmodels/viewmodels.dart';
import '../widgets/widgets.dart';
import 'detail_screen.dart';

/// Journals tab (Phase 13.3): search a publication venue by **name**, then open
/// it to browse its recent volumes / search articles inside it, and bookmark it.
/// Logic lives in [JournalsViewModel].
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

/// One journal search result: name, publisher/type, works count, a bookmark
/// toggle, and navigation into the detail.
class _SourceTile extends StatelessWidget {
  const _SourceTile({required this.source});

  final SourceHit source;

  @override
  Widget build(BuildContext context) {
    final bookmarks = context.watch<BookmarkProvider>();
    final saved = bookmarks.isBookmarked(BookmarkType.journal, source.id);
    final subtitleParts = <String>[
      if (source.publisher != null && source.publisher!.isNotEmpty)
        source.publisher!,
      if (source.type != null && source.type!.isNotEmpty) source.type!,
      '${source.worksCount} works',
    ];
    return ListTile(
      leading: const Icon(Icons.menu_book_outlined),
      title: Text(
        source.displayName,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        subtitleParts.join(' · '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: saved ? 'Remove bookmark' : 'Bookmark journal',
            icon: Icon(saved ? Icons.bookmark : Icons.bookmark_border),
            onPressed: () =>
                bookmarks.toggle(Bookmark.fromSource(source)),
          ),
          const Icon(Icons.chevron_right),
        ],
      ),
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

/// Journal Detail (Phase 13.3): recent volumes of a venue (expand a volume to
/// read its articles), an in-journal search for a field/topic, and a bookmark
/// action. Owns a scoped [JournalDetailViewModel].
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
          appBar: AppBar(
            title: Text(title),
            actions: [
              _JournalBookmarkButton(sourceId: sourceId, title: title),
            ],
          ),
          body: ResponsiveBody(
            child: Consumer<JournalDetailViewModel>(
              builder: (context, vm, _) => Column(
                children: [
                  TopicSearchBar(
                    hintText: 'Search articles in this journal (e.g. a topic)',
                    onSubmit: (q) =>
                        context.read<JournalDetailViewModel>().search(q),
                  ),
                  Expanded(child: _buildBody(context, vm)),
                ],
              ),
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
        return LoadingView(
          message: vm.isSearching
              ? 'Searching this journal…'
              : 'Loading recent volumes…',
        );
      case ViewState.error:
        return ErrorView(
          message: vm.errorMessage ?? 'Something went wrong.',
          onRetry: vm.retry,
        );
      case ViewState.empty:
        return EmptyView(
          message: vm.isSearching
              ? 'No articles found for "${vm.query}" in this journal.'
              : 'No recent volumes found for this journal.',
        );
      case ViewState.success:
        return vm.isSearching
            ? _SearchResults(vm: vm)
            : _Volumes(vm: vm, title: title);
    }
  }
}

/// The recent-volumes view: a summary line + one expandable card per volume.
class _Volumes extends StatelessWidget {
  const _Volumes({required this.vm, required this.title});

  final JournalDetailViewModel vm;
  final String title;

  @override
  Widget build(BuildContext context) {
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

/// The in-journal search results: matching articles + a clear action.
class _SearchResults extends StatelessWidget {
  const _SearchResults({required this.vm});

  final JournalDetailViewModel vm;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${vm.searchResults.length} results for "${vm.query}"',
                style: theme.textTheme.titleSmall,
              ),
            ),
            TextButton.icon(
              onPressed: vm.clearSearch,
              icon: const Icon(Icons.close, size: 16),
              label: const Text('Clear'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        for (final work in vm.searchResults)
          PaperCard(
            work: work,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => DetailScreen(work: work)),
            ),
          ),
      ],
    );
  }
}

/// App-bar bookmark toggle for the journal being viewed.
class _JournalBookmarkButton extends StatelessWidget {
  const _JournalBookmarkButton({required this.sourceId, required this.title});

  final String sourceId;
  final String title;

  @override
  Widget build(BuildContext context) {
    final bookmarks = context.watch<BookmarkProvider>();
    final saved = bookmarks.isBookmarked(BookmarkType.journal, sourceId);
    return IconButton(
      tooltip: saved ? 'Remove bookmark' : 'Bookmark journal',
      icon: Icon(saved ? Icons.bookmark : Icons.bookmark_border),
      onPressed: () => bookmarks.toggle(
        Bookmark(
          type: BookmarkType.journal,
          id: sourceId,
          displayName: title,
        ),
      ),
    );
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

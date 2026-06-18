import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/services.dart';
import '../state/state.dart';
import '../theme/app_theme.dart';
import '../widgets/widgets.dart';
import 'detail_screen.dart';

/// My Collection screen (FR-10): the saved bookmarks, grouped by entity type.
///
/// Reads everything from [BookmarkProvider] (which is backed by offline
/// storage), so it works with no network. Publications can be re-opened in the
/// detail screen; every item can be removed.
class CollectionScreen extends StatelessWidget {
  const CollectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BookmarkProvider>();

    if (!provider.ready) {
      return const LoadingView(message: 'Loading your collection…');
    }
    if (provider.bookmarks.isEmpty) {
      return const EmptyView(
        icon: Icons.bookmark_border,
        message:
            'No bookmarks yet.\nTap the bookmark icon on a publication, '
            'journal or author to save it here.',
      );
    }

    final works = provider.byType(BookmarkType.work);
    final journals = provider.byType(BookmarkType.journal);
    final authors = provider.byType(BookmarkType.author);

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        if (works.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: FilledButton.tonalIcon(
              onPressed: () => _exportAll(context, works),
              icon: const Icon(Icons.ios_share, size: 18),
              label: Text('Export all publications (${works.length}) — BibTeX'),
            ),
          ),
        ..._section(context, 'Publications', Icons.article_outlined, works),
        ..._section(context, 'Journals', Icons.menu_book, journals),
        ..._section(context, 'Authors', Icons.people_outline, authors),
      ],
    );
  }

  /// FR-14 Export All: re-fetch full Works for bookmarked publications (to get
  /// authors/biblio) and emit one multi-entry BibTeX string. Bookmarks whose id
  /// is not an OpenAlex work id — or everything, if the network fails — fall
  /// back to the minimal fields stored on the bookmark.
  Future<void> _exportAll(
    BuildContext context,
    List<Bookmark> publications,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final service = context.read<OpenAlexService>();

    final fetchable = <Work>[]; // minimal works carrying a real W-id
    final offline = <Work>[]; // not fetchable → minimal only
    final wIdPattern = RegExp(r'^W\d+$');
    for (final b in publications) {
      final work = b.toWork();
      if (wIdPattern.hasMatch(work.shortId ?? '')) {
        fetchable.add(work);
      } else {
        offline.add(work);
      }
    }

    List<Work> enriched;
    try {
      enriched = fetchable.isEmpty
          ? const []
          : await service.fetchWorksByIds(
              fetchable.map((w) => w.shortId!).toList(),
            );
    } catch (_) {
      enriched = fetchable; // degrade to stored fields on network failure
    }

    final works = [...enriched, ...offline];
    if (works.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Nothing to export.')),
      );
      return;
    }
    if (!context.mounted) return;
    await showExportTextSheet(
      context,
      title: 'Export all — BibTeX (${works.length})',
      text: CitationFormatter.toBibTeXList(works),
    );
  }

  List<Widget> _section(
    BuildContext context,
    String title,
    IconData icon,
    List<Bookmark> items,
  ) {
    if (items.isEmpty) return const [];
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Row(
          children: [
            Icon(icon, size: 18),
            const SizedBox(width: 8),
            Text('$title (${items.length})',
                style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
      ),
      for (final b in items) _BookmarkTile(bookmark: b),
    ];
  }
}

class _BookmarkTile extends StatelessWidget {
  const _BookmarkTile({required this.bookmark});

  final Bookmark bookmark;

  @override
  Widget build(BuildContext context) {
    final isWork = bookmark.type == BookmarkType.work;

    return ListTile(
      title: Text(
        bookmark.displayName,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(_subtitle(), style: AppTheme.mono(context, size: 11)),
      // Only publications have a detail view to re-open offline.
      onTap: isWork
          ? () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => DetailScreen(work: bookmark.toWork()),
                ),
              )
          : null,
      trailing: IconButton(
        tooltip: 'Remove',
        icon: const Icon(Icons.delete_outline),
        onPressed: () => context.read<BookmarkProvider>().remove(
              bookmark.type,
              bookmark.id,
            ),
      ),
    );
  }

  /// A compact, offline-friendly subtitle per entity type.
  String _subtitle() {
    switch (bookmark.type) {
      case BookmarkType.work:
        final year = bookmark.publicationYear?.toString() ?? 'n/a';
        final cites = bookmark.citedByCount ?? 0;
        final journal = bookmark.journalName;
        final base = '$year   ·   $cites citations';
        return journal == null ? base : '$base   ·   $journal';
      case BookmarkType.journal:
      case BookmarkType.author:
        final n = bookmark.worksCount ?? 0;
        return '$n publications';
    }
  }
}

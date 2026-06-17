import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
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
        ..._section(context, 'Publications', Icons.article_outlined, works),
        ..._section(context, 'Journals', Icons.menu_book, journals),
        ..._section(context, 'Authors', Icons.people_outline, authors),
      ],
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

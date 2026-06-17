import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/state.dart';
import '../theme/app_theme.dart';

/// Ranked list of `group_by` buckets (FR-5 journals, FR-6 authors).
///
/// Shows a rank, the display name, a proportional bar, the count, and a bookmark
/// toggle (FR-10). [bookmarkType] tells each row whether it is saving a journal
/// or an author. Renders the top [limit] entries by count.
class RankedCountList extends StatelessWidget {
  const RankedCountList({
    super.key,
    required this.items,
    required this.bookmarkType,
    this.limit = 8,
  });

  final List<GroupByItem> items;

  /// Whether the rows bookmark journals or authors.
  final BookmarkType bookmarkType;
  final int limit;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text('No data available.'),
      );
    }

    final sorted = [...items]..sort((a, b) => b.count.compareTo(a.count));
    final top = (limit > 0 ? sorted.take(limit) : sorted).toList();
    if (top.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text('No data available.'),
      );
    }
    final maxCount = top.first.count;

    return Column(
      children: [
        for (var i = 0; i < top.length; i++)
          _RankRow(
            rank: i + 1,
            item: top[i],
            maxCount: maxCount,
            bookmarkType: bookmarkType,
          ),
      ],
    );
  }
}

class _RankRow extends StatelessWidget {
  const _RankRow({
    required this.rank,
    required this.item,
    required this.maxCount,
    required this.bookmarkType,
  });

  final int rank;
  final GroupByItem item;
  final int maxCount;
  final BookmarkType bookmarkType;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fraction = maxCount == 0 ? 0.0 : item.count / maxCount;
    final bookmarks = context.watch<BookmarkProvider>();
    final saved = bookmarks.isBookmarked(bookmarkType, item.key);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
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
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
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
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: saved ? 'Remove bookmark' : 'Save bookmark',
            icon: Icon(
              saved ? Icons.bookmark : Icons.bookmark_border,
              size: 18,
            ),
            onPressed: () => bookmarks.toggle(_toBookmark()),
          ),
        ],
      ),
    );
  }

  Bookmark _toBookmark() => bookmarkType == BookmarkType.journal
      ? Bookmark.fromJournal(item)
      : Bookmark.fromAuthor(item);
}

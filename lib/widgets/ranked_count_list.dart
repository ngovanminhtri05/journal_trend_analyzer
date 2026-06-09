import 'package:flutter/material.dart';

import '../models/models.dart';

/// Ranked list of `group_by` buckets (FR-5 journals, FR-6 authors).
///
/// Shows a rank, the display name, a proportional bar, and the count. Renders
/// the top [limit] entries by count.
class RankedCountList extends StatelessWidget {
  const RankedCountList({super.key, required this.items, this.limit = 8});

  final List<GroupByItem> items;
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
    final top = sorted.take(limit).toList();
    final maxCount = top.first.count;

    return Column(
      children: [
        for (var i = 0; i < top.length; i++)
          _RankRow(rank: i + 1, item: top[i], maxCount: maxCount),
      ],
    );
  }
}

class _RankRow extends StatelessWidget {
  const _RankRow({
    required this.rank,
    required this.item,
    required this.maxCount,
  });

  final int rank;
  final GroupByItem item;
  final int maxCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fraction = maxCount == 0 ? 0.0 : item.count / maxCount;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: Text('$rank.', style: theme.textTheme.labelLarge),
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
          Text('${item.count}', style: theme.textTheme.labelMedium),
        ],
      ),
    );
  }
}

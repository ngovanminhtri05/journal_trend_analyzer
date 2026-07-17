import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme/app_theme.dart';

/// Compact card for a publication in a list (FR-1): title, journal, year and
/// citation count. Optional [rank] shows a mono position number (used by
/// top-cited lists); optional [onTap] navigates to the detail screen.
class PaperCard extends StatelessWidget {
  const PaperCard({super.key, required this.work, this.onTap, this.rank});

  final Work work;
  final VoidCallback? onTap;
  final int? rank;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final year = work.publicationYear?.toString() ?? 'n/a';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Card(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (rank != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 12, top: 2),
                    child: Text(
                      rank!.toString().padLeft(2, '0'),
                      style: AppTheme.mono(
                        context,
                        size: 13,
                        color: AppTheme.muted,
                      ),
                    ),
                  ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        work.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium,
                      ),
                      if (work.journalName != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          work.journalName!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppTheme.muted,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Text(
                        '$year   ·   ${work.citedByCount} citations',
                        style: AppTheme.mono(context, size: 11),
                      ),
                    ],
                  ),
                ),
                if (onTap != null)
                  const Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: AppTheme.muted,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

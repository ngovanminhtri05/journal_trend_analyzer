import 'package:flutter/material.dart';

import '../models/models.dart';

/// Compact card for a publication in a list (FR-1): title, year, citations,
/// and journal. Optional [rank] shows a position badge (used by top-cited
/// lists); optional [onTap] navigates to the detail screen.
class PaperCard extends StatelessWidget {
  const PaperCard({super.key, required this.work, this.onTap, this.rank});

  final Work work;
  final VoidCallback? onTap;
  final int? rank;

  @override
  Widget build(BuildContext context) {
    final year = work.publicationYear?.toString() ?? 'n/a';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        onTap: onTap,
        leading: rank != null
            ? CircleAvatar(child: Text('$rank'))
            : const Icon(Icons.article_outlined),
        title: Text(work.title, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            if (work.journalName != null)
              Text(
                work.journalName!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            const SizedBox(height: 4),
            Row(
              children: [
                _Chip(icon: Icons.calendar_today, label: year),
                const SizedBox(width: 8),
                _Chip(
                  icon: Icons.format_quote,
                  label: '${work.citedByCount} citations',
                ),
              ],
            ),
          ],
        ),
        trailing: onTap != null ? const Icon(Icons.chevron_right) : null,
        isThreeLine: true,
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14),
        const SizedBox(width: 4),
        Text(label, style: style),
      ],
    );
  }
}

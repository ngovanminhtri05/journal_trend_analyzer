import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/state.dart';
import '../widgets/widgets.dart';

/// Topic comparison screen (FR-8).
///
/// Lets the user enter 2–3 topic keywords, then charts their publications-per-
/// year on one multi-line chart and tabulates headline stats. Any active FR-13
/// taxonomy filter is applied to every topic. Each topic resolves independently,
/// so one failure does not break the screen.
class ComparisonScreen extends StatefulWidget {
  const ComparisonScreen({super.key});

  @override
  State<ComparisonScreen> createState() => _ComparisonScreenState();
}

class _ComparisonScreenState extends State<ComparisonScreen> {
  // Start with the two required inputs; up to [ComparisonProvider.maxTopics].
  final List<TextEditingController> _controllers = [
    TextEditingController(),
    TextEditingController(),
  ];

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _addField() {
    if (_controllers.length >= ComparisonProvider.maxTopics) return;
    setState(() => _controllers.add(TextEditingController()));
  }

  void _removeField(int index) {
    if (_controllers.length <= ComparisonProvider.minTopics) return;
    setState(() {
      _controllers.removeAt(index).dispose();
    });
  }

  void _compare() {
    final topics = _controllers
        .map((c) => c.text.trim())
        .where((t) => t.isNotEmpty)
        .toList();
    if (topics.length < ComparisonProvider.minTopics) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter at least 2 topics to compare.')),
      );
      return;
    }
    FocusScope.of(context).unfocus();
    final filters = context.read<FilterProvider>().activeFilterClauses;
    context.read<ComparisonProvider>().compare(topics, filters: filters);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ComparisonProvider>();
    final filterActive = context.watch<FilterProvider>().hasActiveFilter;

    return Column(
      children: [
        _buildInputs(filterActive),
        const Divider(height: 1),
        Expanded(child: _buildBody(provider)),
      ],
    );
  }

  Widget _buildInputs(bool filterActive) {
    final canAdd = _controllers.length < ComparisonProvider.maxTopics;
    final canRemove = _controllers.length > ComparisonProvider.minTopics;

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          for (var i = 0; i < _controllers.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controllers[i],
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: 'Topic ${i + 1}',
                        hintText: 'e.g. Deep Learning',
                        prefixIcon: const Icon(Icons.topic_outlined, size: 20),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Remove topic',
                    onPressed: canRemove ? () => _removeField(i) : null,
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              TextButton.icon(
                onPressed: canAdd ? _addField : null,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add topic'),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: _compare,
                icon: const Icon(Icons.compare_arrows, size: 18),
                label: const Text('Compare'),
              ),
            ],
          ),
          if (filterActive)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  const Icon(Icons.filter_list, size: 14),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Taxonomy filter from Search is applied to every topic.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBody(ComparisonProvider provider) {
    if (provider.state == ViewState.loading) {
      return const LoadingView(message: 'Comparing topics…');
    }
    if (provider.state != ViewState.success) {
      // idle (and any unused states): prompt the user.
      return const EmptyView(
        icon: Icons.compare_arrows,
        message: 'Enter 2–3 topics and tap Compare to chart them side by side.',
      );
    }

    final results = provider.results;
    final anyChart = results.any((r) => r.hasChartData);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Publications per year',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        if (anyChart)
          MultiLineYearChart(topics: results)
        else
          const EmptyView(message: 'No yearly data for these topics.'),
        const SizedBox(height: 24),
        Text(
          'Comparison',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        _ComparisonTable(results: results),
        const SizedBox(height: 16),
        // Surface per-topic errors explicitly (the table also marks them).
        for (final r in results)
          if (r.status == TopicStatus.error)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '"${r.topic}": ${r.errorMessage ?? 'failed to load.'}',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
      ],
    );
  }
}

/// Side-by-side stats table: one row per topic (FR-8 #5).
class _ComparisonTable extends StatelessWidget {
  const _ComparisonTable({required this.results});

  final List<TopicComparison> results;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 24,
        columns: const [
          DataColumn(label: Text('Topic')),
          DataColumn(label: Text('Total'), numeric: true),
          DataColumn(label: Text('Avg cites'), numeric: true),
          DataColumn(label: Text('Peak year'), numeric: true),
        ],
        rows: [
          for (var i = 0; i < results.length; i++) _row(context, i, results[i]),
        ],
      ),
    );
  }

  DataRow _row(BuildContext context, int index, TopicComparison r) {
    final ok = r.status == TopicStatus.success;
    final note = switch (r.status) {
      TopicStatus.success => null,
      TopicStatus.empty => 'no data',
      TopicStatus.error => 'error',
    };

    return DataRow(
      cells: [
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: ComparisonPalette.colorAt(index),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 160),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      r.topic,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (r.classification != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: TrendBadge(
                          classification: r.classification!,
                          dense: true,
                        ),
                      ),
                    if (note != null)
                      Text(
                        note,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: r.status == TopicStatus.error
                              ? Theme.of(context).colorScheme.error
                              : Theme.of(context).colorScheme.outline,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        DataCell(Text(ok ? _formatInt(r.totalPublications) : '—')),
        DataCell(Text(ok ? r.averageCitations.toStringAsFixed(1) : '—')),
        DataCell(Text(ok ? (r.peakYear?.toString() ?? '—') : '—')),
      ],
    );
  }

  /// Adds thousands separators (e.g. 1234567 → 1,234,567).
  String _formatInt(int value) {
    final s = value.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buffer.write(',');
      buffer.write(s[i]);
    }
    return buffer.toString();
  }
}

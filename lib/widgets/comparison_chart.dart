import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../state/state.dart';

/// Index-stable colors for compared topics, shared by the chart legend and the
/// comparison table so a topic keeps the same color everywhere (FR-8).
class ComparisonPalette {
  const ComparisonPalette._();

  static const List<Color> colors = [
    Color(0xFF2F3437), // charcoal (matches AppTheme.ink)
    Color(0xFF1F6C9F), // blue (matches AppTheme.paleBlueInk)
    Color(0xFFB45309), // terracotta
  ];

  static Color colorAt(int index) => colors[index % colors.length];
}

/// Multi-line chart of publications-per-year for several topics (FR-8 #4).
///
/// Takes the full comparison [topics] list and draws one line per topic that
/// has chart data, using [ComparisonPalette] colors keyed by the topic's index
/// in that list (so the color matches the table). Years are unified across
/// topics, sorted chronologically, and trimmed to the most recent [maxYears] so
/// the chart stays readable on a phone.
class MultiLineYearChart extends StatelessWidget {
  const MultiLineYearChart({
    super.key,
    required this.topics,
    this.maxYears = 12,
  });

  final List<TopicComparison> topics;
  final int maxYears;

  @override
  Widget build(BuildContext context) {
    // Build a (originalIndex, year→count) series for each chartable topic.
    final series = <_Series>[];
    for (var i = 0; i < topics.length; i++) {
      final t = topics[i];
      if (!t.hasChartData) continue;
      final counts = <int, int>{};
      for (final g in t.yearCounts) {
        final year = int.tryParse(g.key);
        if (year != null) counts[year] = g.count;
      }
      if (counts.isNotEmpty) {
        series.add(_Series(index: i, topic: t.topic, counts: counts));
      }
    }

    if (series.isEmpty) {
      return const SizedBox(
        height: 120,
        child: Center(child: Text('No yearly data to chart.')),
      );
    }

    // Unified, sorted, recent-trimmed list of years across all series.
    final yearSet = <int>{};
    for (final s in series) {
      yearSet.addAll(s.counts.keys);
    }
    final allYears = yearSet.toList()..sort();
    final years = allYears.length <= maxYears
        ? allYears
        : allYears.sublist(allYears.length - maxYears);
    final xOf = {for (var i = 0; i < years.length; i++) years[i]: i};

    var maxCount = 1;
    for (final s in series) {
      for (final y in years) {
        final c = s.counts[y] ?? 0;
        if (c > maxCount) maxCount = c;
      }
    }

    final theme = Theme.of(context);
    const leftReserved = 44.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Legend(series: series),
        const SizedBox(height: 12),
        SizedBox(
          height: 260,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final plotWidth = (constraints.maxWidth - leftReserved).clamp(
                1.0,
                double.infinity,
              );
              // Thin year labels so 4-digit years never overlap on a phone.
              final maxLabels = (plotWidth / 44).floor().clamp(2, years.length);
              final labelStep = (years.length / maxLabels).ceil();

              return LineChart(
                LineChartData(
                  minX: 0,
                  maxX: (years.length - 1).toDouble(),
                  minY: 0,
                  maxY: maxCount * 1.2,
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipItems: (spots) => spots.map((spot) {
                        final s = series[spot.barIndex];
                        return LineTooltipItem(
                          '${s.topic}: ${spot.y.toInt()}',
                          TextStyle(color: ComparisonPalette.colorAt(s.index)),
                        );
                      }).toList(),
                    ),
                  ),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: leftReserved,
                        getTitlesWidget: (value, meta) {
                          if (value != meta.max &&
                              value != value.roundToDouble()) {
                            return const SizedBox.shrink();
                          }
                          return Text(
                            _compact(value),
                            style: theme.textTheme.labelSmall,
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        getTitlesWidget: (value, meta) {
                          final i = value.toInt();
                          if (i < 0 ||
                              i >= years.length ||
                              value != value.roundToDouble()) {
                            return const SizedBox.shrink();
                          }
                          final last = years.length - 1;
                          final show =
                              i == last ||
                              (i % labelStep == 0 && (last - i) >= labelStep);
                          if (!show) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              '${years[i]}',
                              style: theme.textTheme.labelSmall,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  gridData: const FlGridData(show: true, drawVerticalLine: false),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    for (final s in series)
                      LineChartBarData(
                        isCurved: false,
                        color: ComparisonPalette.colorAt(s.index),
                        barWidth: 2.5,
                        dotData: const FlDotData(show: false),
                        spots: [
                          for (final y in years)
                            FlSpot(
                              xOf[y]!.toDouble(),
                              (s.counts[y] ?? 0).toDouble(),
                            ),
                        ],
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  /// Formats an axis value compactly: 1500 → "1.5k", 2000000 → "2M".
  String _compact(double value) {
    final v = value.round();
    if (v >= 1000000) {
      return '${(v / 1000000).toStringAsFixed(v % 1000000 == 0 ? 0 : 1)}M';
    }
    if (v >= 1000) {
      return '${(v / 1000).toStringAsFixed(v % 1000 == 0 ? 0 : 1)}k';
    }
    return '$v';
  }
}

/// One chartable topic: its original index (for color) and year→count map.
class _Series {
  const _Series({
    required this.index,
    required this.topic,
    required this.counts,
  });

  final int index;
  final String topic;
  final Map<int, int> counts;
}

class _Legend extends StatelessWidget {
  const _Legend({required this.series});

  final List<_Series> series;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 6,
      children: [
        for (final s in series)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: ComparisonPalette.colorAt(s.index),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 6),
              Text(s.topic, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
      ],
    );
  }
}

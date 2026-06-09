import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/models.dart';

/// Bar chart of publication counts per year (FR-3).
///
/// Expects raw `group_by=publication_year` buckets. It sorts them
/// chronologically and shows the most recent [maxYears] years so the trend
/// stays readable on a phone.
class YearBarChart extends StatelessWidget {
  const YearBarChart({super.key, required this.data, this.maxYears = 12});

  final List<GroupByItem> data;
  final int maxYears;

  @override
  Widget build(BuildContext context) {
    final years = _orderedYears();
    if (years.isEmpty) {
      return const SizedBox(
        height: 100,
        child: Center(child: Text('No yearly data.')),
      );
    }

    final maxCount =
        years.map((e) => e.count).reduce((a, b) => a > b ? a : b).toDouble();
    final theme = Theme.of(context);

    return SizedBox(
      height: 240,
      child: BarChart(
        BarChartData(
          maxY: maxCount * 1.2,
          alignment: BarChartAlignment.spaceAround,
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, _, rod, _) => BarTooltipItem(
                '${years[group.x].keyDisplayName}\n${rod.toY.toInt()}',
                TextStyle(color: theme.colorScheme.onInverseSurface),
              ),
            ),
          ),
          titlesData: FlTitlesData(
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                getTitlesWidget: (value, meta) {
                  if (value != value.roundToDouble()) {
                    return const SizedBox.shrink();
                  }
                  return Text(value.toInt().toString(),
                      style: theme.textTheme.labelSmall);
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= years.length) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(years[i].keyDisplayName,
                        style: theme.textTheme.labelSmall),
                  );
                },
              ),
            ),
          ),
          gridData: const FlGridData(show: true, drawVerticalLine: false),
          borderData: FlBorderData(show: false),
          barGroups: [
            for (var i = 0; i < years.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: years[i].count.toDouble(),
                    color: theme.colorScheme.primary,
                    width: 14,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(4),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  /// Parses year keys, drops unparseable ones, sorts ascending, and keeps the
  /// most recent [maxYears].
  List<GroupByItem> _orderedYears() {
    final parsed = data
        .where((e) => int.tryParse(e.key) != null)
        .toList()
      ..sort((a, b) => int.parse(a.key).compareTo(int.parse(b.key)));
    if (parsed.length <= maxYears) return parsed;
    return parsed.sublist(parsed.length - maxYears);
  }
}

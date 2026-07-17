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

  /// Width reserved for the Y axis (shared by the layout math and the titles).
  static const double _leftReserved = 44.0;

  @override
  Widget build(BuildContext context) {
    final years = _orderedYears();
    if (years.isEmpty) {
      return const SizedBox(
        height: 100,
        child: Center(child: Text('No yearly data.')),
      );
    }

    final maxCount = years
        .map((e) => e.count)
        .reduce((a, b) => a > b ? a : b)
        .toDouble();

    return SizedBox(
      height: 240,
      child: LayoutBuilder(
        builder: (context, constraints) =>
            _buildChart(context, years, maxCount, constraints),
      ),
    );
  }

  /// Builds the chart for the given layout [constraints], sizing the bars and
  /// thinning the year labels so they stay readable on the available width.
  Widget _buildChart(
    BuildContext context,
    List<GroupByItem> years,
    double maxCount,
    BoxConstraints constraints,
  ) {
    // Plot width available to the bars (chart width minus the Y axis).
    final plotWidth = (constraints.maxWidth - _leftReserved).clamp(
      1.0,
      double.infinity,
    );
    final slot = plotWidth / years.length;
    // Bar fills ~55% of its slot, clamped so it never overlaps a neighbour on
    // narrow screens nor looks like a hairline on wide ones.
    final barWidth = (slot * 0.55).clamp(5.0, 16.0);
    // Show at most as many year labels as comfortably fit (~40px each),
    // skipping the rest so 4-digit years never overlap on a phone.
    final maxLabels = (plotWidth / 40).floor().clamp(2, years.length);
    final labelStep = (years.length / maxLabels).ceil();
    final theme = Theme.of(context);

    return BarChart(
      BarChartData(
        maxY: maxCount * 1.2,
        alignment: BarChartAlignment.spaceAround,
        barTouchData: _touchData(theme, years),
        titlesData: _titlesData(theme, years, labelStep),
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        borderData: FlBorderData(show: false),
        barGroups: _barGroups(theme, years, barWidth),
      ),
    );
  }

  /// Tooltip showing the hovered year and its publication count.
  BarTouchData _touchData(ThemeData theme, List<GroupByItem> years) {
    return BarTouchData(
      touchTooltipData: BarTouchTooltipData(
        getTooltipItem: (group, _, rod, _) => BarTooltipItem(
          '${years[group.x].keyDisplayName}\n${rod.toY.toInt()}',
          TextStyle(color: theme.colorScheme.onInverseSurface),
        ),
      ),
    );
  }

  /// Axis titles: a compact Y axis and a thinned X (year) axis; top/right hidden.
  FlTitlesData _titlesData(
    ThemeData theme,
    List<GroupByItem> years,
    int labelStep,
  ) {
    return FlTitlesData(
      topTitles: const AxisTitles(
        sideTitles: SideTitles(showTitles: false),
      ),
      rightTitles: const AxisTitles(
        sideTitles: SideTitles(showTitles: false),
      ),
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: _leftReserved,
          getTitlesWidget: (value, meta) {
            if (value != meta.max && value != value.roundToDouble()) {
              return const SizedBox.shrink();
            }
            return Text(_compact(value), style: theme.textTheme.labelSmall);
          },
        ),
      ),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 28,
          getTitlesWidget: (value, meta) =>
              _bottomTitle(theme, years, labelStep, value),
        ),
      ),
    );
  }

  /// One X-axis (year) label, thinned so labels never crowd the most recent.
  Widget _bottomTitle(
    ThemeData theme,
    List<GroupByItem> years,
    int labelStep,
    double value,
  ) {
    final i = value.toInt();
    if (i < 0 || i >= years.length) {
      return const SizedBox.shrink();
    }
    // Always keep the most recent year, then thin the rest — skipping any
    // regular label that would crowd the last.
    final last = years.length - 1;
    final show = i == last || (i % labelStep == 0 && (last - i) >= labelStep);
    if (!show) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(years[i].keyDisplayName, style: theme.textTheme.labelSmall),
    );
  }

  /// One rounded bar per year, coloured with the theme primary.
  List<BarChartGroupData> _barGroups(
    ThemeData theme,
    List<GroupByItem> years,
    double barWidth,
  ) {
    return [
      for (var i = 0; i < years.length; i++)
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: years[i].count.toDouble(),
              color: theme.colorScheme.primary,
              width: barWidth,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(4),
              ),
            ),
          ],
        ),
    ];
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

  /// Parses year keys, drops unparseable ones, sorts ascending, and keeps the
  /// most recent [maxYears].
  List<GroupByItem> _orderedYears() {
    final parsed = data.where((e) => int.tryParse(e.key) != null).toList()
      ..sort((a, b) => int.parse(a.key).compareTo(int.parse(b.key)));
    if (parsed.length <= maxYears) return parsed;
    return parsed.sublist(parsed.length - maxYears);
  }
}

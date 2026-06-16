import 'package:flutter/material.dart';

import '../services/services.dart';

/// Visual badge for a topic's trend classification (FR-9).
///
/// Maps a [TrendClassification] to a colored pill with an emoji, a Vietnamese
/// label, and a tooltip explaining *why* the topic was classified that way. All
/// Vietnamese, color and icon choices live here so the classifier stays a pure,
/// UI-agnostic helper.
///
/// Set [dense] for tight contexts (e.g. the comparison table) to drop the
/// padding and shrink the text.
class TrendBadge extends StatelessWidget {
  const TrendBadge({super.key, required this.classification, this.dense = false});

  final TrendClassification classification;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final style = _styleFor(classification.category);
    // Round to whole percent for a friendly explanation; the normalized slope
    // is fractional growth per year (0.12 → 12%/yr).
    final pct = (classification.normalizedSlope * 100).abs().round();
    final range = '${classification.fromYear}–${classification.toYear}';

    return Tooltip(
      message: _tooltipFor(classification.category, pct, range),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: dense ? 8 : 10,
          vertical: dense ? 3 : 5,
        ),
        decoration: BoxDecoration(
          color: style.background,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          style.label,
          style: TextStyle(
            color: style.foreground,
            fontSize: dense ? 11 : 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  _BadgeStyle _styleFor(TrendCategory category) {
    switch (category) {
      case TrendCategory.emerging:
        return const _BadgeStyle(
          label: 'Đang lên',
          foreground: Color(0xFF1B7F4B),
          background: Color(0xFFE3F4EA),
        );
      case TrendCategory.mature:
        return const _BadgeStyle(
          label: 'Bão hòa',
          foreground: Color(0xFF8A6D1A),
          background: Color(0xFFF6EFD9),
        );
      case TrendCategory.declining:
        return const _BadgeStyle(
          label: 'Đang giảm',
          foreground: Color(0xFF9F2F2D),
          background: Color(0xFFF7E4E3),
        );
    }
  }

  String _tooltipFor(TrendCategory category, int pct, String range) {
    switch (category) {
      case TrendCategory.emerging:
        return 'Giai đoạn $range: số công bố tăng ~$pct%/năm → chủ đề đang lên.';
      case TrendCategory.mature:
        return 'Giai đoạn $range: số công bố gần như đi ngang (~$pct%/năm) → đã bão hòa.';
      case TrendCategory.declining:
        return 'Giai đoạn $range: số công bố giảm ~$pct%/năm → chủ đề đang giảm.';
    }
  }
}

class _BadgeStyle {
  const _BadgeStyle({
    required this.label,
    required this.foreground,
    required this.background,
  });

  final String label;
  final Color foreground;
  final Color background;
}

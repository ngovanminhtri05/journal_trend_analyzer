import '../models/models.dart';

/// Trend classification (FR-9).
///
/// Classifies a topic's publication trajectory as Emerging / Mature / Declining
/// from the slope of a best-fit line over its recent yearly publication counts.
/// This is a pure, UI-agnostic helper so it stays trivially unit-testable; the
/// Vietnamese labels, colors and icons live in the `TrendBadge` widget.

/// Coarse direction of a topic's publication trend.
enum TrendCategory { emerging, mature, declining }

/// Result of classifying a topic's yearly publication counts.
class TrendClassification {
  const TrendClassification({
    required this.category,
    required this.slope,
    required this.normalizedSlope,
    required this.fromYear,
    required this.toYear,
  });

  final TrendCategory category;

  /// Raw best-fit slope: change in publications per year.
  final double slope;

  /// Slope divided by the mean yearly count — a scale-independent "fractional
  /// growth per year" (e.g. 0.12 ≈ +12%/yr). This is what the threshold uses.
  final double normalizedSlope;

  /// Inclusive year range the verdict was computed over.
  final int fromYear;
  final int toYear;
}

/// Returns the slope of the best-fit line over yearly publication counts.
///
/// Ordinary least-squares slope = Σ(x-x̄)(y-ȳ) / Σ(x-x̄)². Returns 0 when there
/// are fewer than two points or all years are identical (zero variance in x).
double computeTrendSlope(Map<int, int> yearCounts) {
  if (yearCounts.length < 2) return 0;
  final years = yearCounts.keys.toList()..sort();
  final n = years.length;
  final meanX = years.reduce((a, b) => a + b) / n;
  final meanY = yearCounts.values.reduce((a, b) => a + b) / n;
  double num = 0, den = 0;
  for (final y in years) {
    final dx = y - meanX;
    num += dx * (yearCounts[y]! - meanY);
    den += dx * dx;
  }
  return den == 0 ? 0 : num / den;
}

/// Classifies a topic's publication trend over its most recent [window] years
/// (FR-9). Pass the raw `group_by=publication_year` buckets.
///
/// Returns `null` when fewer than two usable years are available (a slope is
/// meaningless with one point).
///
/// Threshold logic: we compare the *normalized* slope (slope / mean count), not
/// the raw slope, so the verdict does not depend on the topic's absolute size —
/// +50 papers/yr is explosive for a niche topic averaging 100/yr but noise for
/// one averaging 50,000/yr. A band of ±[flatThreshold] (default 5%/yr) is
/// treated as "flat enough" → Mature; beyond it → Emerging / Declining. 5%/yr
/// is a small but clearly directional change for a bibliometric series.
TrendClassification? classifyTrend(
  List<GroupByItem> yearBuckets, {
  int window = 6,
  double flatThreshold = 0.05,
}) {
  // Parse "publication_year" buckets into year → count, dropping non-numeric
  // keys (the group_by response is ordered by count, not year).
  final all = <int, int>{};
  for (final bucket in yearBuckets) {
    final year = int.tryParse(bucket.key);
    if (year != null) all[year] = bucket.count;
  }
  if (all.length < 2) return null;

  // Keep only the most recent [window] years, so the verdict reflects the
  // current trajectory rather than the topic's entire history.
  //
  // Note: the latest calendar year is often still being indexed by OpenAlex and
  // can read artificially low; we keep it for simplicity, but that is the main
  // source of a falsely "Declining" verdict on otherwise hot topics.
  final years = all.keys.toList()..sort();
  final recent = years.length <= window
      ? years
      : years.sublist(years.length - window);
  final recentCounts = {for (final y in recent) y: all[y]!};

  final slope = computeTrendSlope(recentCounts);
  final meanY =
      recentCounts.values.reduce((a, b) => a + b) / recentCounts.length;
  final normalized = meanY == 0 ? 0.0 : slope / meanY;

  final TrendCategory category;
  if (normalized > flatThreshold) {
    category = TrendCategory.emerging;
  } else if (normalized < -flatThreshold) {
    category = TrendCategory.declining;
  } else {
    category = TrendCategory.mature;
  }

  return TrendClassification(
    category: category,
    slope: slope,
    normalizedSlope: normalized,
    fromYear: recent.first,
    toYear: recent.last,
  );
}

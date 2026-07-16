import '../models/models.dart';

/// Lightweight research-gap heuristic for the citation tree (FR-15).
///
/// Pure and UI-agnostic so it is easy to unit-test. In the "Cited by" direction,
/// a paper that cites the current work but is itself **recent** and **not yet
/// widely cited** marks a fresh line of work that has not been picked up — a
/// candidate research gap / opportunity to build on.
class ResearchGap {
  const ResearchGap._();

  /// A citing paper counts as "emerging" when published within [recentYears] of
  /// [currentYear] and cited fewer than [maxCitations] times.
  static bool isEmerging(
    Work work, {
    required int currentYear,
    int recentYears = 3,
    int maxCitations = 10,
  }) {
    final year = work.publicationYear;
    if (year == null) return false;
    return year >= currentYear - recentYears && work.citedByCount < maxCitations;
  }

  /// How many of [works] are emerging.
  static int countEmerging(
    Iterable<Work> works, {
    required int currentYear,
    int recentYears = 3,
    int maxCitations = 10,
  }) =>
      works
          .where((w) => isEmerging(
                w,
                currentYear: currentYear,
                recentYears: recentYears,
                maxCitations: maxCitations,
              ))
          .length;
}

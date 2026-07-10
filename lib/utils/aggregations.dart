import '../models/models.dart';

/// Pure aggregation helpers over OpenAlex result sets.
///
/// Shared by the overview ViewModels (Home / Dashboard) so the dashboard math
/// lives in one tested place instead of being duplicated per ViewModel.

/// Mean citation count across [works] (0 when empty).
double averageCitations(List<Work> works) {
  if (works.isEmpty) return 0;
  final sum = works.fold<int>(0, (acc, w) => acc + w.citedByCount);
  return sum / works.length;
}

/// The year with the highest publication count, or null when [years] is empty
/// or the highest-count bucket's key does not parse as a year.
int? mostActiveYear(List<GroupByItem> years) {
  if (years.isEmpty) return null;
  final top = years.reduce((a, b) => a.count >= b.count ? a : b);
  return int.tryParse(top.key);
}

/// Display name of the highest-count bucket in [items], or null when empty.
String? topDisplayName(List<GroupByItem> items) {
  if (items.isEmpty) return null;
  final top = items.reduce((a, b) => a.count >= b.count ? a : b);
  return top.keyDisplayName;
}

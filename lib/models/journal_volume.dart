import 'work.dart';

/// A journal volume (Phase 13.3): the works of one venue grouped by their
/// `biblio.volume`. When a work has no volume metadata it is grouped by
/// publication year instead, so poorly-tagged journals still show sensible
/// "recent volumes".
class JournalVolume {
  const JournalVolume({required this.label, required this.works, this.year});

  /// Human label, e.g. "Volume 42" or (year fallback) "2024".
  final String label;

  /// Most recent publication year in the group — used for ordering.
  final int? year;

  final List<Work> works;

  int get count => works.length;
}

/// Groups [works] into [JournalVolume]s, most recent first. Works are grouped by
/// `biblio.volume` when present, otherwise by publication year. Within a volume
/// the works are ordered newest-then-most-cited first.
List<JournalVolume> groupWorksIntoVolumes(List<Work> works) {
  final byKey = <String, List<Work>>{};
  for (final w in works) {
    final vol = w.biblio?.volume?.trim();
    final key = (vol != null && vol.isNotEmpty)
        ? 'v:$vol'
        : 'y:${w.publicationYear ?? 0}';
    byKey.putIfAbsent(key, () => <Work>[]).add(w);
  }

  final volumes = <JournalVolume>[];
  byKey.forEach((key, items) {
    final year = items
        .map((w) => w.publicationYear ?? 0)
        .fold<int>(0, (a, b) => a > b ? a : b);
    items.sort((a, b) {
      final byYear = (b.publicationYear ?? 0).compareTo(a.publicationYear ?? 0);
      return byYear != 0 ? byYear : b.citedByCount.compareTo(a.citedByCount);
    });
    final label = key.startsWith('v:')
        ? 'Volume ${key.substring(2)}'
        : (year == 0 ? 'Unknown year' : '$year');
    volumes.add(
      JournalVolume(label: label, year: year == 0 ? null : year, works: items),
    );
  });

  volumes.sort((a, b) => (b.year ?? 0).compareTo(a.year ?? 0));
  return volumes;
}

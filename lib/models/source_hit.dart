import 'taxonomy.dart' show shortOpenAlexId;

/// A journal / source search result from OpenAlex `/sources` (Phase 13.3).
///
/// Richer than [Source] (which only carries a name off a work's
/// `primary_location`): this is what the Journals tab lists when searching a
/// venue by name, so it also exposes the publisher, output size and type.
class SourceHit {
  const SourceHit({
    required this.id,
    required this.displayName,
    this.publisher,
    this.worksCount = 0,
    this.type,
    this.homepageUrl,
  });

  /// Full OpenAlex id URL (e.g. `https://openalex.org/S123`).
  final String id;
  final String displayName;

  /// Publishing organisation (`host_organization_name`), when known.
  final String? publisher;

  /// Total works OpenAlex has indexed for this source.
  final int worksCount;

  /// Source type — `journal`, `repository`, `conference`, …
  final String? type;
  final String? homepageUrl;

  /// Short OpenAlex id (e.g. `S123`) parsed from [id].
  String get shortId => shortOpenAlexId(id);

  factory SourceHit.fromJson(Map<String, dynamic> json) => SourceHit(
    id: (json['id'] as String?) ?? '',
    displayName: (json['display_name'] as String?) ?? 'Unknown source',
    publisher: json['host_organization_name'] as String?,
    worksCount: (json['works_count'] as num?)?.toInt() ?? 0,
    type: json['type'] as String?,
    homepageUrl: json['homepage_url'] as String?,
  );
}

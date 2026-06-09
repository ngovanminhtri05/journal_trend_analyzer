import 'author.dart';
import 'source.dart';

/// A publication ("work") from OpenAlex.
///
/// Maps the subset of fields the app displays. The abstract is stored as the
/// raw `abstract_inverted_index` and decoded on demand (see
/// `reconstructAbstract` in `services/abstract_decoder.dart`).
class Work {
  const Work({
    this.id,
    required this.title,
    this.publicationYear,
    required this.citedByCount,
    this.source,
    required this.authors,
    this.doi,
    this.abstractInvertedIndex,
  });

  final String? id;
  final String title;
  final int? publicationYear;
  final int citedByCount;
  final Source? source;
  final List<Author> authors;
  final String? doi;
  final Map<String, dynamic>? abstractInvertedIndex;

  /// Journal/source display name, if known.
  String? get journalName => source?.displayName;

  /// Comma-separated author names for compact display.
  String get authorNames => authors.map((a) => a.displayName).join(', ');

  factory Work.fromJson(Map<String, dynamic> json) {
    // Title: prefer display_name, fall back to title.
    final title = (json['display_name'] as String?) ??
        (json['title'] as String?) ??
        'Untitled';

    // DOI: prefer top-level doi, fall back to ids.doi.
    final ids = json['ids'] as Map<String, dynamic>?;
    final doi = (json['doi'] as String?) ?? (ids?['doi'] as String?);

    // Source: primary_location.source.
    final primaryLocation = json['primary_location'] as Map<String, dynamic>?;
    final sourceJson = primaryLocation?['source'] as Map<String, dynamic>?;
    final source = sourceJson != null ? Source.fromJson(sourceJson) : null;

    // Authors: authorships[].author.
    final authorships = (json['authorships'] as List<dynamic>?) ?? const [];
    final authors = authorships
        .whereType<Map<String, dynamic>>()
        .map((a) => a['author'])
        .whereType<Map<String, dynamic>>()
        .map(Author.fromJson)
        .toList();

    return Work(
      id: json['id'] as String?,
      title: title,
      publicationYear: (json['publication_year'] as num?)?.toInt(),
      citedByCount: (json['cited_by_count'] as num?)?.toInt() ?? 0,
      source: source,
      authors: authors,
      doi: doi,
      abstractInvertedIndex:
          json['abstract_inverted_index'] as Map<String, dynamic>?,
    );
  }
}

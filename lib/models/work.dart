import 'author.dart';
import 'biblio.dart';
import 'source.dart';
import 'taxonomy.dart';

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
    this.biblio,
    this.referencedWorks = const [],
    this.referencedWorksCount = 0,
  });

  final String? id;
  final String title;
  final int? publicationYear;
  final int citedByCount;
  final Source? source;
  final List<Author> authors;
  final String? doi;
  final Map<String, dynamic>? abstractInvertedIndex;

  /// Bibliographic locators (volume/issue/pages) for citation export (FR-14).
  final Biblio? biblio;

  /// Short OpenAlex ids of the works this paper references (FR-15, outgoing).
  final List<String> referencedWorks;

  /// Total number of referenced works (`referenced_works_count`).
  final int referencedWorksCount;

  /// Journal/source display name, if known.
  String? get journalName => source?.displayName;

  /// Comma-separated author names for compact display.
  String get authorNames => authors.map((a) => a.displayName).join(', ');

  /// Short OpenAlex id (e.g. "W2741809807") parsed from the full [id] URL.
  String? get shortId => id == null ? null : shortOpenAlexId(id!);

  /// Surname (last whitespace-separated token) of the first author, or null.
  /// Used for citation keys and APA formatting (FR-14).
  String? get firstAuthorSurname {
    if (authors.isEmpty) return null;
    final name = authors.first.displayName.trim();
    if (name.isEmpty) return null;
    return name.split(RegExp(r'\s+')).last;
  }

  factory Work.fromJson(Map<String, dynamic> json) {
    // Title: prefer display_name, fall back to title.
    final title =
        (json['display_name'] as String?) ??
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

    // Biblio locators (FR-14).
    final biblioJson = json['biblio'] as Map<String, dynamic>?;
    final biblio = biblioJson != null ? Biblio.fromJson(biblioJson) : null;

    // Referenced works (FR-15): array of full OpenAlex URLs → short ids.
    final refs = (json['referenced_works'] as List<dynamic>?) ?? const [];
    final referencedWorks = refs
        .whereType<String>()
        .map(shortOpenAlexId)
        .where((id) => id.isNotEmpty)
        .toList();
    final referencedWorksCount =
        (json['referenced_works_count'] as num?)?.toInt() ??
        referencedWorks.length;

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
      biblio: biblio,
      referencedWorks: referencedWorks,
      referencedWorksCount: referencedWorksCount,
    );
  }
}

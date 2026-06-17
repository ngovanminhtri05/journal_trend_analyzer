import 'author.dart';
import 'group_by_item.dart';
import 'source.dart';
import 'work.dart';

/// The kind of entity a [Bookmark] points at (FR-10).
enum BookmarkType { work, journal, author }

/// A locally-saved bookmark (FR-10).
///
/// Stores only the minimum needed to re-display the entity offline — no network
/// is required to render a saved item. Persisted as JSON by `BookmarkService`.
class Bookmark {
  const Bookmark({
    required this.type,
    required this.id,
    required this.displayName,
    this.publicationYear,
    this.citedByCount,
    this.journalName,
    this.worksCount,
  });

  final BookmarkType type;

  /// OpenAlex id (short or full URL) — unique within a [type].
  final String id;
  final String displayName;

  // Work-only extras.
  final int? publicationYear;
  final int? citedByCount;
  final String? journalName;

  // Journal/Author extra: publication count from the group_by bucket.
  final int? worksCount;

  factory Bookmark.fromWork(Work work) => Bookmark(
    type: BookmarkType.work,
    // Fall back to the title when OpenAlex omits an id, so toggling still has a
    // stable key.
    id: work.id ?? work.title,
    displayName: work.title,
    publicationYear: work.publicationYear,
    citedByCount: work.citedByCount,
    journalName: work.journalName,
  );

  factory Bookmark.fromJournal(GroupByItem item) => Bookmark(
    type: BookmarkType.journal,
    id: item.key,
    displayName: item.keyDisplayName,
    worksCount: item.count,
  );

  factory Bookmark.fromAuthor(GroupByItem item) => Bookmark(
    type: BookmarkType.author,
    id: item.key,
    displayName: item.keyDisplayName,
    worksCount: item.count,
  );

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'id': id,
    'display_name': displayName,
    if (publicationYear != null) 'publication_year': publicationYear,
    if (citedByCount != null) 'cited_by_count': citedByCount,
    if (journalName != null) 'journal_name': journalName,
    if (worksCount != null) 'works_count': worksCount,
  };

  factory Bookmark.fromJson(Map<String, dynamic> json) => Bookmark(
    type: BookmarkType.values.firstWhere(
      (t) => t.name == json['type'],
      orElse: () => BookmarkType.work,
    ),
    id: (json['id'] ?? '').toString(),
    displayName: (json['display_name'] as String?) ?? 'Untitled',
    publicationYear: (json['publication_year'] as num?)?.toInt(),
    citedByCount: (json['cited_by_count'] as num?)?.toInt(),
    journalName: json['journal_name'] as String?,
    worksCount: (json['works_count'] as num?)?.toInt(),
  );

  /// Rebuilds a partial [Work] from the stored fields so a saved publication can
  /// be re-opened in the detail screen offline. Fields not persisted (authors,
  /// DOI, abstract) come back empty — the detail screen already handles that.
  Work toWork() => Work(
    id: id,
    title: displayName,
    publicationYear: publicationYear,
    citedByCount: citedByCount ?? 0,
    source: journalName != null ? Source(displayName: journalName!) : null,
    authors: const <Author>[],
  );
}

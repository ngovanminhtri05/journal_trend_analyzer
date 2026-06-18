/// Bibliographic locators from OpenAlex `work.biblio` (FR-14).
///
/// OpenAlex returns these as strings (or null). Used to fill volume / issue /
/// pages in exported citations.
class Biblio {
  const Biblio({this.volume, this.issue, this.firstPage, this.lastPage});

  final String? volume;
  final String? issue;
  final String? firstPage;
  final String? lastPage;

  /// Page range in BibTeX style: "12--34", or a single page, or null.
  String? get pages {
    if (firstPage != null && lastPage != null) return '$firstPage--$lastPage';
    return firstPage ?? lastPage;
  }

  bool get isEmpty =>
      volume == null && issue == null && firstPage == null && lastPage == null;

  factory Biblio.fromJson(Map<String, dynamic> json) => Biblio(
    volume: _str(json['volume']),
    issue: _str(json['issue']),
    firstPage: _str(json['first_page']),
    lastPage: _str(json['last_page']),
  );

  /// Normalizes a JSON value to a non-empty trimmed string, or null.
  static String? _str(dynamic value) {
    if (value == null) return null;
    final s = value.toString().trim();
    return s.isEmpty ? null : s;
  }
}

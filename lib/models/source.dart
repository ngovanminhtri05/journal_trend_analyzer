/// A publication venue (journal/source) from OpenAlex.
///
/// Parsed from `primary_location.source`.
class Source {
  const Source({this.id, required this.displayName});

  final String? id;
  final String displayName;

  factory Source.fromJson(Map<String, dynamic> json) {
    return Source(
      id: json['id'] as String?,
      displayName: (json['display_name'] as String?) ?? 'Unknown source',
    );
  }
}

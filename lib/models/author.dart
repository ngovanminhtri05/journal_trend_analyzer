/// An author from OpenAlex.
///
/// Parsed from `authorships[].author`.
class Author {
  const Author({this.id, required this.displayName});

  final String? id;
  final String displayName;

  factory Author.fromJson(Map<String, dynamic> json) {
    return Author(
      id: json['id'] as String?,
      displayName: (json['display_name'] as String?) ?? 'Unknown author',
    );
  }
}

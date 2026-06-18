/// Reconstructs a readable abstract from OpenAlex's `abstract_inverted_index`.
///
/// OpenAlex does not return abstracts as plain text. Instead it returns an
/// inverted index mapping each word to the list of positions where it occurs.
/// This rebuilds the original word order.
///
/// Returns `null` when the input is null or empty so callers can render an
/// "abstract unavailable" state.
String? reconstructAbstract(Map<String, dynamic>? invertedIndex) {
  if (invertedIndex == null || invertedIndex.isEmpty) return null;

  final positions = <int, String>{};
  invertedIndex.forEach((word, posList) {
    if (posList is List) {
      for (final p in posList) {
        if (p is int) positions[p] = word;
      }
    }
  });

  if (positions.isEmpty) return null;

  final sorted = positions.keys.toList()..sort();
  return sorted.map((k) => positions[k]).join(' ');
}

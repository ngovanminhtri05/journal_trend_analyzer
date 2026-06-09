/// A single bucket from an OpenAlex `group_by` aggregation response.
///
/// Each entry has the shape `{ key, key_display_name, count }`.
class GroupByItem {
  const GroupByItem({
    required this.key,
    required this.keyDisplayName,
    required this.count,
  });

  final String key;
  final String keyDisplayName;
  final int count;

  factory GroupByItem.fromJson(Map<String, dynamic> json) {
    return GroupByItem(
      key: (json['key'] ?? '').toString(),
      keyDisplayName:
          (json['key_display_name'] as String?) ?? (json['key'] ?? '').toString(),
      count: (json['count'] as num?)?.toInt() ?? 0,
    );
  }
}

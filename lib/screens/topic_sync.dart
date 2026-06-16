import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Keeps an analytic screen (Trends, Dashboard) in sync with the topic searched
/// on the Search tab *and* the active taxonomy filter (FR-13).
///
/// Reloads when either the [topic] or the [filters] differ from what was last
/// loaded. Scheduling happens after the current frame (you can't trigger a
/// provider update during build); the [context.mounted] guard avoids acting on
/// a disposed screen.
void syncSharedTopic({
  required BuildContext context,
  required String topic,
  required List<String> filters,
  required String lastLoadedTopic,
  required List<String> lastLoadedFilters,
  required void Function(String topic, List<String> filters) load,
}) {
  if (topic.isEmpty) return;
  final unchanged =
      topic == lastLoadedTopic && listEquals(filters, lastLoadedFilters);
  if (unchanged) return;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (context.mounted) load(topic, filters);
  });
}

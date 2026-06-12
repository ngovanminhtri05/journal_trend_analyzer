import 'package:flutter/widgets.dart';

/// Keeps an analytic screen (Trends, Dashboard) in sync with the topic searched
/// on the Search tab.
///
/// When [topic] is non-empty and differs from [lastLoaded], schedules [load]
/// after the current frame (you can't trigger a provider update during build).
/// The [context.mounted] guard avoids acting on a disposed screen.
void syncSharedTopic({
  required BuildContext context,
  required String topic,
  required String lastLoaded,
  required void Function(String topic) load,
}) {
  if (topic.isEmpty || topic == lastLoaded) return;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (context.mounted) load(topic);
  });
}

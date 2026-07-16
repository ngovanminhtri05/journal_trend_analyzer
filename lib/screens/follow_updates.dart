import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/openalex_service.dart';
import '../services/follow_updates_service.dart';
import '../viewmodels/viewmodels.dart';

/// Runs the follow "new paper" check for the signed-in user's bookmarked authors
/// and journals, and pushes any alerts to the Notification Center (banner +
/// list). Returns `(followsChecked, newAlerts)`. Client-side only — no backend.
Future<({int follows, int alerts})> checkFollowUpdates(
  BuildContext context,
) async {
  final bookmarks = context.read<BookmarkProvider>();
  final follows = [
    ...bookmarks.byType(BookmarkType.author),
    ...bookmarks.byType(BookmarkType.journal),
  ];
  if (follows.isEmpty) return (follows: 0, alerts: 0);

  final service = FollowUpdatesService(context.read<OpenAlexService>());
  final alerts = await service.checkForNewPapers(follows);
  if (!context.mounted) return (follows: follows.length, alerts: alerts.length);

  final notifications = context.read<NotificationsViewModel>();
  for (final alert in alerts) {
    await notifications.pushLocal(alert);
  }
  return (follows: follows.length, alerts: alerts.length);
}

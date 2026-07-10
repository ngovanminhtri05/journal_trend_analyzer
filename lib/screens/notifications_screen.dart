import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../firebase/messaging_service.dart';
import '../theme/app_theme.dart';
import '../viewmodels/notifications_viewmodel.dart';
import '../widgets/widgets.dart';

/// Notification Center (Lab 03 task 8.2): lists received FCM messages and shows
/// the device token so a test push can be targeted. Pure View over
/// [NotificationsViewModel].
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<NotificationsViewModel>();
    final items = vm.notifications;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (items.isNotEmpty)
            IconButton(
              tooltip: 'Clear all',
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: vm.clear,
            ),
        ],
      ),
      body: ResponsiveBody(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _TokenCard(token: vm.token),
            const SizedBox(height: 16),
            if (items.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 48),
                child: EmptyView(
                  icon: Icons.notifications_none,
                  message:
                      'No notifications yet. Send one from the '
                      'Firebase console to see it here.',
                ),
              )
            else
              for (final n in items) _NotificationTile(notification: n),
          ],
        ),
      ),
    );
  }
}

/// Shows the FCM registration token with a copy action, so the user can send a
/// targeted test push from the Firebase console.
class _TokenCard extends StatelessWidget {
  const _TokenCard({required this.token});

  final String? token;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('This device FCM token', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            if (token == null)
              Text(
                'Token unavailable (permission denied or no Google Play '
                'Services).',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppTheme.muted,
                ),
              )
            else ...[
              SelectableText(token!, style: theme.textTheme.bodySmall),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  icon: const Icon(Icons.copy, size: 16),
                  label: const Text('Copy token'),
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    await Clipboard.setData(ClipboardData(text: token!));
                    messenger.showSnackBar(
                      const SnackBar(content: Text('Token copied.')),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification});

  final AppNotification notification;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.notifications_outlined),
        title: Text(notification.title),
        subtitle: Text(notification.body),
        trailing: Text(
          _formatTime(notification.receivedAt),
          style: Theme.of(context).textTheme.labelSmall,
        ),
      ),
    );
  }

  String _formatTime(DateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(t.month)}/${two(t.day)} ${two(t.hour)}:${two(t.minute)}';
  }
}

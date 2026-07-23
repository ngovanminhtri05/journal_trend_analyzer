import 'package:flutter/material.dart';

import '../firebase/admin_messaging_service.dart';
import '../firebase/admin_users_service.dart';
import '../viewmodels/admin_send_notification_viewmodel.dart';
import 'admin_send_notification_screen.dart';
import 'admin_storage_screen.dart';

/// Per-user admin view reached from the Users list: the account's details plus
/// shortcuts to that user's uploaded reports and a targeted push notification.
class AdminUserDetailScreen extends StatelessWidget {
  const AdminUserDetailScreen({super.key, required this.user});

  final AdminUserSummary user;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(user.label)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        user.isAdmin
                            ? Icons.shield_outlined
                            : Icons.person_outline,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          user.label,
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _kv(theme, 'Email', user.email ?? '—'),
                  _kv(theme, 'User ID', user.uid),
                  _kv(theme, 'Status', user.disabled ? 'Disabled' : 'Active'),
                  _kv(theme, 'Role', user.isAdmin ? 'Admin' : 'User'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const Icon(Icons.folder_outlined),
              title: const Text('Reports'),
              subtitle: const Text('Reports this user uploaded'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => AdminStorageScreen(uid: user.uid),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.notifications_active_outlined),
              title: const Text('Send notification'),
              subtitle: const Text('Push a message to just this user'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => AdminSendNotificationScreen(
                    recipientLabel: user.label,
                    viewModel: AdminSendNotificationViewModel(
                      AdminMessagingService(),
                      targetUid: user.uid,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _kv(ThemeData theme, String key, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 76,
            child: Text(
              key,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ),
          Expanded(child: SelectableText(value, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

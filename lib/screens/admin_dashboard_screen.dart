import 'package:flutter/material.dart';

import 'admin_logs_screen.dart';
import 'admin_remote_config_screen.dart';
import 'admin_send_notification_screen.dart';
import 'admin_storage_screen.dart';
import 'admin_users_screen.dart';

/// Entry point for the in-app Firebase admin panel (reached from the Profile
/// tab's "Admin Dashboard" tile, gated on [AuthViewModel.isAdmin]). A 4-card
/// menu, matching the app's list→detail navigation pattern.
class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin Dashboard')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _AdminCard(
            icon: Icons.people_outline,
            title: 'Users',
            subtitle: 'List, disable, or delete accounts',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AdminUsersScreen()),
            ),
          ),
          const SizedBox(height: 12),
          _AdminCard(
            icon: Icons.tune,
            title: 'Remote Config',
            subtitle: 'View and edit server-tunable parameters',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const AdminRemoteConfigScreen(),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _AdminCard(
            icon: Icons.folder_outlined,
            title: 'Storage',
            subtitle: "Browse and manage every user's reports",
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AdminStorageScreen()),
            ),
          ),
          const SizedBox(height: 12),
          _AdminCard(
            icon: Icons.receipt_long_outlined,
            title: 'Logs',
            subtitle: 'Recent analytics events and crash reports',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AdminLogsScreen()),
            ),
          ),
          const SizedBox(height: 12),
          _AdminCard(
            icon: Icons.campaign_outlined,
            title: 'Send notification',
            subtitle: 'Broadcast a push message to all users',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const AdminSendNotificationScreen(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminCard extends StatelessWidget {
  const _AdminCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

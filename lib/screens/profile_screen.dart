import 'package:flutter/material.dart';

/// Profile tab (Lab 03).
///
/// The full Profile experience — Google account info, sign out, notification
/// center, PDF report export, Remote Config and Crashlytics demos — is part of
/// the Firebase phases (PLANS-Lab03 Phase 8) and is blocked until the Firebase
/// project is configured. Until then this tab is a clear placeholder so the
/// 4-tab shell is navigable end to end.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 24),
        Icon(
          Icons.account_circle_outlined,
          size: 72,
          color: theme.colorScheme.outline,
        ),
        const SizedBox(height: 16),
        Text(
          'Profile',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(
          'Google Sign-In, notifications, PDF report export and the Firebase '
          'demos arrive once the Firebase project is configured.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 24),
        const Card(
          child: ListTile(
            leading: Icon(Icons.cloud_off_outlined),
            title: Text('Firebase not configured yet'),
            subtitle: Text('See docs/FIREBASE-SETUP.md'),
          ),
        ),
      ],
    );
  }
}

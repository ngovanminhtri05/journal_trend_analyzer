import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../firebase/crash_reporter_service.dart';
import '../firebase/remote_config_service.dart';
import '../theme/app_theme.dart';
import '../viewmodels/auth_viewmodel.dart';

/// Profile tab (Lab 03, task 8.1).
///
/// Shows the signed-in Google account (photo / name / email) and a Sign Out
/// action, binding to [AuthViewModel]. Pure View: the account data and the
/// sign-out flow live in the ViewModel.
///
/// The [AuthViewModel] is provided by [AuthGate], which is only mounted once
/// Firebase is configured (R2). Until then the app opens straight on the shell
/// with no auth provider, so this screen looks the ViewModel up as nullable and
/// falls back to a clear placeholder instead of crashing. The remaining Profile
/// features (notification center, PDF report export, Remote Config and
/// Crashlytics demos) are the later Firebase phases (PLANS-Lab03 Phase 8/9).
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Nullable lookup: returns null when no AuthViewModel is in the tree yet
    // (app running before the Firebase auth gate is activated).
    final vm = context.watch<AuthViewModel?>();
    final user = vm?.user;

    if (vm == null || user == null) {
      return const _SignedOutPlaceholder();
    }

    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 16),
        Center(
          child: _Avatar(photoUrl: user.photoUrl, label: user.label),
        ),
        const SizedBox(height: 16),
        Text(
          user.label,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge,
        ),
        if (user.email != null && user.email!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            user.email!,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(color: AppTheme.muted),
          ),
        ],
        const SizedBox(height: 24),
        Card(
          child: Column(
            children: [
              if (user.displayName != null && user.displayName!.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: const Text('Name'),
                  subtitle: Text(user.displayName!),
                ),
              if (user.email != null && user.email!.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.email_outlined),
                  title: const Text('Email'),
                  subtitle: Text(user.email!),
                ),
              ListTile(
                leading: const Icon(Icons.badge_outlined),
                title: const Text('User ID'),
                subtitle: Text(user.uid),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const _RemoteConfigCard(),
        const SizedBox(height: 16),
        const _CrashlyticsCard(),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: vm.signOut,
          icon: const Icon(Icons.logout),
          label: const Text('Sign out'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ],
    );
  }
}

/// Remote Config demo (task 8.4): shows the two server-tunable values that
/// drive the Journals / Keywords list lengths.
class _RemoteConfigCard extends StatelessWidget {
  const _RemoteConfigCard();

  @override
  Widget build(BuildContext context) {
    final config = context.watch<RemoteConfigApi?>();
    if (config == null) return const SizedBox.shrink();
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Text('Remote Config'),
          ),
          ListTile(
            leading: const Icon(Icons.tune),
            title: const Text('Max journals'),
            trailing: Text('${config.maxJournals}'),
          ),
          ListTile(
            leading: const Icon(Icons.tune),
            title: const Text('Max keywords'),
            trailing: Text('${config.maxKeywords}'),
          ),
        ],
      ),
    );
  }
}

/// Crashlytics demo (task 8.5): a handled (non-fatal) error and a forced test
/// crash, so both paths can be shown landing in the Crashlytics console.
class _CrashlyticsCard extends StatelessWidget {
  const _CrashlyticsCard();

  @override
  Widget build(BuildContext context) {
    final reporter = context.watch<CrashReporterApi?>();
    if (reporter == null) return const SizedBox.shrink();
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Text('Crashlytics'),
          ),
          ListTile(
            leading: const Icon(Icons.report_gmailerrorred_outlined),
            title: const Text('Log handled error'),
            subtitle: const Text('Records a non-fatal error'),
            onTap: () async {
              final messenger = ScaffoldMessenger.of(context);
              await reporter.log('User tapped the handled-error demo.');
              await reporter.recordError(
                Exception('Demo handled exception from Profile'),
                StackTrace.current,
                reason: 'crashlytics-demo-handled',
              );
              messenger.showSnackBar(
                const SnackBar(
                  content: Text('Handled error sent to Crashlytics.'),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.bug_report_outlined),
            title: const Text('Force test crash'),
            subtitle: const Text('Crashes the app; report uploads on relaunch'),
            onTap: () => _confirmCrash(context, reporter),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmCrash(
    BuildContext context,
    CrashReporterApi reporter,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Force a test crash?'),
        content: const Text(
          'The app will close immediately. The crash report uploads to '
          'Crashlytics the next time you open the app.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Crash'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) reporter.forceCrash();
  }
}

/// Circular account picture, falling back to the account initial when there is
/// no photo URL (or it fails to load).
class _Avatar extends StatelessWidget {
  const _Avatar({required this.photoUrl, required this.label});

  final String? photoUrl;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final initial = label.isNotEmpty ? label[0].toUpperCase() : '?';
    final fallback = Text(
      initial,
      style: theme.textTheme.headlineMedium?.copyWith(
        color: theme.colorScheme.onPrimaryContainer,
      ),
    );
    return CircleAvatar(
      radius: 44,
      backgroundColor: theme.colorScheme.primaryContainer,
      foregroundImage: (photoUrl != null && photoUrl!.isNotEmpty)
          ? NetworkImage(photoUrl!)
          : null,
      child: fallback,
    );
  }
}

/// Shown when no user is signed in — i.e. the app is running before the Firebase
/// auth gate is configured. Keeps the 4-tab shell navigable end to end.
class _SignedOutPlaceholder extends StatelessWidget {
  const _SignedOutPlaceholder();

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
          'Sign in with Google to see your account here. Notifications, PDF '
          'report export and the Firebase demos arrive once the Firebase '
          'project is configured.',
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

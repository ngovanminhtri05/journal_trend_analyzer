import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../firebase/admin_users_service.dart';
import '../viewmodels/admin_users_viewmodel.dart';
import '../viewmodels/view_state.dart';
import '../widgets/widgets.dart';

/// Admin Users screen: list every account, disable/enable, or delete it.
class AdminUsersScreen extends StatelessWidget {
  const AdminUsersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AdminUsersViewModel>(
      create: (_) => AdminUsersViewModel(AdminUsersService())..load(),
      child: Scaffold(
        appBar: AppBar(title: const Text('Users')),
        body: Consumer<AdminUsersViewModel>(
          builder: (context, vm, _) => _buildBody(context, vm),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, AdminUsersViewModel vm) {
    switch (vm.state) {
      case ViewState.idle:
      case ViewState.loading:
        return const LoadingView(message: 'Loading users…');
      case ViewState.error:
        return ErrorView(
          message: vm.errorMessage ?? 'Something went wrong.',
          onRetry: vm.retry,
        );
      case ViewState.empty:
        return const EmptyView(message: 'No users found.');
      case ViewState.success:
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: vm.users.length,
          itemBuilder: (context, i) =>
              _UserTile(user: vm.users[i], vm: vm),
        );
    }
  }
}

class _UserTile extends StatelessWidget {
  const _UserTile({required this.user, required this.vm});

  final AdminUserSummary user;
  final AdminUsersViewModel vm;

  @override
  Widget build(BuildContext context) {
    final busy = vm.isBusy(user.uid);
    return Card(
      child: ListTile(
        leading: Icon(
          user.isAdmin ? Icons.shield_outlined : Icons.person_outline,
        ),
        title: Text(user.label),
        subtitle: Text(
          user.disabled ? 'Disabled' : 'Active',
          style: TextStyle(
            color: user.disabled
                ? Theme.of(context).colorScheme.error
                : null,
          ),
        ),
        trailing: busy
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : PopupMenuButton<String>(
                onSelected: (value) => value == 'delete'
                    ? _confirmDelete(context)
                    : _toggleDisabled(context),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'toggle',
                    child: Text(user.disabled ? 'Enable' : 'Disable'),
                  ),
                  const PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this account?'),
        content: Text(
          '${user.label} will be permanently removed from Firebase Auth. '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      final before = vm.errorMessage;
      await vm.delete(user.uid);
      if (vm.errorMessage != null && vm.errorMessage != before) {
        messenger.showSnackBar(SnackBar(content: Text(vm.errorMessage!)));
      }
    }
  }

  Future<void> _toggleDisabled(BuildContext context) async {
    if (user.disabled) {
      // Re-enabling an account is not destructive; no confirmation needed.
      final messenger = ScaffoldMessenger.of(context);
      final before = vm.errorMessage;
      await vm.setDisabled(user.uid, false);
      if (vm.errorMessage != null && vm.errorMessage != before) {
        messenger.showSnackBar(SnackBar(content: Text(vm.errorMessage!)));
      }
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Disable this account?'),
        content: Text(
          '${user.label} will not be able to sign in until re-enabled.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Disable'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      await vm.setDisabled(user.uid, true);
      if (vm.errorMessage != null) {
        messenger.showSnackBar(SnackBar(content: Text(vm.errorMessage!)));
      }
    }
  }
}

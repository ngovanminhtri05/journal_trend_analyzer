import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../firebase/admin_remote_config_service.dart';
import '../viewmodels/admin_remote_config_viewmodel.dart';
import '../viewmodels/view_state.dart';
import '../widgets/widgets.dart';

/// Admin Remote Config screen: view every parameter and edit its default
/// value — the in-app replacement for hand-editing values in the console.
class AdminRemoteConfigScreen extends StatelessWidget {
  const AdminRemoteConfigScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AdminRemoteConfigViewModel>(
      create: (_) =>
          AdminRemoteConfigViewModel(AdminRemoteConfigService())..load(),
      child: Scaffold(
        appBar: AppBar(title: const Text('Remote Config')),
        body: Consumer<AdminRemoteConfigViewModel>(
          builder: (context, vm, _) => _buildBody(context, vm),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, AdminRemoteConfigViewModel vm) {
    switch (vm.state) {
      case ViewState.idle:
      case ViewState.loading:
        return const LoadingView(message: 'Loading parameters…');
      case ViewState.error:
        return ErrorView(
          message: vm.errorMessage ?? 'Something went wrong.',
          onRetry: vm.retry,
        );
      case ViewState.empty:
        return const EmptyView(message: 'No Remote Config parameters yet.');
      case ViewState.success:
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final param in vm.parameters)
              _ParamTile(
                param: param,
                vm: vm,
                onTap: () => _showEditDialog(context, vm, existing: param),
              ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _showEditDialog(context, vm),
              icon: const Icon(Icons.add),
              label: const Text('Add parameter'),
            ),
          ],
        );
    }
  }

  Future<void> _showEditDialog(
    BuildContext context,
    AdminRemoteConfigViewModel vm, {
    RemoteConfigParam? existing,
  }) async {
    final keyController = TextEditingController(text: existing?.key ?? '');
    final valueController = TextEditingController(
      text: existing?.defaultValue ?? '',
    );
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'Add parameter' : 'Edit parameter'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: keyController,
              enabled: existing == null,
              decoration: const InputDecoration(labelText: 'Key'),
            ),
            TextField(
              controller: valueController,
              decoration: const InputDecoration(labelText: 'Default value'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result ?? false) {
      final key = keyController.text.trim();
      if (key.isNotEmpty) {
        vm.updateParameter(key, valueController.text.trim());
      }
    }
  }
}

class _ParamTile extends StatelessWidget {
  const _ParamTile({required this.param, required this.vm, required this.onTap});

  final RemoteConfigParam param;
  final AdminRemoteConfigViewModel vm;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.tune),
        title: Text(param.key),
        subtitle: Text(param.defaultValue),
        trailing: const Icon(Icons.edit_outlined),
        onTap: onTap,
      ),
    );
  }
}

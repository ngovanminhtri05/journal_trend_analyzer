import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../firebase/admin_remote_config_service.dart';
import '../firebase/remote_config_service.dart';
import '../viewmodels/admin_remote_config_viewmodel.dart';
import '../viewmodels/view_state.dart';
import '../widgets/widgets.dart';

/// A tunable the admin panel knows how to present as a friendly stepper (label,
/// help text, clamped range) instead of a raw key/value field.
class _KnownParam {
  const _KnownParam({
    required this.label,
    required this.description,
    required this.min,
    required this.max,
    required this.step,
    required this.defaultValue,
  });

  final String label;
  final String description;
  final int min;
  final int max;
  final int step;
  final int defaultValue;
}

const Map<String, _KnownParam> _known = {
  RemoteConfigService.keyHomePageSize: _KnownParam(
    label: 'Home feed page size',
    description: 'Papers loaded per page on the Home feed.',
    min: RemoteConfigService.minHomePageSize,
    max: RemoteConfigService.maxHomePageSize,
    step: 1,
    defaultValue: RemoteConfigService.defaultHomePageSize,
  ),
  RemoteConfigService.keyMaxJournals: _KnownParam(
    label: 'Max journals shown',
    description: 'Rows in the Journals ranked list.',
    min: 1,
    max: 100,
    step: 1,
    defaultValue: RemoteConfigService.defaultMaxJournals,
  ),
  RemoteConfigService.keyMaxKeywords: _KnownParam(
    label: 'Max keywords shown',
    description: 'Rows in the Keywords ranked list.',
    min: 1,
    max: 100,
    step: 1,
    defaultValue: RemoteConfigService.defaultMaxKeywords,
  ),
};

/// Admin Remote Config screen: view every parameter and edit its default
/// value — the in-app replacement for hand-editing values in the console.
class AdminRemoteConfigScreen extends StatelessWidget {
  const AdminRemoteConfigScreen({super.key, this.viewModel});

  /// Injected for tests/previews; production builds the Cloud-Functions-backed
  /// view model.
  final AdminRemoteConfigViewModel? viewModel;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AdminRemoteConfigViewModel>(
      create: (_) =>
          (viewModel ?? AdminRemoteConfigViewModel(AdminRemoteConfigService()))
            ..load(),
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
      // Both empty and populated show the known tunables as friendly steppers;
      // an admin should never face a blank config screen.
      case ViewState.empty:
      case ViewState.success:
        return _content(context, vm);
    }
  }

  Widget _content(BuildContext context, AdminRemoteConfigViewModel vm) {
    final byKey = {for (final p in vm.parameters) p.key: p.defaultValue};
    final extras = vm.parameters
        .where((p) => !_known.containsKey(p.key))
        .toList();

    Future<void> setValue(String key, int value) async {
      await vm.updateParameter(key, '$value');
      if (context.mounted && vm.errorMessage != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(vm.errorMessage!)));
      }
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const _SectionLabel('App settings'),
        for (final entry in _known.entries)
          _KnownParamTile(
            meta: entry.value,
            value: int.tryParse(byKey[entry.key] ?? '') ?? entry.value.defaultValue,
            onChanged: (v) => setValue(entry.key, v),
          ),
        if (extras.isNotEmpty) ...[
          const SizedBox(height: 16),
          const _SectionLabel('Other parameters'),
          for (final param in extras)
            _ParamTile(
              param: param,
              vm: vm,
              onTap: () => _showEditDialog(context, vm, existing: param),
            ),
        ],
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => _showEditDialog(context, vm),
          icon: const Icon(Icons.add),
          label: const Text('Add parameter'),
        ),
      ],
    );
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
    final messenger = ScaffoldMessenger.of(context);
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
        await vm.updateParameter(key, valueController.text.trim());
        if (vm.errorMessage != null) {
          messenger.showSnackBar(SnackBar(content: Text(vm.errorMessage!)));
        }
      }
    }
  }
}

/// Small muted section heading.
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 6),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Theme.of(context).colorScheme.outline,
        ),
      ),
    );
  }
}

/// A known tunable rendered as a labeled stepper (−/value/+) clamped to its
/// range, instead of a raw key/value field.
class _KnownParamTile extends StatelessWidget {
  const _KnownParamTile({
    required this.meta,
    required this.value,
    required this.onChanged,
  });

  final _KnownParam meta;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final v = value.clamp(meta.min, meta.max);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            const Icon(Icons.tune),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(meta.label, style: theme.textTheme.titleMedium),
                  Text(
                    meta.description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Decrease',
              onPressed: v <= meta.min
                  ? null
                  : () => onChanged((v - meta.step).clamp(meta.min, meta.max)),
              icon: const Icon(Icons.remove_circle_outline),
            ),
            SizedBox(
              width: 34,
              child: Text(
                '$v',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium,
              ),
            ),
            IconButton(
              tooltip: 'Increase',
              onPressed: v >= meta.max
                  ? null
                  : () => onChanged((v + meta.step).clamp(meta.min, meta.max)),
              icon: const Icon(Icons.add_circle_outline),
            ),
          ],
        ),
      ),
    );
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

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../viewmodels/viewmodels.dart';
import '../widgets/widgets.dart';
import 'detail_screen.dart';

/// Home tab (Phase 13.2): a light overview of the **most recent publications in
/// the user's own research field**. The field is chosen on the Profile tab and
/// stored locally ([ResearchFieldProvider]); there are no OpenAlex aggregate
/// totals here — just recent work to skim. All logic lives in [HomeViewModel].
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final fieldProvider = context.watch<ResearchFieldProvider>();
    final vm = context.watch<HomeViewModel>();

    if (!fieldProvider.ready) {
      return const LoadingView(message: 'Loading…');
    }

    // Keep the ViewModel's feed in sync with the chosen field.
    final chosen = fieldProvider.field ?? '';
    if (chosen != vm.field) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (chosen != vm.field) vm.loadForField(chosen);
      });
    }

    if (!fieldProvider.isSet) {
      return _FieldPrompt(onSave: fieldProvider.setField);
    }

    return Column(
      children: [
        _FieldHeader(
          field: chosen,
          onEdit: () => _editField(context, fieldProvider, chosen),
        ),
        Expanded(child: _buildBody(context, vm)),
      ],
    );
  }

  Widget _buildBody(BuildContext context, HomeViewModel vm) {
    switch (vm.state) {
      case ViewState.idle:
      case ViewState.loading:
        return const LoadingView(message: 'Loading recent publications…');
      case ViewState.error:
        return ErrorView(
          message: vm.errorMessage ?? 'Something went wrong.',
          onRetry: vm.retry,
        );
      case ViewState.empty:
        return EmptyView(
          message: 'No recent publications found for "${vm.field}".',
        );
      case ViewState.success:
        return _RecentFeed(vm: vm);
    }
  }

  Future<void> _editField(
    BuildContext context,
    ResearchFieldProvider provider,
    String current,
  ) async {
    final value = await _promptForField(context, initial: current);
    if (value != null) await provider.setField(value);
  }
}

/// Recent-publications list for the chosen field, with the PDF export action.
class _RecentFeed extends StatelessWidget {
  const _RecentFeed({required this.vm});

  final HomeViewModel vm;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Recent publications',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              if (vm.canExport || vm.isExporting)
                TextButton.icon(
                  onPressed: vm.isExporting
                      ? null
                      : () => _exportReport(context, vm),
                  icon: vm.isExporting
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.picture_as_pdf_outlined, size: 18),
                  label: Text(vm.isExporting ? 'Exporting…' : 'Export'),
                ),
            ],
          ),
        ),
        for (final work in vm.recentWorks)
          PaperCard(
            work: work,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => DetailScreen(work: work)),
            ),
          ),
        const SizedBox(height: 16),
      ],
    );
  }
}

/// Shown when no research field is set yet: a short prompt + an inline input.
class _FieldPrompt extends StatelessWidget {
  const _FieldPrompt({required this.onSave});

  final Future<void> Function(String) onSave;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.interests_outlined, size: 64, color: theme.colorScheme.outline),
            const SizedBox(height: 16),
            Text(
              'Set your research field',
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Home shows the most recent publications in the field you '
              'research. You can change it any time from Profile.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () async {
                final value = await _promptForField(context);
                if (value != null) await onSave(value);
              },
              icon: const Icon(Icons.add),
              label: const Text('Choose a field'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Header shown once a field is chosen: the field name + an edit affordance.
class _FieldHeader extends StatelessWidget {
  const _FieldHeader({required this.field, required this.onEdit});

  final String field;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
      child: Row(
        children: [
          Icon(Icons.interests_outlined, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Your research field', style: theme.textTheme.labelSmall),
                Text(
                  field,
                  style: theme.textTheme.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Change field',
            icon: const Icon(Icons.edit_outlined, size: 20),
            onPressed: onEdit,
          ),
        ],
      ),
    );
  }
}

/// Shared dialog that asks the user to type a research field. Returns the
/// trimmed value, or null when cancelled / empty.
Future<String?> _promptForField(BuildContext context, {String initial = ''}) {
  final controller = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Your research field'),
      content: TextField(
        controller: controller,
        autofocus: true,
        textInputAction: TextInputAction.done,
        decoration: const InputDecoration(
          hintText: 'e.g. Machine Learning, Genomics',
        ),
        onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, controller.text.trim()),
          child: const Text('Save'),
        ),
      ],
    ),
  ).then((v) => (v == null || v.isEmpty) ? null : v);
}

/// Builds the field report PDF, opens the OS share sheet for the saved file,
/// and — when the cloud upload succeeded — shows the Storage download URL.
Future<void> _exportReport(BuildContext context, HomeViewModel vm) async {
  final uid = context.read<AuthViewModel?>()?.user?.uid ?? 'anonymous';
  final messenger = ScaffoldMessenger.of(context);
  await vm.exportReport(uid: uid);
  if (!context.mounted) return;

  if (vm.exportError != null) {
    messenger.showSnackBar(SnackBar(content: Text(vm.exportError!)));
    return;
  }

  final path = vm.reportFilePath;
  if (path != null) {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(path)],
        text: 'Recent publications in ${vm.field}',
      ),
    );
  }
  if (!context.mounted) return;

  final url = vm.reportUrl;
  if (url != null) {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Report uploaded'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Your PDF report is also stored in Firebase Storage:'),
            const SizedBox(height: 8),
            SelectableText(url, style: Theme.of(ctx).textTheme.bodySmall),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: url));
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Copy link'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
}

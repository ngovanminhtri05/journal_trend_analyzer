import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../viewmodels/viewmodels.dart';
import '../widgets/widgets.dart';
import 'detail_screen.dart';

/// Home tab (Phase 13.2): a light feed of **trending publications** — recently
/// published and highly cited. It loads on open (global trending); an optional
/// research field (set on Profile or here) scopes the trend to a topic. No
/// OpenAlex aggregate totals — just the papers. Logic lives in [HomeViewModel].
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final fieldProvider = context.watch<ResearchFieldProvider>();
    final vm = context.watch<HomeViewModel>();

    if (!fieldProvider.ready) {
      return const LoadingView(message: 'Loading…');
    }

    // Load trending on open, and reload when the field filter changes.
    final chosen = fieldProvider.field ?? '';
    if (vm.state == ViewState.idle || chosen != vm.field) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (vm.state == ViewState.idle || chosen != vm.field) {
          vm.load(field: chosen);
        }
      });
    }

    return Column(
      children: [
        _TrendingHeader(
          field: chosen,
          onEdit: () async {
            final value = await _promptForField(context, initial: chosen);
            if (value != null) await fieldProvider.setField(value);
          },
          onClear: chosen.isEmpty
              ? null
              : () => fieldProvider.setField(''),
        ),
        Expanded(child: _buildBody(context, vm)),
      ],
    );
  }

  Widget _buildBody(BuildContext context, HomeViewModel vm) {
    switch (vm.state) {
      case ViewState.idle:
      case ViewState.loading:
        return const LoadingView(message: 'Loading trending publications…');
      case ViewState.error:
        return ErrorView(
          message: vm.errorMessage ?? 'Something went wrong.',
          onRetry: vm.retry,
        );
      case ViewState.empty:
        return EmptyView(
          message: vm.field.isEmpty
              ? 'No trending publications right now.'
              : 'No trending publications found for "${vm.field}".',
        );
      case ViewState.success:
        return _TrendingFeed(vm: vm);
    }
  }
}

/// Trending list, with the PDF export action.
class _TrendingFeed extends StatelessWidget {
  const _TrendingFeed({required this.vm});

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
                  'Trending now',
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

/// Header: shows whether the feed is global or field-scoped, with edit/clear.
class _TrendingHeader extends StatelessWidget {
  const _TrendingHeader({
    required this.field,
    required this.onEdit,
    this.onClear,
  });

  final String field;
  final VoidCallback onEdit;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scoped = field.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
      child: Row(
        children: [
          Icon(
            Icons.trending_up,
            size: 18,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Trending publications', style: theme.textTheme.labelSmall),
                Text(
                  scoped ? 'In $field' : 'Across all fields',
                  style: theme.textTheme.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (onClear != null)
            IconButton(
              tooltip: 'Show all fields',
              icon: const Icon(Icons.clear, size: 20),
              onPressed: onClear,
            ),
          IconButton(
            tooltip: 'Filter by field',
            icon: const Icon(Icons.tune, size: 20),
            onPressed: onEdit,
          ),
        ],
      ),
    );
  }
}

/// Dialog that asks the user to type a research field. Returns the trimmed
/// value, or null when cancelled / empty.
Future<String?> _promptForField(BuildContext context, {String initial = ''}) {
  final controller = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Filter trending by field'),
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
          child: const Text('Apply'),
        ),
      ],
    ),
  ).then((v) => (v == null || v.isEmpty) ? null : v);
}

/// Builds the trending report PDF, opens the OS share sheet for the saved file,
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
        text: vm.field.isEmpty
            ? 'Trending publications'
            : 'Trending publications in ${vm.field}',
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

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/models.dart';
import '../viewmodels/viewmodels.dart';
import '../widgets/widgets.dart';
import 'detail_screen.dart';

/// Home tab (Phase 14): a research-discovery feed. It opens on **rising**
/// publications (recent + gaining citations); the user can switch the sort
/// (Rising / Newest / Top cited), search papers, and filter by an OpenAlex
/// subfield. Cursor pagination loads more as the list scrolls. No aggregate
/// totals — just the papers. Logic lives in [HomeViewModel].
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final vm = context.read<HomeViewModel>();
      if (vm.state == ViewState.idle) vm.load();
    });
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    final vm = context.read<HomeViewModel>();
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 400) vm.loadMore();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<HomeViewModel>();
    final subfields = context.watch<SubfieldFilterProvider?>();

    // Keep the feed in sync with the selected subfield.
    final selectedId = subfields?.subfieldId;
    if (subfields != null && selectedId != vm.subfieldId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (selectedId != vm.subfieldId) vm.setSubfield(selectedId);
      });
    }

    return Column(
      children: [
        TopicSearchBar(
          hintText: 'Search papers (e.g. large language models)',
          onSubmit: (q) => context.read<HomeViewModel>().search(q),
        ),
        _Controls(vm: vm, subfields: subfields),
        Expanded(child: _buildBody(context, vm)),
      ],
    );
  }

  Widget _buildBody(BuildContext context, HomeViewModel vm) {
    switch (vm.state) {
      case ViewState.idle:
      case ViewState.loading:
        return const LoadingView(message: 'Loading publications…');
      case ViewState.error:
        return ErrorView(
          message: vm.errorMessage ?? 'Something went wrong.',
          onRetry: vm.retry,
        );
      case ViewState.empty:
        return RefreshIndicator(
          onRefresh: vm.refresh,
          child: ListView(
            children: [
              const SizedBox(height: 120),
              EmptyView(
                message: vm.query.isNotEmpty
                    ? 'No papers found for "${vm.query}".'
                    : (vm.sort == WorkSort.newest &&
                          vm.followedJournalCount > 0)
                    ? 'No recent papers from the journals you follow. '
                          'Follow more journals on the Journals tab.'
                    : 'No publications found. Pull to refresh.',
              ),
            ],
          ),
        );
      case ViewState.success:
        return RefreshIndicator(
          onRefresh: vm.refresh,
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: vm.works.length + 1, // + footer
            itemBuilder: (context, i) {
              if (i == vm.works.length) return _Footer(vm: vm);
              final work = vm.works[i];
              return PaperCard(
                work: work,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => DetailScreen(work: work)),
                ),
              );
            },
          ),
        );
    }
  }
}

/// Sort toggle + subfield filter chip + export action.
class _Controls extends StatelessWidget {
  const _Controls({required this.vm, required this.subfields});

  final HomeViewModel vm;
  final SubfieldFilterProvider? subfields;

  @override
  Widget build(BuildContext context) {
    final selected = subfields?.selected;
    return Column(
      children: [
        // Sort toggle gets the full width so all three labels fit.
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 2, 12, 0),
          child: SizedBox(
            width: double.infinity,
            child: SegmentedButton<WorkSort>(
              showSelectedIcon: false,
              style: const ButtonStyle(visualDensity: VisualDensity.compact),
              segments: [
                for (final s in WorkSort.values)
                  ButtonSegment(value: s, label: Text(s.label, maxLines: 1)),
              ],
              selected: {vm.sort},
              onSelectionChanged: (s) =>
                  context.read<HomeViewModel>().setSort(s.first),
            ),
          ),
        ),
        // Subfield filter + export on their own row.
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 2, 4, 2),
          child: Row(
            children: [
              if (subfields != null)
                Flexible(
                  child: InputChip(
                    avatar: const Icon(Icons.category_outlined, size: 18),
                    label: Text(
                      selected?.displayName ?? 'All fields',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onPressed: () => _openSubfieldPicker(context, subfields!),
                    onDeleted: selected == null
                        ? null
                        : () => subfields!.clear(),
                  ),
                ),
              const Spacer(),
              if (vm.canExport || vm.isExporting)
                IconButton(
                  tooltip: 'Export PDF report',
                  onPressed: vm.isExporting
                      ? null
                      : () => _exportReport(context, vm),
                  icon: vm.isExporting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.picture_as_pdf_outlined),
                ),
            ],
          ),
        ),
        // Newest is scoped to followed journals — say so, so a short list or an
        // empty feed is never a mystery.
        if (vm.sort == WorkSort.newest)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
            child: Row(
              children: [
                Icon(
                  vm.followedJournalCount > 0
                      ? Icons.bookmark
                      : Icons.bookmark_border,
                  size: 14,
                  color: Theme.of(context).colorScheme.outline,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    vm.followedJournalCount > 0
                        ? 'From ${vm.followedJournalCount} followed '
                              '${vm.followedJournalCount == 1 ? "journal" : "journals"}'
                        : 'All journals — follow journals to focus this feed',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// List footer: a "load more" spinner / button, or an end-of-list marker.
class _Footer extends StatelessWidget {
  const _Footer({required this.vm});

  final HomeViewModel vm;

  @override
  Widget build(BuildContext context) {
    if (vm.loadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    if (vm.hasMore) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: TextButton(
            onPressed: vm.loadMore,
            child: const Text('Load more'),
          ),
        ),
      );
    }
    return const SizedBox(height: 24);
  }
}

/// Bottom-sheet picker for the OpenAlex subfield filter (searchable list).
Future<void> _openSubfieldPicker(
  BuildContext context,
  SubfieldFilterProvider provider,
) async {
  provider.ensureLoaded();
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => _SubfieldPickerSheet(provider: provider),
  );
}

class _SubfieldPickerSheet extends StatefulWidget {
  const _SubfieldPickerSheet({required this.provider});

  final SubfieldFilterProvider provider;

  @override
  State<_SubfieldPickerSheet> createState() => _SubfieldPickerSheetState();
}

class _SubfieldPickerSheetState extends State<_SubfieldPickerSheet> {
  String _filter = '';

  @override
  Widget build(BuildContext context) {
    final provider = widget.provider;
    return AnimatedBuilder(
      animation: provider,
      builder: (context, _) {
        final all = provider.subfields;
        final query = _filter.trim().toLowerCase();
        final items = query.isEmpty
            ? all
            : all
                  .where((s) => s.displayName.toLowerCase().contains(query))
                  .toList();
        return SizedBox(
          height: MediaQuery.of(context).size.height * 0.7,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Column(
              children: [
                TextField(
                  autofocus: true,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Filter subfields',
                  ),
                  onChanged: (v) => setState(() => _filter = v),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: !provider.ready && provider.loading
                      ? const LoadingView(message: 'Loading subfields…')
                      : provider.loadError != null
                      ? ErrorView(
                          message: provider.loadError!,
                          onRetry: provider.ensureLoaded,
                        )
                      : ListView(
                          children: [
                            ListTile(
                              leading: const Icon(Icons.clear_all),
                              title: const Text('All fields'),
                              selected: provider.selected == null,
                              onTap: () {
                                provider.clear();
                                Navigator.pop(context);
                              },
                            ),
                            for (final s in items)
                              ListTile(
                                title: Text(s.displayName),
                                selected: provider.selected == s,
                                onTap: () {
                                  provider.select(s);
                                  Navigator.pop(context);
                                },
                              ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Builds the feed report PDF, opens the OS share sheet for the saved file, and
/// — when the cloud upload succeeded — shows the Storage download URL.
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
        text: vm.query.isEmpty
            ? 'Trending publications'
            : 'Publications for ${vm.query}',
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

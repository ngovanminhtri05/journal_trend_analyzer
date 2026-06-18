import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/services.dart';
import '../state/state.dart';
import '../theme/app_theme.dart';
import '../widgets/widgets.dart';
import 'detail_screen.dart';

/// Direction of the citation tree (FR-15).
enum CitationDirection { references, citedBy }

/// Sort order for the "Cited by" direction (FR-15).
enum CitedBySort { newest, mostCited }

extension on CitedBySort {
  /// OpenAlex sort expression.
  String get apiValue => this == CitedBySort.newest
      ? 'publication_date:desc'
      : 'cited_by_count:desc';

  String get label => this == CitedBySort.newest ? 'Newest' : 'Most cited';
}

/// Citation tree explorer (FR-15, tree form).
///
/// Unlike the flat lists on the detail screen, this shows the citation network
/// as an inline, lazily-expanding tree so a researcher can trace several levels
/// at once and spot clusters / sparse branches (research gaps). Each node
/// expands on demand (one request per expand) and the path is cycle-guarded.
class CitationTreeScreen extends StatefulWidget {
  const CitationTreeScreen({super.key, required this.root});

  final Work root;

  @override
  State<CitationTreeScreen> createState() => _CitationTreeScreenState();
}

class _CitationTreeScreenState extends State<CitationTreeScreen> {
  CitationDirection _dir = CitationDirection.references;
  CitedBySort _citedBySort = CitedBySort.newest;

  @override
  Widget build(BuildContext context) {
    final rootId = widget.root.shortId ?? widget.root.title;
    return Scaffold(
      appBar: AppBar(title: const Text('Citation tree')),
      body: ResponsiveBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: SegmentedButton<CitationDirection>(
                segments: const [
                  ButtonSegment(
                    value: CitationDirection.references,
                    icon: Icon(Icons.south_west, size: 16),
                    label: Text('References'),
                  ),
                  ButtonSegment(
                    value: CitationDirection.citedBy,
                    icon: Icon(Icons.north_east, size: 16),
                    label: Text('Cited by'),
                  ),
                ],
                selected: {_dir},
                onSelectionChanged: (s) => setState(() => _dir = s.first),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: Text(
                _dir == CitationDirection.references
                    ? 'Expand a paper to see what it builds on. Sparse branches hint at gaps.'
                    : 'Expand a paper to see who built on it. "Emerging" = recent & lightly-cited → a possible research gap.',
                style: AppTheme.mono(context, size: 11),
              ),
            ),
            // Sort control only applies to the "Cited by" direction.
            if (_dir == CitationDirection.citedBy)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Row(
                  children: [
                    Text('Sort: ', style: AppTheme.mono(context, size: 12)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SegmentedButton<CitedBySort>(
                        showSelectedIcon: false,
                        style: const ButtonStyle(
                          visualDensity: VisualDensity.compact,
                        ),
                        segments: [
                          for (final s in CitedBySort.values)
                            ButtonSegment(value: s, label: Text(s.label)),
                        ],
                        selected: {_citedBySort},
                        onSelectionChanged: (s) =>
                            setState(() => _citedBySort = s.first),
                      ),
                    ),
                  ],
                ),
              ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
                children: [
                  _CitationNode(
                    // Rebuild the whole tree when the direction or sort changes.
                    key: ValueKey('$_dir-${_citedBySort.apiValue}-$rootId'),
                    work: widget.root,
                    direction: _dir,
                    citedBySort: _citedBySort,
                    depth: 0,
                    ancestors: {rootId},
                    initiallyExpanded: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One node in the tree. Holds its own expand/loading/children state and
/// renders child nodes recursively (indented by [depth]).
class _CitationNode extends StatefulWidget {
  const _CitationNode({
    super.key,
    required this.work,
    required this.direction,
    required this.depth,
    required this.ancestors,
    this.citedBySort = CitedBySort.newest,
    this.initiallyExpanded = false,
  });

  final Work work;
  final CitationDirection direction;
  final CitedBySort citedBySort;
  final int depth;

  /// Short ids on the path from the root to this node (cycle guard).
  final Set<String> ancestors;
  final bool initiallyExpanded;

  @override
  State<_CitationNode> createState() => _CitationNodeState();
}

class _CitationNodeState extends State<_CitationNode> {
  static const int _maxDepth = 6;
  static const int _maxChildren = 25;

  bool _expanded = false;
  bool _loaded = false;
  ViewState _state = ViewState.idle;
  String? _error;
  List<Work> _children = const [];

  String? get _selfId => widget.work.shortId;

  bool get _isLoop =>
      _selfId != null && widget.ancestors.contains(_selfId) && widget.depth > 0;

  int get _childCount => widget.direction == CitationDirection.references
      ? widget.work.referencedWorksCount
      : widget.work.citedByCount;

  bool get _canExpand =>
      !_isLoop && widget.depth < _maxDepth && _childCount > 0;

  /// FR-15 research-gap signal: only meaningful in the "Cited by" direction.
  bool get _isEmerging =>
      widget.direction == CitationDirection.citedBy &&
      ResearchGap.isEmerging(widget.work, currentYear: DateTime.now().year);

  @override
  void initState() {
    super.initState();
    if (widget.initiallyExpanded && _canExpand) {
      _expanded = true;
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _state = ViewState.loading;
      _error = null;
    });
    try {
      final service = context.read<OpenAlexService>();
      final List<Work> kids;
      if (widget.direction == CitationDirection.references) {
        final ids = widget.work.referencedWorks.take(_maxChildren).toList();
        kids = ids.isEmpty ? const [] : await service.fetchWorksByIds(ids);
      } else {
        final id = widget.work.shortId;
        kids = id == null
            ? const []
            : await service.getCitedBy(
                id,
                perPage: _maxChildren,
                sort: widget.citedBySort.apiValue,
              );
      }
      if (!mounted) return;
      setState(() {
        _children = kids;
        _state = kids.isEmpty ? ViewState.empty : ViewState.success;
        _loaded = true;
      });
    } on OpenAlexException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _state = ViewState.error;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load this branch.';
        _state = ViewState.error;
      });
    }
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    if (_expanded && !_loaded) _load();
  }

  void _openDetail() => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => DetailScreen(work: widget.work)),
      );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _row(context),
        if (_expanded) _childrenArea(),
      ],
    );
  }

  Widget _row(BuildContext context) {
    final theme = Theme.of(context);
    final bookmarks = context.watch<BookmarkProvider>();
    final saved =
        bookmarks.isBookmarked(BookmarkType.work, widget.work.id ?? widget.work.title);
    final author = widget.work.authors.isNotEmpty
        ? widget.work.authors.first.displayName
        : 'Unknown';
    final year = widget.work.publicationYear?.toString() ?? 'n/a';

    return Padding(
      padding: EdgeInsets.only(left: widget.depth * 14.0, top: 2, bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 32,
            child: _isLoop
                ? const Tooltip(
                    message: 'Already shown higher in this branch',
                    child: Icon(Icons.loop, size: 16),
                  )
                : _canExpand
                    ? IconButton(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        icon: Icon(
                          _expanded
                              ? Icons.expand_more
                              : Icons.chevron_right,
                          size: 20,
                        ),
                        onPressed: _toggle,
                      )
                    : const Icon(Icons.fiber_manual_record, size: 7),
          ),
          Expanded(
            child: InkWell(
              onTap: _openDetail,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.work.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            '$author · $year · Cited by ${widget.work.citedByCount}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTheme.mono(context, size: 11),
                          ),
                        ),
                        if (_isEmerging) ...[
                          const SizedBox(width: 6),
                          const _EmergingPill(),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, size: 18),
            onSelected: (v) {
              switch (v) {
                case 'open':
                  _openDetail();
                case 'bookmark':
                  bookmarks.toggle(Bookmark.fromWork(widget.work));
                case 'export':
                  showCitationSheet(context, widget.work);
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'open', child: Text('Open detail')),
              PopupMenuItem(
                value: 'bookmark',
                child: Text(saved ? 'Remove bookmark' : 'Bookmark'),
              ),
              const PopupMenuItem(
                value: 'export',
                child: Text('Export citation'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _childrenArea() {
    final leftPad = widget.depth * 14.0 + 32;
    switch (_state) {
      case ViewState.idle:
      case ViewState.loading:
        return Padding(
          padding: EdgeInsets.only(left: leftPad, top: 4, bottom: 8),
          child: const Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 10),
              Text('Loading…'),
            ],
          ),
        );
      case ViewState.error:
        return Padding(
          padding: EdgeInsets.only(left: leftPad, top: 4, bottom: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _error ?? 'Something went wrong.',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
              TextButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        );
      case ViewState.empty:
        return Padding(
          padding: EdgeInsets.only(left: leftPad, top: 4, bottom: 8),
          child: Text(
            widget.direction == CitationDirection.references
                ? 'No reference data available.'
                : 'No citing papers found.',
            style: TextStyle(color: Theme.of(context).colorScheme.outline),
          ),
        );
      case ViewState.success:
        final nextAncestors = {...widget.ancestors, ?_selfId};
        final emergingCount = widget.direction == CitationDirection.citedBy
            ? ResearchGap.countEmerging(
                _children,
                currentYear: DateTime.now().year,
              )
            : 0;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (emergingCount > 0)
              Padding(
                padding: EdgeInsets.only(left: leftPad, top: 2, bottom: 4),
                child: Text(
                  '$emergingCount of ${_children.length} citing papers are emerging '
                  '(recent & lightly cited) — possible research gaps.',
                  style: AppTheme.mono(context, size: 11)
                      .copyWith(color: const Color(0xFF1B7F4B)),
                ),
              ),
            for (final child in _children)
              _CitationNode(
                work: child,
                direction: widget.direction,
                citedBySort: widget.citedBySort,
                depth: widget.depth + 1,
                ancestors: nextAncestors,
              ),
          ],
        );
    }
  }
}

/// Small "Emerging" pill marking a recent, lightly-cited citing paper (FR-15
/// research-gap signal).
class _EmergingPill extends StatelessWidget {
  const _EmergingPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFE3F4EA),
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Text(
        'Emerging',
        style: TextStyle(
          color: Color(0xFF1B7F4B),
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

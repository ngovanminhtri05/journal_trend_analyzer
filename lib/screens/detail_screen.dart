import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/models.dart';
import '../services/services.dart';
import '../state/state.dart';
import '../theme/app_theme.dart';
import '../widgets/widgets.dart';
import 'citation_tree_screen.dart';

/// Publication detail screen (FR-2): full metadata, decoded abstract, and an
/// openable DOI link. Pushed on top of the navigation shell from a result tap.
class DetailScreen extends StatelessWidget {
  const DetailScreen({super.key, required this.work});

  final Work work;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final abstractText = reconstructAbstract(work.abstractInvertedIndex);
    final doiUrl = _doiUrl(work.doi);

    final bookmarks = context.watch<BookmarkProvider>();
    final saved = bookmarks.isBookmarked(BookmarkType.work, work.id ?? work.title);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Publication'),
        actions: [
          IconButton(
            tooltip: 'Citation tree',
            icon: const Icon(Icons.account_tree_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => CitationTreeScreen(root: work),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Export citation',
            icon: const Icon(Icons.ios_share),
            onPressed: () => showCitationSheet(context, work),
          ),
          IconButton(
            tooltip: saved ? 'Remove bookmark' : 'Save bookmark',
            icon: Icon(saved ? Icons.bookmark : Icons.bookmark_border),
            onPressed: () => bookmarks.toggle(Bookmark.fromWork(work)),
          ),
        ],
      ),
      body: ResponsiveBody(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(work.title, style: theme.textTheme.headlineSmall),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _MetaChip(
                  icon: Icons.calendar_today,
                  label: work.publicationYear?.toString() ?? 'Year n/a',
                ),
                _MetaChip(
                  icon: Icons.format_quote,
                  label: '${work.citedByCount} citations',
                ),
                if (work.journalName != null)
                  _MetaChip(icon: Icons.menu_book, label: work.journalName!),
              ],
            ),
            const SizedBox(height: 24),
            _Section(
              title: 'Authors',
              child: Text(work.authors.isEmpty ? 'Unknown' : work.authorNames),
            ),
            if (doiUrl != null)
              _Section(
                title: 'DOI',
                child: InkWell(
                  onTap: () => _openDoi(context, doiUrl),
                  child: Row(
                    children: [
                      const Icon(Icons.link, size: 18),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          doiUrl,
                          style: TextStyle(
                            color: theme.colorScheme.secondary,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                      const Icon(Icons.open_in_new, size: 16),
                    ],
                  ),
                ),
              ),
            _Section(
              title: 'Abstract',
              child: Text(
                abstractText ?? 'No abstract available for this publication.',
                style: abstractText == null
                    ? TextStyle(
                        fontStyle: FontStyle.italic,
                        color: theme.colorScheme.outline,
                      )
                    : null,
              ),
            ),
            // FR-15: citation network — lazy-loaded on expand.
            _CitationSection(work: work, direction: _CitationDirection.references),
            _CitationSection(work: work, direction: _CitationDirection.citedBy),
          ],
        ),
      ),
    );
  }

  /// Normalizes a raw DOI value into an openable https URL.
  String? _doiUrl(String? doi) {
    if (doi == null || doi.isEmpty) return null;
    if (doi.startsWith('http')) return doi;
    return 'https://doi.org/$doi';
  }

  Future<void> _openDoi(BuildContext context, String url) async {
    final messenger = ScaffoldMessenger.of(context);
    bool ok = false;
    try {
      final uri = Uri.parse(url);
      ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      ok = false; // malformed URI or no handler available on the device
    }
    if (!ok) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not open the DOI link.')),
      );
    }
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 16),
      label: Text(label),
      visualDensity: VisualDensity.compact,
    );
  }
}

/// Which side of the citation network a section shows (FR-15).
enum _CitationDirection { references, citedBy }

/// A lazily-loaded "References (N)" / "Cited by (N)" section.
///
/// Fetches only when first expanded (to save requests) and manages its own
/// loading / empty / error state independently of the other section.
class _CitationSection extends StatefulWidget {
  const _CitationSection({required this.work, required this.direction});

  final Work work;
  final _CitationDirection direction;

  @override
  State<_CitationSection> createState() => _CitationSectionState();
}

class _CitationSectionState extends State<_CitationSection> {
  ViewState _state = ViewState.idle;
  String? _error;
  List<Work> _items = const [];
  bool _started = false;

  bool get _isReferences => widget.direction == _CitationDirection.references;

  int get _count => _isReferences
      ? widget.work.referencedWorksCount
      : widget.work.citedByCount;

  String get _title =>
      _isReferences ? 'References ($_count)' : 'Cited by ($_count)';

  Future<void> _load() async {
    setState(() {
      _state = ViewState.loading;
      _error = null;
    });
    try {
      final service = context.read<OpenAlexService>();
      final List<Work> works;
      if (_isReferences) {
        // Cap to the first 50 ids to keep this to a single request.
        final ids = widget.work.referencedWorks.take(50).toList();
        works = ids.isEmpty ? const [] : await service.fetchWorksByIds(ids);
      } else {
        final id = widget.work.shortId;
        works = id == null ? const [] : await service.getCitedBy(id);
      }
      if (!mounted) return;
      setState(() {
        _items = works;
        _state = works.isEmpty ? ViewState.empty : ViewState.success;
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
        _error = 'Could not load this list.';
        _state = ViewState.error;
      });
    }
  }

  void _onExpansionChanged(bool expanded) {
    if (expanded && !_started) {
      _started = true;
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.only(bottom: 8),
          title: Text(_title, style: Theme.of(context).textTheme.titleMedium),
          onExpansionChanged: _onExpansionChanged,
          children: [_buildBody()],
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_state) {
      case ViewState.idle:
      case ViewState.loading:
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 12),
              Text('Loading…'),
            ],
          ),
        );
      case ViewState.error:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
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
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            _isReferences
                ? 'No reference data available.'
                : 'No citing papers found.',
            style: TextStyle(color: Theme.of(context).colorScheme.outline),
          ),
        );
      case ViewState.success:
        return Column(
          children: [for (final w in _items) _CitationItem(work: w)],
        );
    }
  }
}

/// One row in a citation list: title, first author + year, citations, with
/// bookmark + export actions. Tapping opens that paper's detail (recursive).
class _CitationItem extends StatelessWidget {
  const _CitationItem({required this.work});

  final Work work;

  @override
  Widget build(BuildContext context) {
    final bookmarks = context.watch<BookmarkProvider>();
    final saved =
        bookmarks.isBookmarked(BookmarkType.work, work.id ?? work.title);
    final author = work.authors.isNotEmpty
        ? work.authors.first.displayName
        : 'Unknown';
    final year = work.publicationYear?.toString() ?? 'n/a';

    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(work.title, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '$author · $year · Cited by ${work.citedByCount}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTheme.mono(context, size: 11),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: 'Export citation',
            icon: const Icon(Icons.ios_share, size: 18),
            onPressed: () => showCitationSheet(context, work),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: saved ? 'Remove bookmark' : 'Save bookmark',
            icon: Icon(
              saved ? Icons.bookmark : Icons.bookmark_border,
              size: 18,
            ),
            onPressed: () => bookmarks.toggle(Bookmark.fromWork(work)),
          ),
        ],
      ),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => DetailScreen(work: work)),
      ),
    );
  }
}

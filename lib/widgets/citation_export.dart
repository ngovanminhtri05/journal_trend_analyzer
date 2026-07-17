import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/models.dart';
import '../services/services.dart';
import '../theme/app_theme.dart';

/// Citation export UI (FR-14).
///
/// Two entry points share the same sheet body:
///   - [showCitationSheet] for one [Work] (with a BibTeX/RIS/APA selector),
///   - [showExportTextSheet] for pre-built text (e.g. Export All from the
///     collection).
/// Both offer Copy (clipboard) and Share (`share_plus`, text only — no backend).

enum _CiteFormat { bibtex, ris, apa }

Future<void> showCitationSheet(BuildContext context, Work work) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _CitationSheet(work: work),
  );
}

Future<void> showExportTextSheet(
  BuildContext context, {
  required String title,
  required String text,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _SheetBody(title: title, text: text),
  );
}

Future<void> _copy(BuildContext context, String text) async {
  final messenger = ScaffoldMessenger.of(context);
  await Clipboard.setData(ClipboardData(text: text));
  messenger.showSnackBar(
    const SnackBar(content: Text('Copied to clipboard')),
  );
}

Future<void> _share(String text) =>
    SharePlus.instance.share(ShareParams(text: text));

class _CitationSheet extends StatefulWidget {
  const _CitationSheet({required this.work});

  final Work work;

  @override
  State<_CitationSheet> createState() => _CitationSheetState();
}

class _CitationSheetState extends State<_CitationSheet> {
  _CiteFormat _format = _CiteFormat.bibtex;

  /// The record being exported — may be swapped for a richer "canonical"
  /// version via [_improve] (FR-14).
  late Work _work = widget.work;
  bool _improving = false;

  String get _text {
    switch (_format) {
      case _CiteFormat.bibtex:
        return CitationFormatter.toBibTeX(_work);
      case _CiteFormat.ris:
        return CitationFormatter.toRIS(_work);
      case _CiteFormat.apa:
        return CitationFormatter.toAPA(_work);
    }
  }

  /// OpenAlex often holds several variants of the same paper; when the current
  /// record lacks a journal it is usually a poor duplicate. Look up the
  /// most-cited record with the same title and swap it in (user-triggered, so
  /// we never silently replace with a wrong paper).
  Future<void> _improve() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _improving = true);
    try {
      final candidates =
          await context.read<OpenAlexService>().findBestRecordByTitle(_work.title);
      final target = _work.title.toLowerCase().trim();
      final better = candidates.where(
        (w) => w.journalName != null && w.title.toLowerCase().trim() == target,
      );
      if (better.isNotEmpty) {
        setState(() => _work = better.first);
        messenger.showSnackBar(
          const SnackBar(content: Text('Updated to the most-cited matching record.')),
        );
      } else {
        messenger.showSnackBar(
          const SnackBar(content: Text('No more complete record found.')),
        );
      }
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not look up a better record.')),
      );
    } finally {
      if (mounted) setState(() => _improving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final header = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SegmentedButton<_CiteFormat>(
          segments: const [
            ButtonSegment(value: _CiteFormat.bibtex, label: Text('BibTeX')),
            ButtonSegment(value: _CiteFormat.ris, label: Text('RIS')),
            ButtonSegment(value: _CiteFormat.apa, label: Text('APA')),
          ],
          selected: {_format},
          onSelectionChanged: (s) => setState(() => _format = s.first),
        ),
        // Offer enrichment only for records that look incomplete.
        if (_work.journalName == null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: TextButton.icon(
              onPressed: _improving ? null : _improve,
              icon: _improving
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_fix_high, size: 16),
              label: const Text('Improve metadata (find best version)'),
            ),
          ),
      ],
    );

    return _SheetBody(title: 'Export citation', text: _text, header: header);
  }
}

class _SheetBody extends StatelessWidget {
  const _SheetBody({required this.title, required this.text, this.header});

  final String title;
  final String text;
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height * 0.5;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (header != null) ...[
            const SizedBox(height: 12),
            Center(child: header!),
          ],
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.fill,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SingleChildScrollView(
                child: SelectableText(
                  text,
                  style: AppTheme.mono(context, size: 12, color: AppTheme.ink),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _copy(context, text),
                  icon: const Icon(Icons.copy, size: 18),
                  label: const Text('Copy'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _share(text),
                  icon: const Icon(Icons.share, size: 18),
                  label: const Text('Share'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/models.dart';
import '../services/abstract_decoder.dart';
import '../widgets/widgets.dart';

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

    return Scaffold(
      appBar: AppBar(title: const Text('Publication')),
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

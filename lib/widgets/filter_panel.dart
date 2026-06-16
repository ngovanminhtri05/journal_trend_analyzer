import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/state.dart';
import '../theme/app_theme.dart';

/// Cascading taxonomy filter (FR-13) for the Search screen.
///
/// Three tiers, each narrowing the next:
///   Domain (4, hard-coded) → Field (26, hard-coded, filtered by domain)
///   → Subfield (loaded from /subfields, filtered by field).
///
/// The deepest "Topic" tier is intentionally omitted: the screen's keyword
/// search already covers free-text topic lookup.
///
/// Reads/writes the shared [FilterProvider], so selections automatically flow to
/// the Search results and the Trend / Dashboard screens. The whole panel lives
/// inside a collapsible [ExpansionTile] to keep the search view uncluttered.
///
/// Note on [DropdownButtonFormField] (Flutter 3.41): `initialValue` only seeds
/// the field on first build, so a cascading reset (e.g. domain change clearing
/// the field) would otherwise leave a stale selection on screen. Each dropdown
/// therefore carries a [ValueKey] derived from the current selection, forcing a
/// fresh field — and a fresh seed — whenever the relevant level changes.
class FilterPanel extends StatelessWidget {
  const FilterPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final filter = context.watch<FilterProvider>();
    final activeCount = _activeLevelCount(filter);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      child: Theme(
        // Drop the ExpansionTile's default dividers for the flat look.
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          leading: const Icon(Icons.filter_list, size: 20),
          title: const Text('Filter by topic taxonomy'),
          subtitle: Text(
            activeCount == 0
                ? 'Domain · Field · Subfield'
                : '$activeCount filter${activeCount == 1 ? '' : 's'} active',
            style: AppTheme.mono(context, size: 11),
          ),
          children: [
            _DomainDropdown(filter: filter),
            const SizedBox(height: 12),
            _FieldDropdown(filter: filter),
            const SizedBox(height: 12),
            _SubfieldDropdown(filter: filter),
            if (filter.hasActiveFilter) ...[
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: filter.clear,
                  icon: const Icon(Icons.clear_all, size: 18),
                  label: const Text('Clear filters'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  int _activeLevelCount(FilterProvider f) {
    var n = 0;
    if (f.domain != null) n++;
    if (f.field != null) n++;
    if (f.subfield != null) n++;
    return n;
  }
}

class _DomainDropdown extends StatelessWidget {
  const _DomainDropdown({required this.filter});

  final FilterProvider filter;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<Domain>(
      key: ValueKey('domain-${filter.domain?.id}'),
      initialValue: filter.domain,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Domain',
        prefixIcon: Icon(Icons.public, size: 20),
      ),
      hint: const Text('Any domain'),
      items: [
        for (final d in Taxonomy.domains)
          DropdownMenuItem(value: d, child: Text(d.name)),
      ],
      onChanged: filter.selectDomain,
    );
  }
}

class _FieldDropdown extends StatelessWidget {
  const _FieldDropdown({required this.filter});

  final FilterProvider filter;

  @override
  Widget build(BuildContext context) {
    final enabled = filter.domain != null;
    final fields = filter.fieldsForDomain;
    return DropdownButtonFormField<Field>(
      key: ValueKey('field-${filter.domain?.id}-${filter.field?.id}'),
      initialValue: filter.field,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: 'Field',
        prefixIcon: const Icon(Icons.category_outlined, size: 20),
        enabled: enabled,
      ),
      hint: Text(enabled ? 'Any field' : 'Select a domain first'),
      items: [
        for (final f in fields)
          DropdownMenuItem(value: f, child: Text(f.name)),
      ],
      // Disabled when no domain chosen (null onChanged greys the control out).
      onChanged: enabled ? (f) => filter.selectField(f) : null,
    );
  }
}

class _SubfieldDropdown extends StatelessWidget {
  const _SubfieldDropdown({required this.filter});

  final FilterProvider filter;

  @override
  Widget build(BuildContext context) {
    if (filter.subfieldsLoading) {
      return const Row(
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 12),
          Text('Loading subfields…'),
        ],
      );
    }

    if (filter.subfieldsError != null && filter.field != null) {
      return Text(
        filter.subfieldsError!,
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      );
    }

    final enabled = filter.field != null;
    final subfields = filter.subfieldsForField;
    return DropdownButtonFormField<Subfield>(
      key: ValueKey('subfield-${filter.field?.id}-${filter.subfield?.id}'),
      initialValue: filter.subfield,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: 'Subfield',
        prefixIcon: const Icon(Icons.account_tree_outlined, size: 20),
        enabled: enabled,
      ),
      hint: Text(enabled ? 'Any subfield' : 'Select a field first'),
      items: [
        for (final s in subfields)
          DropdownMenuItem(value: s, child: Text(s.displayName)),
      ],
      onChanged: enabled ? filter.selectSubfield : null,
    );
  }
}

import 'package:flutter/foundation.dart';

import '../models/models.dart';
import '../services/openalex_service.dart';

/// Holds the current OpenAlex taxonomy selection (FR-13) and exposes the active
/// filter clauses that the data providers append to their `/works` queries.
///
/// This provider is the single source of truth for the selected
/// Domain → Field → Subfield, so the same filter applies to the Search results
/// *and* the Trend / Dashboard analysis screens. (Free-text topic lookup is
/// handled by the screen's keyword search, not by this panel.)
///
/// Cascading reset rules:
///   - changing Domain resets Field and Subfield
///   - changing Field  resets Subfield
class FilterProvider extends ChangeNotifier {
  FilterProvider(this._service);

  final OpenAlexService _service;

  Domain? domain;
  Field? field;
  Subfield? subfield;

  // Subfield catalog, fetched once from /subfields and cached for the session.
  List<Subfield> _subfields = const [];
  bool _subfieldsLoaded = false;
  bool subfieldsLoading = false;
  String? subfieldsError;

  /// Fields belonging to the selected domain (empty when no domain chosen).
  List<Field> get fieldsForDomain =>
      domain == null ? const [] : Taxonomy.fieldsForDomain(domain!.id);

  /// Subfields belonging to the selected field (empty when none chosen or the
  /// catalog hasn't loaded yet).
  List<Subfield> get subfieldsForField => field == null
      ? const []
      : _subfields.where((s) => s.fieldId == field!.id).toList();

  /// The current selection as a value object.
  TaxonomyFilter get currentFilter =>
      TaxonomyFilter(domain: domain, field: field, subfield: subfield);

  /// The filter clauses to append to `/works` calls (deepest level only).
  ///
  /// Returned as a list so it composes with any future non-taxonomy filters and
  /// matches `OpenAlexService`'s comma-joined `filter=` contract.
  List<String> get activeFilterClauses {
    final clause = currentFilter.toFilterClause();
    return clause == null ? const [] : [clause];
  }

  bool get hasActiveFilter => currentFilter.toFilterClause() != null;

  void selectDomain(Domain? value) {
    if (value == domain) return;
    domain = value;
    field = null;
    subfield = null;
    notifyListeners();
  }

  /// Selecting a field also kicks off the subfield catalog load (cached).
  Future<void> selectField(Field? value) async {
    if (value == field) return;
    field = value;
    subfield = null;
    notifyListeners();
    if (value != null) await ensureSubfieldsLoaded();
  }

  void selectSubfield(Subfield? value) {
    if (value == subfield) return;
    subfield = value;
    notifyListeners();
  }

  /// Clears the taxonomy selection only. The screen's keyword search is
  /// independent and is left untouched.
  void clear() {
    if (!hasActiveFilter && domain == null) return;
    domain = null;
    field = null;
    subfield = null;
    notifyListeners();
  }

  /// Loads the subfield catalog once and caches it. Safe to call repeatedly.
  Future<void> ensureSubfieldsLoaded() async {
    if (_subfieldsLoaded || subfieldsLoading) return;
    subfieldsLoading = true;
    subfieldsError = null;
    notifyListeners();
    try {
      _subfields = await _service.getSubfields();
      _subfieldsLoaded = true;
    } on OpenAlexException catch (e) {
      subfieldsError = e.message;
    } catch (_) {
      subfieldsError = 'Could not load subfields. Tap a field again to retry.';
    }
    subfieldsLoading = false;
    notifyListeners();
  }
}

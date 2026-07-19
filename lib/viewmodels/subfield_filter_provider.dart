import 'package:flutter/foundation.dart';

import '../models/models.dart';
import '../services/openalex_service.dart';

/// Loads and caches the OpenAlex subfield taxonomy and tracks the subfield the
/// Home discovery feed is filtered by (Phase 14.2).
///
/// There are ~250 subfields and they don't change within a session, so the list
/// is fetched once via [OpenAlexService.getSubfields] and cached. Views read
/// [subfieldId] and pass it to the feed; the picker reads [subfields].
class SubfieldFilterProvider extends ChangeNotifier {
  SubfieldFilterProvider(this._service);

  final OpenAlexService _service;

  List<Subfield> _subfields = const [];
  bool _loaded = false;
  bool _loading = false;

  /// Set when the last load failed (offline, etc.); UI may surface it.
  String? loadError;

  Subfield? _selected;

  List<Subfield> get subfields => _subfields;
  bool get ready => _loaded;
  bool get loading => _loading;
  Subfield? get selected => _selected;

  /// Short OpenAlex id of the selected subfield, or null when unfiltered.
  String? get subfieldId => _selected?.id;

  /// Fetches the subfield list once and caches it. Repeat calls are no-ops.
  Future<void> ensureLoaded() async {
    if (_loaded || _loading) return;
    _loading = true;
    notifyListeners();
    try {
      _subfields = await _service.getSubfields();
      _loaded = true;
      loadError = null;
    } catch (_) {
      loadError = 'Could not load subfields. Please try again.';
    }
    _loading = false;
    notifyListeners();
  }

  void select(Subfield? subfield) {
    if (_selected == subfield) return;
    _selected = subfield;
    notifyListeners();
  }

  void clear() => select(null);
}

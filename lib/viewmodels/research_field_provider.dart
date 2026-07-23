import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Holds the user's chosen research field (Phase 13.1), persisted locally with
/// [SharedPreferences] so the Home overview can show recent work in *their*
/// field. No network, no Firebase — the field is a per-device preference the
/// user sets on the Profile tab.
class ResearchFieldProvider extends ChangeNotifier {
  ResearchFieldProvider({SharedPreferences? prefs}) : _prefs = prefs;

  static const _key = 'research_field';

  SharedPreferences? _prefs;
  String? _field;
  bool _ready = false;

  /// The chosen field, or null when the user has not picked one yet.
  String? get field => _field;

  /// Whether a non-empty field has been chosen.
  bool get isSet => _field != null && _field!.isNotEmpty;

  /// Whether the initial load from storage has completed.
  bool get ready => _ready;

  Future<void> load() async {
    _prefs ??= await SharedPreferences.getInstance();
    final saved = _prefs!.getString(_key)?.trim();
    _field = (saved != null && saved.isNotEmpty) ? saved : null;
    _ready = true;
    notifyListeners();
  }

  Future<void> setField(String field) async {
    final value = field.trim();
    _prefs ??= await SharedPreferences.getInstance();
    if (value.isEmpty) {
      await _prefs!.remove(_key);
      _field = null;
    } else {
      await _prefs!.setString(_key, value);
      _field = value;
    }
    notifyListeners();
  }

  Future<void> clear() => setField('');
}

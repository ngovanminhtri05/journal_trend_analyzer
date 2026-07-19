import 'dart:async';

import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

/// App-wide tunables sourced from Firebase Remote Config (Lab 03 task 9.4).
///
/// Views/ViewModels read these getters; they never touch the Remote Config SDK
/// directly. The API is a [Listenable] so the UI can rebuild when the server
/// pushes a new config **without restarting the app** (see
/// [RemoteConfigService.initialize]). Tests use [StaticRemoteConfig].
abstract interface class RemoteConfigApi implements Listenable {
  /// Max journals shown in the Journals ranked list.
  int get maxJournals;

  /// Max keywords shown in the Keywords ranked list.
  int get maxKeywords;

  /// How many publications the Home feed fetches per page (server-tunable).
  int get homePageSize;

  /// Human-readable diagnostic of where the values came from and how the last
  /// fetch went (shown on the Profile card so the demo is verifiable).
  String get statusLabel;
}

/// Firebase-backed [RemoteConfigApi].
///
/// [initialize] sets in-code defaults, fetches + activates the server values,
/// caches them into plain fields, and then subscribes to Remote Config
/// **real-time updates**: when a new config is published, the SDK pushes it to
/// the app, which activates it and notifies listeners — the UI updates live, no
/// restart needed.
class RemoteConfigService extends ChangeNotifier implements RemoteConfigApi {
  RemoteConfigService({FirebaseRemoteConfig? remoteConfig})
    : _injected = remoteConfig;

  final FirebaseRemoteConfig? _injected;

  static const String keyMaxJournals = 'max_journals';
  static const String keyMaxKeywords = 'max_keywords';
  static const String keyHomePageSize = 'home_page_size';
  static const int defaultMaxJournals = 15;
  static const int defaultMaxKeywords = 20;
  static const int defaultHomePageSize = 25;

  /// OpenAlex accepts 1–200 per page; keep the tunable inside a sane range so a
  /// bad console value can't break (or hammer) the feed.
  static const int minHomePageSize = 5;
  static const int maxHomePageSize = 200;

  int _maxJournals = defaultMaxJournals;
  int _maxKeywords = defaultMaxKeywords;
  int _homePageSize = defaultHomePageSize;
  String _statusLabel = 'Not fetched yet';

  StreamSubscription<RemoteConfigUpdate>? _updates;

  @override
  int get maxJournals => _maxJournals;

  @override
  int get maxKeywords => _maxKeywords;

  @override
  int get homePageSize => _homePageSize;

  @override
  String get statusLabel => _statusLabel;

  /// Loads defaults, fetches + activates remote values, caches the result, and
  /// starts listening for real-time config pushes. Any fetch failure (offline,
  /// etc.) leaves the in-code defaults in place.
  Future<void> initialize() async {
    final rc = _injected ?? FirebaseRemoteConfig.instance;
    await rc.setConfigSettings(
      RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        // Fetch fresh on every launch as well, so a published change is picked
        // up even if the real-time channel is unavailable (offline, etc.).
        minimumFetchInterval: Duration.zero,
      ),
    );
    await rc.setDefaults(const {
      keyMaxJournals: defaultMaxJournals,
      keyMaxKeywords: defaultMaxKeywords,
      keyHomePageSize: defaultHomePageSize,
    });

    var fetchStatus = 'no fetch';
    try {
      await rc.fetchAndActivate();
      fetchStatus = rc.lastFetchStatus.name; // success / throttle / failure
    } catch (_) {
      fetchStatus = rc.lastFetchStatus.name;
    }
    _cacheValues(rc, 'fetch: $fetchStatus');

    // Real-time updates: apply a newly published config while the app runs.
    try {
      _updates = rc.onConfigUpdated.listen((_) async {
        try {
          await rc.activate();
          _cacheValues(rc, 'live update');
          notifyListeners();
        } catch (_) {
          // Ignore a failed activation; the next launch re-fetches.
        }
      });
    } catch (_) {
      // Real-time channel unavailable — the startup fetch above still applies.
    }
  }

  /// Re-reads the cached values and recomputes [statusLabel].
  ///
  /// A `remote` value source means the console value was fetched + activated;
  /// `default` means it fell back to the in-code default (param not published,
  /// fetch failed, or wrong key).
  void _cacheValues(FirebaseRemoteConfig rc, String origin) {
    _maxJournals = rc.getInt(keyMaxJournals);
    _maxKeywords = rc.getInt(keyMaxKeywords);
    // Clamp so a bad console value can't break the feed.
    _homePageSize = rc
        .getInt(keyHomePageSize)
        .clamp(minHomePageSize, maxHomePageSize);
    final fromServer =
        rc.getValue(keyMaxJournals).source == ValueSource.valueRemote;
    _statusLabel = fromServer
        ? 'From server · $origin'
        : 'In-code defaults · $origin';
  }

  @override
  void dispose() {
    _updates?.cancel();
    super.dispose();
  }
}

/// Fixed [RemoteConfigApi] for tests, previews, or Firebase-free contexts.
///
/// Never changes, so the [Listenable] hooks are no-ops.
class StaticRemoteConfig implements RemoteConfigApi {
  const StaticRemoteConfig({
    this.maxJournals = RemoteConfigService.defaultMaxJournals,
    this.maxKeywords = RemoteConfigService.defaultMaxKeywords,
    this.homePageSize = RemoteConfigService.defaultHomePageSize,
  });

  @override
  final int maxJournals;
  @override
  final int maxKeywords;
  @override
  final int homePageSize;

  @override
  String get statusLabel => 'Static (test defaults)';

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}
}

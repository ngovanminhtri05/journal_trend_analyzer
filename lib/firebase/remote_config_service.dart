import 'package:firebase_remote_config/firebase_remote_config.dart';

/// App-wide tunables sourced from Firebase Remote Config (Lab 03 task 9.4).
///
/// Views/ViewModels read these getters; they never touch the Remote Config SDK
/// directly. Values are plain ints resolved once at [initialize] time, so
/// reading them never requires Firebase — tests use [StaticRemoteConfig].
abstract interface class RemoteConfigApi {
  /// Max journals shown in the Journals ranked list.
  int get maxJournals;

  /// Max keywords shown in the Keywords ranked list.
  int get maxKeywords;

  /// Human-readable diagnostic of where the values came from and how the last
  /// fetch went (shown on the Profile card so the demo is verifiable).
  String get statusLabel;
}

/// Firebase-backed [RemoteConfigApi].
///
/// [initialize] sets in-code defaults, fetches + activates the server values,
/// then caches them into plain fields. The getters return those cached fields,
/// so they are safe to read before/without Firebase (they just return the
/// defaults until a successful fetch updates them).
class RemoteConfigService implements RemoteConfigApi {
  RemoteConfigService({FirebaseRemoteConfig? remoteConfig})
    : _injected = remoteConfig;

  final FirebaseRemoteConfig? _injected;

  static const String keyMaxJournals = 'max_journals';
  static const String keyMaxKeywords = 'max_keywords';
  static const int defaultMaxJournals = 15;
  static const int defaultMaxKeywords = 20;

  int _maxJournals = defaultMaxJournals;
  int _maxKeywords = defaultMaxKeywords;
  String _statusLabel = 'Not fetched yet';

  @override
  int get maxJournals => _maxJournals;

  @override
  int get maxKeywords => _maxKeywords;

  @override
  String get statusLabel => _statusLabel;

  /// Loads defaults, fetches + activates remote values, and caches the result.
  /// Any fetch failure (offline, etc.) leaves the in-code defaults in place.
  Future<void> initialize() async {
    final rc = _injected ?? FirebaseRemoteConfig.instance;
    await rc.setConfigSettings(
      RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        // Fetch fresh on every launch (lab/demo): a change published in the
        // Firebase console shows up the next time the app is (re)started, in
        // both debug and release. Raise this in a real production app.
        minimumFetchInterval: Duration.zero,
      ),
    );
    await rc.setDefaults(const {
      keyMaxJournals: defaultMaxJournals,
      keyMaxKeywords: defaultMaxKeywords,
    });

    var fetchStatus = 'no fetch';
    try {
      await rc.fetchAndActivate();
      fetchStatus = rc.lastFetchStatus.name; // success / throttle / failure
    } catch (_) {
      // Keep defaults on failure.
      fetchStatus = rc.lastFetchStatus.name;
    }

    _maxJournals = rc.getInt(keyMaxJournals);
    _maxKeywords = rc.getInt(keyMaxKeywords);

    // Diagnose where the applied value came from: a `remote` source means the
    // console value was fetched + activated; `default` means it fell back to the
    // in-code default (param not published, fetch failed, or wrong key).
    final source = rc.getValue(keyMaxJournals).source;
    final fromServer = source == ValueSource.valueRemote;
    _statusLabel = fromServer
        ? 'From server · fetch: $fetchStatus'
        : 'In-code defaults · fetch: $fetchStatus';
  }
}

/// Fixed [RemoteConfigApi] for tests, previews, or Firebase-free contexts.
class StaticRemoteConfig implements RemoteConfigApi {
  const StaticRemoteConfig({
    this.maxJournals = RemoteConfigService.defaultMaxJournals,
    this.maxKeywords = RemoteConfigService.defaultMaxKeywords,
  });

  @override
  final int maxJournals;
  @override
  final int maxKeywords;

  @override
  String get statusLabel => 'Static (test defaults)';
}

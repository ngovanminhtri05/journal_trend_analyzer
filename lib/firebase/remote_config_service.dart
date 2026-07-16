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

  @override
  int get maxJournals => _maxJournals;

  @override
  int get maxKeywords => _maxKeywords;

  /// Loads defaults, fetches + activates remote values, and caches the result.
  /// Any fetch failure (offline, etc.) leaves the in-code defaults in place.
  Future<void> initialize() async {
    final rc = _injected ?? FirebaseRemoteConfig.instance;
    await rc.setConfigSettings(
      RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: const Duration(hours: 1),
      ),
    );
    await rc.setDefaults(const {
      keyMaxJournals: defaultMaxJournals,
      keyMaxKeywords: defaultMaxKeywords,
    });
    try {
      await rc.fetchAndActivate();
    } catch (_) {
      // Keep defaults on failure.
    }
    _maxJournals = rc.getInt(keyMaxJournals);
    _maxKeywords = rc.getInt(keyMaxKeywords);
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
}

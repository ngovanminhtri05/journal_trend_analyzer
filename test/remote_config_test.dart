import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:journal_trend_analyzer/firebase/remote_config_service.dart';
import 'package:mocktail/mocktail.dart';

class _MockRemoteConfig extends Mock implements FirebaseRemoteConfig {}

class _MockValue extends Mock implements RemoteConfigValue {}

void main() {
  setUpAll(() {
    registerFallbackValue(
      RemoteConfigSettings(
        fetchTimeout: Duration.zero,
        minimumFetchInterval: Duration.zero,
      ),
    );
    registerFallbackValue(<String, dynamic>{});
  });

  group('StaticRemoteConfig', () {
    test('reports its configured values', () {
      const config = StaticRemoteConfig(maxJournals: 5, maxKeywords: 7);
      expect(config.maxJournals, 5);
      expect(config.maxKeywords, 7);
    });

    test('defaults match RemoteConfigService defaults', () {
      const config = StaticRemoteConfig();
      expect(config.maxJournals, RemoteConfigService.defaultMaxJournals);
      expect(config.maxKeywords, RemoteConfigService.defaultMaxKeywords);
    });
  });

  group('RemoteConfigService', () {
    late _MockRemoteConfig rc;

    setUp(() {
      rc = _MockRemoteConfig();
      when(() => rc.setConfigSettings(any())).thenAnswer((_) async {});
      when(() => rc.setDefaults(any())).thenAnswer((_) async {});
      // Stubs for the diagnostics added to initialize().
      final value = _MockValue();
      when(() => value.source).thenReturn(ValueSource.valueRemote);
      when(() => rc.getValue(any())).thenReturn(value);
      when(() => rc.lastFetchStatus).thenReturn(RemoteConfigFetchStatus.success);
    });

    test('caches the fetched server values', () async {
      when(() => rc.fetchAndActivate()).thenAnswer((_) async => true);
      when(() => rc.getInt('max_journals')).thenReturn(30);
      when(() => rc.getInt('max_keywords')).thenReturn(40);

      final service = RemoteConfigService(remoteConfig: rc);
      await service.initialize();

      expect(service.maxJournals, 30);
      expect(service.maxKeywords, 40);
    });

    test('keeps defaults when fetchAndActivate throws', () async {
      when(() => rc.fetchAndActivate()).thenThrow(Exception('offline'));
      // With no successful fetch, getInt returns the values registered as
      // defaults via setDefaults.
      when(
        () => rc.getInt('max_journals'),
      ).thenReturn(RemoteConfigService.defaultMaxJournals);
      when(
        () => rc.getInt('max_keywords'),
      ).thenReturn(RemoteConfigService.defaultMaxKeywords);

      final service = RemoteConfigService(remoteConfig: rc);
      await service.initialize(); // must not rethrow

      expect(service.maxJournals, RemoteConfigService.defaultMaxJournals);
      expect(service.maxKeywords, RemoteConfigService.defaultMaxKeywords);
    });

    test('reports defaults before initialize is called', () {
      final service = RemoteConfigService(remoteConfig: rc);
      expect(service.maxJournals, RemoteConfigService.defaultMaxJournals);
      expect(service.maxKeywords, RemoteConfigService.defaultMaxKeywords);
    });
  });
}

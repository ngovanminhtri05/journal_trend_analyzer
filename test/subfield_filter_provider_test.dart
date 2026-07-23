import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:journal_trend_analyzer/services/openalex_service.dart';
import 'package:journal_trend_analyzer/viewmodels/subfield_filter_provider.dart';

String _subfieldsBody() => jsonEncode({
  'meta': {'count': 2},
  'results': [
    {
      'id': 'https://openalex.org/subfields/1702',
      'display_name': 'Artificial Intelligence',
      'field': {'id': 'https://openalex.org/fields/17'},
    },
    {
      'id': 'https://openalex.org/subfields/1703',
      'display_name': 'Computational Theory',
      'field': {'id': 'https://openalex.org/fields/17'},
    },
  ],
});

void main() {
  group('SubfieldFilterProvider (Phase 14.2)', () {
    test('ensureLoaded fetches subfields once and caches them', () async {
      final captured = <Uri>[];
      final service = OpenAlexService(
        client: MockClient((req) async {
          captured.add(req.url);
          return http.Response(_subfieldsBody(), 200);
        }),
        mailto: 't@e.com',
      );
      final provider = SubfieldFilterProvider(service);

      expect(provider.ready, isFalse);
      await provider.ensureLoaded();

      expect(provider.ready, isTrue);
      expect(provider.subfields, hasLength(2));
      expect(provider.subfields.first.displayName, 'Artificial Intelligence');
      expect(captured, hasLength(1));
      expect(captured.single.path, '/subfields');

      // Second call is a cached no-op — no extra request.
      await provider.ensureLoaded();
      expect(captured, hasLength(1));
    });

    test('select exposes the short subfield id; clear resets it', () async {
      final service = OpenAlexService(
        client: MockClient((_) async => http.Response(_subfieldsBody(), 200)),
        mailto: 't@e.com',
      );
      final provider = SubfieldFilterProvider(service);
      await provider.ensureLoaded();

      expect(provider.subfieldId, isNull);

      final sub = provider.subfields.first;
      provider.select(sub);
      expect(provider.selected, sub);
      expect(provider.subfieldId, '1702'); // short id

      provider.clear();
      expect(provider.selected, isNull);
      expect(provider.subfieldId, isNull);
    });

    test('load error is captured, not thrown', () async {
      final service = OpenAlexService(
        client: MockClient((_) async => http.Response('x', 500)),
        mailto: 't@e.com',
      );
      final provider = SubfieldFilterProvider(service);

      await provider.ensureLoaded(); // must not throw
      expect(provider.ready, isFalse);
      expect(provider.loadError, isNotNull);
    });
  });
}

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:journal_trend_analyzer/services/openalex_service.dart';

void main() {
  group('citation network service (FR-15)', () {
    test('fetchWorksByIds builds an openalex OR filter (short ids)', () async {
      late Uri captured;
      final service = OpenAlexService(
        client: MockClient((req) async {
          captured = req.url;
          return http.Response(
            jsonEncode({
              'results': [
                {
                  'id': 'https://openalex.org/W1',
                  'display_name': 'A',
                  'cited_by_count': 1,
                },
              ],
            }),
            200,
          );
        }),
      );

      final works =
          await service.fetchWorksByIds(['W1', 'https://openalex.org/W2']);

      expect(captured.path, '/works');
      expect(captured.queryParameters['filter'], 'openalex:W1|W2');
      expect(works.length, 1);
    });

    test('getCitedBy builds the cites filter sorted newest-first', () async {
      late Uri captured;
      final service = OpenAlexService(
        client: MockClient((req) async {
          captured = req.url;
          return http.Response(jsonEncode({'results': []}), 200);
        }),
      );

      await service.getCitedBy('https://openalex.org/W2741809807');

      expect(captured.queryParameters['filter'], 'cites:W2741809807');
      expect(captured.queryParameters['sort'], 'publication_date:desc');
    });

    test('fetchWorksByIds chunks >50 ids into multiple requests', () async {
      var calls = 0;
      final service = OpenAlexService(
        client: MockClient((req) async {
          calls++;
          return http.Response(jsonEncode({'results': []}), 200);
        }),
      );

      await service.fetchWorksByIds(List.generate(120, (i) => 'W$i'));
      expect(calls, 3); // 50 + 50 + 20
    });

    test('findBestRecordByTitle builds a title.search filter, most-cited first',
        () async {
      late Uri captured;
      final service = OpenAlexService(
        client: MockClient((req) async {
          captured = req.url;
          return http.Response(jsonEncode({'results': []}), 200);
        }),
      );

      await service.findBestRecordByTitle('Attention Is All You Need');

      expect(
        captured.queryParameters['filter'],
        'title.search:Attention Is All You Need',
      );
      expect(captured.queryParameters['sort'], 'cited_by_count:desc');
    });

    test('empty id list makes no request', () async {
      var calls = 0;
      final service = OpenAlexService(
        client: MockClient((req) async {
          calls++;
          return http.Response('{}', 200);
        }),
      );

      final result = await service.fetchWorksByIds(const []);
      expect(result, isEmpty);
      expect(calls, 0);
    });
  });
}

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:journal_trend_analyzer/models/models.dart';
import 'package:journal_trend_analyzer/services/openalex_service.dart';

/// Builds a service whose every request is captured into [captured] and
/// answered with [response].
OpenAlexService _serviceReturning(
  http.Response response, {
  List<Uri>? captured,
}) {
  final client = MockClient((request) async {
    captured?.add(request.url);
    return response;
  });
  return OpenAlexService(client: client, mailto: 'test@example.com');
}

String _worksBody(List<Map<String, dynamic>> results, {int count = 0}) {
  return jsonEncode({
    'meta': {'count': count},
    'results': results,
  });
}

String _groupBody(List<Map<String, dynamic>> groups) {
  return jsonEncode({
    'meta': {'count': 0},
    'results': const [],
    'group_by': groups,
  });
}

void main() {
  group('searchWorks', () {
    test(
      'hits /works with search, per-page and mailto, parses results',
      () async {
        final captured = <Uri>[];
        final service = _serviceReturning(
          http.Response(
            _worksBody([
              {
                'display_name': 'Paper A',
                'publication_year': 2020,
                'cited_by_count': 5,
              },
            ], count: 1),
            200,
          ),
          captured: captured,
        );

        final works = await service.searchWorks(
          'machine learning',
          perPage: 50,
        );

        expect(works, isA<List<Work>>());
        expect(works.single.title, 'Paper A');

        final uri = captured.single;
        expect(uri.host, 'api.openalex.org');
        expect(uri.path, '/works');
        expect(uri.queryParameters['search'], 'machine learning');
        expect(uri.queryParameters['per-page'], '50');
        expect(uri.queryParameters['mailto'], 'test@example.com');
      },
    );
  });

  group('getTopCited', () {
    test('adds sort=cited_by_count:desc', () async {
      final captured = <Uri>[];
      final service = _serviceReturning(
        http.Response(_worksBody(const []), 200),
        captured: captured,
      );

      await service.getTopCited('ai', perPage: 25);

      expect(captured.single.queryParameters['sort'], 'cited_by_count:desc');
      expect(captured.single.queryParameters['per-page'], '25');
    });
  });

  group('group_by helpers', () {
    test(
      'groupByYear uses group_by=publication_year and parses buckets',
      () async {
        final captured = <Uri>[];
        final service = _serviceReturning(
          http.Response(
            _groupBody([
              {'key': '2020', 'key_display_name': '2020', 'count': 12},
              {'key': '2021', 'key_display_name': '2021', 'count': 8},
            ]),
            200,
          ),
          captured: captured,
        );

        final groups = await service.groupByYear('ai');

        expect(captured.single.queryParameters['group_by'], 'publication_year');
        expect(groups, isA<List<GroupByItem>>());
        expect(groups.length, 2);
        expect(groups.first.count, 12);
      },
    );

    test('groupByJournal uses group_by=primary_location.source.id', () async {
      final captured = <Uri>[];
      final service = _serviceReturning(
        http.Response(_groupBody(const []), 200),
        captured: captured,
      );

      await service.groupByJournal('ai');
      expect(
        captured.single.queryParameters['group_by'],
        'primary_location.source.id',
      );
    });

    test('groupByAuthor uses group_by=authorships.author.id', () async {
      final captured = <Uri>[];
      final service = _serviceReturning(
        http.Response(_groupBody(const []), 200),
        captured: captured,
      );

      await service.groupByAuthor('ai');
      expect(
        captured.single.queryParameters['group_by'],
        'authorships.author.id',
      );
    });
  });

  group('getTotalCount', () {
    test('returns meta.count', () async {
      final service = _serviceReturning(
        http.Response(_worksBody(const [], count: 1234), 200),
      );
      expect(await service.getTotalCount('ai'), 1234);
    });
  });

  group('error mapping', () {
    test('429 throws RateLimitException', () async {
      final service = _serviceReturning(http.Response('rate limited', 429));
      expect(
        () => service.searchWorks('ai'),
        throwsA(isA<RateLimitException>()),
      );
    });

    test('5xx throws NetworkException', () async {
      final service = _serviceReturning(http.Response('boom', 500));
      expect(() => service.searchWorks('ai'), throwsA(isA<NetworkException>()));
    });

    test('invalid JSON throws ParseException', () async {
      final service = _serviceReturning(http.Response('not json', 200));
      expect(() => service.searchWorks('ai'), throwsA(isA<ParseException>()));
    });

    test('client/transport failure throws NetworkException', () async {
      final client = MockClient(
        (_) async => throw http.ClientException('down'),
      );
      final service = OpenAlexService(
        client: client,
        mailto: 'test@example.com',
      );
      expect(() => service.searchWorks('ai'), throwsA(isA<NetworkException>()));
    });
  });
}

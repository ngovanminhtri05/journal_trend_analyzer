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

  group('discoverWorks (Phase 14.1)', () {
    String discoverBody(
      List<Map<String, dynamic>> results, {
      String? nextCursor,
    }) => jsonEncode({
      'meta': {'count': results.length, 'next_cursor': nextCursor},
      'results': results,
    });

    test('rising (default): recent window + most-cited, cursor primed', () async {
      final captured = <Uri>[];
      final service = _serviceReturning(
        http.Response(
          discoverBody([
            {'display_name': 'Rising Paper', 'cited_by_count': 12},
          ], nextCursor: 'CUR2'),
          200,
        ),
        captured: captured,
      );

      final page = await service.discoverWorks(); // defaults: rising, 365d

      expect(page, isA<WorksPage>());
      expect(page.works.single.title, 'Rising Paper');
      expect(page.nextCursor, 'CUR2');
      expect(page.hasMore, isTrue);

      final uri = captured.single;
      expect(uri.path, '/works');
      expect(uri.queryParameters['sort'], 'cited_by_count:desc');
      expect(uri.queryParameters['per-page'], '25');
      expect(uri.queryParameters['cursor'], '*'); // first page primes the cursor
      expect(
        uri.queryParameters['filter'],
        contains('from_publication_date:'),
      );
      expect(uri.queryParameters['search'], isNull);
    });

    test('newest: sort by date, no recency window', () async {
      final captured = <Uri>[];
      final service = _serviceReturning(
        http.Response(discoverBody(const []), 200),
        captured: captured,
      );

      await service.discoverWorks(sort: WorkSort.newest);

      final uri = captured.single;
      expect(uri.queryParameters['sort'], 'publication_date:desc');
      expect(uri.queryParameters['filter'], isNot(contains('from_publication_date')));
    });

    test('never returns future-dated records (caps at today)', () async {
      // OpenAlex holds placeholder dates like 2050-01-01; without an upper
      // bound they dominate the `newest` sort.
      final captured = <Uri>[];
      final service = _serviceReturning(
        http.Response(discoverBody(const []), 200),
        captured: captured,
      );

      await service.discoverWorks(sort: WorkSort.newest);

      final today = DateTime.now();
      final iso =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-'
          '${today.day.toString().padLeft(2, '0')}';
      expect(
        captured.single.queryParameters['filter'],
        contains('to_publication_date:$iso'),
      );
    });

    test('sourceIds scope the feed to followed journals (OR-joined)', () async {
      final captured = <Uri>[];
      final service = _serviceReturning(
        http.Response(discoverBody(const []), 200),
        captured: captured,
      );

      await service.discoverWorks(
        sort: WorkSort.newest,
        sourceIds: const ['https://openalex.org/S1', 'S2'],
      );

      expect(
        captured.single.queryParameters['filter'],
        contains('primary_location.source.id:S1|S2'),
      );
    });

    test('subfield filter uses the short id', () async {
      final captured = <Uri>[];
      final service = _serviceReturning(
        http.Response(discoverBody(const []), 200),
        captured: captured,
      );

      await service.discoverWorks(
        subfieldId: 'https://openalex.org/subfields/1702',
      );

      final uri = captured.single;
      expect(
        uri.queryParameters['filter'],
        contains('primary_topic.subfield.id:1702'),
      );
    });

    test('search: relevance sort, no window, keeps subfield filter', () async {
      final captured = <Uri>[];
      final service = _serviceReturning(
        http.Response(discoverBody(const []), 200),
        captured: captured,
      );

      await service.discoverWorks(query: 'crispr', subfieldId: '1702');

      final uri = captured.single;
      expect(uri.queryParameters['search'], 'crispr');
      expect(uri.queryParameters['sort'], 'relevance_score:desc');
      expect(uri.queryParameters['filter'], isNot(contains('from_publication_date')));
      expect(
        uri.queryParameters['filter'],
        contains('primary_topic.subfield.id:1702'),
      );
    });

    test('threads a supplied cursor; null next_cursor means no more pages', () async {
      final captured = <Uri>[];
      final service = _serviceReturning(
        http.Response(discoverBody(const []), 200), // meta.next_cursor: null
        captured: captured,
      );

      final page = await service.discoverWorks(cursor: 'ABC123');

      expect(captured.single.queryParameters['cursor'], 'ABC123');
      expect(page.nextCursor, isNull);
      expect(page.hasMore, isFalse);
    });
  });
}

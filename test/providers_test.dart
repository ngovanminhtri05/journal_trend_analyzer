import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:journal_trend_analyzer/services/openalex_service.dart';
import 'package:journal_trend_analyzer/state/state.dart';

/// MockClient that routes OpenAlex requests by their `group_by`/`sort` params.
http.Client _router({bool empty = false}) {
  String works() => jsonEncode({
        'meta': {'count': empty ? 0 : 1234},
        'results': empty
            ? const []
            : [
                {
                  'display_name': 'High Impact Paper',
                  'publication_year': 2021,
                  'cited_by_count': 900,
                },
                {
                  'display_name': 'Second Paper',
                  'publication_year': 2020,
                  'cited_by_count': 100,
                },
              ],
      });

  String group(List<Map<String, dynamic>> g) => jsonEncode({
        'meta': {'count': 0},
        'results': const [],
        'group_by': empty ? const [] : g,
      });

  return MockClient((req) async {
    final gb = req.url.queryParameters['group_by'];
    switch (gb) {
      case 'publication_year':
        return http.Response(
            group([
              {'key': '2021', 'key_display_name': '2021', 'count': 25},
              {'key': '2020', 'key_display_name': '2020', 'count': 10},
            ]),
            200);
      case 'primary_location.source.id':
        return http.Response(
            group([
              {'key': 'S1', 'key_display_name': 'Nature', 'count': 30},
            ]),
            200);
      case 'authorships.author.id':
        return http.Response(
            group([
              {'key': 'A1', 'key_display_name': 'Jane Doe', 'count': 12},
            ]),
            200);
      default:
        return http.Response(works(), 200);
    }
  });
}

OpenAlexService _service({bool empty = false}) =>
    OpenAlexService(client: _router(empty: empty), mailto: 't@e.com');

OpenAlexService _failing(int status) => OpenAlexService(
    client: MockClient((_) async => http.Response('x', status)), mailto: 't@e.com');

void main() {
  group('SearchProvider', () {
    test('idle initially', () {
      expect(SearchProvider(_service()).state, ViewState.idle);
    });

    test('loading then success with results', () async {
      final p = SearchProvider(_service());
      final future = p.search('ai');
      expect(p.state, ViewState.loading);
      await future;
      expect(p.state, ViewState.success);
      expect(p.results, isNotEmpty);
    });

    test('empty when no results', () async {
      final p = SearchProvider(_service(empty: true));
      await p.search('zzz');
      expect(p.state, ViewState.empty);
      expect(p.results, isEmpty);
    });

    test('error on rate limit', () async {
      final p = SearchProvider(_failing(429));
      await p.search('ai');
      expect(p.state, ViewState.error);
      expect(p.errorMessage, isNotNull);
    });

    test('blank query is ignored', () async {
      final p = SearchProvider(_service());
      await p.search('   ');
      expect(p.state, ViewState.idle);
    });
  });

  group('TrendProvider', () {
    test('loading then success populates all sections', () async {
      final p = TrendProvider(_service());
      final future = p.load('ai');
      expect(p.state, ViewState.loading);
      await future;
      expect(p.state, ViewState.success);
      expect(p.yearCounts, isNotEmpty);
      expect(p.topJournals, isNotEmpty);
      expect(p.topAuthors, isNotEmpty);
      expect(p.topPapers, isNotEmpty);
    });

    test('error on server failure', () async {
      final p = TrendProvider(_failing(500));
      await p.load('ai');
      expect(p.state, ViewState.error);
    });
  });

  group('DashboardProvider', () {
    test('success computes the six metrics', () async {
      final p = DashboardProvider(_service());
      await p.load('ai');
      expect(p.state, ViewState.success);
      final s = p.summary!;
      expect(s.totalPublications, 1234);
      expect(s.mostActiveYear, 2021);
      expect(s.topJournal, 'Nature');
      expect(s.topAuthor, 'Jane Doe');
      expect(s.mostInfluential?.title, 'High Impact Paper');
      expect(s.averageCitations, 500); // (900 + 100) / 2
    });

    test('empty when total count is zero', () async {
      final p = DashboardProvider(_service(empty: true));
      await p.load('zzz');
      expect(p.state, ViewState.empty);
    });

    test('error on failure', () async {
      final p = DashboardProvider(_failing(500));
      await p.load('ai');
      expect(p.state, ViewState.error);
    });
  });
}

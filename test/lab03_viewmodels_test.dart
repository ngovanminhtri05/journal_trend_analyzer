import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:journal_trend_analyzer/services/openalex_service.dart';
import 'package:journal_trend_analyzer/viewmodels/viewmodels.dart';

/// Captures every request URI so tests can assert OpenAlex URL building
/// (group_by / filter / sort), then routes a canned response by query params.
class _Recorder {
  final List<Uri> uris = [];

  http.Client client({bool empty = false}) {
    String works() => jsonEncode({
      'meta': {'count': empty ? 0 : 4321},
      'results': empty
          ? const []
          : [
              {
                'display_name': 'Top Paper',
                'publication_year': 2022,
                'cited_by_count': 800,
              },
              {
                'display_name': 'Next Paper',
                'publication_year': 2019,
                'cited_by_count': 200,
              },
            ],
    });

    String groups(List<Map<String, dynamic>> g) => jsonEncode({
      'meta': {'count': 0},
      'results': const [],
      'group_by': empty ? const [] : g,
    });

    return MockClient((req) async {
      uris.add(req.url);
      final gb = req.url.queryParameters['group_by'];
      switch (gb) {
        case 'publication_year':
          return http.Response(
            groups([
              {'key': '2022', 'key_display_name': '2022', 'count': 40},
              {'key': '2019', 'key_display_name': '2019', 'count': 12},
            ]),
            200,
          );
        case 'primary_location.source.id':
          return http.Response(
            groups([
              {
                'key': 'https://openalex.org/S1',
                'key_display_name': 'Nature',
                'count': 30,
              },
              {
                'key': 'https://openalex.org/S2',
                'key_display_name': 'Science',
                'count': 18,
              },
            ]),
            200,
          );
        case 'authorships.author.id':
          return http.Response(
            groups([
              {
                'key': 'https://openalex.org/A2',
                'key_display_name': 'Bob',
                'count': 7,
              },
              {
                'key': 'https://openalex.org/A1',
                'key_display_name': 'Alice',
                'count': 20,
              },
            ]),
            200,
          );
        case 'keywords.id':
          return http.Response(
            groups([
              {
                'key': 'https://openalex.org/keywords/neural-networks',
                'key_display_name': 'neural networks',
                'count': 50,
              },
              {
                'key': 'https://openalex.org/keywords/optimization',
                'key_display_name': 'optimization',
                'count': 22,
              },
            ]),
            200,
          );
        default:
          return http.Response(works(), 200);
      }
    });
  }
}

OpenAlexService _failing(int status) => OpenAlexService(
  client: MockClient((_) async => http.Response('x', status)),
  mailto: 't@e.com',
);

void main() {
  group('HomeViewModel', () {
    test('idle initially', () {
      final rec = _Recorder();
      final vm = HomeViewModel(
        OpenAlexService(client: rec.client(), mailto: 't@e.com'),
      );
      expect(vm.state, ViewState.idle);
    });

    test('loading then success computes the overview', () async {
      final rec = _Recorder();
      final vm = HomeViewModel(
        OpenAlexService(client: rec.client(), mailto: 't@e.com'),
      );
      final future = vm.search('ai');
      expect(vm.state, ViewState.loading);
      await future;

      expect(vm.state, ViewState.success);
      final s = vm.summary!;
      expect(s.totalPublications, 4321);
      expect(s.mostActiveYear, 2022);
      expect(s.topJournal, 'Nature');
      expect(s.topAuthor, 'Alice'); // highest count wins, not first
      expect(s.mostInfluential?.title, 'Top Paper');
      expect(s.averageCitations, 500); // (800 + 200) / 2
      expect(vm.yearCounts, isNotEmpty);
    });

    test('empty when total count is zero', () async {
      final rec = _Recorder();
      final vm = HomeViewModel(
        OpenAlexService(client: rec.client(empty: true), mailto: 't@e.com'),
      );
      await vm.search('zzz');
      expect(vm.state, ViewState.empty);
    });

    test('blank query ignored', () async {
      final rec = _Recorder();
      final vm = HomeViewModel(
        OpenAlexService(client: rec.client(), mailto: 't@e.com'),
      );
      await vm.search('   ');
      expect(vm.state, ViewState.idle);
    });

    test('error on failure', () async {
      final vm = HomeViewModel(_failing(500));
      await vm.search('ai');
      expect(vm.state, ViewState.error);
    });
  });

  group('JournalsViewModel', () {
    test('ranks journals by count desc and builds group_by URL', () async {
      final rec = _Recorder();
      final vm = JournalsViewModel(
        OpenAlexService(client: rec.client(), mailto: 't@e.com'),
      );
      await vm.load('ai');

      expect(vm.state, ViewState.success);
      expect(vm.journals.map((j) => j.keyDisplayName), ['Nature', 'Science']);
      expect(vm.journals.first.count, 30);
      expect(vm.totalInTopJournals, 48);
      expect(
        rec.uris.any(
          (u) =>
              u.queryParameters['group_by'] == 'primary_location.source.id' &&
              u.queryParameters['search'] == 'ai',
        ),
        isTrue,
      );
    });

    test('empty when no journals', () async {
      final rec = _Recorder();
      final vm = JournalsViewModel(
        OpenAlexService(client: rec.client(empty: true), mailto: 't@e.com'),
      );
      await vm.load('zzz');
      expect(vm.state, ViewState.empty);
    });
  });

  group('JournalDetailViewModel', () {
    test('loads count + related works with a source filter', () async {
      final rec = _Recorder();
      final vm = JournalDetailViewModel(
        OpenAlexService(client: rec.client(), mailto: 't@e.com'),
      );
      await vm.load('https://openalex.org/S1');

      expect(vm.state, ViewState.success);
      expect(vm.totalPublications, 4321);
      expect(vm.relatedWorks, isNotEmpty);
      expect(vm.averageTopCitations, 500);
      expect(
        rec.uris.any(
          (u) => u.queryParameters['filter'] == 'primary_location.source.id:S1',
        ),
        isTrue,
      );
    });
  });

  group('KeywordsViewModel', () {
    test('ranks keywords by count desc and builds keywords.id group_by',
        () async {
      final rec = _Recorder();
      final vm = KeywordsViewModel(
        OpenAlexService(client: rec.client(), mailto: 't@e.com'),
      );
      await vm.load('ai');

      expect(vm.state, ViewState.success);
      expect(vm.keywords.first.keyDisplayName, 'neural networks');
      expect(vm.keywords.first.count, 50);
      expect(
        rec.uris.any((u) => u.queryParameters['group_by'] == 'keywords.id'),
        isTrue,
      );
    });

    test('error on rate limit', () async {
      final vm = KeywordsViewModel(_failing(429));
      await vm.load('ai');
      expect(vm.state, ViewState.error);
      expect(vm.errorMessage, isNotNull);
    });
  });

  group('KeywordDetailViewModel', () {
    test('loads year/author/journal/works scoped by keywords.id', () async {
      final rec = _Recorder();
      final vm = KeywordDetailViewModel(
        OpenAlexService(client: rec.client(), mailto: 't@e.com'),
      );
      await vm.load('https://openalex.org/keywords/neural-networks');

      expect(vm.state, ViewState.success);
      expect(vm.yearCounts, isNotEmpty);
      // Authors must be ranked descending by count.
      expect(vm.topAuthors.map((a) => a.keyDisplayName), ['Alice', 'Bob']);
      expect(vm.topAuthors.first.count, 20);
      expect(vm.relatedJournals, isNotEmpty);
      expect(vm.relatedWorks, isNotEmpty);
      // Every scoped query carries the keyword filter (short id).
      final scoped = rec.uris.where(
        (u) => u.queryParameters['filter'] == 'keywords.id:neural-networks',
      );
      expect(scoped.length, greaterThanOrEqualTo(4));
    });
  });
}

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter/foundation.dart';
import 'package:journal_trend_analyzer/firebase/remote_config_service.dart';
import 'package:journal_trend_analyzer/models/models.dart';
import 'package:journal_trend_analyzer/services/openalex_service.dart';
import 'package:journal_trend_analyzer/viewmodels/viewmodels.dart';

/// A Remote Config whose page size can be changed at runtime, to simulate a
/// real-time server push.
class _FakeRemoteConfig extends ChangeNotifier implements RemoteConfigApi {
  _FakeRemoteConfig(this._homePageSize);

  int _homePageSize;

  void pushHomePageSize(int value) {
    _homePageSize = value;
    notifyListeners();
  }

  @override
  int get homePageSize => _homePageSize;
  @override
  int get maxJournals => RemoteConfigService.defaultMaxJournals;
  @override
  int get maxKeywords => RemoteConfigService.defaultMaxKeywords;
  @override
  String get statusLabel => 'fake';
}

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
      // Phase 13.3: journal search by name via /sources.
      if (req.url.path == '/sources') {
        return http.Response(
          jsonEncode({
            'meta': {'count': empty ? 0 : 2},
            'results': empty
                ? const []
                : [
                    {
                      'id': 'https://openalex.org/S1',
                      'display_name': 'Nature',
                      'host_organization_name': 'Springer',
                      'works_count': 1000,
                      'type': 'journal',
                    },
                    {
                      'id': 'https://openalex.org/S2',
                      'display_name': 'Nature Communications',
                      'host_organization_name': 'Springer',
                      'works_count': 500,
                      'type': 'journal',
                    },
                  ],
          }),
          200,
        );
      }
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
  group('HomeViewModel (discovery, Phase 14.3)', () {
    // A /works mock that serves cursor pages: first page (cursor=*) → 2 works +
    // next_cursor 'C2'; the C2 page → 1 more work + next_cursor null.
    ({OpenAlexService service, List<Uri> uris}) pagedService() {
      final uris = <Uri>[];
      final service = OpenAlexService(
        client: MockClient((req) async {
          uris.add(req.url);
          if (req.url.queryParameters['cursor'] == 'C2') {
            return http.Response(
              jsonEncode({
                'meta': {'count': 3, 'next_cursor': null},
                'results': [
                  {'display_name': 'Page2 Paper', 'cited_by_count': 1},
                ],
              }),
              200,
            );
          }
          return http.Response(
            jsonEncode({
              'meta': {'count': 3, 'next_cursor': 'C2'},
              'results': [
                {'display_name': 'Rising A', 'cited_by_count': 9},
                {'display_name': 'Rising B', 'cited_by_count': 7},
              ],
            }),
            200,
          );
        }),
        mailto: 't@e.com',
      );
      return (service: service, uris: uris);
    }

    test('idle initially, rising by default', () {
      final vm = HomeViewModel(pagedService().service);
      expect(vm.state, ViewState.idle);
      expect(vm.sort, WorkSort.rising);
    });

    test('load: rising feed (recent window + most cited), cursor primed',
        () async {
      final s = pagedService();
      final vm = HomeViewModel(s.service);
      final f = vm.load();
      expect(vm.state, ViewState.loading);
      await f;

      expect(vm.state, ViewState.success);
      expect(vm.works.map((w) => w.title), ['Rising A', 'Rising B']);
      expect(vm.hasMore, isTrue);
      final u = s.uris.single;
      expect(u.path, '/works');
      expect(u.queryParameters['sort'], 'cited_by_count:desc');
      expect(u.queryParameters['cursor'], '*');
      expect(u.queryParameters['filter'], contains('from_publication_date'));
      expect(u.queryParameters['search'], isNull);
    });

    test('setSort(newest) reloads by date with no window', () async {
      final s = pagedService();
      final vm = HomeViewModel(s.service);
      await vm.load();
      await vm.setSort(WorkSort.newest);

      expect(vm.sort, WorkSort.newest);
      expect(s.uris.last.queryParameters['sort'], 'publication_date:desc');
      expect(
        s.uris.last.queryParameters['filter'] ?? '',
        isNot(contains('from_publication_date')),
      );
    });

    test('search reloads with relevance ranking', () async {
      final s = pagedService();
      final vm = HomeViewModel(s.service);
      await vm.search('crispr');

      expect(vm.query, 'crispr');
      expect(s.uris.last.queryParameters['search'], 'crispr');
      expect(s.uris.last.queryParameters['sort'], 'relevance_score:desc');
    });

    test('setSubfield scopes the feed', () async {
      final s = pagedService();
      final vm = HomeViewModel(s.service);
      await vm.setSubfield('1702');

      expect(vm.subfieldId, '1702');
      expect(
        s.uris.last.queryParameters['filter'],
        contains('primary_topic.subfield.id:1702'),
      );
    });

    test('loadMore appends the next page, threads cursor, stops at the end',
        () async {
      final s = pagedService();
      final vm = HomeViewModel(s.service);
      await vm.load();
      expect(vm.works, hasLength(2));

      await vm.loadMore();
      expect(vm.works.map((w) => w.title),
          ['Rising A', 'Rising B', 'Page2 Paper']);
      expect(vm.hasMore, isFalse);
      expect(s.uris.last.queryParameters['cursor'], 'C2');

      // Exhausted → no-op.
      final before = s.uris.length;
      await vm.loadMore();
      expect(s.uris.length, before);
    });

    test('fetches the Remote Config page size', () async {
      final s = pagedService();
      final vm = HomeViewModel(
        s.service,
        remoteConfig: const StaticRemoteConfig(homePageSize: 7),
      );
      await vm.load();

      expect(vm.pageSize, 7);
      expect(s.uris.last.queryParameters['per-page'], '7');
    });

    test('applies a live Remote Config page-size push', () async {
      final s = pagedService();
      final config = _FakeRemoteConfig(5);
      final vm = HomeViewModel(s.service, remoteConfig: config);
      await vm.load();
      expect(s.uris.last.queryParameters['per-page'], '5');

      // Server pushes a new size — the feed refetches with it, no restart.
      config.pushHomePageSize(9);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(s.uris.last.queryParameters['per-page'], '9');
    });

    test('empty and error states', () async {
      final emptyService = OpenAlexService(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'meta': {'count': 0, 'next_cursor': null},
              'results': const [],
            }),
            200,
          ),
        ),
        mailto: 't@e.com',
      );
      final vmEmpty = HomeViewModel(emptyService);
      await vmEmpty.load();
      expect(vmEmpty.state, ViewState.empty);

      final vmErr = HomeViewModel(_failing(500));
      await vmErr.load();
      expect(vmErr.state, ViewState.error);
    });
  });

  group('JournalsViewModel', () {
    test('searches sources by name, journals first', () async {
      final rec = _Recorder();
      final vm = JournalsViewModel(
        OpenAlexService(client: rec.client(), mailto: 't@e.com'),
      );
      await vm.search('nature');

      expect(vm.state, ViewState.success);
      expect(vm.sources.map((s) => s.displayName),
          containsAll(['Nature', 'Nature Communications']));
      expect(vm.sources.first.type, 'journal');
      expect(
        rec.uris.any(
          (u) =>
              u.path == '/sources' && u.queryParameters['search'] == 'nature',
        ),
        isTrue,
      );
    });

    test('empty when no journals', () async {
      final rec = _Recorder();
      final vm = JournalsViewModel(
        OpenAlexService(client: rec.client(empty: true), mailto: 't@e.com'),
      );
      await vm.search('zzz');
      expect(vm.state, ViewState.empty);
    });
  });

  group('JournalDetailViewModel', () {
    test('loads recent works grouped into volumes for a source', () async {
      final rec = _Recorder();
      final vm = JournalDetailViewModel(
        OpenAlexService(client: rec.client(), mailto: 't@e.com'),
      );
      await vm.load('https://openalex.org/S1');

      expect(vm.state, ViewState.success);
      expect(vm.recentWorkCount, 2);
      expect(vm.volumes, isNotEmpty);
      // No biblio.volume in the fixture → grouped by year, newest first.
      expect(vm.volumes.first.year, 2022);
      expect(
        rec.uris.any(
          (u) =>
              u.queryParameters['filter'] ==
                  'primary_location.source.id:S1' &&
              u.queryParameters['sort'] == 'publication_date:desc',
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

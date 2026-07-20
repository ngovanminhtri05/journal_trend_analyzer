import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import '../models/models.dart';
import 'openalex_exceptions.dart';

export 'openalex_exceptions.dart';

/// Thin client over the OpenAlex API.
///
/// All calls go directly from the mobile client to `api.openalex.org` (no
/// backend). A `mailto` is sent on every request to use the polite pool for
/// more stable rate limits. The `http.Client` is injectable for testing.
///
/// Every `/works` query accepts an optional `filters` list (FR-13): each entry
/// is a ready-to-use OpenAlex filter clause (e.g. `primary_topic.field.id:17`)
/// and they are AND-joined with commas into the `filter=` query parameter.
class OpenAlexService {
  OpenAlexService({http.Client? client, this.mailto})
    : _client = client ?? http.Client();

  static const String _host = 'api.openalex.org';
  static const String _worksPath = '/works';
  static const String _sourcesPath = '/sources';
  static const String _subfieldsPath = '/subfields';
  static const Duration _timeout = Duration(seconds: 15);

  final http.Client _client;

  /// Email for the OpenAlex polite pool (recommended, not required).
  final String? mailto;

  /// FR-1: free-text search returning a list of works.
  Future<List<Work>> searchWorks(
    String keyword, {
    int perPage = 50,
    List<String> filters = const [],
  }) async {
    final json = await _getJson(
      _worksUri({'search': keyword, 'per-page': '$perPage'}, filters),
    );
    return _parseWorks(json);
  }

  /// FR-4: works ranked by citation count, descending.
  Future<List<Work>> getTopCited(
    String keyword, {
    int perPage = 25,
    List<String> filters = const [],
  }) async {
    final json = await _getJson(
      _worksUri({
        'search': keyword,
        'sort': 'cited_by_count:desc',
        'per-page': '$perPage',
      }, filters),
    );
    return _parseWorks(json);
  }

  /// FR-3: publication counts per year.
  Future<List<GroupByItem>> groupByYear(
    String keyword, {
    List<String> filters = const [],
  }) => _groupBy(keyword, 'publication_year', filters);

  /// FR-5: publication counts per journal/source.
  Future<List<GroupByItem>> groupByJournal(
    String keyword, {
    List<String> filters = const [],
  }) => _groupBy(keyword, 'primary_location.source.id', filters);

  /// Phase 13.3 (Journals): find publication venues by **name** via `/sources`.
  Future<List<SourceHit>> searchSources(String name, {int perPage = 25}) async {
    final query = name.trim();
    if (query.isEmpty) return const [];
    final json = await _getJson(
      _apiUri(_sourcesPath, {'search': query, 'per-page': '$perPage'}),
    );
    final results = json['results'];
    if (results is! List) {
      throw const ParseException('Missing results array in /sources.');
    }
    return results
        .whereType<Map<String, dynamic>>()
        .map(SourceHit.fromJson)
        .where((s) => s.id.isNotEmpty)
        .toList();
  }

  /// Phase 13.3 (Journal detail): the most recent works of a source, newest
  /// first, with enough breadth to group into recent volumes client-side.
  Future<List<Work>> recentWorksBySource(
    String sourceId, {
    int perPage = 150,
  }) => recentWorksByEntity(
    'primary_location.source.id',
    sourceId,
    perPage: perPage,
  );

  /// Phase 13.3+ (Journal detail search): works published in [sourceId] that
  /// match a free-text [query] (a field/topic within that journal), newest
  /// first. With no query it returns the journal's recent works.
  Future<List<Work>> worksInSource(
    String sourceId, {
    String? query,
    int perPage = 50,
  }) async {
    final id = shortOpenAlexId(sourceId);
    if (id.isEmpty) return const [];
    final params = <String, String>{
      'filter': 'primary_location.source.id:$id',
      'sort': 'publication_date:desc',
      'per-page': '$perPage',
    };
    final q = query?.trim() ?? '';
    if (q.isNotEmpty) params['search'] = q;
    final json = await _getJson(_apiUri(_worksPath, params));
    return _parseWorks(json);
  }

  /// Phase 13.2 (Home): the most recent publications for a topic/field, newest
  /// first. No aggregation — a light, per-paper feed for the user's own field.
  Future<List<Work>> recentWorksByTopic(
    String topic, {
    int perPage = 25,
  }) async {
    final query = topic.trim();
    if (query.isEmpty) return const [];
    final json = await _getJson(
      _worksUri({
        'search': query,
        'sort': 'publication_date:desc',
        'per-page': '$perPage',
      }, const []),
    );
    return _parseWorks(json);
  }

  /// Phase 14.1 (Home discovery): a cursor-paginated feed of works.
  ///
  /// - No [query]: a browse feed ordered by [sort]. `rising` scopes to a
  ///   recency window ([windowDays]) and orders by citations; `newest` orders by
  ///   publication date with no lower bound.
  /// - With [query]: a relevance-ranked search (`relevance_score:desc`, all
  ///   time — no recency window).
  ///
  /// [subfieldId] (full or short OpenAlex id) scopes to
  /// `primary_topic.subfield.id`. [sourceIds] scopes to a set of venues
  /// (OR-joined) — used to show only the journals the user follows.
  /// [cursor] threads OpenAlex cursor pagination — pass null for the first page
  /// (primed with `*`), then feed back [WorksPage.nextCursor]. No new HTTP client.
  Future<WorksPage> discoverWorks({
    String? query,
    String? subfieldId,
    List<String> sourceIds = const [],
    WorkSort sort = WorkSort.rising,
    int windowDays = 365,
    String? cursor,
    int perPage = 25,
  }) async {
    final q = query?.trim() ?? '';
    final isSearch = q.isNotEmpty;

    final filters = <String>[];
    // Recency window applies only to the browse feed (search spans all time).
    final windowed = !isSearch && sort == WorkSort.rising && windowDays > 0;
    if (windowed) {
      final since = DateTime.now().subtract(Duration(days: windowDays));
      filters.add('from_publication_date:${_isoDate(since)}');
    }
    // Never surface future-dated records. OpenAlex holds placeholder /
    // "forthcoming" publication dates (2050-01-01 and similar) which would
    // otherwise dominate the `newest` sort.
    filters.add('to_publication_date:${_isoDate(DateTime.now())}');
    final subId = subfieldId == null ? '' : shortOpenAlexId(subfieldId);
    if (subId.isNotEmpty) filters.add('primary_topic.subfield.id:$subId');
    // Followed venues: OpenAlex ORs values within one filter clause with `|`.
    final sources = sourceIds
        .map(shortOpenAlexId)
        .where((id) => id.isNotEmpty)
        .toList();
    if (sources.isNotEmpty) {
      filters.add('primary_location.source.id:${sources.join('|')}');
    }

    final sortKey = isSearch
        ? 'relevance_score:desc'
        : (sort == WorkSort.newest
              ? 'publication_date:desc'
              : 'cited_by_count:desc');

    final json = await _getJson(
      _apiUri(_worksPath, {
        'sort': sortKey,
        'per-page': '$perPage',
        'cursor': cursor ?? '*',
        if (filters.isNotEmpty) 'filter': filters.join(','),
        if (isSearch) 'search': q,
      }),
    );

    final meta = json['meta'];
    final nextCursor = (meta is Map) ? meta['next_cursor'] as String? : null;
    return WorksPage(works: _parseWorks(json), nextCursor: nextCursor);
  }

  /// Formats a date as `YYYY-MM-DD` for OpenAlex `from_publication_date`.
  static String _isoDate(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)}';
  }

  /// Phase 13.2 (Home): **trending** publications — recently published *and*
  /// highly cited (recent citation momentum). Global by default; pass [field] to
  /// scope the trend to a topic. No aggregate totals — just the papers.
  Future<List<Work>> trendingWorks({String? field, int perPage = 25}) async {
    final since = DateTime.now().subtract(const Duration(days: 365 * 2));
    final fromDate = '${since.year}-01-01';
    final params = <String, String>{
      'filter': 'from_publication_date:$fromDate',
      'sort': 'cited_by_count:desc',
      'per-page': '$perPage',
    };
    final query = field?.trim() ?? '';
    if (query.isNotEmpty) params['search'] = query;
    final json = await _getJson(_apiUri(_worksPath, params));
    return _parseWorks(json);
  }

  /// FR-6: publication counts per author.
  Future<List<GroupByItem>> groupByAuthor(
    String keyword, {
    List<String> filters = const [],
  }) => _groupBy(keyword, 'authorships.author.id', filters);

  /// Lab 03 (Keywords): publication counts per keyword for a topic search.
  Future<List<GroupByItem>> groupByKeyword(
    String keyword, {
    List<String> filters = const [],
  }) => _groupBy(keyword, 'keywords.id', filters);

  /// Lab 03 (Journal / Keyword detail): works matching a raw OpenAlex [filters]
  /// list with no free-text search term, most-cited first by default. Filters
  /// are AND-joined with commas. Reuses `_apiUri`/`_getJson`/`_parseWorks` — no
  /// new HTTP client.
  Future<List<Work>> getWorksByFilter(
    List<String> filters, {
    int perPage = 25,
    String sort = 'cited_by_count:desc',
  }) async {
    if (filters.isEmpty) return const [];
    final json = await _getJson(
      _apiUri(_worksPath, {
        'filter': filters.join(','),
        'sort': sort,
        'per-page': '$perPage',
      }),
    );
    return _parseWorks(json);
  }

  /// Lab 03 (Journal / Keyword detail): `meta.count` of works matching a raw
  /// [filters] list (no free-text search).
  Future<int> getCountByFilter(List<String> filters) async {
    if (filters.isEmpty) return 0;
    final json = await _getJson(
      _apiUri(_worksPath, {'filter': filters.join(','), 'per-page': '1'}),
    );
    final meta = json['meta'];
    if (meta is! Map || meta['count'] is! num) {
      throw const ParseException('Missing meta.count in response.');
    }
    return (meta['count'] as num).toInt();
  }

  /// Lab 03 (Keyword detail): `group_by` aggregation over [dimension] for works
  /// matching a raw [filters] list (no free-text search). Used to scope a
  /// year-trend or author ranking to a single keyword.
  Future<List<GroupByItem>> groupByFilter(
    String dimension,
    List<String> filters,
  ) async {
    final json = await _getJson(
      _apiUri(_worksPath, {
        'group_by': dimension,
        if (filters.isNotEmpty) 'filter': filters.join(','),
      }),
    );
    return _parseGroups(json);
  }

  /// FR-7: total number of works matching the topic (`meta.count`).
  Future<int> getTotalCount(
    String keyword, {
    List<String> filters = const [],
  }) async {
    final json = await _getJson(
      _worksUri({'search': keyword, 'per-page': '1'}, filters),
    );
    final meta = json['meta'];
    if (meta is! Map || meta['count'] is! num) {
      throw const ParseException('Missing meta.count in response.');
    }
    return (meta['count'] as num).toInt();
  }

  /// FR-13: full list of OpenAlex subfields (Domain → Field → **Subfield**).
  ///
  /// There are ~250 subfields, so this pages through with `per-page=200`. The
  /// caller is expected to cache the result (it never changes within a session).
  Future<List<Subfield>> getSubfields() async {
    const perPage = 200;
    final all = <Subfield>[];
    var page = 1;
    while (true) {
      final json = await _getJson(
        _apiUri(_subfieldsPath, {
          'per-page': '$perPage',
          'page': '$page',
          'select': 'id,display_name,field',
        }),
      );
      final results = json['results'];
      if (results is! List) {
        throw const ParseException('Missing results array in /subfields.');
      }
      final batch = results
          .whereType<Map<String, dynamic>>()
          .map(Subfield.fromJson)
          .toList();
      all.addAll(batch);
      // Last page reached when the batch is short.
      if (batch.length < perPage) break;
      page++;
      if (page > 10) break; // safety cap; OpenAlex offset paging stops at 10k
    }
    return all;
  }

  /// FR-15 (outgoing references): fetch full Work objects for a list of short
  /// OpenAlex ids using the `openalex:` OR filter, chunked so the URL stays
  /// short. Pass at most a screenful of ids (the caller caps references).
  Future<List<Work>> fetchWorksByIds(
    List<String> ids, {
    int chunkSize = 50,
  }) async {
    final clean = ids.map(shortOpenAlexId).where((s) => s.isNotEmpty).toList();
    if (clean.isEmpty) return const [];
    final out = <Work>[];
    for (var i = 0; i < clean.length; i += chunkSize) {
      final chunk = clean.sublist(i, min(i + chunkSize, clean.length));
      final json = await _getJson(
        _apiUri(_worksPath, {
          'filter': 'openalex:${chunk.join('|')}',
          'per-page': '${chunk.length}',
        }),
      );
      out.addAll(_parseWorks(json));
    }
    return out;
  }

  /// FR-14: find candidate records for a [title], most-cited first. Used to
  /// pick a "canonical" version when the record in hand is missing metadata
  /// (OpenAlex often holds several variants of the same paper).
  Future<List<Work>> findBestRecordByTitle(
    String title, {
    int perPage = 5,
  }) async {
    // OpenAlex uses ',' as the filter delimiter and '|' as OR, so a comma in a
    // `.search` value returns HTTP 403. Strip those reserved characters.
    final query = title
        .replaceAll(RegExp(r'[,|]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (query.isEmpty) return const [];
    final json = await _getJson(
      _apiUri(_worksPath, {
        'filter': 'title.search:$query',
        'sort': 'cited_by_count:desc',
        'per-page': '$perPage',
      }),
    );
    return _parseWorks(json);
  }

  /// FR-15 (incoming citations): fetch works that cite [workId]. [sort] is an
  /// OpenAlex sort expression (default newest first; pass
  /// `cited_by_count:desc` for most-cited first).
  Future<List<Work>> getCitedBy(
    String workId, {
    int perPage = 25,
    String sort = 'publication_date:desc',
  }) async {
    final id = shortOpenAlexId(workId);
    if (id.isEmpty) return const [];
    final json = await _getJson(
      _apiUri(_worksPath, {
        'filter': 'cites:$id',
        'sort': sort,
        'per-page': '$perPage',
      }),
    );
    return _parseWorks(json);
  }

  /// Most recent works for a followed author or journal (new-paper alerts).
  /// [filterField] is e.g. `authorships.author.id` or
  /// `primary_location.source.id`; [entityId] a short or full OpenAlex id.
  Future<List<Work>> recentWorksByEntity(
    String filterField,
    String entityId, {
    int perPage = 5,
  }) async {
    final id = shortOpenAlexId(entityId);
    if (id.isEmpty) return const [];
    final json = await _getJson(
      _apiUri(_worksPath, {
        'filter': '$filterField:$id',
        'sort': 'publication_date:desc',
        'per-page': '$perPage',
      }),
    );
    return _parseWorks(json);
  }

  Future<List<GroupByItem>> _groupBy(
    String keyword,
    String dimension,
    List<String> filters,
  ) async {
    final json = await _getJson(
      _worksUri({'search': keyword, 'group_by': dimension}, filters),
    );
    return _parseGroups(json);
  }

  /// Parses the `group_by` bucket array shared by all aggregation queries.
  List<GroupByItem> _parseGroups(Map<String, dynamic> json) {
    final groups = json['group_by'];
    if (groups is! List) {
      throw const ParseException('Missing group_by array in response.');
    }
    return groups
        .whereType<Map<String, dynamic>>()
        .map(GroupByItem.fromJson)
        .toList();
  }

  /// Builds a `/works` URI, appending the comma-joined `filter=` clause when
  /// any taxonomy/other filters are supplied.
  Uri _worksUri(Map<String, String> params, List<String> filters) {
    return _apiUri(_worksPath, {
      ...params,
      if (filters.isNotEmpty) 'filter': filters.join(','),
    });
  }

  /// Builds an arbitrary OpenAlex URI, always attaching the polite-pool mailto.
  Uri _apiUri(String path, Map<String, String> params) {
    final query = {
      ...params,
      if (mailto != null && mailto!.isNotEmpty) 'mailto': mailto!,
    };
    return Uri.https(_host, path, query);
  }

  /// Performs the GET, maps transport/status errors to typed exceptions, and
  /// decodes the JSON body.
  Future<Map<String, dynamic>> _getJson(Uri uri) async {
    final http.Response response;
    try {
      response = await _client.get(uri).timeout(_timeout);
    } on OpenAlexException {
      rethrow;
    } catch (e) {
      // SocketException, http.ClientException, TimeoutException, etc. Keep the
      // technical detail off the UI; surface a friendly, actionable message.
      throw NetworkException(
        'Could not reach OpenAlex. Please check your connection and retry.',
      );
    }

    if (response.statusCode == 429) {
      throw const RateLimitException();
    }
    if (response.statusCode != 200) {
      throw NetworkException(
        'OpenAlex returned HTTP ${response.statusCode}.',
        statusCode: response.statusCode,
      );
    }

    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const ParseException('Unexpected response shape.');
      }
      return decoded;
    } on ParseException {
      rethrow;
    } catch (_) {
      throw const ParseException();
    }
  }

  List<Work> _parseWorks(Map<String, dynamic> json) {
    final results = json['results'];
    if (results is! List) {
      throw const ParseException('Missing results array in response.');
    }
    return results
        .whereType<Map<String, dynamic>>()
        .map(Work.fromJson)
        .toList();
  }

  /// Closes the underlying HTTP client.
  void dispose() => _client.close();
}

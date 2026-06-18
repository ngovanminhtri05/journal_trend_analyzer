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

  /// FR-6: publication counts per author.
  Future<List<GroupByItem>> groupByAuthor(
    String keyword, {
    List<String> filters = const [],
  }) => _groupBy(keyword, 'authorships.author.id', filters);

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
    final clean = ids.map(_shortId).where((s) => s.isNotEmpty).toList();
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
    final query = title.trim();
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
    final id = _shortId(workId);
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

  /// Last path segment of an OpenAlex id ("https://openalex.org/W1" → "W1").
  static String _shortId(String id) {
    final trimmed = id.trim();
    final slash = trimmed.lastIndexOf('/');
    return slash == -1 ? trimmed : trimmed.substring(slash + 1);
  }

  Future<List<GroupByItem>> _groupBy(
    String keyword,
    String dimension,
    List<String> filters,
  ) async {
    final json = await _getJson(
      _worksUri({'search': keyword, 'group_by': dimension}, filters),
    );
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

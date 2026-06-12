import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/models.dart';
import 'openalex_exceptions.dart';

export 'openalex_exceptions.dart';

/// Thin client over the OpenAlex `/works` endpoint.
///
/// All calls go directly from the mobile client to `api.openalex.org` (no
/// backend). A `mailto` is sent on every request to use the polite pool for
/// more stable rate limits. The `http.Client` is injectable for testing.
class OpenAlexService {
  OpenAlexService({http.Client? client, this.mailto})
    : _client = client ?? http.Client();

  static const String _host = 'api.openalex.org';
  static const String _worksPath = '/works';
  static const Duration _timeout = Duration(seconds: 15);

  final http.Client _client;

  /// Email for the OpenAlex polite pool (recommended, not required).
  final String? mailto;

  /// FR-1: free-text search returning a list of works.
  Future<List<Work>> searchWorks(String keyword, {int perPage = 50}) async {
    final json = await _getJson(
      _worksUri({'search': keyword, 'per-page': '$perPage'}),
    );
    return _parseWorks(json);
  }

  /// FR-4: works ranked by citation count, descending.
  Future<List<Work>> getTopCited(String keyword, {int perPage = 25}) async {
    final json = await _getJson(
      _worksUri({
        'search': keyword,
        'sort': 'cited_by_count:desc',
        'per-page': '$perPage',
      }),
    );
    return _parseWorks(json);
  }

  /// FR-3: publication counts per year.
  Future<List<GroupByItem>> groupByYear(String keyword) =>
      _groupBy(keyword, 'publication_year');

  /// FR-5: publication counts per journal/source.
  Future<List<GroupByItem>> groupByJournal(String keyword) =>
      _groupBy(keyword, 'primary_location.source.id');

  /// FR-6: publication counts per author.
  Future<List<GroupByItem>> groupByAuthor(String keyword) =>
      _groupBy(keyword, 'authorships.author.id');

  /// FR-7: total number of works matching the topic (`meta.count`).
  Future<int> getTotalCount(String keyword) async {
    final json = await _getJson(
      _worksUri({'search': keyword, 'per-page': '1'}),
    );
    final meta = json['meta'];
    if (meta is! Map || meta['count'] is! num) {
      throw const ParseException('Missing meta.count in response.');
    }
    return (meta['count'] as num).toInt();
  }

  Future<List<GroupByItem>> _groupBy(String keyword, String dimension) async {
    final json = await _getJson(
      _worksUri({'search': keyword, 'group_by': dimension}),
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

  Uri _worksUri(Map<String, String> params) {
    final query = {
      ...params,
      if (mailto != null && mailto!.isNotEmpty) 'mailto': mailto!,
    };
    return Uri.https(_host, _worksPath, query);
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

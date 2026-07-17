import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'package:journal_trend_analyzer/models/models.dart';
import 'package:journal_trend_analyzer/services/follow_updates_service.dart';
import 'package:journal_trend_analyzer/services/openalex_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  // OpenAlexService whose "latest work" is controlled by [latestId].
  ({OpenAlexService service, void Function(String) setLatest}) buildService() {
    var latestId = 'W1';
    final service = OpenAlexService(
      mailto: 't@e.com',
      client: MockClient((req) async {
        return http.Response(
          jsonEncode({
            'results': [
              {
                'id': 'https://openalex.org/$latestId',
                'display_name': 'Paper $latestId',
              },
            ],
          }),
          200,
        );
      }),
    );
    return (service: service, setLatest: (v) => latestId = v);
  }

  const author = Bookmark(
    type: BookmarkType.author,
    id: 'https://openalex.org/A1',
    displayName: 'Dr X',
  );

  test('alerts on first check, then only when the latest work changes', () async {
    final env = buildService();
    final follow = FollowUpdatesService(env.service);

    // First check: no prior "seen" → alert with the current latest.
    final first = await follow.checkForNewPapers([author]);
    expect(first, hasLength(1));
    expect(first.first.title, 'New paper — Dr X');
    expect(first.first.body, 'Paper W1');

    // Same latest → no alert.
    final second = await follow.checkForNewPapers([author]);
    expect(second, isEmpty);

    // A newer work appears → alert again.
    env.setLatest('W2');
    final third = await follow.checkForNewPapers([author]);
    expect(third, hasLength(1));
    expect(third.first.body, 'Paper W2');
  });

  test('ignores work bookmarks and empty follow lists', () async {
    final env = buildService();
    final follow = FollowUpdatesService(env.service);

    expect(await follow.checkForNewPapers([]), isEmpty);
    expect(
      await follow.checkForNewPapers([
        const Bookmark(
          type: BookmarkType.work,
          id: 'W9',
          displayName: 'A paper',
        ),
      ]),
      isEmpty,
    );
  });
}

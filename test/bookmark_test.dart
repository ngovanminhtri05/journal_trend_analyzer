import 'package:flutter_test/flutter_test.dart';
import 'package:journal_trend_analyzer/models/models.dart';
import 'package:journal_trend_analyzer/services/bookmark_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  // Needed so the shared_preferences mock channel is available.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Bookmark model', () {
    test('work round-trips through JSON', () {
      final work = Work(
        id: 'https://openalex.org/W1',
        title: 'Deep Learning',
        publicationYear: 2020,
        citedByCount: 99,
        source: const Source(displayName: 'Nature'),
        authors: const [],
      );

      final restored = Bookmark.fromJson(Bookmark.fromWork(work).toJson());

      expect(restored.type, BookmarkType.work);
      expect(restored.id, 'https://openalex.org/W1');
      expect(restored.displayName, 'Deep Learning');
      expect(restored.publicationYear, 2020);
      expect(restored.citedByCount, 99);
      expect(restored.journalName, 'Nature');
    });

    test('journal and author derive from group_by buckets', () {
      final bucket =
          GroupByItem(key: 'S1', keyDisplayName: 'Journal X', count: 42);

      final journal = Bookmark.fromJournal(bucket);
      expect(journal.type, BookmarkType.journal);
      expect(journal.displayName, 'Journal X');
      expect(journal.worksCount, 42);

      expect(Bookmark.fromAuthor(bucket).type, BookmarkType.author);
    });

    test('toWork rebuilds a partial work for offline detail', () {
      final bookmark = Bookmark.fromWork(
        Work(id: 'W2', title: 'T', citedByCount: 5, authors: const []),
      );
      final work = bookmark.toWork();
      expect(work.id, 'W2');
      expect(work.title, 'T');
      expect(work.citedByCount, 5);
    });
  });

  group('BookmarkService persistence', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('save then load returns the same bookmarks', () async {
      final service = BookmarkService();
      await service.init();
      final items = [
        Bookmark.fromWork(
          Work(id: 'W1', title: 'A', citedByCount: 1, authors: const []),
        ),
        Bookmark.fromJournal(
          GroupByItem(key: 'S1', keyDisplayName: 'J', count: 3),
        ),
      ];
      await service.save(items);

      // A fresh instance reads the persisted store (simulates an app restart).
      final reopened = BookmarkService();
      await reopened.init();
      final loaded = reopened.load();

      expect(loaded.length, 2);
      expect(loaded[0].id, 'W1');
      expect(loaded[1].type, BookmarkType.journal);
    });

    test('load returns empty when nothing is stored', () async {
      final service = BookmarkService();
      await service.init();
      expect(service.load(), isEmpty);
    });

    test('load drops orphaned entries with an empty id', () async {
      final service = BookmarkService();
      await service.init();
      // One valid bookmark + one with an empty id (e.g. an "unknown" bucket).
      await service.save([
        Bookmark.fromWork(
          Work(id: 'W1', title: 'A', citedByCount: 1, authors: const []),
        ),
        Bookmark.fromJournal(
          GroupByItem(key: '', keyDisplayName: 'Unknown', count: 0),
        ),
      ]);

      final loaded = service.load();
      expect(loaded.length, 1);
      expect(loaded.single.id, 'W1');
    });
  });
}

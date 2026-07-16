import 'package:flutter_test/flutter_test.dart';
import 'package:journal_trend_analyzer/models/work.dart';
import 'package:journal_trend_analyzer/models/author.dart';
import 'package:journal_trend_analyzer/models/source.dart';
import 'package:journal_trend_analyzer/models/group_by_item.dart';

void main() {
  group('Work.fromJson', () {
    final fullJson = <String, dynamic>{
      'id': 'https://openalex.org/W123',
      'doi': 'https://doi.org/10.1234/abc',
      'title': 'Deep Learning',
      'display_name': 'Deep Learning',
      'publication_year': 2020,
      'cited_by_count': 1500,
      'ids': {'doi': 'https://doi.org/10.1234/abc'},
      'primary_location': {
        'source': {'id': 'https://openalex.org/S456', 'display_name': 'Nature'},
      },
      'authorships': [
        {
          'author': {
            'id': 'https://openalex.org/A1',
            'display_name': 'Jane Doe',
          },
        },
        {
          'author': {
            'id': 'https://openalex.org/A2',
            'display_name': 'John Smith',
          },
        },
      ],
      'abstract_inverted_index': {
        'Deep': [0],
        'learning': [1],
      },
    };

    test('parses all core fields', () {
      final work = Work.fromJson(fullJson);
      expect(work.id, 'https://openalex.org/W123');
      expect(work.title, 'Deep Learning');
      expect(work.publicationYear, 2020);
      expect(work.citedByCount, 1500);
      expect(work.doi, 'https://doi.org/10.1234/abc');
      expect(work.source?.displayName, 'Nature');
      expect(work.journalName, 'Nature');
      expect(work.authors.length, 2);
      expect(work.authors.first.displayName, 'Jane Doe');
      expect(work.authorNames, 'Jane Doe, John Smith');
      expect(work.abstractInvertedIndex, isNotNull);
    });

    test('falls back to title when display_name is missing', () {
      final json = Map<String, dynamic>.from(fullJson)..remove('display_name');
      final work = Work.fromJson(json);
      expect(work.title, 'Deep Learning');
    });

    test('falls back to ids.doi when top-level doi is missing', () {
      final json = Map<String, dynamic>.from(fullJson)..remove('doi');
      final work = Work.fromJson(json);
      expect(work.doi, 'https://doi.org/10.1234/abc');
    });

    test('is null-safe when optional fields are absent', () {
      final work = Work.fromJson(<String, dynamic>{});
      expect(work.title, isNotEmpty); // placeholder, not crash
      expect(work.publicationYear, isNull);
      expect(work.citedByCount, 0);
      expect(work.doi, isNull);
      expect(work.source, isNull);
      expect(work.journalName, isNull);
      expect(work.authors, isEmpty);
      expect(work.abstractInvertedIndex, isNull);
    });
  });

  group('Source.fromJson', () {
    test('parses id and display_name', () {
      final s = Source.fromJson({'id': 'S1', 'display_name': 'IEEE'});
      expect(s.id, 'S1');
      expect(s.displayName, 'IEEE');
    });
  });

  group('Author.fromJson', () {
    test('parses id and display_name', () {
      final a = Author.fromJson({'id': 'A1', 'display_name': 'Ada Lovelace'});
      expect(a.id, 'A1');
      expect(a.displayName, 'Ada Lovelace');
    });
  });

  group('GroupByItem.fromJson', () {
    test('parses key, key_display_name and count', () {
      final g = GroupByItem.fromJson({
        'key': '2020',
        'key_display_name': '2020',
        'count': 42,
      });
      expect(g.key, '2020');
      expect(g.keyDisplayName, '2020');
      expect(g.count, 42);
    });
  });
}

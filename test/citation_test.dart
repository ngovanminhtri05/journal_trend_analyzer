import 'package:flutter_test/flutter_test.dart';
import 'package:journal_trend_analyzer/models/models.dart';
import 'package:journal_trend_analyzer/services/citation_formatter.dart';

Work _attention() => Work.fromJson(const {
  'id': 'https://openalex.org/W2741809807',
  'display_name': 'Attention Is All You Need',
  'publication_year': 2017,
  'cited_by_count': 100000,
  'doi': 'https://doi.org/10.5555/3295222.3295349',
  'primary_location': {
    'source': {'display_name': 'NeurIPS'},
  },
  'authorships': [
    {
      'author': {'display_name': 'Ashish Vaswani'},
    },
    {
      'author': {'display_name': 'Noam Shazeer'},
    },
  ],
  'biblio': {
    'volume': '30',
    'issue': '2',
    'first_page': '5998',
    'last_page': '6008',
  },
  'referenced_works': [
    'https://openalex.org/W123',
    'https://openalex.org/W456',
  ],
  'referenced_works_count': 2,
});

void main() {
  group('Work citation fields (FR-14/15)', () {
    test('parses biblio, referenced works, and helpers', () {
      final w = _attention();
      expect(w.shortId, 'W2741809807');
      expect(w.firstAuthorSurname, 'Vaswani');
      expect(w.biblio?.volume, '30');
      expect(w.biblio?.issue, '2');
      expect(w.biblio?.pages, '5998--6008');
      expect(w.referencedWorks, ['W123', 'W456']);
      expect(w.referencedWorksCount, 2);
    });
  });

  group('CitationFormatter', () {
    test('citationKey is <surname><year> lowercased', () {
      expect(CitationFormatter.citationKey(_attention()), 'vaswani2017');
    });

    test('BibTeX has the expected fields and never prints null', () {
      final bib = CitationFormatter.toBibTeX(_attention());
      expect(bib, startsWith('@article{vaswani2017,'));
      expect(bib, contains('title = {Attention Is All You Need}'));
      expect(bib, contains('author = {Ashish Vaswani and Noam Shazeer}'));
      expect(bib, contains('journal = {NeurIPS}'));
      expect(bib, contains('year = {2017}'));
      expect(bib, contains('volume = {30}'));
      expect(bib, contains('number = {2}'));
      expect(bib, contains('pages = {5998--6008}'));
      expect(bib, contains('doi = {10.5555/3295222.3295349}'));
      expect(bib, isNot(contains('null')));
      expect(bib.trim(), endsWith('}'));
    });

    test('omits missing fields entirely', () {
      final bare = Work(title: 'Bare', citedByCount: 0, authors: const []);
      final bib = CitationFormatter.toBibTeX(bare);
      expect(bib, contains('title = {Bare}'));
      expect(bib, isNot(contains('journal')));
      expect(bib, isNot(contains('author')));
      expect(bib, isNot(contains('null')));
    });

    test('RIS starts with TY, ends with ER, one AU per author', () {
      final ris = CitationFormatter.toRIS(_attention());
      expect(ris, startsWith('TY  - JOUR'));
      expect(ris, contains('AU  - Ashish Vaswani'));
      expect(ris, contains('AU  - Noam Shazeer'));
      expect(ris, contains('PY  - 2017'));
      expect(ris.trim(), endsWith('ER  -'));
    });

    test('APA has year, title, initials and DOI url', () {
      final apa = CitationFormatter.toAPA(_attention());
      expect(apa, contains('(2017).'));
      expect(apa, contains('Attention Is All You Need'));
      expect(apa, contains('Vaswani, A.'));
      expect(apa, contains('https://doi.org/10.5555/3295222.3295349'));
    });

    test('toBibTeXList joins multiple entries', () {
      final list =
          CitationFormatter.toBibTeXList([_attention(), _attention()]);
      expect('@article{'.allMatches(list).length, 2);
    });
  });
}

import '../models/models.dart';

/// Formats a [Work] into standard citation strings (FR-14).
///
/// Pure and UI-agnostic (no Flutter imports) so it is trivially unit-testable.
/// Reads only fields already present on the [Work] model — it never calls the
/// network. Any null field is omitted from the output (we never print "null").
class CitationFormatter {
  const CitationFormatter._();

  // ---------------------------------------------------------------- BibTeX ---

  /// A single `@article{...}` BibTeX entry.
  static String toBibTeX(Work work) {
    final lines = <String>[];
    void add(String key, String? value) {
      if (value != null && value.isNotEmpty) lines.add('  $key = {$value}');
    }

    add('title', work.title);
    add('author', _authorsAnd(work));
    add('journal', work.journalName);
    add('year', work.publicationYear?.toString());
    add('volume', work.biblio?.volume);
    add('number', work.biblio?.issue);
    add('pages', work.biblio?.pages);
    add('doi', _bareDoi(work.doi));

    return '@article{${citationKey(work)},\n${lines.join(',\n')}\n}';
  }

  /// Several works as one multi-entry BibTeX string (Export All — FR-14).
  static String toBibTeXList(Iterable<Work> works) =>
      works.map(toBibTeX).join('\n\n');

  // ------------------------------------------------------------------- RIS ---

  /// RIS entry (type JOUR) — the format Zotero/Mendeley import.
  static String toRIS(Work work) {
    final lines = <String>['TY  - JOUR'];
    void add(String tag, String? value) {
      if (value != null && value.isNotEmpty) lines.add('$tag  - $value');
    }

    add('TI', work.title);
    for (final a in work.authors) {
      if (a.displayName.isNotEmpty) lines.add('AU  - ${a.displayName}');
    }
    add('PY', work.publicationYear?.toString());
    add('JO', work.journalName);
    add('VL', work.biblio?.volume);
    add('IS', work.biblio?.issue);
    add('SP', work.biblio?.firstPage);
    add('EP', work.biblio?.lastPage);
    add('DO', _bareDoi(work.doi));
    lines.add('ER  - ');
    return lines.join('\n');
  }

  // ------------------------------------------------------------------- APA ---

  /// Plain-text APA-7-style reference (journals can't be italicized in plain
  /// text, so the journal name is shown unstyled).
  static String toAPA(Work work) {
    final buffer = StringBuffer();

    final authors = _authorsApa(work);
    if (authors != null) buffer.write('$authors ');

    final year = work.publicationYear?.toString();
    buffer.write('(${year ?? 'n.d.'}). ');

    buffer.write('${work.title}. ');

    final journal = work.journalName;
    if (journal != null) {
      buffer.write(journal);
      final volume = work.biblio?.volume;
      if (volume != null) {
        buffer.write(', $volume');
        final issue = work.biblio?.issue;
        if (issue != null) buffer.write('($issue)');
      }
      final pages = work.biblio?.pages;
      if (pages != null) buffer.write(', ${pages.replaceAll('--', '–')}');
      buffer.write('. ');
    }

    final url = _doiUrl(work.doi);
    if (url != null) buffer.write(url);

    return buffer.toString().trim();
  }

  // -------------------------------------------------------------- helpers ---

  /// `<firstAuthorSurname><year>` lowercased ASCII (e.g. "smith2023"). Falls
  /// back to the first title word, then to the short id, then "ref".
  static String citationKey(Work work) {
    final title = work.title.trim();
    final base = work.firstAuthorSurname ??
        (title.isEmpty ? null : title.split(RegExp(r'\s+')).first) ??
        work.shortId ??
        'ref';
    final slug = base.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    final year = work.publicationYear?.toString() ?? '';
    final key = '$slug$year';
    return key.isEmpty ? 'ref' : key;
  }

  /// BibTeX author list: "First Author and Second Author and ...".
  static String? _authorsAnd(Work work) {
    if (work.authors.isEmpty) return null;
    final names = work.authors
        .map((a) => a.displayName)
        .where((n) => n.isNotEmpty)
        .toList();
    return names.isEmpty ? null : names.join(' and ');
  }

  /// APA author list: "Surname, F. M., & Surname, G." (best-effort).
  static String? _authorsApa(Work work) {
    final names = work.authors
        .map((a) => _apaName(a.displayName))
        .where((n) => n.isNotEmpty)
        .toList();
    if (names.isEmpty) return null;
    if (names.length == 1) return names.first;
    return '${names.sublist(0, names.length - 1).join(', ')}, & ${names.last}';
  }

  /// "First Middle Last" → "Last, F. M." (best-effort; single tokens pass
  /// through unchanged).
  static String _apaName(String displayName) {
    final parts = displayName.trim().split(RegExp(r'\s+'));
    if (parts.length < 2) return displayName.trim();
    final surname = parts.last;
    final initials = parts
        .sublist(0, parts.length - 1)
        .where((p) => p.isNotEmpty)
        .map((p) => '${p[0].toUpperCase()}.')
        .join(' ');
    return '$surname, $initials';
  }

  /// Strips a DOI URL prefix to the bare DOI ("10.1145/..."), or null.
  static String? _bareDoi(String? doi) {
    if (doi == null || doi.trim().isEmpty) return null;
    final bare = doi.trim().replaceFirst(
      RegExp(r'^https?://(dx\.)?doi\.org/', caseSensitive: false),
      '',
    );
    return bare.isEmpty ? null : bare;
  }

  /// Full DOI URL ("https://doi.org/10..."), or null.
  static String? _doiUrl(String? doi) {
    final bare = _bareDoi(doi);
    return bare == null ? null : 'https://doi.org/$bare';
  }
}

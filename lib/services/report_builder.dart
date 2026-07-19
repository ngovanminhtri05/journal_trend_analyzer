import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/models.dart';

/// Builds the dashboard PDF report (Lab 03 task 8.3).
///
/// Pure and UI-agnostic: it takes primitive summary values (never a ViewModel or
/// Firebase type) and returns the encoded PDF bytes, so it is trivially
/// unit-testable and keeps the `services` layer free of upstream dependencies.
Future<Uint8List> buildDashboardReportPdf({
  required String topic,
  required int totalPublications,
  required double averageCitations,
  int? mostActiveYear,
  String? topJournal,
  String? topAuthor,
  String? mostInfluentialTitle,
  required List<GroupByItem> years,
  String? trendLabel,
  DateTime? generatedAt,
}) async {
  final doc = pw.Document();
  final now = generatedAt ?? DateTime.now();

  // The built-in Helvetica font is ASCII-only, so keep every value ASCII-safe
  // (no em dashes) to avoid missing glyphs in the rendered PDF.
  const na = 'N/A';
  final metrics = <List<String>>[
    ['Total publications', '$totalPublications'],
    ['Average citations', averageCitations.toStringAsFixed(1)],
    ['Most active year', mostActiveYear?.toString() ?? na],
    ['Top journal', _ascii(topJournal) ?? na],
    ['Top author', _ascii(topAuthor) ?? na],
    if (trendLabel != null) ['Trend', _titleCase(trendLabel)],
  ];

  // Newest years first, capped so the table stays on one page.
  final sortedYears = [...years]
    ..sort((a, b) => b.keyDisplayName.compareTo(a.keyDisplayName));
  final yearRows = sortedYears
      .take(15)
      .map((y) => [y.keyDisplayName, '${y.count}'])
      .toList();

  doc.addPage(
    pw.MultiPage(
      pageTheme: pw.PageTheme(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
      ),
      build: (context) => [
        pw.Header(
          level: 0,
          child: pw.Text(
            'Journal Trend Analyzer - Research Report',
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
          ),
        ),
        pw.Text(
          'Topic: ${_ascii(topic) ?? na}',
          style: const pw.TextStyle(fontSize: 14),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          'Generated: ${_formatDate(now)}',
          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
        ),
        pw.SizedBox(height: 20),
        pw.Text(
          'Overview',
          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 8),
        pw.TableHelper.fromTextArray(
          headers: const ['Metric', 'Value'],
          data: metrics,
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          cellAlignment: pw.Alignment.centerLeft,
        ),
        if (mostInfluentialTitle != null) ...[
          pw.SizedBox(height: 16),
          pw.Text(
            'Most influential publication',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          pw.Text(_ascii(mostInfluentialTitle) ?? na),
        ],
        if (yearRows.isNotEmpty) ...[
          pw.SizedBox(height: 16),
          pw.Text(
            'Publications by year',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.TableHelper.fromTextArray(
            headers: const ['Year', 'Publications'],
            data: yearRows,
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
        ],
      ],
    ),
  );

  return doc.save();
}

/// Plain, isolate-sendable input for [renderRecentPapersReportPdf].
class RecentPapersReportData {
  const RecentPapersReportData({
    required this.field,
    required this.rows,
    required this.generatedAt,
  });

  final String field;

  /// One row per paper: `[title, authors, year, venue]`, already ASCII-safe.
  final List<List<String>> rows;

  final DateTime generatedAt;
}

/// Builds a "recent publications" PDF (Phase 13.2) — the Home export.
///
/// Rendering a PDF is CPU-heavy and would jank the UI if it ran on the main
/// isolate, so the rows are prepared here (cheap) and the actual render is
/// handed to a background isolate via [compute].
Future<Uint8List> buildRecentPapersReportPdf({
  required String field,
  required List<Work> works,
  DateTime? generatedAt,
}) {
  const na = 'N/A';
  final rows = works
      .take(40)
      .map(
        (w) => <String>[
          _ascii(w.title) ?? na,
          _ascii(w.authorNames) ?? na,
          w.publicationYear?.toString() ?? na,
          _ascii(w.journalName) ?? na,
        ],
      )
      .toList();

  return compute(
    renderRecentPapersReportPdf,
    RecentPapersReportData(
      field: _ascii(field) ?? na,
      rows: rows,
      generatedAt: generatedAt ?? DateTime.now(),
    ),
  );
}

/// Renders the recent-papers PDF. Top-level so it can run on a background
/// isolate via [compute] — never call this on the UI isolate directly.
Future<Uint8List> renderRecentPapersReportPdf(
  RecentPapersReportData data,
) async {
  final doc = pw.Document();
  final now = data.generatedAt;
  final rows = data.rows;
  final field = data.field;

  doc.addPage(
    pw.MultiPage(
      pageTheme: pw.PageTheme(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
      ),
      build: (context) => [
        pw.Header(
          level: 0,
          child: pw.Text(
            'Journal Trend Analyzer - Recent Publications',
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
          ),
        ),
        pw.Text(
          'Field: $field',
          style: const pw.TextStyle(fontSize: 14),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          'Generated: ${_formatDate(now)}',
          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
        ),
        pw.SizedBox(height: 20),
        if (rows.isEmpty)
          pw.Text('No recent publications found.')
        else
          pw.TableHelper.fromTextArray(
            headers: const ['Title', 'Authors', 'Year', 'Venue'],
            data: rows,
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            cellAlignment: pw.Alignment.centerLeft,
            columnWidths: {
              0: const pw.FlexColumnWidth(3),
              1: const pw.FlexColumnWidth(2),
              2: const pw.FlexColumnWidth(0.7),
              3: const pw.FlexColumnWidth(1.6),
            },
          ),
      ],
    ),
  );

  return doc.save();
}

String _titleCase(String value) =>
    value.isEmpty ? value : value[0].toUpperCase() + value.substring(1);

/// Makes a string safe for the ASCII-only built-in PDF font: non-ASCII code
/// units become '?'. Returns null for a null/empty input (so callers can fall
/// back to a placeholder).
String? _ascii(String? value) {
  if (value == null || value.isEmpty) return null;
  return String.fromCharCodes(
    value.codeUnits.map((c) => c <= 0x7e ? c : 0x3f), // 0x3f == '?'
  );
}

String _formatDate(DateTime d) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
}

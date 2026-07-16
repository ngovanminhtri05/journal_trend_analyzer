import 'dart:typed_data';

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

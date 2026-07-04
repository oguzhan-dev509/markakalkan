import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class MonitoringPdfMetric {
  const MonitoringPdfMetric({required this.label, required this.value});

  final String label;
  final String value;
}

class MonitoringPdfRow {
  const MonitoringPdfRow({required this.label, required this.value});

  final String label;
  final String value;
}

class MonitoringPdfSection {
  const MonitoringPdfSection({
    required this.title,
    this.description,
    this.rows = const <MonitoringPdfRow>[],
    this.paragraphs = const <String>[],
  });

  final String title;
  final String? description;
  final List<MonitoringPdfRow> rows;
  final List<String> paragraphs;
}

class MonitoringPdfReportData {
  const MonitoringPdfReportData({
    required this.title,
    required this.subtitle,
    required this.fileNamePrefix,
    required this.generatedAt,
    required this.metrics,
    required this.sections,
    this.scoreLabel,
    this.scoreValue,
    this.footerNote,
  });

  final String title;
  final String subtitle;
  final String fileNamePrefix;
  final DateTime generatedAt;
  final String? scoreLabel;
  final String? scoreValue;
  final List<MonitoringPdfMetric> metrics;
  final List<MonitoringPdfSection> sections;
  final String? footerNote;

  String get fileName => '${fileNamePrefix}_${_fileDate(generatedAt)}.pdf';
}

abstract final class MonitoringPdfReportService {
  static Future<void> previewAndPrint(MonitoringPdfReportData report) async {
    final bytes = await build(report);

    await Printing.layoutPdf(
      name: report.fileName,
      onLayout: (_) async => bytes,
    );
  }

  static Future<void> saveOrShare(MonitoringPdfReportData report) async {
    final bytes = await build(report);

    await Printing.sharePdf(bytes: bytes, filename: report.fileName);
  }

  static Future<Uint8List> build(MonitoringPdfReportData report) async {
    final regularFont = await PdfGoogleFonts.notoSansRegular();
    final boldFont = await PdfGoogleFonts.notoSansBold();

    final document = pw.Document(
      title: report.title,
      author: 'MarkaKalkan',
      creator: 'MarkaKalkan - Dijital Pazar \u0130zleme',
      subject: report.subtitle,
    );

    final navy = PdfColor.fromHex('#183247');
    final teal = PdfColor.fromHex('#2C8F83');
    final lightTeal = PdfColor.fromHex('#E8F6F4');
    final background = PdfColor.fromHex('#F4F7F8');
    final border = PdfColor.fromHex('#DDE5E9');
    final text = PdfColor.fromHex('#37454F');
    final muted = PdfColor.fromHex('#687580');

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(34, 34, 34, 42),
        theme: pw.ThemeData.withFont(base: regularFont, bold: boldFont),
        header: (context) {
          if (context.pageNumber == 1) {
            return pw.SizedBox();
          }

          return pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 14),
            padding: const pw.EdgeInsets.only(bottom: 8),
            decoration: pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: border)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'MarkaKalkan - Dijital Pazar \u0130zleme',
                  style: pw.TextStyle(
                    color: navy,
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  report.title,
                  style: pw.TextStyle(color: muted, fontSize: 8),
                ),
              ],
            ),
          );
        },
        footer: (context) {
          return pw.Container(
            margin: const pw.EdgeInsets.only(top: 12),
            padding: const pw.EdgeInsets.only(top: 8),
            decoration: pw.BoxDecoration(
              border: pw.Border(top: pw.BorderSide(color: border)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  report.footerNote ??
                      'Bu rapor MarkaKalkan canl\u0131 operasyon '
                          'verilerinden \u00fcretilmi\u015ftir.',
                  style: pw.TextStyle(color: muted, fontSize: 7.5),
                ),
                pw.Text(
                  '${context.pageNumber} / ${context.pagesCount}',
                  style: pw.TextStyle(color: muted, fontSize: 8),
                ),
              ],
            ),
          );
        },
        build: (context) {
          return [
            pw.Container(
              padding: const pw.EdgeInsets.all(24),
              decoration: pw.BoxDecoration(
                color: navy,
                borderRadius: pw.BorderRadius.circular(14),
              ),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'MARKAKALKAN',
                          style: pw.TextStyle(
                            color: teal,
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                            letterSpacing: 1.5,
                          ),
                        ),
                        pw.SizedBox(height: 10),
                        pw.Text(
                          report.title,
                          style: pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 23,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 8),
                        pw.Text(
                          report.subtitle,
                          style: pw.TextStyle(
                            color: PdfColor.fromHex('#D9E5EA'),
                            fontSize: 10,
                            lineSpacing: 3,
                          ),
                        ),
                        pw.SizedBox(height: 13),
                        pw.Text(
                          'Rapor \u00fcretim zaman\u0131: '
                          '${_formatDateTime(report.generatedAt)}',
                          style: pw.TextStyle(
                            color: teal,
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (report.scoreValue != null)
                    pw.Container(
                      width: 122,
                      margin: const pw.EdgeInsets.only(left: 18),
                      padding: const pw.EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 17,
                      ),
                      decoration: pw.BoxDecoration(
                        color: PdfColor.fromHex('#25465A'),
                        borderRadius: pw.BorderRadius.circular(11),
                      ),
                      child: pw.Column(
                        children: [
                          pw.SizedBox(
                            width: 96,
                            height: 34,
                            child: pw.FittedBox(
                              fit: pw.BoxFit.scaleDown,
                              alignment: pw.Alignment.center,
                              child: pw.Text(
                                report.scoreValue!,
                                style: pw.TextStyle(
                                  color: teal,
                                  fontSize: 27,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            report.scoreLabel ?? '',
                            textAlign: pw.TextAlign.center,
                            style: pw.TextStyle(
                              color: PdfColor.fromHex('#D9E5EA'),
                              fontSize: 8,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            pw.SizedBox(height: 18),
            _metricGrid(
              report.metrics,
              navy: navy,
              teal: teal,
              lightTeal: lightTeal,
              border: border,
              muted: muted,
            ),
            pw.SizedBox(height: 18),
            for (final section in report.sections) ...[
              ..._sectionWidgets(
                section,
                navy: navy,
                teal: teal,
                background: background,
                border: border,
                text: text,
                muted: muted,
              ),
              pw.SizedBox(height: 14),
            ],
          ];
        },
      ),
    );

    return document.save();
  }

  static pw.Widget _metricGrid(
    List<MonitoringPdfMetric> metrics, {
    required PdfColor navy,
    required PdfColor teal,
    required PdfColor lightTeal,
    required PdfColor border,
    required PdfColor muted,
  }) {
    if (metrics.isEmpty) {
      return pw.SizedBox();
    }

    final rows = <pw.Widget>[];

    for (var index = 0; index < metrics.length; index += 3) {
      final rowMetrics = metrics.skip(index).take(3).toList();

      rows.add(
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            for (var itemIndex = 0; itemIndex < 3; itemIndex++) ...[
              pw.Expanded(
                child: itemIndex < rowMetrics.length
                    ? pw.Container(
                        padding: const pw.EdgeInsets.all(12),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.white,
                          border: pw.Border.all(color: border),
                          borderRadius: pw.BorderRadius.circular(9),
                        ),
                        child: pw.Row(
                          children: [
                            pw.Container(
                              width: 29,
                              height: 29,
                              decoration: pw.BoxDecoration(
                                color: lightTeal,
                                borderRadius: pw.BorderRadius.circular(7),
                              ),
                              child: pw.Center(
                                child: pw.Container(
                                  width: 9,
                                  height: 9,
                                  decoration: pw.BoxDecoration(
                                    color: teal,
                                    shape: pw.BoxShape.circle,
                                  ),
                                ),
                              ),
                            ),
                            pw.SizedBox(width: 9),
                            pw.Expanded(
                              child: pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  pw.Text(
                                    rowMetrics[itemIndex].value,
                                    style: pw.TextStyle(
                                      color: navy,
                                      fontSize: 17,
                                      fontWeight: pw.FontWeight.bold,
                                    ),
                                  ),
                                  pw.SizedBox(height: 2),
                                  pw.Text(
                                    rowMetrics[itemIndex].label,
                                    style: pw.TextStyle(
                                      color: muted,
                                      fontSize: 7.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )
                    : pw.SizedBox(),
              ),
              if (itemIndex < 2) pw.SizedBox(width: 8),
            ],
          ],
        ),
      );

      if (index + 3 < metrics.length) {
        rows.add(pw.SizedBox(height: 8));
      }
    }

    return pw.Column(children: rows);
  }

  static List<pw.Widget> _sectionWidgets(
    MonitoringPdfSection section, {
    required PdfColor navy,
    required PdfColor teal,
    required PdfColor background,
    required PdfColor border,
    required PdfColor text,
    required PdfColor muted,
  }) {
    final widgets = <pw.Widget>[
      pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: pw.BoxDecoration(
          color: PdfColors.white,
          border: pw.Border.all(color: border),
          borderRadius: pw.BorderRadius.circular(9),
        ),
        child: pw.Row(
          children: [
            pw.Container(
              width: 5,
              height: 19,
              decoration: pw.BoxDecoration(
                color: teal,
                borderRadius: pw.BorderRadius.circular(3),
              ),
            ),
            pw.SizedBox(width: 9),
            pw.Expanded(
              child: pw.Text(
                section.title,
                style: pw.TextStyle(
                  color: navy,
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    ];

    final description = section.description?.trim();

    if (description != null && description.isNotEmpty) {
      widgets.add(
        pw.Container(
          width: double.infinity,
          margin: const pw.EdgeInsets.only(top: 4),
          padding: const pw.EdgeInsets.all(11),
          decoration: pw.BoxDecoration(
            color: background,
            border: pw.Border.all(color: border),
            borderRadius: pw.BorderRadius.circular(7),
          ),
          child: pw.Text(
            description,
            style: pw.TextStyle(color: muted, fontSize: 8.5, lineSpacing: 2),
          ),
        ),
      );
    }

    for (var index = 0; index < section.rows.length; index++) {
      final row = section.rows[index];

      widgets.add(
        pw.Container(
          width: double.infinity,
          margin: const pw.EdgeInsets.only(top: 4),
          padding: const pw.EdgeInsets.symmetric(horizontal: 13, vertical: 8),
          decoration: pw.BoxDecoration(
            color: index.isEven ? background : PdfColors.white,
            border: pw.Border.all(color: border),
            borderRadius: pw.BorderRadius.circular(6),
          ),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.SizedBox(
                width: 165,
                child: pw.Text(
                  row.label,
                  style: pw.TextStyle(
                    color: muted,
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.Expanded(
                child: pw.Text(
                  row.value,
                  style: pw.TextStyle(
                    color: text,
                    fontSize: 8.5,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    for (var index = 0; index < section.paragraphs.length; index++) {
      final paragraph = section.paragraphs[index];

      widgets.add(
        pw.Container(
          width: double.infinity,
          margin: const pw.EdgeInsets.only(top: 4),
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            color: background,
            border: pw.Border.all(color: border),
            borderRadius: pw.BorderRadius.circular(7),
          ),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(
                width: 18,
                height: 18,
                decoration: pw.BoxDecoration(
                  color: teal,
                  shape: pw.BoxShape.circle,
                ),
                child: pw.Center(
                  child: pw.Text(
                    '${index + 1}',
                    style: pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 7,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
              ),
              pw.SizedBox(width: 9),
              pw.Expanded(
                child: pw.Text(
                  paragraph,
                  style: pw.TextStyle(
                    color: text,
                    fontSize: 8.5,
                    lineSpacing: 2,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (section.rows.isEmpty && section.paragraphs.isEmpty) {
      widgets.add(
        pw.Container(
          width: double.infinity,
          height: 8,
          margin: const pw.EdgeInsets.only(top: 4),
          decoration: pw.BoxDecoration(
            color: PdfColors.white,
            border: pw.Border.all(color: border),
            borderRadius: pw.BorderRadius.circular(6),
          ),
        ),
      );
    }

    return widgets;
  }
}

String _fileDate(DateTime value) {
  final local = value.toLocal();

  String twoDigits(int number) => number.toString().padLeft(2, '0');

  return '${local.year}'
      '${twoDigits(local.month)}'
      '${twoDigits(local.day)}_'
      '${twoDigits(local.hour)}'
      '${twoDigits(local.minute)}';
}

String _formatDateTime(DateTime value) {
  final local = value.toLocal();

  String twoDigits(int number) => number.toString().padLeft(2, '0');

  return '${twoDigits(local.day)}.${twoDigits(local.month)}.${local.year} '
      '${twoDigits(local.hour)}:${twoDigits(local.minute)}';
}

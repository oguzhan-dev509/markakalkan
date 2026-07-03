import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class DigitalBrandIntelligencePdfFinding {
  const DigitalBrandIntelligencePdfFinding({
    required this.title,
    required this.platform,
    required this.seller,
    required this.riskLabel,
    required this.reviewLabel,
    required this.location,
    required this.priceLabel,
    required this.evidenceCompletionPercent,
    required this.interventionScore,
    required this.fieldRecommended,
    required this.violations,
    required this.taskName,
  });

  final String title;
  final String platform;
  final String seller;
  final String riskLabel;
  final String reviewLabel;
  final String location;
  final String priceLabel;
  final int evidenceCompletionPercent;
  final int interventionScore;
  final bool fieldRecommended;
  final List<String> violations;
  final String taskName;
}

class DigitalBrandIntelligencePdfPriceSummary {
  const DigitalBrandIntelligencePdfPriceSummary({
    required this.currency,
    required this.recordCount,
    required this.averagePrice,
    required this.minimumPrice,
    required this.maximumPrice,
    required this.upTo500Count,
    required this.from500To1500Count,
    required this.from1500To3000Count,
    required this.above3000Count,
  });

  final String currency;
  final int recordCount;
  final double averagePrice;
  final double minimumPrice;
  final double maximumPrice;
  final int upTo500Count;
  final int from500To1500Count;
  final int from1500To3000Count;
  final int above3000Count;
}

class DigitalBrandIntelligencePdfData {
  const DigitalBrandIntelligencePdfData({
    required this.generatedAt,
    required this.totalAvailableFindings,
    required this.filteredFindingCount,
    required this.activeFilters,
    required this.taskCount,
    required this.processedPageCount,
    required this.highRiskCount,
    required this.mediumRiskCount,
    required this.lowRiskCount,
    required this.unknownRiskCount,
    required this.platformCount,
    required this.uniqueSellerCount,
    required this.cityCount,
    required this.fieldRecommendedCount,
    required this.pendingReviewCount,
    required this.confirmedCount,
    required this.archivedEvidenceCount,
    required this.completeEvidenceCount,
    required this.averageEvidenceCompletionPercent,
    required this.averageInterventionScore,
    required this.highestInterventionScore,
    required this.totalViolationSignals,
    required this.sourceDistribution,
    required this.countryDistribution,
    required this.cityDistribution,
    required this.violationDistribution,
    required this.priceSummaries,
    required this.priorityFindings,
  });

  final DateTime generatedAt;
  final int totalAvailableFindings;
  final int filteredFindingCount;
  final List<String> activeFilters;
  final int taskCount;
  final int processedPageCount;
  final int highRiskCount;
  final int mediumRiskCount;
  final int lowRiskCount;
  final int unknownRiskCount;
  final int platformCount;
  final int uniqueSellerCount;
  final int cityCount;
  final int fieldRecommendedCount;
  final int pendingReviewCount;
  final int confirmedCount;
  final int archivedEvidenceCount;
  final int completeEvidenceCount;
  final int averageEvidenceCompletionPercent;
  final int averageInterventionScore;
  final int highestInterventionScore;
  final int totalViolationSignals;
  final Map<String, int> sourceDistribution;
  final Map<String, int> countryDistribution;
  final Map<String, int> cityDistribution;
  final Map<String, int> violationDistribution;
  final List<DigitalBrandIntelligencePdfPriceSummary> priceSummaries;
  final List<DigitalBrandIntelligencePdfFinding> priorityFindings;
}

class DigitalBrandIntelligencePdfService {
  const DigitalBrandIntelligencePdfService();

  String _twoDigits(int value) => value.toString().padLeft(2, '0');

  String _fileDate(DateTime value) {
    return '${value.year}'
        '${_twoDigits(value.month)}'
        '${_twoDigits(value.day)}_'
        '${_twoDigits(value.hour)}'
        '${_twoDigits(value.minute)}';
  }

  String _displayDate(DateTime value) {
    return '${_twoDigits(value.day)}.'
        '${_twoDigits(value.month)}.'
        '${value.year} '
        '${_twoDigits(value.hour)}:'
        '${_twoDigits(value.minute)}';
  }

  Future<void> export(DigitalBrandIntelligencePdfData data) async {
    final regularFont = await PdfGoogleFonts.notoSansRegular();
    final boldFont = await PdfGoogleFonts.notoSansBold();

    final document = pw.Document(
      title: 'Türkiye Dijital Marka İhlali Görünüm Raporu',
      author: 'MarkaKalkan',
      creator: 'MarkaKalkan Dijital Dedektif',
    );

    final regularStyle = pw.TextStyle(
      font: regularFont,
      fontSize: 9,
      color: PdfColors.blueGrey900,
    );

    final boldStyle = pw.TextStyle(
      font: boldFont,
      fontSize: 9,
      color: PdfColors.blueGrey900,
    );

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(34, 34, 34, 42),
        theme: pw.ThemeData.withFont(base: regularFont, bold: boldFont),
        footer: (context) => pw.Container(
          padding: const pw.EdgeInsets.only(top: 6),
          decoration: const pw.BoxDecoration(
            border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Oluşturulma: ${_displayDate(data.generatedAt)}',
                style: pw.TextStyle(
                  font: regularFont,
                  fontSize: 7,
                  color: PdfColors.grey600,
                ),
              ),
              pw.Text(
                'Sayfa ${context.pageNumber} / ${context.pagesCount}',
                style: pw.TextStyle(
                  font: regularFont,
                  fontSize: 7,
                  color: PdfColors.grey600,
                ),
              ),
            ],
          ),
        ),
        build: (context) => [
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(18),
            decoration: pw.BoxDecoration(
              color: PdfColors.blueGrey900,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'MARKAKALKAN',
                  style: pw.TextStyle(
                    font: boldFont,
                    fontSize: 11,
                    color: PdfColors.teal200,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  'Türkiye Dijital Marka İhlali Görünüm Raporu',
                  style: pw.TextStyle(
                    font: boldFont,
                    fontSize: 21,
                    color: PdfColors.white,
                  ),
                ),
                pw.SizedBox(height: 7),
                pw.Text(
                  '${data.filteredFindingCount} / '
                  '${data.totalAvailableFindings} bulgu',
                  style: pw.TextStyle(
                    font: boldFont,
                    fontSize: 10,
                    color: PdfColors.white,
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 16),
          pw.Text(
            'PDF servis bağlantı testi',
            style: pw.TextStyle(font: boldFont, fontSize: 15),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            'Bu ilk sürüm veri modelini ve PDF üretim altyapısını '
            'doğrulamak için oluşturulmuştur.',
            style: regularStyle,
          ),
          pw.SizedBox(height: 12),
          pw.Text('Aktif filtreler', style: boldStyle),
          pw.SizedBox(height: 5),
          ...data.activeFilters.map(
            (filter) => pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 3),
              child: pw.Text('• $filter', style: regularStyle),
            ),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(
      name: 'markakalkan_dijital_ihlaller_${_fileDate(data.generatedAt)}.pdf',
      onLayout: (_) async => document.save(),
    );
  }
}

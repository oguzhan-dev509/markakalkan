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
      fontSize: 8.5,
      color: PdfColors.blueGrey900,
    );

    final mutedStyle = pw.TextStyle(
      font: regularFont,
      fontSize: 7.5,
      color: PdfColors.blueGrey600,
    );

    final boldStyle = pw.TextStyle(
      font: boldFont,
      fontSize: 8.5,
      color: PdfColors.blueGrey900,
    );

    pw.Widget sectionTitle(String title, {String? description}) {
      return pw.Padding(
        padding: const pw.EdgeInsets.only(top: 15, bottom: 7),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              title,
              style: pw.TextStyle(
                font: boldFont,
                fontSize: 14,
                color: PdfColors.blueGrey900,
              ),
            ),
            if (description != null) ...[
              pw.SizedBox(height: 2),
              pw.Text(description, style: mutedStyle),
            ],
          ],
        ),
      );
    }

    pw.Widget metricCard(String label, String value) {
      return pw.Container(
        width: 118,
        padding: const pw.EdgeInsets.all(9),
        decoration: pw.BoxDecoration(
          color: PdfColors.grey100,
          border: pw.Border.all(color: PdfColors.grey300),
          borderRadius: pw.BorderRadius.circular(5),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              value,
              style: pw.TextStyle(
                font: boldFont,
                fontSize: 15,
                color: PdfColors.teal700,
              ),
            ),
            pw.SizedBox(height: 3),
            pw.Text(label, style: regularStyle),
          ],
        ),
      );
    }

    pw.Widget distributionCard(
      String title,
      Map<String, int> values, {
      int limit = 10,
    }) {
      final entries = values.entries.take(limit).toList();

      return pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey300),
          borderRadius: pw.BorderRadius.circular(5),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(title, style: boldStyle),
            pw.SizedBox(height: 7),
            if (entries.isEmpty)
              pw.Text('Kayıt bulunmuyor.', style: mutedStyle)
            else
              ...entries.map(
                (entry) => pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 4),
                  child: pw.Row(
                    children: [
                      pw.Expanded(
                        child: pw.Text(entry.key, style: regularStyle),
                      ),
                      pw.Text('${entry.value}', style: boldStyle),
                    ],
                  ),
                ),
              ),
          ],
        ),
      );
    }

    pw.Widget filterBox() {
      return pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          color: PdfColors.teal50,
          border: pw.Border.all(color: PdfColors.teal100),
          borderRadius: pw.BorderRadius.circular(5),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: data.activeFilters
              .map(
                (filter) => pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 3),
                  child: pw.Text('• $filter', style: regularStyle),
                ),
              )
              .toList(),
        ),
      );
    }

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
            padding: const pw.EdgeInsets.only(bottom: 6),
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(color: PdfColors.grey300),
              ),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'MarkaKalkan Dijital Dedektif',
                  style: pw.TextStyle(
                    font: boldFont,
                    fontSize: 7.5,
                    color: PdfColors.blueGrey700,
                  ),
                ),
                pw.Text(
                  'Türkiye Dijital Marka İhlali Görünüm Raporu',
                  style: pw.TextStyle(
                    font: regularFont,
                    fontSize: 7.5,
                    color: PdfColors.blueGrey700,
                  ),
                ),
              ],
            ),
          );
        },
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
                pw.SizedBox(height: 6),
                pw.Text(
                  'Dijital araştırmaların risk, coğrafya, delil ve '
                  'müdahale önceliği görünümü.',
                  style: pw.TextStyle(
                    font: regularFont,
                    fontSize: 9,
                    color: PdfColors.grey200,
                  ),
                ),
                pw.SizedBox(height: 11),
                pw.Text(
                  '${data.filteredFindingCount} / '
                  '${data.totalAvailableFindings} bulgu rapora dâhil edildi.',
                  style: pw.TextStyle(
                    font: boldFont,
                    fontSize: 9,
                    color: PdfColors.white,
                  ),
                ),
              ],
            ),
          ),

          sectionTitle('Uygulanan Filtreler'),
          filterBox(),

          sectionTitle(
            'Yönetici Özeti',
            description:
                'Filtrelenmiş dijital bulgular üzerinden hesaplanan '
                'operasyonel göstergeler.',
          ),
          pw.Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              metricCard('Araştırma görevi', '${data.taskCount}'),
              metricCard('İşlenen sayfa', '${data.processedPageCount}'),
              metricCard('Toplam bulgu', '${data.filteredFindingCount}'),
              metricCard('Yüksek risk', '${data.highRiskCount}'),
              metricCard('Platform', '${data.platformCount}'),
              metricCard('Benzersiz satıcı', '${data.uniqueSellerCount}'),
              metricCard('Şehir', '${data.cityCount}'),
              metricCard('Saha önerisi', '${data.fieldRecommendedCount}'),
              metricCard('İnceleme bekleyen', '${data.pendingReviewCount}'),
              metricCard('Doğrulanan', '${data.confirmedCount}'),
              metricCard(
                'Ortalama delil',
                '%${data.averageEvidenceCompletionPercent}',
              ),
              metricCard(
                'Ortalama skor',
                '${data.averageInterventionScore}/100',
              ),
            ],
          ),

          sectionTitle('Risk Dağılımı'),
          pw.Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              metricCard('Yüksek risk', '${data.highRiskCount}'),
              metricCard('Orta risk', '${data.mediumRiskCount}'),
              metricCard('Düşük risk', '${data.lowRiskCount}'),
              metricCard('İnceleniyor', '${data.unknownRiskCount}'),
            ],
          ),

          sectionTitle('Kaynak ve Coğrafya Analizi'),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: distributionCard('Platformlar', data.sourceDistribution),
              ),
              pw.SizedBox(width: 8),
              pw.Expanded(
                child: distributionCard('Ülkeler', data.countryDistribution),
              ),
              pw.SizedBox(width: 8),
              pw.Expanded(
                child: distributionCard('Şehirler', data.cityDistribution),
              ),
            ],
          ),

          sectionTitle(
            'İhlâl Türleri',
            description:
                'Bulgularda tespit edilen ihlâl göstergelerinin dağılımı.',
          ),
          distributionCard(
            'Tespit edilen ihlâl göstergeleri',
            data.violationDistribution,
            limit: 15,
          ),

          sectionTitle('Delil ve Müdahale Hazırlığı'),
          pw.Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              metricCard('Arşivlenen delil', '${data.archivedEvidenceCount}'),
              metricCard('Tam delil paketi', '${data.completeEvidenceCount}'),
              metricCard(
                'Delil tamamlama',
                '%${data.averageEvidenceCompletionPercent}',
              ),
              metricCard(
                'Ortalama skor',
                '${data.averageInterventionScore}/100',
              ),
              metricCard(
                'En yüksek skor',
                '${data.highestInterventionScore}/100',
              ),
              metricCard('İhlâl sinyali', '${data.totalViolationSignals}'),
            ],
          ),

          sectionTitle('Fiyat Analizi'),
          if (data.priceSummaries.isEmpty)
            pw.Text('Fiyat kaydı bulunmuyor.', style: mutedStyle)
          else
            ...data.priceSummaries.map(
              (summary) => pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 8),
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: pw.BorderRadius.circular(5),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      '${summary.currency} · '
                      '${summary.recordCount} fiyat kaydı',
                      style: boldStyle,
                    ),
                    pw.SizedBox(height: 5),
                    pw.Text(
                      'Ortalama: '
                      '${summary.averagePrice.toStringAsFixed(2)} '
                      '${summary.currency}  |  '
                      'En düşük: '
                      '${summary.minimumPrice.toStringAsFixed(2)} '
                      '${summary.currency}  |  '
                      'En yüksek: '
                      '${summary.maximumPrice.toStringAsFixed(2)} '
                      '${summary.currency}',
                      style: regularStyle,
                    ),
                    if (summary.currency == 'TRY') ...[
                      pw.SizedBox(height: 4),
                      pw.Text(
                        '0–499 TL: ${summary.upTo500Count}  |  '
                        '500–1499 TL: ${summary.from500To1500Count}  |  '
                        '1500–2999 TL: ${summary.from1500To3000Count}  |  '
                        '3000 TL ve üzeri: ${summary.above3000Count}',
                        style: mutedStyle,
                      ),
                    ],
                  ],
                ),
              ),
            ),

          sectionTitle(
            'Müdahale Öncelikli Bulgular',
            description:
                'Yüksek risk veya saha incelemesi önerisi taşıyan kayıtlar.',
          ),
          if (data.priorityFindings.isEmpty)
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(5),
              ),
              child: pw.Text(
                'Aktif filtrelere uygun öncelikli bulgu bulunmuyor.',
                style: regularStyle,
              ),
            )
          else
            ...data.priorityFindings.asMap().entries.map((entry) {
              final finding = entry.value;

              return pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 8),
                padding: const pw.EdgeInsets.all(11),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: pw.BorderRadius.circular(5),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Container(
                          width: 22,
                          height: 22,
                          alignment: pw.Alignment.center,
                          decoration: const pw.BoxDecoration(
                            color: PdfColors.teal700,
                            shape: pw.BoxShape.circle,
                          ),
                          child: pw.Text(
                            '${entry.key + 1}',
                            style: pw.TextStyle(
                              font: boldFont,
                              fontSize: 8,
                              color: PdfColors.white,
                            ),
                          ),
                        ),
                        pw.SizedBox(width: 8),
                        pw.Expanded(
                          child: pw.Text(
                            finding.title,
                            style: pw.TextStyle(
                              font: boldFont,
                              fontSize: 10,
                              color: PdfColors.blueGrey900,
                            ),
                          ),
                        ),
                        pw.Text(
                          '${finding.interventionScore}/100',
                          style: pw.TextStyle(
                            font: boldFont,
                            fontSize: 10,
                            color: PdfColors.teal700,
                          ),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 7),
                    pw.Text(
                      'Platform: ${finding.platform}  |  '
                      'Satıcı: ${finding.seller}',
                      style: regularStyle,
                    ),
                    pw.Text(
                      'Risk: ${finding.riskLabel}  |  '
                      'İnceleme: ${finding.reviewLabel}',
                      style: regularStyle,
                    ),
                    pw.Text(
                      'Konum: ${finding.location}  |  '
                      'Fiyat: ${finding.priceLabel}',
                      style: regularStyle,
                    ),
                    pw.Text(
                      'Delil tamamlama: '
                      '%${finding.evidenceCompletionPercent}  |  '
                      'Saha önerisi: '
                      '${finding.fieldRecommended ? 'Evet' : 'Hayır'}',
                      style: regularStyle,
                    ),
                    if (finding.violations.isNotEmpty)
                      pw.Text(
                        'İhlâl göstergeleri: '
                        '${finding.violations.join(', ')}',
                        style: regularStyle,
                      ),
                    pw.Text('Görev: ${finding.taskName}', style: mutedStyle),
                  ],
                ),
              );
            }),
        ],
      ),
    );

    await Printing.layoutPdf(
      name: 'markakalkan_dijital_ihlaller_${_fileDate(data.generatedAt)}.pdf',
      onLayout: (_) async => document.save(),
    );
  }
}

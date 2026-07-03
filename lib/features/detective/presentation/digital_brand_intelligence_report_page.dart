import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:markakalkan/core/theme/markakalkan_theme.dart';
import 'package:markakalkan/features/detective/presentation/digital_detective_findings_page.dart';

class DigitalBrandIntelligenceReportPage extends StatefulWidget {
  const DigitalBrandIntelligenceReportPage({super.key});

  @override
  State<DigitalBrandIntelligenceReportPage> createState() =>
      _DigitalBrandIntelligenceReportPageState();
}

class _DigitalBrandIntelligenceReportPageState
    extends State<DigitalBrandIntelligenceReportPage> {
  late Future<_BrandIntelligenceReport> _reportFuture;

  @override
  void initState() {
    super.initState();
    _reportFuture = _loadReport();
  }

  Future<_BrandIntelligenceReport> _loadReport() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw StateError(
        'Marka istihbarat raporunu görüntülemek için giriş yapılmalıdır.',
      );
    }

    final tasksSnapshot = await FirebaseFirestore.instance
        .collection('brands')
        .doc(user.uid)
        .collection('digitalDetectiveTasks')
        .get();

    final findings = <_ReportFinding>[];
    var processedPageCount = 0;

    for (final taskDocument in tasksSnapshot.docs) {
      final taskData = taskDocument.data();

      final processedCount = taskData['processedCount'];
      if (processedCount is num) {
        processedPageCount += processedCount.toInt();
      }

      final findingsSnapshot = await taskDocument.reference
          .collection('findings')
          .get();

      for (final findingDocument in findingsSnapshot.docs) {
        findings.add(
          _ReportFinding(
            id: findingDocument.id,
            taskId: taskDocument.id,
            taskName:
                taskData['taskName']?.toString() ?? 'Dijital Dedektif Görevi',
            data: findingDocument.data(),
          ),
        );
      }
    }

    return _BrandIntelligenceReport.fromData(
      taskCount: tasksSnapshot.docs.length,
      processedPageCount: processedPageCount,
      findings: findings,
    );
  }

  void _refresh() {
    setState(() {
      _reportFuture = _loadReport();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MarkaKalkanTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text(
          'Türkiye Dijital Marka İhlali Görünüm Raporu',
          style: TextStyle(
            color: MarkaKalkanTheme.navy,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: IconButton(
              tooltip: 'Raporu yenile',
              onPressed: _refresh,
              icon: const Icon(Icons.refresh),
            ),
          ),
        ],
      ),
      body: FutureBuilder<_BrandIntelligenceReport>(
        future: _reportFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _ReportMessage(
              icon: Icons.error_outline,
              title: 'Rapor oluşturulamadı',
              description: snapshot.error.toString(),
              action: FilledButton.icon(
                onPressed: _refresh,
                icon: const Icon(Icons.refresh),
                label: const Text('Tekrar Dene'),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final report = snapshot.data!;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1280),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _ReportHeader(report: report),
                    const SizedBox(height: 24),
                    _SectionTitle(
                      title: 'Yönetici Özeti',
                      description:
                          'Dijital araştırmaların kapsamı, risk seviyesi ve '
                          'operasyonel durumunun genel görünümü.',
                    ),
                    const SizedBox(height: 14),
                    _MetricGrid(report: report),
                    const SizedBox(height: 28),
                    _SectionTitle(
                      title: 'Risk ve İhlal Analizi',
                      description:
                          'Bulguların risk seviyelerine ve tespit edilen '
                          'ihlal göstergelerine göre dağılımı.',
                    ),
                    const SizedBox(height: 14),
                    _ResponsiveTwoColumn(
                      left: _DistributionCard(
                        title: 'Risk Dağılımı',
                        icon: Icons.warning_amber_rounded,
                        entries: [
                          _DistributionEntry(
                            label: 'Yüksek risk',
                            value: report.highRiskCount,
                            total: report.totalFindings,
                          ),
                          _DistributionEntry(
                            label: 'Orta risk',
                            value: report.mediumRiskCount,
                            total: report.totalFindings,
                          ),
                          _DistributionEntry(
                            label: 'Düşük risk',
                            value: report.lowRiskCount,
                            total: report.totalFindings,
                          ),
                          _DistributionEntry(
                            label: 'İnceleniyor',
                            value: report.unknownRiskCount,
                            total: report.totalFindings,
                          ),
                        ],
                      ),
                      right: _DistributionCard(
                        title: 'En Sık Görülen İhlal Türleri',
                        icon: Icons.gavel_outlined,
                        entries: report.violationDistribution.entries
                            .take(8)
                            .map(
                              (entry) => _DistributionEntry(
                                label: _violationLabel(entry.key),
                                value: entry.value,
                                total: report.totalViolationSignals,
                              ),
                            )
                            .toList(),
                      ),
                    ),
                    const SizedBox(height: 28),
                    _SectionTitle(
                      title: 'Kaynak ve Coğrafya Analizi',
                      description:
                          'Şüpheli kayıtların platform, ülke ve şehir '
                          'yoğunluklarına göre görünümü.',
                    ),
                    const SizedBox(height: 14),
                    _ResponsiveTwoColumn(
                      left: _DistributionCard(
                        title: 'Kaynaklara Göre Dağılım',
                        icon: Icons.public_outlined,
                        entries: report.sourceDistribution.entries
                            .take(8)
                            .map(
                              (entry) => _DistributionEntry(
                                label: entry.key,
                                value: entry.value,
                                total: report.totalFindings,
                              ),
                            )
                            .toList(),
                      ),
                      right: _DistributionCard(
                        title: 'Şehir Yoğunluğu',
                        icon: Icons.location_city_outlined,
                        entries: report.cityDistribution.entries
                            .take(8)
                            .map(
                              (entry) => _DistributionEntry(
                                label: entry.key,
                                value: entry.value,
                                total: report.totalFindings,
                              ),
                            )
                            .toList(),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _ResponsiveTwoColumn(
                      left: _DistributionCard(
                        title: 'Ülkelere Göre Dağılım',
                        icon: Icons.flag_outlined,
                        entries: report.countryDistribution.entries
                            .take(8)
                            .map(
                              (entry) => _DistributionEntry(
                                label: entry.key,
                                value: entry.value,
                                total: report.totalFindings,
                              ),
                            )
                            .toList(),
                      ),
                      right: _PriceAnalysisCard(
                        summaries: report.priceSummaries,
                      ),
                    ),
                    const SizedBox(height: 28),
                    _SectionTitle(
                      title: 'Delil ve İnceleme Durumu',
                      description:
                          'Uzman doğrulaması, saha incelemesi ve delil '
                          'arşivleme süreçlerinin mevcut durumu.',
                    ),
                    const SizedBox(height: 14),
                    _StatusGrid(report: report),
                    const SizedBox(height: 18),
                    _ResponsiveTwoColumn(
                      left: _EvidenceCompletionCard(report: report),
                      right: _InterventionScoreCard(report: report),
                    ),
                    const SizedBox(height: 28),
                    _SectionTitle(
                      title: 'Müdahale Öncelik Listesi',
                      description:
                          'Yüksek riskli veya saha incelemesi önerilmiş '
                          'bulgular önceliklendirilmiştir.',
                    ),
                    const SizedBox(height: 14),
                    _PriorityFindingsCard(findings: report.priorityFindings),
                    const SizedBox(height: 28),
                    const _NetworkIntelligenceNotice(),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

bool _hasEvidenceText(dynamic value) {
  return value?.toString().trim().isNotEmpty == true;
}

bool _hasValidHttpUrl(dynamic value) {
  final uri = Uri.tryParse(value?.toString().trim() ?? '');

  return uri != null &&
      (uri.scheme == 'http' || uri.scheme == 'https') &&
      uri.host.isNotEmpty;
}

bool _hasCapturedAt(dynamic value) {
  if (value is Timestamp || value is DateTime) {
    return true;
  }

  return _hasEvidenceText(value);
}

bool _isArchivedEvidence(Map<String, dynamic> data) {
  final status = data['archiveStatus']?.toString().trim().toLowerCase() ?? '';

  return status == 'archived' || status == 'completed';
}

bool _isConfirmedFinding(Map<String, dynamic> data) {
  final status = data['reviewStatus']?.toString().trim().toLowerCase() ?? '';

  return status == 'confirmed' || status == 'approved';
}

int _findingViolationCount(Map<String, dynamic> data) {
  final violations = data['violationIds'];

  if (violations is! List) {
    return 0;
  }

  return violations.whereType<String>().where((value) {
    return value.trim().isNotEmpty;
  }).length;
}

int _evidenceCompletionPoints(Map<String, dynamic> data) {
  var completed = 0;

  if (_hasValidHttpUrl(data['sourceUrl'])) {
    completed++;
  }

  if (_hasEvidenceText(data['pageTitle'])) {
    completed++;
  }

  if (_hasCapturedAt(data['capturedAt'])) {
    completed++;
  }

  if (_hasValidHttpUrl(data['screenshotUrl'])) {
    completed++;
  }

  if (_hasEvidenceText(data['contentHash'])) {
    completed++;
  }

  if (_isArchivedEvidence(data)) {
    completed++;
  }

  return completed;
}

int _evidenceCompletionPercent(Map<String, dynamic> data) {
  return ((_evidenceCompletionPoints(data) / 6) * 100).round();
}

int _interventionScore(Map<String, dynamic> data) {
  var score = 0;

  if (_isHighRisk(data)) {
    score += 35;
  }

  if (data['fieldRecommended'] == true) {
    score += 20;
  }

  if (_isConfirmedFinding(data)) {
    score += 20;
  }

  if (_isArchivedEvidence(data)) {
    score += 15;
  }

  final violationScore = _findingViolationCount(data) * 2;
  score += violationScore > 10 ? 10 : violationScore;

  return score.clamp(0, 100);
}

class _BrandIntelligenceReport {
  const _BrandIntelligenceReport({
    required this.taskCount,
    required this.processedPageCount,
    required this.totalFindings,
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
    required this.priceRecordCount,
    required this.totalViolationSignals,
    required this.sourceDistribution,
    required this.countryDistribution,
    required this.cityDistribution,
    required this.violationDistribution,
    required this.priceSummaries,
    required this.priorityFindings,
  });

  factory _BrandIntelligenceReport.fromData({
    required int taskCount,
    required int processedPageCount,
    required List<_ReportFinding> findings,
  }) {
    final sourceCounts = <String, int>{};
    final countryCounts = <String, int>{};
    final cityCounts = <String, int>{};
    final violationCounts = <String, int>{};
    final pricesByCurrency = <String, List<double>>{};
    final sellers = <String>{};

    var highRiskCount = 0;
    var mediumRiskCount = 0;
    var lowRiskCount = 0;
    var unknownRiskCount = 0;
    var fieldRecommendedCount = 0;
    var pendingReviewCount = 0;
    var confirmedCount = 0;
    var archivedEvidenceCount = 0;
    var completeEvidenceCount = 0;
    var totalEvidenceCompletionPercent = 0;
    var totalInterventionScore = 0;
    var highestInterventionScore = 0;
    var priceRecordCount = 0;
    var totalViolationSignals = 0;

    for (final finding in findings) {
      final data = finding.data;
      final evidencePercent = _evidenceCompletionPercent(data);
      final interventionScore = _interventionScore(data);

      totalEvidenceCompletionPercent += evidencePercent;
      totalInterventionScore += interventionScore;

      if (evidencePercent == 100) {
        completeEvidenceCount++;
      }

      if (interventionScore > highestInterventionScore) {
        highestInterventionScore = interventionScore;
      }

      final risk = data['riskLevel']?.toString().trim().toLowerCase() ?? '';

      switch (risk) {
        case 'high':
        case 'yüksek':
          highRiskCount++;
        case 'medium':
        case 'orta':
          mediumRiskCount++;
        case 'low':
        case 'düşük':
          lowRiskCount++;
        default:
          unknownRiskCount++;
      }

      final source = data['sourcePlatform']?.toString().trim() ?? '';
      if (source.isNotEmpty) {
        sourceCounts[source] = (sourceCounts[source] ?? 0) + 1;
      }

      final country = data['country']?.toString().trim() ?? '';
      if (country.isNotEmpty) {
        countryCounts[country] = (countryCounts[country] ?? 0) + 1;
      }

      final city = data['city']?.toString().trim() ?? '';
      if (city.isNotEmpty) {
        cityCounts[city] = (cityCounts[city] ?? 0) + 1;
      }

      final seller = data['sellerName']?.toString().trim().toLowerCase() ?? '';
      if (seller.isNotEmpty) {
        sellers.add(seller);
      }

      final violations = data['violationIds'];
      if (violations is List) {
        for (final value in violations.whereType<String>()) {
          violationCounts[value] = (violationCounts[value] ?? 0) + 1;
          totalViolationSignals++;
        }
      }

      if (data['fieldRecommended'] == true) {
        fieldRecommendedCount++;
      }

      final reviewStatus =
          data['reviewStatus']?.toString().trim().toLowerCase() ?? '';

      if (reviewStatus == 'pending' ||
          reviewStatus == 'in_review' ||
          reviewStatus == 'reviewing') {
        pendingReviewCount++;
      }

      if (reviewStatus == 'confirmed' || reviewStatus == 'approved') {
        confirmedCount++;
      }

      final archiveStatus =
          data['archiveStatus']?.toString().trim().toLowerCase() ?? '';

      if (archiveStatus == 'archived' || archiveStatus == 'completed') {
        archivedEvidenceCount++;
      }

      final price = data['price'];
      if (price is num) {
        final rawCurrency =
            data['currency']?.toString().trim().toUpperCase() ?? '';
        final currency = rawCurrency.isEmpty ? 'TRY' : rawCurrency;

        pricesByCurrency
            .putIfAbsent(currency, () => <double>[])
            .add(price.toDouble());

        priceRecordCount++;
      }
    }

    final averageEvidenceCompletionPercent = findings.isEmpty
        ? 0
        : (totalEvidenceCompletionPercent / findings.length).round();

    final averageInterventionScore = findings.isEmpty
        ? 0
        : (totalInterventionScore / findings.length).round();

    final priceSummaries = pricesByCurrency.entries.map((entry) {
      final prices = [...entry.value]..sort();
      final total = prices.fold<double>(
        0,
        (totalSoFar, value) => totalSoFar + value,
      );

      return _CurrencyPriceSummary(
        currency: entry.key,
        recordCount: prices.length,
        averagePrice: prices.isEmpty ? 0 : total / prices.length,
        minimumPrice: prices.isEmpty ? 0 : prices.first,
        maximumPrice: prices.isEmpty ? 0 : prices.last,
        upTo500Count: prices.where((price) => price < 500).length,
        from500To1500Count: prices
            .where((price) => price >= 500 && price < 1500)
            .length,
        from1500To3000Count: prices
            .where((price) => price >= 1500 && price < 3000)
            .length,
        above3000Count: prices.where((price) => price >= 3000).length,
      );
    }).toList()..sort((a, b) => a.currency.compareTo(b.currency));

    final priorityFindings =
        findings.where((finding) {
          final risk =
              finding.data['riskLevel']?.toString().trim().toLowerCase() ?? '';

          return risk == 'high' ||
              risk == 'yüksek' ||
              finding.data['fieldRecommended'] == true;
        }).toList()..sort((a, b) {
          final scoreComparison = _interventionScore(
            b.data,
          ).compareTo(_interventionScore(a.data));

          if (scoreComparison != 0) {
            return scoreComparison;
          }

          return _timestampMilliseconds(
            b.data['detectedAt'],
          ).compareTo(_timestampMilliseconds(a.data['detectedAt']));
        });

    return _BrandIntelligenceReport(
      taskCount: taskCount,
      processedPageCount: processedPageCount,
      totalFindings: findings.length,
      highRiskCount: highRiskCount,
      mediumRiskCount: mediumRiskCount,
      lowRiskCount: lowRiskCount,
      unknownRiskCount: unknownRiskCount,
      platformCount: sourceCounts.length,
      uniqueSellerCount: sellers.length,
      cityCount: cityCounts.length,
      fieldRecommendedCount: fieldRecommendedCount,
      pendingReviewCount: pendingReviewCount,
      confirmedCount: confirmedCount,
      archivedEvidenceCount: archivedEvidenceCount,
      completeEvidenceCount: completeEvidenceCount,
      averageEvidenceCompletionPercent: averageEvidenceCompletionPercent,
      averageInterventionScore: averageInterventionScore,
      highestInterventionScore: highestInterventionScore,
      priceRecordCount: priceRecordCount,
      totalViolationSignals: totalViolationSignals,
      sourceDistribution: _sortMap(sourceCounts),
      countryDistribution: _sortMap(countryCounts),
      cityDistribution: _sortMap(cityCounts),
      violationDistribution: _sortMap(violationCounts),
      priceSummaries: priceSummaries,
      priorityFindings: priorityFindings.take(10).toList(),
    );
  }

  final int taskCount;
  final int processedPageCount;
  final int totalFindings;
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
  final int priceRecordCount;
  final int totalViolationSignals;
  final Map<String, int> sourceDistribution;
  final Map<String, int> countryDistribution;
  final Map<String, int> cityDistribution;
  final Map<String, int> violationDistribution;
  final List<_CurrencyPriceSummary> priceSummaries;
  final List<_ReportFinding> priorityFindings;
}

class _CurrencyPriceSummary {
  const _CurrencyPriceSummary({
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

class _ReportFinding {
  const _ReportFinding({
    required this.id,
    required this.taskId,
    required this.taskName,
    required this.data,
  });

  final String id;
  final String taskId;
  final String taskName;
  final Map<String, dynamic> data;
}

class _ReportHeader extends StatelessWidget {
  const _ReportHeader({required this.report});

  final _BrandIntelligenceReport report;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [MarkaKalkanTheme.navy, Color(0xFF183B4E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFF254D60),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.analytics_outlined,
              color: MarkaKalkanTheme.teal,
              size: 40,
            ),
          ),
          const SizedBox(width: 22),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Türkiye Dijital Marka İhlali Görünümü',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 27,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 9),
                Text(
                  '${report.taskCount} araştırma görevi ve '
                  '${report.totalFindings} dijital bulgu üzerinden '
                  'oluşturulan marka istihbarat özeti.',
                  style: const TextStyle(color: Color(0xFFD9E5EA), height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.report});

  final _BrandIntelligenceReport report;

  @override
  Widget build(BuildContext context) {
    final metrics = [
      _MetricData('Toplam Bulgu', '${report.totalFindings}', Icons.fact_check),
      _MetricData(
        'Taranan Kayıt',
        '${report.processedPageCount}',
        Icons.manage_search,
      ),
      _MetricData(
        'İncelenen Platform',
        '${report.platformCount}',
        Icons.public,
      ),
      _MetricData(
        'Şüpheli Satıcı',
        '${report.uniqueSellerCount}',
        Icons.storefront,
      ),
      _MetricData(
        'Yüksek Riskli İlan',
        '${report.highRiskCount}',
        Icons.warning_amber_rounded,
      ),
      _MetricData(
        'Şehir Yoğunluğu',
        '${report.cityCount}',
        Icons.location_city,
      ),
      _MetricData(
        'Doğrulanan Vaka',
        '${report.confirmedCount}',
        Icons.verified_outlined,
      ),
      _MetricData(
        'Fiyat Kaydı',
        '${report.priceRecordCount}',
        Icons.payments_outlined,
      ),
      _MetricData(
        'Delil Tamamlama',
        '%${report.averageEvidenceCompletionPercent}',
        Icons.fact_check_outlined,
      ),
      _MetricData(
        'Ort. Müdahale Skoru',
        '${report.averageInterventionScore}/100',
        Icons.speed_outlined,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 650
            ? 1
            : constraints.maxWidth < 1000
            ? 2
            : 4;

        const spacing = 14.0;
        final width =
            (constraints.maxWidth - ((columns - 1) * spacing)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: metrics
              .map(
                (metric) => SizedBox(
                  width: width,
                  child: _MetricCard(data: metric),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _MetricData {
  const _MetricData(this.label, this.value, this.icon);

  final String label;
  final String value;
  final IconData icon;
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.data});

  final _MetricData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: const Color(0xFFE0E7EC)),
      ),
      child: Row(
        children: [
          Container(
            width: 45,
            height: 45,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F6F4),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(data.icon, color: MarkaKalkanTheme.teal),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.value,
                  style: const TextStyle(
                    color: MarkaKalkanTheme.navy,
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  data.label,
                  style: const TextStyle(
                    color: Color(0xFF687580),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.description});

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: MarkaKalkanTheme.navy,
            fontSize: 23,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          description,
          style: const TextStyle(color: Color(0xFF687580), height: 1.45),
        ),
      ],
    );
  }
}

class _ResponsiveTwoColumn extends StatelessWidget {
  const _ResponsiveTwoColumn({required this.left, required this.right});

  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 820) {
          return Column(children: [left, const SizedBox(height: 14), right]);
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: left),
            const SizedBox(width: 14),
            Expanded(child: right),
          ],
        );
      },
    );
  }
}

class _DistributionEntry {
  const _DistributionEntry({
    required this.label,
    required this.value,
    required this.total,
  });

  final String label;
  final int value;
  final int total;
}

class _DistributionCard extends StatelessWidget {
  const _DistributionCard({
    required this.title,
    required this.icon,
    required this.entries,
  });

  final String title;
  final IconData icon;
  final List<_DistributionEntry> entries;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(21),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE0E7EC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: MarkaKalkanTheme.teal),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: MarkaKalkanTheme.navy,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (entries.isEmpty)
            const Text(
              'Bu bölüm için henüz yeterli veri oluşmadı.',
              style: TextStyle(color: Color(0xFF687580)),
            )
          else
            ...entries.map((entry) {
              final ratio = entry.total <= 0 ? 0.0 : entry.value / entry.total;

              return Padding(
                padding: const EdgeInsets.only(bottom: 15),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            entry.label,
                            style: const TextStyle(
                              color: MarkaKalkanTheme.navy,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(
                          '${entry.value}',
                          style: const TextStyle(
                            color: MarkaKalkanTheme.navy,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    LinearProgressIndicator(
                      value: ratio.clamp(0.0, 1.0),
                      minHeight: 7,
                      borderRadius: BorderRadius.circular(99),
                      backgroundColor: const Color(0xFFE9EEF1),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _PriceAnalysisCard extends StatelessWidget {
  const _PriceAnalysisCard({required this.summaries});

  final List<_CurrencyPriceSummary> summaries;

  String _formatPrice(double value, String currency) {
    return '${value.toStringAsFixed(2)} $currency';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(21),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE0E7EC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.price_check_outlined, color: MarkaKalkanTheme.teal),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Ürün ve Fiyat Dağılımı',
                  style: TextStyle(
                    color: MarkaKalkanTheme.navy,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (summaries.isEmpty)
            const Text(
              'Fiyat analizi için henüz yeterli veri oluşmadı.',
              style: TextStyle(color: Color(0xFF687580)),
            )
          else
            ...summaries.indexed.map((entry) {
              final index = entry.$1;
              final summary = entry.$2;
              final isTry = summary.currency == 'TRY';

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    summary.currency,
                    style: const TextStyle(
                      color: MarkaKalkanTheme.blue,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _PriceSummaryRow(
                    label: 'Fiyat kaydı',
                    value: '${summary.recordCount}',
                  ),
                  _PriceSummaryRow(
                    label: 'Ortalama fiyat',
                    value: _formatPrice(summary.averagePrice, summary.currency),
                  ),
                  _PriceSummaryRow(
                    label: 'En düşük fiyat',
                    value: _formatPrice(summary.minimumPrice, summary.currency),
                  ),
                  _PriceSummaryRow(
                    label: 'En yüksek fiyat',
                    value: _formatPrice(summary.maximumPrice, summary.currency),
                  ),
                  if (isTry) ...[
                    const SizedBox(height: 10),
                    const Text(
                      'Fiyat segmentleri',
                      style: TextStyle(
                        color: MarkaKalkanTheme.navy,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _PriceSummaryRow(
                      label: '0–500 TL',
                      value: '${summary.upTo500Count}',
                    ),
                    _PriceSummaryRow(
                      label: '500–1.500 TL',
                      value: '${summary.from500To1500Count}',
                    ),
                    _PriceSummaryRow(
                      label: '1.500–3.000 TL',
                      value: '${summary.from1500To3000Count}',
                    ),
                    _PriceSummaryRow(
                      label: '3.000 TL üzeri',
                      value: '${summary.above3000Count}',
                    ),
                  ],
                  if (index != summaries.length - 1)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 14),
                      child: Divider(height: 1),
                    ),
                ],
              );
            }),
        ],
      ),
    );
  }
}

class _PriceSummaryRow extends StatelessWidget {
  const _PriceSummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF687580),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: MarkaKalkanTheme.navy,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _EvidenceCompletionCard extends StatelessWidget {
  const _EvidenceCompletionCard({required this.report});

  final _BrandIntelligenceReport report;

  @override
  Widget build(BuildContext context) {
    final ratio = report.averageEvidenceCompletionPercent / 100;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE0E7EC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.fact_check_outlined, color: MarkaKalkanTheme.teal),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Delil Tamamlama Oranı',
                  style: TextStyle(
                    color: MarkaKalkanTheme.navy,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            '%${report.averageEvidenceCompletionPercent}',
            style: const TextStyle(
              color: MarkaKalkanTheme.navy,
              fontSize: 32,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: ratio.clamp(0.0, 1.0),
            minHeight: 10,
            borderRadius: BorderRadius.circular(99),
            backgroundColor: const Color(0xFFE9EEF1),
          ),
          const SizedBox(height: 16),
          Text(
            'Tam delil paketi: ${report.completeEvidenceCount} / '
            '${report.totalFindings}',
            style: const TextStyle(
              color: MarkaKalkanTheme.navy,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Kaynak bağlantısı, sayfa başlığı, yakalama tarihi, ekran '
            'görüntüsü, içerik hash’i ve arşiv durumu birlikte ölçülür.',
            style: TextStyle(color: Color(0xFF687580), height: 1.45),
          ),
        ],
      ),
    );
  }
}

class _InterventionScoreCard extends StatelessWidget {
  const _InterventionScoreCard({required this.report});

  final _BrandIntelligenceReport report;

  @override
  Widget build(BuildContext context) {
    final ratio = report.averageInterventionScore / 100;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE0E7EC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.speed_outlined, color: MarkaKalkanTheme.teal),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Müdahale Skoru',
                  style: TextStyle(
                    color: MarkaKalkanTheme.navy,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            '${report.averageInterventionScore}/100',
            style: const TextStyle(
              color: MarkaKalkanTheme.navy,
              fontSize: 32,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: ratio.clamp(0.0, 1.0),
            minHeight: 10,
            borderRadius: BorderRadius.circular(99),
            backgroundColor: const Color(0xFFE9EEF1),
          ),
          const SizedBox(height: 16),
          Text(
            'En yüksek bulgu skoru: ${report.highestInterventionScore}/100',
            style: const TextStyle(
              color: MarkaKalkanTheme.navy,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Risk seviyesi, saha önerisi, uzman doğrulaması, arşivlenmiş '
            'delil ve ihlal sinyalleri birlikte değerlendirilir.',
            style: TextStyle(color: Color(0xFF687580), height: 1.45),
          ),
        ],
      ),
    );
  }
}

class _StatusGrid extends StatelessWidget {
  const _StatusGrid({required this.report});

  final _BrandIntelligenceReport report;

  @override
  Widget build(BuildContext context) {
    final items = [
      _MetricData(
        'Saha İncelemesi Önerilen',
        '${report.fieldRecommendedCount}',
        Icons.location_searching,
      ),
      _MetricData(
        'Uzman İncelemesi Bekleyen',
        '${report.pendingReviewCount}',
        Icons.person_search_outlined,
      ),
      _MetricData(
        'Arşivlenen Delil',
        '${report.archivedEvidenceCount}',
        Icons.inventory_2_outlined,
      ),
      _MetricData(
        'Doğrulanan Vaka',
        '${report.confirmedCount}',
        Icons.verified_outlined,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 700 ? 1 : 4;
        const spacing = 14.0;
        final width =
            (constraints.maxWidth - ((columns - 1) * spacing)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: items
              .map(
                (item) => SizedBox(
                  width: width,
                  child: _MetricCard(data: item),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _InterventionScorePart {
  const _InterventionScorePart({required this.label, required this.points});

  final String label;
  final int points;
}

class _EvidenceChecklistItem {
  const _EvidenceChecklistItem({required this.label, required this.completed});

  final String label;
  final bool completed;
}

List<_InterventionScorePart> _interventionScoreParts(
  Map<String, dynamic> data,
) {
  final violationCount = _findingViolationCount(data);
  final violationPoints = (violationCount * 2).clamp(0, 10);

  return [
    _InterventionScorePart(
      label: 'Yüksek risk',
      points: _isHighRisk(data) ? 35 : 0,
    ),
    _InterventionScorePart(
      label: 'Saha incelemesi önerisi',
      points: data['fieldRecommended'] == true ? 20 : 0,
    ),
    _InterventionScorePart(
      label: 'Uzman doğrulaması',
      points: _isConfirmedFinding(data) ? 20 : 0,
    ),
    _InterventionScorePart(
      label: 'Arşivlenmiş delil',
      points: _isArchivedEvidence(data) ? 15 : 0,
    ),
    _InterventionScorePart(
      label: '$violationCount ihlal sinyali',
      points: violationPoints,
    ),
  ];
}

List<_EvidenceChecklistItem> _evidenceChecklist(Map<String, dynamic> data) {
  return [
    _EvidenceChecklistItem(
      label: 'Kaynak bağlantısı',
      completed: _hasValidHttpUrl(data['sourceUrl']),
    ),
    _EvidenceChecklistItem(
      label: 'Sayfa başlığı',
      completed: _hasEvidenceText(data['pageTitle']),
    ),
    _EvidenceChecklistItem(
      label: 'Yakalama tarihi',
      completed: _hasCapturedAt(data['capturedAt']),
    ),
    _EvidenceChecklistItem(
      label: 'Ekran görüntüsü',
      completed: _hasValidHttpUrl(data['screenshotUrl']),
    ),
    _EvidenceChecklistItem(
      label: 'İçerik hash’i',
      completed: _hasEvidenceText(data['contentHash']),
    ),
    _EvidenceChecklistItem(
      label: 'Delil arşivleme',
      completed: _isArchivedEvidence(data),
    ),
  ];
}

String _interventionReadinessLabel(int score) {
  if (score >= 85) {
    return 'Acil Müdahale';
  }

  if (score >= 70) {
    return 'Müdahaleye Hazır';
  }

  if (score >= 40) {
    return 'İnceleme Önceliği';
  }

  return 'İzleme';
}

void _showInterventionDetails(BuildContext context, Map<String, dynamic> data) {
  final score = _interventionScore(data);
  final evidencePercent = _evidenceCompletionPercent(data);
  final scoreParts = _interventionScoreParts(data);
  final checklist = _evidenceChecklist(data);

  showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.analytics_outlined, color: MarkaKalkanTheme.teal),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Skor ve Delil Ayrıntısı',
                style: TextStyle(
                  color: MarkaKalkanTheme.navy,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 620,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data['productTitle']?.toString().trim().isNotEmpty == true
                      ? data['productTitle'].toString()
                      : 'Dijital bulgu',
                  style: const TextStyle(
                    color: MarkaKalkanTheme.navy,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F7F9),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Müdahale Skoru',
                        style: TextStyle(
                          color: Color(0xFF687580),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text(
                            '$score/100',
                            style: const TextStyle(
                              color: MarkaKalkanTheme.navy,
                              fontSize: 30,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE5F3F1),
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Text(
                              _interventionReadinessLabel(score),
                              style: const TextStyle(
                                color: MarkaKalkanTheme.teal,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      LinearProgressIndicator(
                        value: (score / 100).clamp(0.0, 1.0),
                        minHeight: 9,
                        borderRadius: BorderRadius.circular(99),
                        backgroundColor: const Color(0xFFDCE5E9),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Skor Bileşenleri',
                  style: TextStyle(
                    color: MarkaKalkanTheme.navy,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                ...scoreParts.map(
                  (part) => Padding(
                    padding: const EdgeInsets.only(bottom: 9),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            part.label,
                            style: const TextStyle(
                              color: Color(0xFF4F5D68),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(
                          '+${part.points}',
                          style: TextStyle(
                            color: part.points > 0
                                ? MarkaKalkanTheme.teal
                                : const Color(0xFF98A2AA),
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 30),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Delil Kontrol Listesi',
                        style: TextStyle(
                          color: MarkaKalkanTheme.navy,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Text(
                      '%$evidencePercent',
                      style: const TextStyle(
                        color: MarkaKalkanTheme.teal,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: (evidencePercent / 100).clamp(0.0, 1.0),
                  minHeight: 9,
                  borderRadius: BorderRadius.circular(99),
                  backgroundColor: const Color(0xFFE9EEF1),
                ),
                const SizedBox(height: 16),
                ...checklist.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        Icon(
                          item.completed
                              ? Icons.check_circle_rounded
                              : Icons.cancel_rounded,
                          color: item.completed
                              ? const Color(0xFF16866F)
                              : const Color(0xFFB42318),
                          size: 21,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            item.label,
                            style: TextStyle(
                              color: item.completed
                                  ? MarkaKalkanTheme.navy
                                  : const Color(0xFF687580),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Text(
                          item.completed ? 'Tamamlandı' : 'Eksik',
                          style: TextStyle(
                            color: item.completed
                                ? const Color(0xFF16866F)
                                : const Color(0xFFB42318),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Kapat'),
          ),
        ],
      );
    },
  );
}

class _PriorityFindingsCard extends StatelessWidget {
  const _PriorityFindingsCard({required this.findings});

  final List<_ReportFinding> findings;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE0E7EC)),
      ),
      child: findings.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Müdahale önceliği taşıyan bulgu bulunmuyor.',
                style: TextStyle(color: Color(0xFF687580)),
              ),
            )
          : Column(
              children: findings.indexed.map((entry) {
                final index = entry.$1;
                final finding = entry.$2;
                final data = finding.data;

                return Column(
                  children: [
                    ListTile(
                      isThreeLine: true,
                      minVerticalPadding: 12,
                      onTap: () =>
                          DigitalDetectiveFindingsPage.showFindingDetails(
                            context,
                            findingId: finding.id,
                            data: data,
                          ),
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFFFDECEC),
                        foregroundColor: const Color(0xFFB42318),
                        child: Text('${index + 1}'),
                      ),
                      title: Text(
                        data['productTitle']?.toString() ??
                            'İsimsiz dijital bulgu',
                        style: const TextStyle(
                          color: MarkaKalkanTheme.navy,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${data['sourcePlatform'] ?? 'Kaynak belirtilmedi'} · '
                            '${data['sellerName'] ?? 'Satıcı belirtilmedi'}\n'
                            '${finding.taskName} · '
                            'Müdahale skoru: ${_interventionScore(data)}/100',
                          ),
                          const SizedBox(height: 5),
                          TextButton.icon(
                            onPressed: () =>
                                _showInterventionDetails(context, data),
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(0, 34),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            icon: const Icon(
                              Icons.analytics_outlined,
                              size: 18,
                            ),
                            label: const Text(
                              'Skor ve delil ayrıntısını gör',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _isHighRisk(data) ? 'Yüksek Risk' : 'Saha Önerisi',
                            style: TextStyle(
                              color: _isHighRisk(data)
                                  ? const Color(0xFFB42318)
                                  : MarkaKalkanTheme.blue,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.open_in_new_rounded,
                            size: 19,
                            color: MarkaKalkanTheme.blue,
                          ),
                        ],
                      ),
                    ),
                    if (index != findings.length - 1) const Divider(height: 1),
                  ],
                );
              }).toList(),
            ),
    );
  }
}

class _NetworkIntelligenceNotice extends StatelessWidget {
  const _NetworkIntelligenceNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF1F8),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD2E0EC)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.hub_outlined, color: MarkaKalkanTheme.blue),
          SizedBox(width: 14),
          Expanded(
            child: Text(
              'Satıcı ağları, tekrar eden telefon numaraları, hesaplar, '
              'alan adları ve yeniden açılan ilanlar; ilgili kimlik alanları '
              'bulgu kayıtlarına eklendikçe bu raporda otomatik olarak '
              'ilişkilendirilecektir.',
              style: TextStyle(
                color: MarkaKalkanTheme.navy,
                height: 1.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportMessage extends StatelessWidget {
  const _ReportMessage({
    required this.icon,
    required this.title,
    required this.description,
    this.action,
  });

  final IconData icon;
  final String title;
  final String description;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 620),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFE0E7EC)),
          ),
          child: Column(
            children: [
              Icon(icon, size: 58, color: MarkaKalkanTheme.teal),
              const SizedBox(height: 18),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: MarkaKalkanTheme.navy,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                description,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF687580), height: 1.5),
              ),
              if (action != null) ...[const SizedBox(height: 22), action!],
            ],
          ),
        ),
      ),
    );
  }
}

bool _isHighRisk(Map<String, dynamic> data) {
  final value = data['riskLevel']?.toString().trim().toLowerCase() ?? '';
  return value == 'high' || value == 'yüksek';
}

int _timestampMilliseconds(dynamic value) {
  if (value is Timestamp) {
    return value.millisecondsSinceEpoch;
  }

  if (value is DateTime) {
    return value.millisecondsSinceEpoch;
  }

  return 0;
}

Map<String, int> _sortMap(Map<String, int> source) {
  final entries = source.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  return Map<String, int>.fromEntries(entries);
}

String _violationLabel(String value) {
  return switch (value) {
    'counterfeit_product' => 'Sahte ürün şüphesi',
    'fake_certificate' => 'Sahte sertifika',
    'fake_label' => 'Sahte etiket',
    'parallel_import_gray_market' => 'Paralel ithalat / gri pazar',
    'unauthorized_seller' => 'Yetkisiz satıcı',
    'brand_misuse' => 'Markanın izinsiz kullanımı',
    'logo_misuse' => 'Logo veya görsel kimlik ihlali',
    'domain_abuse' => 'Alan adı ihlali',
    'fake_website' => 'Sahte internet sitesi',
    'misleading_advertising' => 'Yanıltıcı reklam',
    _ => value,
  };
}

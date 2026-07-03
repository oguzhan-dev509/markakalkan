import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:markakalkan/core/theme/markakalkan_theme.dart';

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
                    const SizedBox(height: 28),
                    _SectionTitle(
                      title: 'Delil ve İnceleme Durumu',
                      description:
                          'Uzman doğrulaması, saha incelemesi ve delil '
                          'arşivleme süreçlerinin mevcut durumu.',
                    ),
                    const SizedBox(height: 14),
                    _StatusGrid(report: report),
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
    required this.totalEstimatedValue,
    required this.totalViolationSignals,
    required this.sourceDistribution,
    required this.cityDistribution,
    required this.violationDistribution,
    required this.priorityFindings,
  });

  factory _BrandIntelligenceReport.fromData({
    required int taskCount,
    required int processedPageCount,
    required List<_ReportFinding> findings,
  }) {
    final sourceCounts = <String, int>{};
    final cityCounts = <String, int>{};
    final violationCounts = <String, int>{};
    final sellers = <String>{};

    var highRiskCount = 0;
    var mediumRiskCount = 0;
    var lowRiskCount = 0;
    var unknownRiskCount = 0;
    var fieldRecommendedCount = 0;
    var pendingReviewCount = 0;
    var confirmedCount = 0;
    var archivedEvidenceCount = 0;
    var totalEstimatedValue = 0.0;
    var totalViolationSignals = 0;

    for (final finding in findings) {
      final data = finding.data;
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
        totalEstimatedValue += price.toDouble();
      }
    }

    final priorityFindings =
        findings.where((finding) {
          final risk =
              finding.data['riskLevel']?.toString().trim().toLowerCase() ?? '';

          return risk == 'high' ||
              risk == 'yüksek' ||
              finding.data['fieldRecommended'] == true;
        }).toList()..sort((a, b) {
          final aHigh = _isHighRisk(a.data) ? 1 : 0;
          final bHigh = _isHighRisk(b.data) ? 1 : 0;

          if (aHigh != bHigh) {
            return bHigh.compareTo(aHigh);
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
      totalEstimatedValue: totalEstimatedValue,
      totalViolationSignals: totalViolationSignals,
      sourceDistribution: _sortMap(sourceCounts),
      cityDistribution: _sortMap(cityCounts),
      violationDistribution: _sortMap(violationCounts),
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
  final double totalEstimatedValue;
  final int totalViolationSignals;
  final Map<String, int> sourceDistribution;
  final Map<String, int> cityDistribution;
  final Map<String, int> violationDistribution;
  final List<_ReportFinding> priorityFindings;
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
        'Tahmini Bulgu Değeri',
        '${report.totalEstimatedValue.toStringAsFixed(2)} TRY',
        Icons.payments_outlined,
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
                      subtitle: Text(
                        '${data['sourcePlatform'] ?? 'Kaynak belirtilmedi'} · '
                        '${data['sellerName'] ?? 'Satıcı belirtilmedi'}\n'
                        '${finding.taskName}',
                      ),
                      trailing: Text(
                        _isHighRisk(data) ? 'Yüksek Risk' : 'Saha Önerisi',
                        style: TextStyle(
                          color: _isHighRisk(data)
                              ? const Color(0xFFB42318)
                              : MarkaKalkanTheme.blue,
                          fontWeight: FontWeight.w800,
                        ),
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

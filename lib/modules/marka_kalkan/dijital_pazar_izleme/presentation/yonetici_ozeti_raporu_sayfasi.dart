import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:markakalkan/core/theme/markakalkan_theme.dart';

import '../services/monitoring_pdf_report_service.dart';

import '../constants/monitoring_enums.dart';
import '../models/crawl_job_model.dart';
import '../models/monitored_page_model.dart';
import '../models/monitoring_event_model.dart';
import '../models/monitoring_signal_model.dart';
import '../models/monitoring_source_model.dart';
import '../repositories/crawl_job_repository.dart';
import '../repositories/monitored_page_repository.dart';
import '../repositories/monitoring_event_repository.dart';
import '../repositories/monitoring_signal_repository.dart';
import '../repositories/monitoring_source_repository.dart';

class YoneticiOzetiRaporuSayfasi extends StatefulWidget {
  const YoneticiOzetiRaporuSayfasi({super.key});

  @override
  State<YoneticiOzetiRaporuSayfasi> createState() =>
      _YoneticiOzetiRaporuSayfasiState();
}

class _YoneticiOzetiRaporuSayfasiState
    extends State<YoneticiOzetiRaporuSayfasi> {
  Future<_ExecutiveSummaryData>? _future;

  String? get _tenantId => FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    final tenantId = _tenantId;

    setState(() {
      _future = tenantId == null
          ? Future<_ExecutiveSummaryData>.error(
              StateError('Yönetici Özeti için oturum açılmalıdır.'),
            )
          : _loadData(tenantId);
    });
  }

  Future<_ExecutiveSummaryData> _loadData(String tenantId) async {
    final results = await Future.wait<dynamic>([
      MonitoringSourceRepository.instance(
        tenantId: tenantId,
      ).watchAll(limit: 500).first,
      MonitoredPageRepository.instance(
        tenantId: tenantId,
      ).watchAll(limit: 500).first,
      CrawlJobRepository.instance(
        tenantId: tenantId,
      ).watchAll(limit: 500).first,
      MonitoringEventRepository.instance(
        tenantId: tenantId,
      ).watchRecent(limit: 500).first,
      MonitoringSignalRepository.instance(
        tenantId: tenantId,
      ).watchRecent(limit: 500).first,
    ]);

    return _ExecutiveSummaryData(
      sources: results[0] as List<MonitoringSourceModel>,
      pages: results[1] as List<MonitoredPageModel>,
      jobs: results[2] as List<CrawlJobModel>,
      events: results[3] as List<MonitoringEventModel>,
      signals: results[4] as List<MonitoringSignalModel>,
      generatedAt: DateTime.now(),
    );
  }

  Future<void> _openExecutivePdf({required bool saveOrShare}) async {
    final future = _future;

    if (future == null) {
      return;
    }

    try {
      final data = await future;
      final report = _executivePdfData(data);

      if (saveOrShare) {
        await MonitoringPdfReportService.saveOrShare(report);
      } else {
        await MonitoringPdfReportService.previewAndPrint(report);
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('PDF oluşturulamadı: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MarkaKalkanTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text(
          'Yönetici Özeti',
          style: TextStyle(
            color: MarkaKalkanTheme.navy,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'PDF Önizle / Yazdır',
            onPressed: () => _openExecutivePdf(saveOrShare: false),
            icon: const Icon(Icons.picture_as_pdf_outlined),
          ),
          IconButton(
            tooltip: 'PDF Kaydet / Paylaş',
            onPressed: () => _openExecutivePdf(saveOrShare: true),
            icon: const Icon(Icons.download_outlined),
          ),
          IconButton(
            tooltip: 'Yenile',
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: FutureBuilder<_ExecutiveSummaryData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError || !snapshot.hasData) {
            return _ErrorState(error: snapshot.error, onRetry: _reload);
          }

          final data = snapshot.data!;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1180),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _ExecutiveHeader(data: data),
                    const SizedBox(height: 22),
                    _SummaryGrid(data: data),
                    const SizedBox(height: 22),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final narrow = constraints.maxWidth < 900;

                        final operational = _SectionCard(
                          title: 'Operasyon Durumu',
                          icon: Icons.monitor_heart_outlined,
                          child: Column(
                            children: [
                              _MetricRow(
                                label: 'Sağlıklı kaynak',
                                value: data.healthySourceCount,
                                color: const Color(0xFF2C8F83),
                              ),
                              _MetricRow(
                                label: 'Sorunlu kaynak',
                                value: data.problematicSourceCount,
                                color: const Color(0xFFC83C4E),
                              ),
                              _MetricRow(
                                label: 'Aktif izlenen sayfa',
                                value: data.activePageCount,
                                color: const Color(0xFF4B7895),
                              ),
                              _MetricRow(
                                label: 'Aktif tarama görevi',
                                value: data.activeJobCount,
                                color: const Color(0xFF2C8F83),
                              ),
                              _MetricRow(
                                label: 'Başarısızlık yaşayan sayfa',
                                value: data.failedPageCount,
                                color: const Color(0xFFDF6C2F),
                              ),
                            ],
                          ),
                        );

                        final risks = _SectionCard(
                          title: 'Risk ve Olay Görünümü',
                          icon: Icons.warning_amber_rounded,
                          child: Column(
                            children: [
                              _MetricRow(
                                label: 'Yeni izleme olayı',
                                value: data.newEventCount,
                                color: const Color(0xFF4B7895),
                              ),
                              _MetricRow(
                                label: 'Yüksek / kritik olay',
                                value: data.urgentEventCount,
                                color: const Color(0xFFDF6C2F),
                              ),
                              _MetricRow(
                                label: 'Açık risk sinyali',
                                value: data.openSignalCount,
                                color: const Color(0xFFE39A25),
                              ),
                              _MetricRow(
                                label: 'Yüksek / kritik sinyal',
                                value: data.urgentSignalCount,
                                color: const Color(0xFFC83C4E),
                              ),
                              _MetricRow(
                                label: 'İletim hatası',
                                value: data.forwardingFailureCount,
                                color: const Color(0xFF7C6A92),
                              ),
                            ],
                          ),
                        );

                        if (narrow) {
                          return Column(
                            children: [
                              operational,
                              const SizedBox(height: 16),
                              risks,
                            ],
                          );
                        }

                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: operational),
                            const SizedBox(width: 16),
                            Expanded(child: risks),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 22),
                    _ManagementAssessment(data: data),
                    const SizedBox(height: 22),
                    _PriorityActions(data: data),
                    const SizedBox(height: 22),
                    _ReportMetadata(data: data),
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

class _ExecutiveHeader extends StatelessWidget {
  const _ExecutiveHeader({required this.data});

  final _ExecutiveSummaryData data;

  @override
  Widget build(BuildContext context) {
    final score = data.operationalHealthScore;
    final color = _scoreColor(score);

    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [MarkaKalkanTheme.navy, Color(0xFF17445A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 720;

          final scoreBox = Container(
            width: 132,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: Column(
              children: [
                Text(
                  '$score',
                  style: TextStyle(
                    color: color,
                    fontSize: 37,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Operasyon Sağlık Puanı',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFFD9E5EA),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          );

          final content = Column(
            crossAxisAlignment: narrow
                ? CrossAxisAlignment.center
                : CrossAxisAlignment.start,
            children: [
              const Text(
                'Dijital Pazar Yönetici Özeti',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 9),
              const Text(
                'İzleme kapsamı, operasyon sağlığı, değişiklik olayları ve '
                'risk sinyallerinin yönetim seviyesindeki özeti.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFFD9E5EA), height: 1.5),
              ),
              const SizedBox(height: 14),
              Text(
                data.managementHeadline,
                textAlign: TextAlign.center,
                style: TextStyle(color: color, fontWeight: FontWeight.w800),
              ),
            ],
          );

          if (narrow) {
            return Column(
              children: [scoreBox, const SizedBox(height: 18), content],
            );
          }

          return Row(
            children: [
              Expanded(child: content),
              const SizedBox(width: 24),
              scoreBox,
            ],
          );
        },
      ),
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.data});

  final _ExecutiveSummaryData data;

  @override
  Widget build(BuildContext context) {
    final items = <_SummaryItem>[
      _SummaryItem(
        label: 'Kaynak',
        value: data.sources.length,
        icon: Icons.hub_outlined,
      ),
      _SummaryItem(
        label: 'İzlenen Sayfa',
        value: data.pages.length,
        icon: Icons.language_outlined,
      ),
      _SummaryItem(
        label: 'Tarama Görevi',
        value: data.jobs.length,
        icon: Icons.radar_outlined,
      ),
      _SummaryItem(
        label: 'İzleme Olayı',
        value: data.events.length,
        icon: Icons.timeline_outlined,
      ),
      _SummaryItem(
        label: 'Risk Sinyali',
        value: data.signals.length,
        icon: Icons.notification_important_outlined,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        int columns;

        if (constraints.maxWidth < 560) {
          columns = 1;
        } else if (constraints.maxWidth < 900) {
          columns = 2;
        } else {
          columns = 5;
        }

        const spacing = 12.0;

        final width =
            (constraints.maxWidth - ((columns - 1) * spacing)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: items
              .map(
                (item) => SizedBox(
                  width: width,
                  child: _SummaryCard(item: item),
                ),
              )
              .toList(growable: false),
        );
      },
    );
  }
}

class _ManagementAssessment extends StatelessWidget {
  const _ManagementAssessment({required this.data});

  final _ExecutiveSummaryData data;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Yönetim Değerlendirmesi',
      icon: Icons.summarize_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _AssessmentItem(
            title: 'Genel durum',
            text: data.generalAssessment,
            icon: Icons.assessment_outlined,
            color: _scoreColor(data.operationalHealthScore),
          ),
          const SizedBox(height: 12),
          _AssessmentItem(
            title: 'İzleme kapsamı',
            text: data.coverageAssessment,
            icon: Icons.travel_explore_outlined,
            color: const Color(0xFF4B7895),
          ),
          const SizedBox(height: 12),
          _AssessmentItem(
            title: 'Risk görünümü',
            text: data.riskAssessment,
            icon: Icons.shield_outlined,
            color: data.urgentSignalCount > 0
                ? const Color(0xFFC83C4E)
                : const Color(0xFF2C8F83),
          ),
        ],
      ),
    );
  }
}

class _PriorityActions extends StatelessWidget {
  const _PriorityActions({required this.data});

  final _ExecutiveSummaryData data;

  @override
  Widget build(BuildContext context) {
    final actions = data.priorityActions;

    return _SectionCard(
      title: 'Öncelikli Yönetim Aksiyonları',
      icon: Icons.task_alt_outlined,
      child: actions.isEmpty
          ? const _EmptyText(
              text: 'Mevcut verilere göre acil yönetim aksiyonu gerekmiyor.',
            )
          : Column(
              children: actions
                  .asMap()
                  .entries
                  .map(
                    (entry) =>
                        _ActionRow(order: entry.key + 1, text: entry.value),
                  )
                  .toList(growable: false),
            ),
    );
  }
}

class _ReportMetadata extends StatelessWidget {
  const _ReportMetadata({required this.data});

  final _ExecutiveSummaryData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF5FAF9),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: const Color(0xFFCFE8E4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.schedule_outlined, color: MarkaKalkanTheme.teal),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Rapor üretim zamanı: ${_formatDateTime(data.generatedAt)}',
              style: const TextStyle(
                color: Color(0xFF53616B),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const Text(
            'Canlı operasyon verisi',
            style: TextStyle(
              color: MarkaKalkanTheme.teal,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE0E7EC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, color: MarkaKalkanTheme.teal),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: MarkaKalkanTheme.navy,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 17),
          child,
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.item});

  final _SummaryItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 105),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0E7EC)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F6F4),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(item.icon, color: MarkaKalkanTheme.teal, size: 23),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${item.value}',
                  style: const TextStyle(
                    color: MarkaKalkanTheme.navy,
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  item.label,
                  style: const TextStyle(
                    color: Color(0xFF687580),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
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

class _MetricRow extends StatelessWidget {
  const _MetricRow({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF53616B),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            '$value',
            style: TextStyle(
              color: color,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _AssessmentItem extends StatelessWidget {
  const _AssessmentItem({
    required this.title,
    required this.text,
    required this.icon,
    required this.color,
  });

  final String title;
  final String text;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(color: color, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 5),
                Text(
                  text,
                  style: const TextStyle(
                    color: Color(0xFF53616B),
                    height: 1.45,
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

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.order, required this.text});

  final int order;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FA),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 29,
            height: 29,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Color(0xFFE8F6F4),
              shape: BoxShape.circle,
            ),
            child: Text(
              '$order',
              style: const TextStyle(
                color: MarkaKalkanTheme.teal,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Color(0xFF53616B),
                height: 1.45,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyText extends StatelessWidget {
  const _EmptyText({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Color(0xFF687580),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error, required this.onRetry});

  final Object? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 52, color: Colors.redAccent),
            const SizedBox(height: 14),
            const Text(
              'Yönetici Özeti yüklenemedi.',
              style: TextStyle(
                color: MarkaKalkanTheme.navy,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text('$error', textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Tekrar Dene'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExecutiveSummaryData {
  const _ExecutiveSummaryData({
    required this.sources,
    required this.pages,
    required this.jobs,
    required this.events,
    required this.signals,
    required this.generatedAt,
  });

  final List<MonitoringSourceModel> sources;
  final List<MonitoredPageModel> pages;
  final List<CrawlJobModel> jobs;
  final List<MonitoringEventModel> events;
  final List<MonitoringSignalModel> signals;
  final DateTime generatedAt;

  int get healthySourceCount => sources
      .where(
        (source) => source.healthStatus == MonitoringSourceHealthStatus.healthy,
      )
      .length;

  int get problematicSourceCount => sources
      .where(
        (source) =>
            source.healthStatus == MonitoringSourceHealthStatus.degraded ||
            source.healthStatus == MonitoringSourceHealthStatus.failed ||
            source.healthStatus == MonitoringSourceHealthStatus.blocked,
      )
      .length;

  int get activePageCount => pages
      .where(
        (page) => page.trackingStatus == MonitoringPageTrackingStatus.active,
      )
      .length;

  int get activeJobCount =>
      jobs.where((job) => job.status == MonitoringCrawlJobStatus.active).length;

  int get failedPageCount =>
      pages.where((page) => page.consecutiveFailureCount > 0).length;

  int get newEventCount => events
      .where((event) => event.status == MonitoringEventStatus.newEvent)
      .length;

  int get urgentEventCount => events
      .where(
        (event) =>
            event.severity == MonitoringEventSeverity.high ||
            event.severity == MonitoringEventSeverity.critical,
      )
      .length;

  int get openSignalCount => signals.where((signal) => signal.isOpen).length;

  int get urgentSignalCount => signals
      .where(
        (signal) =>
            signal.isOpen &&
            (signal.signalLevel == MonitoringSignalLevel.high ||
                signal.signalLevel == MonitoringSignalLevel.critical),
      )
      .length;

  int get forwardingFailureCount =>
      signals.where((signal) => signal.hasForwardingFailure).length;

  int get operationalHealthScore {
    if (sources.isEmpty && pages.isEmpty && jobs.isEmpty) {
      return 100;
    }

    var score = 100;

    score -= problematicSourceCount * 10;
    score -= failedPageCount * 4;
    score -= urgentEventCount * 3;
    score -= urgentSignalCount * 6;
    score -= forwardingFailureCount * 4;

    if (pages.isNotEmpty && activePageCount == 0) {
      score -= 15;
    }

    if (jobs.isNotEmpty && activeJobCount == 0) {
      score -= 15;
    }

    return score.clamp(0, 100);
  }

  String get managementHeadline {
    if (urgentSignalCount > 0) {
      return '$urgentSignalCount yüksek veya kritik sinyal acil inceleme bekliyor.';
    }

    if (problematicSourceCount > 0 || failedPageCount > 0) {
      return 'Operasyon sürüyor; kaynak ve tarama sağlığında iyileştirme gerekiyor.';
    }

    return 'Operasyon görünümü normal; acil yönetim müdahalesi gerekmiyor.';
  }

  String get generalAssessment {
    if (operationalHealthScore >= 85) {
      return 'Dijital pazar izleme operasyonu genel olarak sağlıklı '
          'çalışmaktadır. Mevcut kaynak, sayfa ve görev yapısı yönetim '
          'takibine uygundur.';
    }

    if (operationalHealthScore >= 65) {
      return 'Operasyon çalışır durumdadır; ancak kaynak sağlığı, tarama '
          'başarısızlıkları veya açık riskler nedeniyle kontrollü iyileştirme '
          'gerekmektedir.';
    }

    return 'Operasyon sağlığı düşük seviyededir. Kaynak erişimi, tarama '
        'sürekliliği ve yüksek öncelikli risk sinyalleri yönetim tarafından '
        'öncelikli ele alınmalıdır.';
  }

  String get coverageAssessment {
    if (sources.isEmpty || pages.isEmpty || jobs.isEmpty) {
      return 'İzleme kapsamının tamamlanması için kaynak, izlenen sayfa ve '
          'tarama görevi zincirinin eksik parçaları oluşturulmalıdır.';
    }

    return '${sources.length} kaynak, ${pages.length} izlenen sayfa ve '
        '${jobs.length} tarama göreviyle operasyon kapsamı kurulmuştur. '
        '$activePageCount sayfa ve $activeJobCount görev aktiftir.';
  }

  String get riskAssessment {
    if (signals.isEmpty && events.isEmpty) {
      return 'Worker tarafından henüz olay veya risk sinyali üretilmemiştir. '
          'Tarama çalışmaları başladığında risk görünümü otomatik oluşacaktır.';
    }

    if (urgentSignalCount > 0) {
      return '$urgentSignalCount yüksek veya kritik açık sinyal bulunmaktadır. '
          'Bu sinyaller doğrulanmalı, gerekirse yükseltilmeli ve vaka sürecine '
          'aktarılmalıdır.';
    }

    return '${events.length} olay ve ${signals.length} risk sinyali '
        'incelenmiştir. Açık yüksek veya kritik sinyal bulunmamaktadır.';
  }

  List<String> get priorityActions {
    final actions = <String>[];

    if (urgentSignalCount > 0) {
      actions.add(
        'Yüksek ve kritik açık risk sinyallerini öncelik sırasına göre '
        'inceleyin ve sorumlu kişilere yönlendirin.',
      );
    }

    if (problematicSourceCount > 0) {
      actions.add(
        'Performansı düşmüş, başarısız veya engellenmiş kaynakların erişim '
        've kullanım koşullarını kontrol edin.',
      );
    }

    if (failedPageCount > 0) {
      actions.add(
        'Ardışık tarama başarısızlığı bulunan sayfaların görev, bağlantı ve '
        'seçici yapılarını yeniden doğrulayın.',
      );
    }

    if (forwardingFailureCount > 0) {
      actions.add(
        'Risk sinyali iletim hatalarını kontrol ederek n8n/worker iletim '
        'kuyruğunu yeniden çalıştırın.',
      );
    }

    if (sources.isEmpty || pages.isEmpty || jobs.isEmpty) {
      actions.add(
        'İzleme kapsamını tamamlamak için kaynak, sayfa ve görev zincirindeki '
        'eksik kayıtları oluşturun.',
      );
    }

    return List<String>.unmodifiable(actions);
  }
}

class _SummaryItem {
  const _SummaryItem({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final int value;
  final IconData icon;
}

Color _scoreColor(int score) {
  if (score >= 85) {
    return const Color(0xFF45C4A8);
  }

  if (score >= 65) {
    return const Color(0xFFE3B34A);
  }

  return const Color(0xFFFF7A7A);
}

String _formatDateTime(DateTime value) {
  final local = value.toLocal();

  String twoDigits(int number) => number.toString().padLeft(2, '0');

  return '${twoDigits(local.day)}.${twoDigits(local.month)}.${local.year} '
      '${twoDigits(local.hour)}:${twoDigits(local.minute)}';
}

MonitoringPdfReportData _executivePdfData(_ExecutiveSummaryData data) {
  final actions = data.priorityActions.isEmpty
      ? const <String>['Mevcut verilere göre acil yönetim aksiyonu gerekmiyor.']
      : data.priorityActions;

  return MonitoringPdfReportData(
    title: 'Dijital Pazar Yönetici Özeti',
    subtitle:
        'İzleme kapsamı, operasyon sağlığı, değişiklik olayları ve risk '
        'sinyallerinin yönetim seviyesindeki özeti.',
    fileNamePrefix: 'markakalkan_yonetici_ozeti',
    generatedAt: data.generatedAt,
    scoreLabel: 'Operasyon Sağlık Puanı',
    scoreValue: '${data.operationalHealthScore}/100',
    metrics: [
      MonitoringPdfMetric(label: 'Kaynak', value: '${data.sources.length}'),
      MonitoringPdfMetric(
        label: 'İzlenen Sayfa',
        value: '${data.pages.length}',
      ),
      MonitoringPdfMetric(label: 'Tarama Görevi', value: '${data.jobs.length}'),
      MonitoringPdfMetric(
        label: 'İzleme Olayı',
        value: '${data.events.length}',
      ),
      MonitoringPdfMetric(
        label: 'Risk Sinyali',
        value: '${data.signals.length}',
      ),
      MonitoringPdfMetric(
        label: 'Yüksek / Kritik Sinyal',
        value: '${data.urgentSignalCount}',
      ),
    ],
    sections: [
      MonitoringPdfSection(
        title: 'Yönetim Değerlendirmesi',
        paragraphs: [
          data.generalAssessment,
          data.coverageAssessment,
          data.riskAssessment,
        ],
      ),
      MonitoringPdfSection(
        title: 'Operasyon Durumu',
        rows: [
          MonitoringPdfRow(
            label: 'Sağlıklı kaynak',
            value: '${data.healthySourceCount}',
          ),
          MonitoringPdfRow(
            label: 'Sorunlu kaynak',
            value: '${data.problematicSourceCount}',
          ),
          MonitoringPdfRow(
            label: 'Aktif izlenen sayfa',
            value: '${data.activePageCount}',
          ),
          MonitoringPdfRow(
            label: 'Aktif tarama görevi',
            value: '${data.activeJobCount}',
          ),
          MonitoringPdfRow(
            label: 'Başarısızlık yaşayan sayfa',
            value: '${data.failedPageCount}',
          ),
        ],
      ),
      MonitoringPdfSection(
        title: 'Risk ve Olay Görünümü',
        rows: [
          MonitoringPdfRow(
            label: 'Yeni izleme olayı',
            value: '${data.newEventCount}',
          ),
          MonitoringPdfRow(
            label: 'Yüksek / kritik olay',
            value: '${data.urgentEventCount}',
          ),
          MonitoringPdfRow(
            label: 'Açık risk sinyali',
            value: '${data.openSignalCount}',
          ),
          MonitoringPdfRow(
            label: 'Yüksek / kritik sinyal',
            value: '${data.urgentSignalCount}',
          ),
          MonitoringPdfRow(
            label: 'İletim hatası',
            value: '${data.forwardingFailureCount}',
          ),
        ],
      ),
      MonitoringPdfSection(
        title: 'Öncelikli Yönetim Aksiyonları',
        paragraphs: actions,
      ),
    ],
  );
}

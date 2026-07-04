import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:markakalkan/core/theme/markakalkan_theme.dart';

import '../constants/monitoring_enums.dart';
import '../models/monitored_page_model.dart';
import '../models/monitoring_event_model.dart';
import '../models/monitoring_signal_model.dart';
import '../repositories/monitored_page_repository.dart';
import '../repositories/monitoring_event_repository.dart';
import '../repositories/monitoring_signal_repository.dart';
import '../services/monitoring_pdf_report_service.dart';

class MarkaRiskRaporuSayfasi extends StatefulWidget {
  const MarkaRiskRaporuSayfasi({super.key});

  @override
  State<MarkaRiskRaporuSayfasi> createState() => _MarkaRiskRaporuSayfasiState();
}

class _MarkaRiskRaporuSayfasiState extends State<MarkaRiskRaporuSayfasi> {
  Future<_BrandRiskData>? _future;

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
          ? Future<_BrandRiskData>.error(
              StateError('Marka Risk Raporu için oturum açılmalıdır.'),
            )
          : _loadData(tenantId);
    });
  }

  Future<_BrandRiskData> _loadData(String tenantId) async {
    final results = await Future.wait<dynamic>([
      MonitoredPageRepository.instance(
        tenantId: tenantId,
      ).watchAll(limit: 500).first,
      MonitoringEventRepository.instance(
        tenantId: tenantId,
      ).watchRecent(limit: 500).first,
      MonitoringSignalRepository.instance(
        tenantId: tenantId,
      ).watchRecent(limit: 500).first,
    ]);

    return _BrandRiskData(
      pages: results[0] as List<MonitoredPageModel>,
      events: results[1] as List<MonitoringEventModel>,
      signals: results[2] as List<MonitoringSignalModel>,
      generatedAt: DateTime.now(),
    );
  }

  Future<void> _openRiskPdf({required bool saveOrShare}) async {
    final future = _future;

    if (future == null) {
      return;
    }

    try {
      final data = await future;
      final report = _brandRiskPdfData(data);

      if (saveOrShare) {
        await MonitoringPdfReportService.saveOrShare(report);
      } else {
        await MonitoringPdfReportService.previewAndPrint(report);
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDF olu\u015fturulamad\u0131: $error')),
      );
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
          'Marka Risk Raporu',
          style: TextStyle(
            color: MarkaKalkanTheme.navy,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'PDF \u00d6nizle / Yazd\u0131r',
            onPressed: () => _openRiskPdf(saveOrShare: false),
            icon: const Icon(Icons.picture_as_pdf_outlined),
          ),
          IconButton(
            tooltip: 'PDF Kaydet / Payla\u015f',
            onPressed: () => _openRiskPdf(saveOrShare: true),
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
      body: FutureBuilder<_BrandRiskData>(
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
                    _RiskHeader(data: data),
                    const SizedBox(height: 22),
                    _SummaryGrid(data: data),
                    const SizedBox(height: 22),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final narrow = constraints.maxWidth < 900;

                        final pageDistribution = _PageRiskDistribution(
                          data: data,
                        );

                        final signalDistribution = _SignalRiskDistribution(
                          data: data,
                        );

                        if (narrow) {
                          return Column(
                            children: [
                              pageDistribution,
                              const SizedBox(height: 16),
                              signalDistribution,
                            ],
                          );
                        }

                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: pageDistribution),
                            const SizedBox(width: 16),
                            Expanded(child: signalDistribution),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 22),
                    _TopRiskPages(data: data),
                    const SizedBox(height: 22),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final narrow = constraints.maxWidth < 900;

                        final events = _UrgentEvents(data: data);
                        final signals = _OpenSignals(data: data);

                        if (narrow) {
                          return Column(
                            children: [
                              events,
                              const SizedBox(height: 16),
                              signals,
                            ],
                          );
                        }

                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: events),
                            const SizedBox(width: 16),
                            Expanded(child: signals),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 22),
                    _RiskAssessment(data: data),
                    const SizedBox(height: 22),
                    _RiskActions(data: data),
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

MonitoringPdfReportData _brandRiskPdfData(_BrandRiskData data) {
  final actions = data.priorityActions.isEmpty
      ? const <String>[
          'Mevcut verilere g\u00f6re acil risk aksiyonu gerekmiyor.',
        ]
      : data.priorityActions;

  return MonitoringPdfReportData(
    title: 'Dijital Pazar Marka Risk Raporu',
    subtitle:
        '\u0130zlenen sayfalar, olaylar ve risk sinyallerinin marka '
        'seviyesindeki risk de\u011ferlendirmesi.',
    fileNamePrefix: 'markakalkan_marka_risk_raporu',
    generatedAt: data.generatedAt,
    scoreLabel: 'Marka Risk Puan\u0131',
    scoreValue: '${data.overallRiskScore}/100',
    metrics: [
      MonitoringPdfMetric(
        label: '\u0130zlenen Sayfa',
        value: '${data.pages.length}',
      ),
      MonitoringPdfMetric(
        label: 'Riskli Sayfa',
        value: '${data.riskyPageCount}',
      ),
      MonitoringPdfMetric(
        label: 'A\u00e7\u0131k Sinyal',
        value: '${data.openSignalCount}',
      ),
      MonitoringPdfMetric(
        label: 'Y\u00fcksek / Kritik Sinyal',
        value: '${data.urgentSignalCount}',
      ),
      MonitoringPdfMetric(
        label: 'Y\u00fcksek / Kritik Olay',
        value: '${data.urgentEvents.length}',
      ),
      MonitoringPdfMetric(
        label: 'Ortalama Sayfa Riski',
        value: '${data.averagePageRiskScore}/100',
      ),
    ],
    sections: [
      MonitoringPdfSection(
        title: 'Marka Risk De\u011ferlendirmesi',
        paragraphs: [
          data.riskHeadline,
          data.generalRiskAssessment,
          data.pageRiskAssessment,
        ],
      ),
      MonitoringPdfSection(
        title: 'Sayfa Risk Da\u011f\u0131l\u0131m\u0131',
        rows: [
          MonitoringPdfRow(
            label: 'Kritik riskli sayfa',
            value: '${data.criticalPageCount}',
          ),
          MonitoringPdfRow(
            label: 'Y\u00fcksek riskli sayfa',
            value: '${data.highPageCount}',
          ),
          MonitoringPdfRow(
            label: 'Orta riskli sayfa',
            value: '${data.mediumPageCount}',
          ),
          MonitoringPdfRow(
            label: 'D\u00fc\u015f\u00fck riskli sayfa',
            value: '${data.lowPageCount}',
          ),
          MonitoringPdfRow(
            label: 'Bilgi seviyesindeki sayfa',
            value: '${data.infoPageCount}',
          ),
        ],
      ),
      MonitoringPdfSection(
        title: 'Sinyal Risk Da\u011f\u0131l\u0131m\u0131',
        rows: [
          MonitoringPdfRow(
            label: 'Kritik a\u00e7\u0131k sinyal',
            value: '${data.criticalSignalCount}',
          ),
          MonitoringPdfRow(
            label: 'Y\u00fcksek a\u00e7\u0131k sinyal',
            value: '${data.highSignalCount}',
          ),
          MonitoringPdfRow(
            label: 'Orta a\u00e7\u0131k sinyal',
            value: '${data.mediumSignalCount}',
          ),
          MonitoringPdfRow(
            label: 'Do\u011frulanm\u0131\u015f sinyal',
            value: '${data.confirmedSignalCount}',
          ),
          MonitoringPdfRow(
            label: 'Eskalasyon uygulanm\u0131\u015f sinyal',
            value: '${data.escalatedSignalCount}',
          ),
        ],
      ),
      MonitoringPdfSection(
        title: 'Operasyonel Risk G\u00f6r\u00fcn\u00fcm\u00fc',
        rows: [
          MonitoringPdfRow(
            label: 'Toplam izleme olay\u0131',
            value: '${data.events.length}',
          ),
          MonitoringPdfRow(
            label: 'Y\u00fcksek / kritik olay',
            value: '${data.urgentEvents.length}',
          ),
          MonitoringPdfRow(
            label: '\u00d6ncelikli a\u00e7\u0131k sinyal',
            value: '${data.prioritizedOpenSignals.length}',
          ),
          MonitoringPdfRow(
            label: 'Risk puan\u0131 bulunan sayfa',
            value: '${data.topRiskPages.length}',
          ),
        ],
      ),
      MonitoringPdfSection(
        title: '\u00d6ncelikli Risk Aksiyonlar\u0131',
        paragraphs: actions,
      ),
    ],
    footerNote:
        'Bu rapor MarkaKalkan canl\u0131 marka risk verilerinden '
        '\u00fcretilmi\u015ftir.',
  );
}

class _RiskHeader extends StatelessWidget {
  const _RiskHeader({required this.data});

  final _BrandRiskData data;

  @override
  Widget build(BuildContext context) {
    final score = data.overallRiskScore;
    final color = _riskScoreColor(score);

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
                  'Marka Risk Puanı',
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
                'Dijital Pazar Marka Risk Görünümü',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 9),
              const Text(
                'İzlenen sayfalar, değişiklik olayları ve risk sinyallerinden '
                'üretilen bütünleşik marka risk değerlendirmesi.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFFD9E5EA), height: 1.5),
              ),
              const SizedBox(height: 14),
              Text(
                data.riskHeadline,
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

  final _BrandRiskData data;

  @override
  Widget build(BuildContext context) {
    final items = <_SummaryItem>[
      _SummaryItem(
        label: 'İzlenen Sayfa',
        value: data.pages.length,
        icon: Icons.language_outlined,
      ),
      _SummaryItem(
        label: 'Riskli Sayfa',
        value: data.riskyPageCount,
        icon: Icons.warning_amber_rounded,
      ),
      _SummaryItem(
        label: 'Toplam Olay',
        value: data.events.length,
        icon: Icons.timeline_outlined,
      ),
      _SummaryItem(
        label: 'Açık Sinyal',
        value: data.openSignalCount,
        icon: Icons.notifications_active_outlined,
      ),
      _SummaryItem(
        label: 'Yüksek / Kritik',
        value: data.urgentSignalCount,
        icon: Icons.crisis_alert_outlined,
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

class _PageRiskDistribution extends StatelessWidget {
  const _PageRiskDistribution({required this.data});

  final _BrandRiskData data;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Sayfa Risk Dağılımı',
      icon: Icons.language_outlined,
      child: Column(
        children: [
          _MetricRow(
            label: 'Kritik risk',
            value: data.criticalPageCount,
            color: const Color(0xFFC83C4E),
          ),
          _MetricRow(
            label: 'Yüksek risk',
            value: data.highPageCount,
            color: const Color(0xFFDF6C2F),
          ),
          _MetricRow(
            label: 'Orta risk',
            value: data.mediumPageCount,
            color: const Color(0xFFE39A25),
          ),
          _MetricRow(
            label: 'Düşük risk',
            value: data.lowPageCount,
            color: const Color(0xFF2C8F83),
          ),
          _MetricRow(
            label: 'Bilgi seviyesi',
            value: data.infoPageCount,
            color: const Color(0xFF4B7895),
          ),
        ],
      ),
    );
  }
}

class _SignalRiskDistribution extends StatelessWidget {
  const _SignalRiskDistribution({required this.data});

  final _BrandRiskData data;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Sinyal Risk Dağılımı',
      icon: Icons.notification_important_outlined,
      child: Column(
        children: [
          _MetricRow(
            label: 'Kritik açık sinyal',
            value: data.criticalSignalCount,
            color: const Color(0xFFC83C4E),
          ),
          _MetricRow(
            label: 'Yüksek açık sinyal',
            value: data.highSignalCount,
            color: const Color(0xFFDF6C2F),
          ),
          _MetricRow(
            label: 'Orta açık sinyal',
            value: data.mediumSignalCount,
            color: const Color(0xFFE39A25),
          ),
          _MetricRow(
            label: 'Doğrulanmış sinyal',
            value: data.confirmedSignalCount,
            color: const Color(0xFF2C8F83),
          ),
          _MetricRow(
            label: 'Yükseltilmiş sinyal',
            value: data.escalatedSignalCount,
            color: const Color(0xFF7C6A92),
          ),
        ],
      ),
    );
  }
}

class _TopRiskPages extends StatelessWidget {
  const _TopRiskPages({required this.data});

  final _BrandRiskData data;

  @override
  Widget build(BuildContext context) {
    final pages = data.topRiskPages;

    return _SectionCard(
      title: 'En Riskli İzlenen Sayfalar',
      icon: Icons.troubleshoot_outlined,
      child: pages.isEmpty
          ? const _EmptyText(
              text: 'Risk puanı bulunan izlenen sayfa henüz yok.',
            )
          : Column(
              children: pages
                  .asMap()
                  .entries
                  .map(
                    (entry) =>
                        _RiskPageRow(order: entry.key + 1, page: entry.value),
                  )
                  .toList(growable: false),
            ),
    );
  }
}

class _UrgentEvents extends StatelessWidget {
  const _UrgentEvents({required this.data});

  final _BrandRiskData data;

  @override
  Widget build(BuildContext context) {
    final events = data.urgentEvents.take(5).toList(growable: false);

    return _SectionCard(
      title: 'Yüksek / Kritik Olaylar',
      icon: Icons.timeline_outlined,
      child: events.isEmpty
          ? const _EmptyText(
              text: 'Yüksek veya kritik izleme olayı bulunmuyor.',
            )
          : Column(
              children: events
                  .map(
                    (event) => _FeedRow(
                      title: event.summary ?? event.eventType.value,
                      subtitle:
                          '${event.eventCategory.value} • '
                          '${_formatDateTime(event.detectedAt)}',
                      color: _eventColor(event.severity),
                    ),
                  )
                  .toList(growable: false),
            ),
    );
  }
}

class _OpenSignals extends StatelessWidget {
  const _OpenSignals({required this.data});

  final _BrandRiskData data;

  @override
  Widget build(BuildContext context) {
    final signals = data.prioritizedOpenSignals.take(5).toList(growable: false);

    return _SectionCard(
      title: 'Öncelikli Açık Sinyaller',
      icon: Icons.notifications_active_outlined,
      child: signals.isEmpty
          ? const _EmptyText(
              text: 'İnceleme bekleyen açık risk sinyali bulunmuyor.',
            )
          : Column(
              children: signals
                  .map(
                    (signal) => _FeedRow(
                      title: signal.title,
                      subtitle:
                          '${signal.ruleName ?? signal.ruleId} • '
                          '${_formatDateTime(signal.detectedAt)}',
                      color: _signalColor(signal.signalLevel),
                    ),
                  )
                  .toList(growable: false),
            ),
    );
  }
}

class _RiskAssessment extends StatelessWidget {
  const _RiskAssessment({required this.data});

  final _BrandRiskData data;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Marka Risk Değerlendirmesi',
      icon: Icons.shield_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _AssessmentItem(
            title: 'Genel risk seviyesi',
            text: data.generalRiskAssessment,
            icon: Icons.assessment_outlined,
            color: _riskScoreColor(data.overallRiskScore),
          ),
          const SizedBox(height: 12),
          _AssessmentItem(
            title: 'Sayfa görünümü',
            text: data.pageRiskAssessment,
            icon: Icons.language_outlined,
            color: data.riskyPageCount > 0
                ? const Color(0xFFDF6C2F)
                : const Color(0xFF2C8F83),
          ),
          const SizedBox(height: 12),
          _AssessmentItem(
            title: 'Sinyal görünümü',
            text: data.signalRiskAssessment,
            icon: Icons.notification_important_outlined,
            color: data.urgentSignalCount > 0
                ? const Color(0xFFC83C4E)
                : const Color(0xFF2C8F83),
          ),
        ],
      ),
    );
  }
}

class _RiskActions extends StatelessWidget {
  const _RiskActions({required this.data});

  final _BrandRiskData data;

  @override
  Widget build(BuildContext context) {
    final actions = data.priorityActions;

    return _SectionCard(
      title: 'Öncelikli Risk Aksiyonları',
      icon: Icons.task_alt_outlined,
      child: actions.isEmpty
          ? const _EmptyText(
              text: 'Mevcut risk görünümünde acil aksiyon gerekmiyor.',
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

  final _BrandRiskData data;

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
            'Canlı risk verisi',
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

class _RiskPageRow extends StatelessWidget {
  const _RiskPageRow({required this.order, required this.page});

  final int order;
  final MonitoredPageModel page;

  @override
  Widget build(BuildContext context) {
    final color = _signalColor(page.riskLevel);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FA),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: Text(
              '$order',
              style: TextStyle(color: color, fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Sayfa: ${_shortId(page.id)}',
              style: const TextStyle(
                color: MarkaKalkanTheme.navy,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Text(
            '${page.riskScore}/100',
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

class _FeedRow extends StatelessWidget {
  const _FeedRow({
    required this.title,
    required this.subtitle,
    required this.color,
  });

  final String title;
  final String subtitle;
  final Color color;

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
          Icon(Icons.warning_amber_rounded, color: color, size: 21),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: MarkaKalkanTheme.navy,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFF7A8791),
                    fontSize: 12,
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
              'Marka Risk Raporu yüklenemedi.',
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

class _BrandRiskData {
  const _BrandRiskData({
    required this.pages,
    required this.events,
    required this.signals,
    required this.generatedAt,
  });

  final List<MonitoredPageModel> pages;
  final List<MonitoringEventModel> events;
  final List<MonitoringSignalModel> signals;
  final DateTime generatedAt;

  int get criticalPageCount => pages
      .where((page) => page.riskLevel == MonitoringSignalLevel.critical)
      .length;

  int get highPageCount => pages
      .where((page) => page.riskLevel == MonitoringSignalLevel.high)
      .length;

  int get mediumPageCount => pages
      .where((page) => page.riskLevel == MonitoringSignalLevel.medium)
      .length;

  int get lowPageCount =>
      pages.where((page) => page.riskLevel == MonitoringSignalLevel.low).length;

  int get infoPageCount => pages
      .where((page) => page.riskLevel == MonitoringSignalLevel.info)
      .length;

  int get riskyPageCount => criticalPageCount + highPageCount + mediumPageCount;

  int get openSignalCount => signals.where((signal) => signal.isOpen).length;

  int get criticalSignalCount => signals
      .where(
        (signal) =>
            signal.isOpen &&
            signal.signalLevel == MonitoringSignalLevel.critical,
      )
      .length;

  int get highSignalCount => signals
      .where(
        (signal) =>
            signal.isOpen && signal.signalLevel == MonitoringSignalLevel.high,
      )
      .length;

  int get mediumSignalCount => signals
      .where(
        (signal) =>
            signal.isOpen && signal.signalLevel == MonitoringSignalLevel.medium,
      )
      .length;

  int get confirmedSignalCount => signals
      .where((signal) => signal.status == MonitoringSignalStatus.confirmed)
      .length;

  int get escalatedSignalCount => signals
      .where((signal) => signal.status == MonitoringSignalStatus.escalated)
      .length;

  int get urgentSignalCount => criticalSignalCount + highSignalCount;

  List<MonitoringEventModel> get urgentEvents {
    final result = events
        .where(
          (event) =>
              event.severity == MonitoringEventSeverity.high ||
              event.severity == MonitoringEventSeverity.critical,
        )
        .toList(growable: false);

    return result;
  }

  List<MonitoringSignalModel> get prioritizedOpenSignals {
    final result = signals.where((signal) => signal.isOpen).toList();

    result.sort(
      (first, second) => _signalRank(
        first.signalLevel,
      ).compareTo(_signalRank(second.signalLevel)),
    );

    return List<MonitoringSignalModel>.unmodifiable(result);
  }

  List<MonitoredPageModel> get topRiskPages {
    final result = pages.where((page) => page.riskScore > 0).toList();

    result.sort((first, second) => second.riskScore.compareTo(first.riskScore));

    return List<MonitoredPageModel>.unmodifiable(result.take(8));
  }

  int get averagePageRiskScore {
    if (pages.isEmpty) {
      return 0;
    }

    final total = pages.fold<int>(0, (sum, page) => sum + page.riskScore);

    return (total / pages.length).round();
  }

  int get overallRiskScore {
    if (pages.isEmpty && events.isEmpty && signals.isEmpty) {
      return 0;
    }

    var score = averagePageRiskScore;

    score += criticalSignalCount * 14;
    score += highSignalCount * 9;
    score += mediumSignalCount * 4;
    score += urgentEvents.length * 3;
    score += escalatedSignalCount * 5;

    return score.clamp(0, 100);
  }

  String get riskHeadline {
    if (urgentSignalCount > 0) {
      return '$urgentSignalCount yüksek veya kritik açık risk sinyali bulunuyor.';
    }

    if (riskyPageCount > 0) {
      return '$riskyPageCount izlenen sayfa orta veya üzeri risk taşıyor.';
    }

    return 'Mevcut verilerde yüksek öncelikli marka riski bulunmuyor.';
  }

  String get generalRiskAssessment {
    if (overallRiskScore >= 70) {
      return 'Marka risk görünümü yüksek seviyededir. Kritik sinyaller, '
          'yüksek riskli sayfalar ve önemli olaylar öncelikli vaka incelemesine '
          'alınmalıdır.';
    }

    if (overallRiskScore >= 35) {
      return 'Marka risk görünümü orta seviyededir. Açık sinyaller ve riskli '
          'sayfalar düzenli takip edilmeli, doğrulanan bulgular vaka sürecine '
          'aktarılmalıdır.';
    }

    return 'Marka risk görünümü düşük seviyededir. Mevcut operasyon normal '
        'izleme ve periyodik kontrol altında sürdürülebilir.';
  }

  String get pageRiskAssessment {
    if (pages.isEmpty) {
      return 'Henüz izlenen sayfa bulunmadığından sayfa tabanlı risk '
          'değerlendirmesi oluşturulamamıştır.';
    }

    if (riskyPageCount == 0) {
      return '${pages.length} izlenen sayfanın hiçbirinde orta, yüksek veya '
          'kritik risk seviyesi bulunmamaktadır.';
    }

    return '${pages.length} izlenen sayfanın $riskyPageCount adedi orta veya '
        'üzeri risk seviyesindedir. Ortalama sayfa risk puanı '
        '$averagePageRiskScore/100 değerindedir.';
  }

  String get signalRiskAssessment {
    if (signals.isEmpty) {
      return 'Worker tarafından henüz risk sinyali üretilmemiştir. Tarama ve '
          'değişiklik motoru çalıştıkça sinyal görünümü otomatik oluşacaktır.';
    }

    if (urgentSignalCount > 0) {
      return '$openSignalCount açık sinyalin $urgentSignalCount adedi yüksek '
          'veya kritik seviyededir. Bu kayıtlar öncelikli inceleme gerektirir.';
    }

    return '$openSignalCount açık risk sinyali bulunmaktadır; yüksek veya '
        'kritik seviyede açık sinyal yoktur.';
  }

  List<String> get priorityActions {
    final actions = <String>[];

    if (criticalSignalCount > 0) {
      actions.add(
        'Kritik risk sinyallerini derhal doğrulayın, sorumlu kişiye atayın '
        've vaka/kanıt sürecine aktarın.',
      );
    }

    if (highSignalCount > 0) {
      actions.add(
        'Yüksek riskli açık sinyalleri sayfa ve olay geçmişiyle birlikte '
        'inceleyerek doğrulama veya reddetme kararı verin.',
      );
    }

    if (criticalPageCount > 0 || highPageCount > 0) {
      actions.add(
        'Yüksek ve kritik risk puanlı sayfaların son sürüm, değişiklik ve '
        'satıcı bağlantılarını öncelikli olarak kontrol edin.',
      );
    }

    if (urgentEvents.isNotEmpty) {
      actions.add(
        'Yüksek ve kritik izleme olaylarını ilişkili risk sinyalleriyle '
        'eşleştirerek kanıt zincirini oluşturun.',
      );
    }

    if (escalatedSignalCount > 0) {
      actions.add(
        'Yükseltilmiş risk sinyallerinin operasyon, hukuk veya marka koruma '
        'ekibine iletim durumunu kontrol edin.',
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

int _signalRank(MonitoringSignalLevel level) {
  switch (level) {
    case MonitoringSignalLevel.critical:
      return 0;
    case MonitoringSignalLevel.high:
      return 1;
    case MonitoringSignalLevel.medium:
      return 2;
    case MonitoringSignalLevel.low:
      return 3;
    case MonitoringSignalLevel.info:
      return 4;
  }
}

Color _riskScoreColor(int score) {
  if (score >= 70) {
    return const Color(0xFFFF7A7A);
  }

  if (score >= 35) {
    return const Color(0xFFE3B34A);
  }

  return const Color(0xFF45C4A8);
}

Color _eventColor(MonitoringEventSeverity severity) {
  switch (severity) {
    case MonitoringEventSeverity.info:
      return const Color(0xFF4B7895);
    case MonitoringEventSeverity.low:
      return const Color(0xFF2C8F83);
    case MonitoringEventSeverity.medium:
      return const Color(0xFFE39A25);
    case MonitoringEventSeverity.high:
      return const Color(0xFFDF6C2F);
    case MonitoringEventSeverity.critical:
      return const Color(0xFFC83C4E);
  }
}

Color _signalColor(MonitoringSignalLevel level) {
  switch (level) {
    case MonitoringSignalLevel.info:
      return const Color(0xFF4B7895);
    case MonitoringSignalLevel.low:
      return const Color(0xFF2C8F83);
    case MonitoringSignalLevel.medium:
      return const Color(0xFFE39A25);
    case MonitoringSignalLevel.high:
      return const Color(0xFFDF6C2F);
    case MonitoringSignalLevel.critical:
      return const Color(0xFFC83C4E);
  }
}

String _formatDateTime(DateTime value) {
  final local = value.toLocal();

  String twoDigits(int number) => number.toString().padLeft(2, '0');

  return '${twoDigits(local.day)}.${twoDigits(local.month)}.${local.year} '
      '${twoDigits(local.hour)}:${twoDigits(local.minute)}';
}

String _shortId(String value) {
  final cleaned = value.trim();

  if (cleaned.length <= 24) {
    return cleaned;
  }

  return '${cleaned.substring(0, 12)}…'
      '${cleaned.substring(cleaned.length - 8)}';
}

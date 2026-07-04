import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:markakalkan/app/router.dart';
import 'package:markakalkan/core/theme/markakalkan_theme.dart';

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

class RaporMerkeziSayfasi extends StatefulWidget {
  const RaporMerkeziSayfasi({super.key});

  @override
  State<RaporMerkeziSayfasi> createState() => _RaporMerkeziSayfasiState();
}

class _RaporMerkeziSayfasiState extends State<RaporMerkeziSayfasi> {
  Future<_ReportCenterData>? _future;

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
          ? Future<_ReportCenterData>.error(
              StateError('Rapor Merkezi için oturum açılmalıdır.'),
            )
          : _loadData(tenantId);
    });
  }

  Future<_ReportCenterData> _loadData(String tenantId) async {
    final sourceRepository = MonitoringSourceRepository.instance(
      tenantId: tenantId,
    );

    final pageRepository = MonitoredPageRepository.instance(tenantId: tenantId);

    final jobRepository = CrawlJobRepository.instance(tenantId: tenantId);

    final eventRepository = MonitoringEventRepository.instance(
      tenantId: tenantId,
    );

    final signalRepository = MonitoringSignalRepository.instance(
      tenantId: tenantId,
    );

    final results = await Future.wait<dynamic>([
      sourceRepository.watchAll(limit: 500).first,
      pageRepository.watchAll(limit: 500).first,
      jobRepository.watchAll(limit: 500).first,
      eventRepository.watchRecent(limit: 500).first,
      signalRepository.watchRecent(limit: 500).first,
    ]);

    return _ReportCenterData(
      sources: results[0] as List<MonitoringSourceModel>,
      pages: results[1] as List<MonitoredPageModel>,
      jobs: results[2] as List<CrawlJobModel>,
      events: results[3] as List<MonitoringEventModel>,
      signals: results[4] as List<MonitoringSignalModel>,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MarkaKalkanTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text(
          'Rapor Merkezi',
          style: TextStyle(
            color: MarkaKalkanTheme.navy,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Yenile',
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: FutureBuilder<_ReportCenterData>(
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
                    _ReportHeader(data: data),
                    const SizedBox(height: 22),
                    _DataSummary(data: data),
                    const SizedBox(height: 24),
                    const Text(
                      'Kurumsal Raporlar',
                      style: TextStyle(
                        color: MarkaKalkanTheme.navy,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Yönetim, risk değerlendirmesi ve vaka kanıt süreçleri '
                      'için hazırlanacak raporları yönetin.',
                      style: TextStyle(color: Color(0xFF687580), height: 1.5),
                    ),
                    const SizedBox(height: 18),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        int columns;

                        if (constraints.maxWidth < 650) {
                          columns = 1;
                        } else if (constraints.maxWidth < 1000) {
                          columns = 2;
                        } else {
                          columns = 3;
                        }

                        const spacing = 16.0;

                        final width =
                            (constraints.maxWidth - ((columns - 1) * spacing)) /
                            columns;

                        final reports = <_ReportDefinition>[
                          _ReportDefinition(
                            title: 'Yönetici Özeti',
                            description:
                                'Kaynak sağlığı, tarama kapsamı, olay ve '
                                'sinyal yoğunluğunu tek yönetici raporunda '
                                'özetler.',
                            icon: Icons.summarize_outlined,
                            status: 'Raporu Aç',
                            metric:
                                '${data.totalOperationalRecords} operasyon kaydı',
                            accentColor: const Color(0xFF2C8F83),
                          ),
                          _ReportDefinition(
                            title: 'Marka Risk Raporu',
                            description:
                                'Yüksek ve kritik riskleri, riskli sayfaları '
                                've açık sinyalleri öncelik sırasıyla sunar.',
                            icon: Icons.shield_outlined,
                            status: 'Raporu Aç',
                            metric:
                                '${data.urgentSignalCount} acil risk sinyali',
                            accentColor: const Color(0xFFDF6C2F),
                          ),
                          _ReportDefinition(
                            title: 'Vaka / Kanıt Raporu',
                            description:
                                'İzleme olayı, sayfa sürümü, değişiklik '
                                'bulgusu ve risk sinyalini kanıt zincirinde '
                                'birleştirir.',
                            icon: Icons.fact_check_outlined,
                            status: 'Raporu Aç',
                            metric: '${data.events.length} izleme olayı',
                            accentColor: const Color(0xFF4B7895),
                          ),
                        ];

                        return Wrap(
                          spacing: spacing,
                          runSpacing: spacing,
                          children: reports
                              .map(
                                (report) => SizedBox(
                                  width: width,
                                  child: _ReportCard(
                                    report: report,
                                    onTap: () {
                                      if (report.title == 'Yönetici Özeti') {
                                        AppRouter.openYoneticiOzetiRaporu(
                                          context,
                                        );
                                        return;
                                      }

                                      if (report.title == 'Marka Risk Raporu') {
                                        AppRouter.openMarkaRiskRaporu(context);
                                        return;
                                      }

                                      if (report.title ==
                                          'Vaka / Kanıt Raporu') {
                                        AppRouter.openVakaKanitRaporu(context);

                                        return;
                                      }

                                      _showReportMessage(report.title);
                                    },
                                  ),
                                ),
                              )
                              .toList(growable: false),
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                    const _PdfInfrastructureCard(),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showReportMessage(String reportName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$reportName ekranı sıradaki geliştirme paketinde açılacaktır.',
        ),
      ),
    );
  }
}

class _ReportHeader extends StatelessWidget {
  const _ReportHeader({required this.data});

  final _ReportCenterData data;

  @override
  Widget build(BuildContext context) {
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

          final icon = Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFF25576B),
              borderRadius: BorderRadius.circular(19),
            ),
            child: const Icon(
              Icons.assessment_outlined,
              size: 40,
              color: MarkaKalkanTheme.teal,
            ),
          );

          final content = Column(
            crossAxisAlignment: narrow
                ? CrossAxisAlignment.center
                : CrossAxisAlignment.start,
            children: [
              const Text(
                'Dijital Pazar Rapor Merkezi',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 9),
              const Text(
                'Operasyon verilerini yönetim, risk ve kanıt raporlarına '
                'dönüştüren kurumsal raporlama katmanı.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFFD9E5EA), height: 1.5),
              ),
              const SizedBox(height: 14),
              Text(
                data.hasReportableData
                    ? 'Rapor üretimine uygun operasyon verileri hazır.'
                    : 'Rapor yapısı hazır; worker verileri geldikçe '
                          'raporlar otomatik zenginleşecektir.',
                style: const TextStyle(
                  color: MarkaKalkanTheme.teal,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          );

          if (narrow) {
            return Column(
              children: [icon, const SizedBox(height: 18), content],
            );
          }

          return Row(
            children: [
              icon,
              const SizedBox(width: 22),
              Expanded(child: content),
            ],
          );
        },
      ),
    );
  }
}

class _DataSummary extends StatelessWidget {
  const _DataSummary({required this.data});

  final _ReportCenterData data;

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

class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.report, required this.onTap});

  final _ReportDefinition report;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(19),
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 285),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(19),
          border: Border.all(color: const Color(0xFFE0E7EC)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0B000000),
              blurRadius: 15,
              offset: Offset(0, 7),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(height: 5, color: report.accentColor),
              Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: report.accentColor.withValues(alpha: 0.09),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        report.icon,
                        color: report.accentColor,
                        size: 29,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      report.title,
                      style: const TextStyle(
                        color: MarkaKalkanTheme.navy,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      report.description,
                      style: const TextStyle(
                        color: Color(0xFF687580),
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      report.metric,
                      style: TextStyle(
                        color: report.accentColor,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            report.status,
                            style: const TextStyle(
                              color: MarkaKalkanTheme.blue,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.arrow_forward_rounded,
                          color: MarkaKalkanTheme.blue,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
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

class _PdfInfrastructureCard extends StatelessWidget {
  const _PdfInfrastructureCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF5FAF9),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFCFE8E4)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.picture_as_pdf_outlined,
            color: MarkaKalkanTheme.teal,
            size: 29,
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PDF Rapor Altyapısı Hazır',
                  style: TextStyle(
                    color: MarkaKalkanTheme.navy,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Projede pdf ve printing paketleri mevcut. Rapor ekranları '
                  'tamamlandıktan sonra kurumsal başlık, tarih, kapsam, '
                  'bulgular ve kanıt listesiyle PDF çıktıları üretilecektir.',
                  style: TextStyle(color: Color(0xFF53616B), height: 1.5),
                ),
              ],
            ),
          ),
        ],
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
              'Rapor Merkezi yüklenemedi.',
              style: TextStyle(
                color: MarkaKalkanTheme.navy,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$error',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF687580)),
            ),
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

class _ReportCenterData {
  const _ReportCenterData({
    required this.sources,
    required this.pages,
    required this.jobs,
    required this.events,
    required this.signals,
  });

  final List<MonitoringSourceModel> sources;
  final List<MonitoredPageModel> pages;
  final List<CrawlJobModel> jobs;
  final List<MonitoringEventModel> events;
  final List<MonitoringSignalModel> signals;

  bool get hasReportableData =>
      sources.isNotEmpty ||
      pages.isNotEmpty ||
      jobs.isNotEmpty ||
      events.isNotEmpty ||
      signals.isNotEmpty;

  int get totalOperationalRecords =>
      sources.length +
      pages.length +
      jobs.length +
      events.length +
      signals.length;

  int get urgentSignalCount => signals
      .where(
        (signal) =>
            signal.isOpen &&
            (signal.signalLevel == MonitoringSignalLevel.high ||
                signal.signalLevel == MonitoringSignalLevel.critical),
      )
      .length;
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

class _ReportDefinition {
  const _ReportDefinition({
    required this.title,
    required this.description,
    required this.icon,
    required this.status,
    required this.metric,
    required this.accentColor,
  });

  final String title;
  final String description;
  final IconData icon;
  final String status;
  final String metric;
  final Color accentColor;
}

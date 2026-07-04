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

class DijitalPazarAnaPaneliSayfasi extends StatefulWidget {
  const DijitalPazarAnaPaneliSayfasi({super.key});

  @override
  State<DijitalPazarAnaPaneliSayfasi> createState() =>
      _DijitalPazarAnaPaneliSayfasiState();
}

class _DijitalPazarAnaPaneliSayfasiState
    extends State<DijitalPazarAnaPaneliSayfasi> {
  Future<_DashboardData>? _dashboardFuture;

  User? get _currentUser => FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    final user = _currentUser;

    setState(() {
      _dashboardFuture = user == null
          ? Future<_DashboardData>.error(
              StateError('Ana panel için oturum açılmalıdır.'),
            )
          : _loadDashboard(user.uid);
    });
  }

  Future<_DashboardData> _loadDashboard(String tenantId) async {
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

    return _DashboardData(
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
          'Dijital Pazar Ana Paneli',
          style: TextStyle(
            color: MarkaKalkanTheme.navy,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Yenile',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: FutureBuilder<_DashboardData>(
        future: _dashboardFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError || !snapshot.hasData) {
            return _ErrorState(error: snapshot.error, onRetry: _refresh);
          }

          final data = snapshot.data!;

          return RefreshIndicator(
            onRefresh: () async {
              final user = _currentUser;

              if (user == null) {
                return;
              }

              final refreshed = await _loadDashboard(user.uid);

              if (!mounted) {
                return;
              }

              setState(() {
                _dashboardFuture = Future<_DashboardData>.value(refreshed);
              });
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1240),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _DashboardHeader(data: data),
                      const SizedBox(height: 22),
                      _SummaryGrid(data: data),
                      const SizedBox(height: 22),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final narrow = constraints.maxWidth < 900;

                          final sourceHealth = _SourceHealthCard(data: data);
                          final riskOverview = _RiskOverviewCard(data: data);

                          if (narrow) {
                            return Column(
                              children: [
                                sourceHealth,
                                const SizedBox(height: 16),
                                riskOverview,
                              ],
                            );
                          }

                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: sourceHealth),
                              const SizedBox(width: 16),
                              Expanded(child: riskOverview),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 22),
                      _QuickActions(),
                      const SizedBox(height: 22),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final narrow = constraints.maxWidth < 900;

                          final events = _RecentEventsCard(
                            events: data.events.take(5).toList(),
                          );

                          final signals = _RecentSignalsCard(
                            signals: data.signals.take(5).toList(),
                          );

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
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({required this.data});

  final _DashboardData data;

  @override
  Widget build(BuildContext context) {
    final score = data.operationalHealthScore;
    final scoreColor = _healthScoreColor(score);

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
            width: 126,
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
                    color: scoreColor,
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                const Text(
                  'Operasyon Sağlığı',
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
                'Dijital Pazar Operasyon Görünümü',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 9),
              const Text(
                'Kaynak sağlığı, tarama operasyonu, olaylar ve risk '
                'sinyalleri tek yönetici görünümünde.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFFD9E5EA), height: 1.5),
              ),
              const SizedBox(height: 14),
              Text(
                data.urgentSignalCount == 0
                    ? 'Acil inceleme bekleyen yüksek veya kritik sinyal yok.'
                    : '${data.urgentSignalCount} yüksek veya kritik sinyal '
                          'acil inceleme bekliyor.',
                style: TextStyle(
                  color: data.urgentSignalCount == 0
                      ? MarkaKalkanTheme.teal
                      : const Color(0xFFFFB45C),
                  fontWeight: FontWeight.w800,
                ),
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

  final _DashboardData data;

  @override
  Widget build(BuildContext context) {
    final items = <_SummaryItem>[
      _SummaryItem(
        label: 'Toplam Kaynak',
        value: data.sources.length,
        icon: Icons.hub_outlined,
      ),
      _SummaryItem(
        label: 'Aktif Sayfa',
        value: data.activePageCount,
        icon: Icons.language_outlined,
      ),
      _SummaryItem(
        label: 'Aktif Görev',
        value: data.activeJobCount,
        icon: Icons.radar_outlined,
      ),
      _SummaryItem(
        label: 'Yeni Olay',
        value: data.newEventCount,
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
        icon: Icons.warning_amber_rounded,
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
          columns = 3;
        }

        const spacing = 14.0;

        final cardWidth =
            (constraints.maxWidth - ((columns - 1) * spacing)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: items
              .map(
                (item) => SizedBox(
                  width: cardWidth,
                  child: _SummaryCard(item: item),
                ),
              )
              .toList(growable: false),
        );
      },
    );
  }
}

class _SourceHealthCard extends StatelessWidget {
  const _SourceHealthCard({required this.data});

  final _DashboardData data;

  @override
  Widget build(BuildContext context) {
    return _PanelCard(
      title: 'Kaynak Sağlığı',
      icon: Icons.monitor_heart_outlined,
      child: Column(
        children: [
          _MetricRow(
            label: 'Sağlıklı',
            value: data.healthySourceCount,
            color: const Color(0xFF2C8F83),
          ),
          _MetricRow(
            label: 'Performansı düşmüş',
            value: data.degradedSourceCount,
            color: const Color(0xFFE39A25),
          ),
          _MetricRow(
            label: 'Başarısız',
            value: data.failedSourceCount,
            color: const Color(0xFFC83C4E),
          ),
          _MetricRow(
            label: 'Engellenmiş',
            value: data.blockedSourceCount,
            color: const Color(0xFF7C6A92),
          ),
          _MetricRow(
            label: 'Durumu bilinmeyen',
            value: data.unknownSourceCount,
            color: const Color(0xFF687580),
          ),
        ],
      ),
    );
  }
}

class _RiskOverviewCard extends StatelessWidget {
  const _RiskOverviewCard({required this.data});

  final _DashboardData data;

  @override
  Widget build(BuildContext context) {
    return _PanelCard(
      title: 'Marka Risk Görünümü',
      icon: Icons.shield_outlined,
      child: Column(
        children: [
          _MetricRow(
            label: 'Kritik riskli sayfa',
            value: data.criticalRiskPageCount,
            color: const Color(0xFFC83C4E),
          ),
          _MetricRow(
            label: 'Yüksek riskli sayfa',
            value: data.highRiskPageCount,
            color: const Color(0xFFDF6C2F),
          ),
          _MetricRow(
            label: 'Orta riskli sayfa',
            value: data.mediumRiskPageCount,
            color: const Color(0xFFE39A25),
          ),
          _MetricRow(
            label: 'Başarısız tarama serisi',
            value: data.failedPageCount,
            color: const Color(0xFF7C6A92),
          ),
          _MetricRow(
            label: 'Ortalama sayfa risk puanı',
            value: data.averageRiskScore,
            suffix: '/100',
            color: _healthScoreColor(100 - data.averageRiskScore),
          ),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final actions = <_QuickAction>[
      _QuickAction(
        label: 'İzlenen Sayfalar',
        icon: Icons.language_outlined,
        onTap: () => AppRouter.openIzlenenSayfalar(context),
      ),
      _QuickAction(
        label: 'Tarama Görevleri',
        icon: Icons.radar_outlined,
        onTap: () => AppRouter.openTaramaGorevleri(context),
      ),
      _QuickAction(
        label: 'İzleme Olayları',
        icon: Icons.timeline_outlined,
        onTap: () => AppRouter.openIzlemeOlaylari(context),
      ),
      _QuickAction(
        label: 'Risk Sinyalleri',
        icon: Icons.notification_important_outlined,
        onTap: () => AppRouter.openRiskSinyalleri(context),
      ),
    ];

    return _PanelCard(
      title: 'Hızlı İşlemler',
      icon: Icons.bolt_outlined,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 720;

          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: actions
                .map(
                  (action) => SizedBox(
                    width: narrow
                        ? constraints.maxWidth
                        : (constraints.maxWidth - 12) / 2,
                    child: OutlinedButton.icon(
                      onPressed: action.onTap,
                      icon: Icon(action.icon),
                      label: Text(action.label),
                      style: OutlinedButton.styleFrom(
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(growable: false),
          );
        },
      ),
    );
  }
}

class _RecentEventsCard extends StatelessWidget {
  const _RecentEventsCard({required this.events});

  final List<MonitoringEventModel> events;

  @override
  Widget build(BuildContext context) {
    return _PanelCard(
      title: 'Son İzleme Olayları',
      icon: Icons.timeline_outlined,
      trailing: TextButton(
        onPressed: () => AppRouter.openIzlemeOlaylari(context),
        child: const Text('Tümünü Gör'),
      ),
      child: events.isEmpty
          ? const _EmptyPanelText(text: 'Henüz izleme olayı üretilmedi.')
          : Column(
              children: events
                  .map(
                    (event) => _FeedRow(
                      icon: Icons.change_circle_outlined,
                      title: event.summary ?? event.eventType.value,
                      subtitle:
                          '${event.eventCategory.value} • '
                          '${_formatDateTime(event.detectedAt)}',
                      color: _eventSeverityColor(event.severity),
                    ),
                  )
                  .toList(growable: false),
            ),
    );
  }
}

class _RecentSignalsCard extends StatelessWidget {
  const _RecentSignalsCard({required this.signals});

  final List<MonitoringSignalModel> signals;

  @override
  Widget build(BuildContext context) {
    return _PanelCard(
      title: 'Son Risk Sinyalleri',
      icon: Icons.notification_important_outlined,
      trailing: TextButton(
        onPressed: () => AppRouter.openRiskSinyalleri(context),
        child: const Text('Tümünü Gör'),
      ),
      child: signals.isEmpty
          ? const _EmptyPanelText(text: 'Henüz risk sinyali üretilmedi.')
          : Column(
              children: signals
                  .map(
                    (signal) => _FeedRow(
                      icon: Icons.warning_amber_rounded,
                      title: signal.title,
                      subtitle:
                          '${signal.ruleName ?? signal.ruleId} • '
                          '${_formatDateTime(signal.detectedAt)}',
                      color: _signalLevelColor(signal.signalLevel),
                    ),
                  )
                  .toList(growable: false),
            ),
    );
  }
}

class _PanelCard extends StatelessWidget {
  const _PanelCard({
    required this.title,
    required this.icon,
    required this.child,
    this.trailing,
  });

  final String title;
  final IconData icon;
  final Widget child;
  final Widget? trailing;

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
              ?trailing,
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
      constraints: const BoxConstraints(minHeight: 118),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: const Color(0xFFE0E7EC)),
      ),
      child: Row(
        children: [
          Container(
            width: 47,
            height: 47,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F6F4),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(item.icon, color: MarkaKalkanTheme.teal),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${item.value}',
                  style: const TextStyle(
                    color: MarkaKalkanTheme.navy,
                    fontSize: 27,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  item.label,
                  style: const TextStyle(
                    color: Color(0xFF687580),
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
    this.suffix = '',
  });

  final String label;
  final int value;
  final Color color;
  final String suffix;

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
            '$value$suffix',
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
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  final IconData icon;
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
          Icon(icon, color: color, size: 21),
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

class _EmptyPanelText extends StatelessWidget {
  const _EmptyPanelText({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 22),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Color(0xFF7A8791),
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
              'Dijital Pazar Ana Paneli yüklenemedi.',
              textAlign: TextAlign.center,
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

class _QuickAction {
  const _QuickAction({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
}

class _DashboardData {
  const _DashboardData({
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

  int get activePageCount => pages
      .where(
        (page) => page.trackingStatus == MonitoringPageTrackingStatus.active,
      )
      .length;

  int get activeJobCount =>
      jobs.where((job) => job.status == MonitoringCrawlJobStatus.active).length;

  int get newEventCount => events
      .where((event) => event.status == MonitoringEventStatus.newEvent)
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

  int get healthySourceCount => sources
      .where(
        (source) => source.healthStatus == MonitoringSourceHealthStatus.healthy,
      )
      .length;

  int get degradedSourceCount => sources
      .where(
        (source) =>
            source.healthStatus == MonitoringSourceHealthStatus.degraded,
      )
      .length;

  int get failedSourceCount => sources
      .where(
        (source) => source.healthStatus == MonitoringSourceHealthStatus.failed,
      )
      .length;

  int get blockedSourceCount => sources
      .where(
        (source) => source.healthStatus == MonitoringSourceHealthStatus.blocked,
      )
      .length;

  int get unknownSourceCount => sources
      .where(
        (source) => source.healthStatus == MonitoringSourceHealthStatus.unknown,
      )
      .length;

  int get criticalRiskPageCount => pages
      .where((page) => page.riskLevel == MonitoringSignalLevel.critical)
      .length;

  int get highRiskPageCount => pages
      .where((page) => page.riskLevel == MonitoringSignalLevel.high)
      .length;

  int get mediumRiskPageCount => pages
      .where((page) => page.riskLevel == MonitoringSignalLevel.medium)
      .length;

  int get failedPageCount =>
      pages.where((page) => page.consecutiveFailureCount > 0).length;

  int get averageRiskScore {
    if (pages.isEmpty) {
      return 0;
    }

    final total = pages.fold<int>(0, (sum, page) => sum + page.riskScore);

    return (total / pages.length).round();
  }

  int get operationalHealthScore {
    if (sources.isEmpty && pages.isEmpty && jobs.isEmpty) {
      return 100;
    }

    var score = 100;

    score -= failedSourceCount * 15;
    score -= blockedSourceCount * 18;
    score -= degradedSourceCount * 6;
    score -= failedPageCount * 4;
    score -= urgentSignalCount * 5;

    if (activePageCount == 0 && pages.isNotEmpty) {
      score -= 15;
    }

    if (activeJobCount == 0 && jobs.isNotEmpty) {
      score -= 15;
    }

    return score.clamp(0, 100);
  }
}

Color _healthScoreColor(int score) {
  if (score >= 85) {
    return const Color(0xFF45C4A8);
  }

  if (score >= 65) {
    return const Color(0xFFE3B34A);
  }

  return const Color(0xFFFF7A7A);
}

Color _eventSeverityColor(MonitoringEventSeverity severity) {
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

Color _signalLevelColor(MonitoringSignalLevel level) {
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

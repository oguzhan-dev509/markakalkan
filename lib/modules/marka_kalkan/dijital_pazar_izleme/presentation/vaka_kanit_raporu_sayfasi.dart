import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:markakalkan/core/theme/markakalkan_theme.dart';

import '../constants/monitoring_enums.dart';
import '../models/monitored_page_model.dart';
import '../models/monitoring_event_model.dart';
import '../models/monitoring_signal_model.dart';
import '../models/page_snapshot_model.dart';
import '../repositories/monitored_page_repository.dart';
import '../repositories/monitoring_event_repository.dart';
import '../repositories/monitoring_signal_repository.dart';
import '../repositories/page_snapshot_repository.dart';
import '../services/monitoring_pdf_report_service.dart';

class VakaKanitRaporuSayfasi extends StatefulWidget {
  const VakaKanitRaporuSayfasi({super.key});

  @override
  State<VakaKanitRaporuSayfasi> createState() => _VakaKanitRaporuSayfasiState();
}

class _VakaKanitRaporuSayfasiState extends State<VakaKanitRaporuSayfasi> {
  Future<_CaseEvidenceData>? _future;

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
          ? Future<_CaseEvidenceData>.error(
              StateError('Vaka / Kanıt Raporu için oturum açılmalıdır.'),
            )
          : _loadData(tenantId);
    });
  }

  Future<_CaseEvidenceData> _loadData(String tenantId) async {
    final pageRepository = MonitoredPageRepository.instance(tenantId: tenantId);
    final eventRepository = MonitoringEventRepository.instance(
      tenantId: tenantId,
    );
    final signalRepository = MonitoringSignalRepository.instance(
      tenantId: tenantId,
    );
    final snapshotRepository = PageSnapshotRepository.instance(
      tenantId: tenantId,
    );

    final results = await Future.wait<dynamic>([
      pageRepository.watchAll(limit: 500).first,
      eventRepository.watchRecent(limit: 200).first,
      signalRepository.watchRecent(limit: 500).first,
    ]);

    final pages = results[0] as List<MonitoredPageModel>;
    final events = results[1] as List<MonitoringEventModel>;
    final signals = results[2] as List<MonitoringSignalModel>;

    final snapshotIds = <String>{};

    for (final event in events) {
      if (event.previousSnapshotId.trim().isNotEmpty) {
        snapshotIds.add(event.previousSnapshotId.trim());
      }

      if (event.currentSnapshotId.trim().isNotEmpty) {
        snapshotIds.add(event.currentSnapshotId.trim());
      }
    }

    final snapshotEntries = await Future.wait(
      snapshotIds.map(
        (snapshotId) async =>
            MapEntry(snapshotId, await snapshotRepository.getById(snapshotId)),
      ),
    );

    final snapshotMap = <String, PageSnapshotModel>{};

    for (final entry in snapshotEntries) {
      final snapshot = entry.value;

      if (snapshot != null) {
        snapshotMap[entry.key] = snapshot;
      }
    }

    final pageMap = <String, MonitoredPageModel>{
      for (final page in pages) page.id: page,
    };

    final signalsByEvent = <String, List<MonitoringSignalModel>>{};

    for (final signal in signals) {
      signalsByEvent
          .putIfAbsent(signal.eventId, () => <MonitoringSignalModel>[])
          .add(signal);
    }

    final evidenceCases = events
        .map((event) {
          final relatedSignals =
              signalsByEvent[event.id] ?? const <MonitoringSignalModel>[];

          return _EvidenceCase(
            event: event,
            page: pageMap[event.pageId],
            previousSnapshot: snapshotMap[event.previousSnapshotId],
            currentSnapshot: snapshotMap[event.currentSnapshotId],
            signals: List<MonitoringSignalModel>.unmodifiable(relatedSignals),
          );
        })
        .toList(growable: false);

    return _CaseEvidenceData(
      pages: pages,
      events: events,
      signals: signals,
      snapshots: List<PageSnapshotModel>.unmodifiable(snapshotMap.values),
      evidenceCases: evidenceCases,
      generatedAt: DateTime.now(),
    );
  }

  Future<void> _openCasePdf({required bool saveOrShare}) async {
    final future = _future;

    if (future == null) {
      return;
    }

    try {
      final data = await future;
      final report = _casePdfData(data);

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
          'Vaka / Kanıt Raporu',
          style: TextStyle(
            color: MarkaKalkanTheme.navy,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'PDF \u00d6nizle / Yazd\u0131r',
            onPressed: () => _openCasePdf(saveOrShare: false),
            icon: const Icon(Icons.picture_as_pdf_outlined),
          ),
          IconButton(
            tooltip: 'PDF Kaydet / Payla\u015f',
            onPressed: () => _openCasePdf(saveOrShare: true),
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
      body: FutureBuilder<_CaseEvidenceData>(
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
                    _EvidenceHeader(data: data),
                    const SizedBox(height: 22),
                    _SummaryGrid(data: data),
                    const SizedBox(height: 22),
                    _EvidenceIntegrityCard(data: data),
                    const SizedBox(height: 22),
                    _EvidenceFlowCard(),
                    const SizedBox(height: 22),
                    _CaseList(data: data),
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

MonitoringPdfReportData _casePdfData(_CaseEvidenceData data) {
  final caseSections = data.evidenceCases
      .take(50)
      .map(
        (evidenceCase) => MonitoringPdfSection(
          title:
              evidenceCase.event.summary ?? evidenceCase.event.eventType.value,
          description:
              '${evidenceCase.event.eventCategory.value} - '
              '${_formatDateTime(evidenceCase.event.detectedAt)}',
          rows: [
            MonitoringPdfRow(
              label: 'Sayfa',
              value: evidenceCase.pageDisplayName,
            ),
            MonitoringPdfRow(
              label: 'Sayfa URL',
              value:
                  evidenceCase.page?.url ?? 'Sayfa kayd\u0131 bulunamad\u0131',
            ),
            MonitoringPdfRow(
              label: 'Olay seviyesi',
              value: evidenceCase.event.severity.value,
            ),
            MonitoringPdfRow(
              label: 'Kan\u0131t zinciri',
              value: evidenceCase.integrityLabel,
            ),
            MonitoringPdfRow(
              label: '\u00d6nceki snapshot',
              value: evidenceCase.event.previousSnapshotId.trim().isEmpty
                  ? 'Yok'
                  : evidenceCase.event.previousSnapshotId,
            ),
            MonitoringPdfRow(
              label: 'G\u00fcncel snapshot',
              value: evidenceCase.event.currentSnapshotId.trim().isEmpty
                  ? 'Yok'
                  : evidenceCase.event.currentSnapshotId,
            ),
            MonitoringPdfRow(
              label: '\u0130li\u015fkili sinyal',
              value: '${evidenceCase.signals.length}',
            ),
            MonitoringPdfRow(
              label: 'Hash kan\u0131t\u0131',
              value: evidenceCase.hasHashEvidence ? 'Var' : 'Eksik',
            ),
          ],
        ),
      )
      .toList(growable: false);

  return MonitoringPdfReportData(
    title: 'Dijital Pazar Vaka / Kan\u0131t Raporu',
    subtitle:
        'Sayfa s\u00fcr\u00fcmleri, de\u011fi\u015fiklik olaylar\u0131 ve risk '
        'sinyallerini kronolojik kan\u0131t zincirinde birle\u015ftiren '
        'inceleme raporu.',
    fileNamePrefix: 'markakalkan_vaka_kanit_raporu',
    generatedAt: data.generatedAt,
    scoreLabel: 'Kan\u0131t B\u00fct\u00fcnl\u00fc\u011f\u00fc',
    scoreValue: '${data.integrityScore}/100',
    metrics: [
      MonitoringPdfMetric(
        label: 'Vaka / Olay',
        value: '${data.evidenceCases.length}',
      ),
      MonitoringPdfMetric(
        label: 'Tam Kan\u0131t Zinciri',
        value: '${data.completeCaseCount}',
      ),
      MonitoringPdfMetric(label: 'Snapshot', value: '${data.snapshots.length}'),
      MonitoringPdfMetric(
        label: 'Eksik Snapshot Vakas\u0131',
        value: '${data.missingSnapshotCaseCount}',
      ),
      MonitoringPdfMetric(
        label: 'Hashli Snapshot',
        value: '${data.hashedSnapshotCount}',
      ),
      MonitoringPdfMetric(
        label: 'Sinyal Ba\u011flant\u0131l\u0131 Vaka',
        value: '${data.caseWithSignalCount}',
      ),
    ],
    sections: [
      MonitoringPdfSection(
        title:
            'Kan\u0131t B\u00fct\u00fcnl\u00fc\u011f\u00fc De\u011ferlendirmesi',
        paragraphs: [
          data.evidenceHeadline,
          data.evidenceCases.isEmpty
              ? 'Hen\u00fcz raporlanabilir vaka veya olay bulunmuyor.'
              : '${data.evidenceCases.length} vaka i\u00e7in kan\u0131t '
                    'zinciri kapsam\u0131 incelenmi\u015ftir.',
        ],
      ),
      MonitoringPdfSection(
        title: 'Kan\u0131t Kapsam\u0131',
        rows: [
          MonitoringPdfRow(
            label: 'Toplam izlenen sayfa',
            value: '${data.pages.length}',
          ),
          MonitoringPdfRow(
            label: 'Toplam olay',
            value: '${data.events.length}',
          ),
          MonitoringPdfRow(
            label: 'Toplam risk sinyali',
            value: '${data.signals.length}',
          ),
          MonitoringPdfRow(
            label: 'Tam snapshot \u00e7ifti',
            value: '${data.completeSnapshotPairCount}',
          ),
          MonitoringPdfRow(
            label: 'HTML ar\u015fivi bulunan snapshot',
            value: '${data.htmlArchiveCount}',
          ),
          MonitoringPdfRow(
            label: 'Ekran g\u00f6r\u00fcnt\u00fcs\u00fc bulunan snapshot',
            value: '${data.screenshotCount}',
          ),
        ],
      ),
      const MonitoringPdfSection(
        title: 'Kan\u0131t Zinciri Ak\u0131\u015f\u0131',
        paragraphs: [
          '1. \u0130zlenen sayfan\u0131n \u00f6nceki ve g\u00fcncel '
              's\u00fcr\u00fcmleri kaydedilir.',
          '2. S\u00fcr\u00fcmler aras\u0131ndaki de\u011fi\u015fiklik olay '
              'olarak s\u0131n\u0131fland\u0131r\u0131l\u0131r.',
          '3. Snapshot hashleri, HTML ar\u015fivi ve ekran '
              'g\u00f6r\u00fcnt\u00fcs\u00fc kan\u0131t kapsam\u0131na eklenir.',
          '4. Risk sinyalleri olay ve sayfa kay\u0131tlar\u0131yla '
              'ili\u015fkilendirilir.',
          '5. Vaka kayd\u0131 inceleme ve hukuki de\u011ferlendirmeye '
              'haz\u0131r hale getirilir.',
        ],
      ),
      ...caseSections,
    ],
    footerNote:
        'Bu rapor MarkaKalkan canl\u0131 vaka, olay, snapshot ve risk '
        'sinyali verilerinden \u00fcretilmi\u015ftir.',
  );
}

class _EvidenceHeader extends StatelessWidget {
  const _EvidenceHeader({required this.data});

  final _CaseEvidenceData data;

  @override
  Widget build(BuildContext context) {
    final integrity = data.integrityScore;
    final integrityColor = _integrityColor(integrity);

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
            width: 140,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: Column(
              children: [
                Text(
                  '$integrity%',
                  style: TextStyle(
                    color: integrityColor,
                    fontSize: 35,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Kanıt Bütünlüğü',
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
                'Dijital Pazar Vaka ve Kanıt Görünümü',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 9),
              const Text(
                'Sayfa sürümleri, değişiklik olayları ve risk sinyallerini '
                'kronolojik kanıt zincirinde birleştiren inceleme raporu.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFFD9E5EA), height: 1.5),
              ),
              const SizedBox(height: 14),
              Text(
                data.evidenceHeadline,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: integrityColor,
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

  final _CaseEvidenceData data;

  @override
  Widget build(BuildContext context) {
    final items = <_SummaryItem>[
      _SummaryItem(
        label: 'Vaka Adayı',
        value: data.evidenceCases.length,
        icon: Icons.folder_copy_outlined,
      ),
      _SummaryItem(
        label: 'İzleme Olayı',
        value: data.events.length,
        icon: Icons.timeline_outlined,
      ),
      _SummaryItem(
        label: 'Snapshot',
        value: data.snapshots.length,
        icon: Icons.layers_outlined,
      ),
      _SummaryItem(
        label: 'Risk Sinyali',
        value: data.signals.length,
        icon: Icons.notification_important_outlined,
      ),
      _SummaryItem(
        label: 'Tam Zincir',
        value: data.completeCaseCount,
        icon: Icons.verified_outlined,
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

class _EvidenceIntegrityCard extends StatelessWidget {
  const _EvidenceIntegrityCard({required this.data});

  final _CaseEvidenceData data;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Kanıt Bütünlüğü Kontrolü',
      icon: Icons.verified_user_outlined,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 760;

          final snapshotChecks = Column(
            children: [
              _MetricRow(
                label: 'İki snapshot bulunan olay',
                value: data.completeSnapshotPairCount,
                color: const Color(0xFF2C8F83),
              ),
              _MetricRow(
                label: 'Eksik snapshot bağlantısı',
                value: data.missingSnapshotCaseCount,
                color: const Color(0xFFC83C4E),
              ),
              _MetricRow(
                label: 'Hash bulunan snapshot',
                value: data.hashedSnapshotCount,
                color: const Color(0xFF4B7895),
              ),
            ],
          );

          final archiveChecks = Column(
            children: [
              _MetricRow(
                label: 'HTML arşivi bulunan snapshot',
                value: data.htmlArchiveCount,
                color: const Color(0xFF2C8F83),
              ),
              _MetricRow(
                label: 'Ekran görüntüsü bulunan snapshot',
                value: data.screenshotCount,
                color: const Color(0xFF4B7895),
              ),
              _MetricRow(
                label: 'Sinyalle desteklenen olay',
                value: data.caseWithSignalCount,
                color: const Color(0xFFE39A25),
              ),
            ],
          );

          if (narrow) {
            return Column(
              children: [
                snapshotChecks,
                const Divider(height: 28),
                archiveChecks,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: snapshotChecks),
              const SizedBox(width: 28),
              Expanded(child: archiveChecks),
            ],
          );
        },
      ),
    );
  }
}

class _EvidenceFlowCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final steps = <_FlowStep>[
      const _FlowStep(
        title: 'İzlenen Sayfa',
        description: 'URL, satıcı, mağaza ve ürün bağlamı',
        icon: Icons.language_outlined,
      ),
      const _FlowStep(
        title: 'Önceki Sürüm',
        description: 'Değişiklik öncesi snapshot ve hash',
        icon: Icons.history_outlined,
      ),
      const _FlowStep(
        title: 'Güncel Sürüm',
        description: 'Değişiklik sonrası snapshot ve hash',
        icon: Icons.layers_outlined,
      ),
      const _FlowStep(
        title: 'İzleme Olayı',
        description: 'Eski/yeni değer ve değişiklik türü',
        icon: Icons.change_circle_outlined,
      ),
      const _FlowStep(
        title: 'Risk Sinyali',
        description: 'Kural, seviye ve inceleme sonucu',
        icon: Icons.notification_important_outlined,
      ),
    ];

    return _SectionCard(
      title: 'Kanıt Zinciri',
      icon: Icons.account_tree_outlined,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final vertical = constraints.maxWidth < 850;

          if (vertical) {
            return Column(
              children: steps
                  .map(
                    (step) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _FlowStepCard(step: step),
                    ),
                  )
                  .toList(growable: false),
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var index = 0; index < steps.length; index++) ...[
                Expanded(child: _FlowStepCard(step: steps[index])),
                if (index < steps.length - 1)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 7, vertical: 25),
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      color: Color(0xFF9AA7B0),
                    ),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _CaseList extends StatelessWidget {
  const _CaseList({required this.data});

  final _CaseEvidenceData data;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Vaka / Kanıt Kayıtları',
      icon: Icons.fact_check_outlined,
      child: data.evidenceCases.isEmpty
          ? const _EmptyState()
          : Column(
              children: data.evidenceCases
                  .take(100)
                  .map(
                    (evidenceCase) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _EvidenceCaseTile(evidenceCase: evidenceCase),
                    ),
                  )
                  .toList(growable: false),
            ),
    );
  }
}

class _EvidenceCaseTile extends StatelessWidget {
  const _EvidenceCaseTile({required this.evidenceCase});

  final _EvidenceCase evidenceCase;

  @override
  Widget build(BuildContext context) {
    final event = evidenceCase.event;
    final color = _eventColor(event.severity);

    return ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFE0E7EC)),
      ),
      collapsedShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFE0E7EC)),
      ),
      backgroundColor: Colors.white,
      collapsedBackgroundColor: const Color(0xFFF9FAFB),
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(Icons.fact_check_outlined, color: color),
      ),
      title: Text(
        event.summary ?? event.eventType.value,
        style: const TextStyle(
          color: MarkaKalkanTheme.navy,
          fontWeight: FontWeight.w800,
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 5),
        child: Text(
          '${event.eventCategory.value} • '
          '${_formatDateTime(event.detectedAt)} • '
          '${evidenceCase.integrityLabel}',
          style: TextStyle(
            color: evidenceCase.isComplete
                ? const Color(0xFF2C8F83)
                : const Color(0xFFDF6C2F),
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      children: [
        _EvidenceSection(
          title: 'Sayfa Bağlamı',
          icon: Icons.language_outlined,
          children: [
            _DetailRow(label: 'Sayfa', value: evidenceCase.pageDisplayName),
            _DetailRow(
              label: 'URL',
              value: evidenceCase.page?.url ?? 'Sayfa kaydı bulunamadı',
            ),
            _DetailRow(label: 'Sayfa kimliği', value: event.pageId),
            _DetailRow(label: 'Kaynak kimliği', value: event.sourceId),
          ],
        ),
        const SizedBox(height: 12),
        _EvidenceSection(
          title: 'Değişiklik Bulgusu',
          icon: Icons.compare_arrows_outlined,
          children: [
            _DetailRow(label: 'Olay türü', value: event.eventType.value),
            _DetailRow(
              label: 'Olay kategorisi',
              value: event.eventCategory.value,
            ),
            _DetailRow(label: 'Önem seviyesi', value: event.severity.value),
            _DetailRow(label: 'Durum', value: event.status.value),
            _DetailRow(
              label: 'Eski değer',
              value: _displayValue(event.oldValue),
            ),
            _DetailRow(
              label: 'Yeni değer',
              value: _displayValue(event.newValue),
            ),
            _DetailRow(
              label: 'Değişim oranı',
              value: event.changeRate == null
                  ? 'Hesaplanmadı'
                  : '%${event.changeRate!.toStringAsFixed(2)}',
            ),
          ],
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final narrow = constraints.maxWidth < 760;

            final previous = _SnapshotCard(
              title: 'Önceki Snapshot',
              snapshot: evidenceCase.previousSnapshot,
              expectedId: event.previousSnapshotId,
            );

            final current = _SnapshotCard(
              title: 'Güncel Snapshot',
              snapshot: evidenceCase.currentSnapshot,
              expectedId: event.currentSnapshotId,
            );

            if (narrow) {
              return Column(
                children: [previous, const SizedBox(height: 12), current],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: previous),
                const SizedBox(width: 12),
                Expanded(child: current),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        _SignalEvidenceSection(signals: evidenceCase.signals),
      ],
    );
  }
}

class _SnapshotCard extends StatelessWidget {
  const _SnapshotCard({
    required this.title,
    required this.snapshot,
    required this.expectedId,
  });

  final String title;
  final PageSnapshotModel? snapshot;
  final String expectedId;

  @override
  Widget build(BuildContext context) {
    final value = snapshot;

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: value == null
            ? const Color(0xFFFFF8F0)
            : const Color(0xFFF5FAF9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: value == null
              ? const Color(0xFFF1C99B)
              : const Color(0xFFCFE8E4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                value == null
                    ? Icons.warning_amber_rounded
                    : Icons.verified_outlined,
                color: value == null
                    ? const Color(0xFFDF6C2F)
                    : const Color(0xFF2C8F83),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: MarkaKalkanTheme.navy,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (value == null)
            Text(
              'Snapshot bulunamadı: ${_shortId(expectedId)}',
              style: const TextStyle(
                color: Color(0xFF9A5E25),
                fontWeight: FontWeight.w700,
              ),
            )
          else ...[
            _DetailRow(label: 'Sürüm', value: '${value.versionNumber}'),
            _DetailRow(
              label: 'Yakalanma zamanı',
              value: _formatDateTime(value.capturedAt),
            ),
            _DetailRow(
              label: 'İçerik hash',
              value: _hashDisplay(value.contentHash),
            ),
            _DetailRow(
              label: 'Metin hash',
              value: _hashDisplay(value.textHash),
            ),
            _DetailRow(
              label: 'Görsel seti hash',
              value: _hashDisplay(value.imageSetHash),
            ),
            _DetailRow(
              label: 'HTML arşivi',
              value: value.hasArchivedHtml ? 'Mevcut' : 'Yok',
            ),
            _DetailRow(
              label: 'Ekran görüntüsü',
              value: value.hasScreenshot ? 'Mevcut' : 'Yok',
            ),
            _DetailRow(label: 'Parser sürümü', value: value.parserVersion),
          ],
        ],
      ),
    );
  }
}

class _SignalEvidenceSection extends StatelessWidget {
  const _SignalEvidenceSection({required this.signals});

  final List<MonitoringSignalModel> signals;

  @override
  Widget build(BuildContext context) {
    return _EvidenceSection(
      title: 'İlişkili Risk Sinyalleri',
      icon: Icons.notification_important_outlined,
      children: signals.isEmpty
          ? const [
              _DetailRow(
                label: 'Sinyal',
                value: 'Bu olay için risk sinyali üretilmemiş',
              ),
            ]
          : signals
                .map(
                  (signal) => Container(
                    margin: const EdgeInsets.only(bottom: 9),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _signalColor(
                        signal.signalLevel,
                      ).withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          signal.title,
                          style: TextStyle(
                            color: _signalColor(signal.signalLevel),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          signal.summary,
                          style: const TextStyle(
                            color: Color(0xFF53616B),
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _DetailRow(
                          label: 'Seviye',
                          value: signal.signalLevel.value,
                        ),
                        _DetailRow(
                          label: 'İnceleme durumu',
                          value: signal.status.value,
                        ),
                        _DetailRow(
                          label: 'İletim durumu',
                          value: signal.forwardingStatus.value,
                        ),
                        _DetailRow(
                          label: 'Kural',
                          value: signal.ruleName ?? signal.ruleId,
                        ),
                        if (signal.resolutionNote != null)
                          _DetailRow(
                            label: 'Çözüm notu',
                            value: signal.resolutionNote!,
                          ),
                      ],
                    ),
                  ),
                )
                .toList(growable: false),
    );
  }
}

class _EvidenceSection extends StatelessWidget {
  const _EvidenceSection({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FA),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, color: MarkaKalkanTheme.teal, size: 21),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: MarkaKalkanTheme.navy,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _FlowStepCard extends StatelessWidget {
  const _FlowStepCard({required this.step});

  final _FlowStep step;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 116),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FA),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Icon(step.icon, color: MarkaKalkanTheme.teal, size: 27),
          const SizedBox(height: 9),
          Text(
            step.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: MarkaKalkanTheme.navy,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            step.description,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF687580),
              fontSize: 11,
              height: 1.35,
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

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 145,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF7A8791),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(
                color: Color(0xFF37454F),
                fontSize: 12,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 34),
      child: Column(
        children: [
          Icon(Icons.fact_check_outlined, size: 48, color: Color(0xFF9AA7B0)),
          SizedBox(height: 12),
          Text(
            'Henüz vaka oluşturacak izleme olayı bulunmuyor.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: MarkaKalkanTheme.navy,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Worker yeni snapshot ve değişiklik olayları ürettiğinde '
            'kanıt zincirleri burada otomatik oluşacaktır.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF7A8791), height: 1.45),
          ),
        ],
      ),
    );
  }
}

class _ReportMetadata extends StatelessWidget {
  const _ReportMetadata({required this.data});

  final _CaseEvidenceData data;

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
            'Canlı kanıt verisi',
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
              'Vaka / Kanıt Raporu yüklenemedi.',
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

class _CaseEvidenceData {
  const _CaseEvidenceData({
    required this.pages,
    required this.events,
    required this.signals,
    required this.snapshots,
    required this.evidenceCases,
    required this.generatedAt,
  });

  final List<MonitoredPageModel> pages;
  final List<MonitoringEventModel> events;
  final List<MonitoringSignalModel> signals;
  final List<PageSnapshotModel> snapshots;
  final List<_EvidenceCase> evidenceCases;
  final DateTime generatedAt;

  int get completeCaseCount =>
      evidenceCases.where((item) => item.isComplete).length;

  int get completeSnapshotPairCount => evidenceCases
      .where(
        (item) => item.previousSnapshot != null && item.currentSnapshot != null,
      )
      .length;

  int get missingSnapshotCaseCount => evidenceCases
      .where(
        (item) => item.previousSnapshot == null || item.currentSnapshot == null,
      )
      .length;

  int get hashedSnapshotCount => snapshots
      .where(
        (snapshot) =>
            _hasText(snapshot.contentHash) ||
            _hasText(snapshot.textHash) ||
            _hasText(snapshot.imageSetHash),
      )
      .length;

  int get htmlArchiveCount =>
      snapshots.where((snapshot) => snapshot.hasArchivedHtml).length;

  int get screenshotCount =>
      snapshots.where((snapshot) => snapshot.hasScreenshot).length;

  int get caseWithSignalCount =>
      evidenceCases.where((item) => item.signals.isNotEmpty).length;

  int get integrityScore {
    if (evidenceCases.isEmpty) {
      return 100;
    }

    final totalPoints = evidenceCases.fold<int>(
      0,
      (sum, item) => sum + item.integrityPoints,
    );

    return ((totalPoints / (evidenceCases.length * 5)) * 100).round().clamp(
      0,
      100,
    );
  }

  String get evidenceHeadline {
    if (evidenceCases.isEmpty) {
      return 'Henüz olay üretilmedi; kanıt raporu veri bekliyor.';
    }

    if (missingSnapshotCaseCount > 0) {
      return '$missingSnapshotCaseCount olayda snapshot bağlantısı eksik.';
    }

    if (integrityScore >= 80) {
      return 'Kanıt zincirleri yüksek bütünlük seviyesinde.';
    }

    return 'Kanıt zincirlerinin arşiv ve hash kapsamı geliştirilmeli.';
  }
}

class _EvidenceCase {
  const _EvidenceCase({
    required this.event,
    required this.page,
    required this.previousSnapshot,
    required this.currentSnapshot,
    required this.signals,
  });

  final MonitoringEventModel event;
  final MonitoredPageModel? page;
  final PageSnapshotModel? previousSnapshot;
  final PageSnapshotModel? currentSnapshot;
  final List<MonitoringSignalModel> signals;

  bool get hasHashEvidence {
    final previous = previousSnapshot;
    final current = currentSnapshot;

    return previous != null &&
        current != null &&
        (_hasText(previous.contentHash) ||
            _hasText(previous.textHash) ||
            _hasText(previous.imageSetHash)) &&
        (_hasText(current.contentHash) ||
            _hasText(current.textHash) ||
            _hasText(current.imageSetHash));
  }

  int get integrityPoints {
    var points = 0;

    if (page != null) {
      points++;
    }

    if (previousSnapshot != null) {
      points++;
    }

    if (currentSnapshot != null) {
      points++;
    }

    if (hasHashEvidence) {
      points++;
    }

    if (signals.isNotEmpty) {
      points++;
    }

    return points;
  }

  bool get isComplete => integrityPoints == 5;

  String get integrityLabel {
    if (isComplete) {
      return 'Tam kanıt zinciri';
    }

    if (previousSnapshot == null || currentSnapshot == null) {
      return 'Snapshot bağlantısı eksik';
    }

    if (!hasHashEvidence) {
      return 'Hash kapsamı eksik';
    }

    if (signals.isEmpty) {
      return 'Sinyal bağlantısı yok';
    }

    return 'Kısmi kanıt zinciri';
  }

  String get pageDisplayName {
    final value = page;

    if (value == null) {
      return 'Sayfa kaydı bulunamadı';
    }

    return value.title ??
        value.productName ??
        value.storeName ??
        value.domain ??
        _shortId(value.id);
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

class _FlowStep {
  const _FlowStep({
    required this.title,
    required this.description,
    required this.icon,
  });

  final String title;
  final String description;
  final IconData icon;
}

bool _hasText(String? value) {
  return value != null && value.trim().isNotEmpty;
}

String _hashDisplay(String? value) {
  if (!_hasText(value)) {
    return 'Yok';
  }

  return _shortId(value!);
}

String _displayValue(dynamic value) {
  if (value == null) {
    return 'Yok';
  }

  if (value is Map || value is List) {
    return value.toString();
  }

  final text = value.toString().trim();

  return text.isEmpty ? 'Boş değer' : text;
}

String _shortId(String value) {
  final cleaned = value.trim();

  if (cleaned.length <= 28) {
    return cleaned;
  }

  return '${cleaned.substring(0, 14)}…'
      '${cleaned.substring(cleaned.length - 10)}';
}

String _formatDateTime(DateTime value) {
  final local = value.toLocal();

  String twoDigits(int number) => number.toString().padLeft(2, '0');

  return '${twoDigits(local.day)}.${twoDigits(local.month)}.${local.year} '
      '${twoDigits(local.hour)}:${twoDigits(local.minute)}';
}

Color _integrityColor(int score) {
  if (score >= 80) {
    return const Color(0xFF45C4A8);
  }

  if (score >= 55) {
    return const Color(0xFFE3B34A);
  }

  return const Color(0xFFFF7A7A);
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

import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:markakalkan/features/risk_scan/data/public_lite_risk_scan_repository.dart';
import 'package:markakalkan/features/risk_scan/presentation/public_lite_risk_scan_controller.dart';

const Key publicLiteRiskScanBrandFieldKey = Key('publicLiteRiskScanBrandField');
const Key publicLiteRiskScanWebsiteFieldKey = Key(
  'publicLiteRiskScanWebsiteField',
);
const Key publicLiteRiskScanStartButtonKey = Key(
  'publicLiteRiskScanStartButton',
);
const Key publicLiteRiskScanRefreshButtonKey = Key(
  'publicLiteRiskScanRefreshButton',
);
const Key publicLiteRiskScanReportButtonKey = Key(
  'publicLiteRiskScanReportButton',
);
const Key publicLiteRiskScanStatusRegionKey = Key(
  'publicLiteRiskScanStatusRegion',
);
const Key publicLiteRiskScanTimelineKey = Key('publicLiteRiskScanTimeline');
const Key publicLiteRiskScanTrustNoticeKey = Key(
  'publicLiteRiskScanTrustNotice',
);
const Key publicLiteRiskScanRetryButtonKey = Key(
  'publicLiteRiskScanRetryButton',
);
const Key publicLiteRiskScanRestartButtonKey = Key(
  'publicLiteRiskScanRestartButton',
);
const Key publicLiteRiskScanResultFocusKey = Key(
  'publicLiteRiskScanResultFocus',
);

final class PublicLiteRiskScanPreviewPage extends StatefulWidget {
  const PublicLiteRiskScanPreviewPage({
    super.key,
    this.repository,
    this.controller,
    this.requestIdFactory,
    this.clientNonceFactory,
  });

  final PublicLiteRiskScanRepository? repository;
  final PublicLiteRiskScanController? controller;
  final String Function()? requestIdFactory;
  final String Function()? clientNonceFactory;

  @override
  State<PublicLiteRiskScanPreviewPage> createState() =>
      _PublicLiteRiskScanPreviewPageState();
}

final class _PublicLiteRiskScanPreviewPageState
    extends State<PublicLiteRiskScanPreviewPage>
    with WidgetsBindingObserver {
  final _formKey = GlobalKey<FormState>();
  final _brandController = TextEditingController();
  final _websiteController = TextEditingController();
  final _resultFocusNode = FocusNode(debugLabel: 'publicLiteRiskScanResult');

  late final PublicLiteRiskScanController _operation;
  late final bool _ownsOperation;
  late final String Function() _requestIdFactory;
  late final String Function() _clientNonceFactory;
  late PublicLiteRiskScanOperationState _lastOperationState;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _ownsOperation = widget.controller == null;
    _operation =
        widget.controller ??
        PublicLiteRiskScanController(
          repository:
              widget.repository ?? CallablePublicLiteRiskScanRepository(),
        );
    _requestIdFactory = widget.requestIdFactory ?? _newUuidV4;
    _clientNonceFactory = widget.clientNonceFactory ?? _newClientNonce;
    _lastOperationState = _operation.state;
  }

  void _scheduleFocusForTransition() {
    final nextState = _operation.state;
    if (nextState == _lastOperationState) return;
    _lastOperationState = nextState;

    final shouldFocus =
        nextState == PublicLiteRiskScanOperationState.completed ||
        nextState == PublicLiteRiskScanOperationState.terminal ||
        nextState == PublicLiteRiskScanOperationState.expired ||
        nextState == PublicLiteRiskScanOperationState.failed;
    if (!shouldFocus) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_resultFocusNode.canRequestFocus) return;
      _resultFocusNode.requestFocus();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _operation.setForeground(state == AppLifecycleState.resumed);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_ownsOperation) {
      _operation.dispose();
    }
    _resultFocusNode.dispose();
    _brandController.dispose();
    _websiteController.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    if (_operation.isBusy || !(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    await _operation.start(
      PublicLiteRiskScanStartRequest(
        requestId: _requestIdFactory(),
        brandName: _brandController.text,
        officialWebsiteUrl: _websiteController.text,
        anonymousClientNonce: _clientNonceFactory(),
      ),
    );
  }

  Future<void> _retry() async {
    final state = _operation.state;
    if (_operation.projection == null ||
        state == PublicLiteRiskScanOperationState.failed ||
        state == PublicLiteRiskScanOperationState.terminal ||
        state == PublicLiteRiskScanOperationState.expired) {
      await _start();
      return;
    }
    await _operation.refreshNow();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _operation,
      builder: (context, _) {
        final projection = _operation.projection;
        _scheduleFocusForTransition();

        return Scaffold(
          appBar: AppBar(title: const Text('Hızlı Risk Taraması — Önizleme')),
          body: SafeArea(
            child: SelectionArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1040),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const _PreviewNotice(),
                        const SizedBox(height: 20),
                        const _PurposeGrid(),
                        const SizedBox(height: 16),
                        const _TrustNotice(),
                        const SizedBox(height: 24),
                        _buildForm(context),
                        Focus(
                          key: publicLiteRiskScanResultFocusKey,
                          focusNode: _resultFocusNode,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (_operation.errorMessage != null) ...[
                                const SizedBox(height: 16),
                                _ErrorCard(
                                  message: _operation.errorMessage!,
                                  onRetry: _operation.isBusy ? null : _retry,
                                ),
                              ],
                              if (projection != null) ...[
                                const SizedBox(height: 24),
                                _buildProjection(context, projection),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildForm(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Marka ve resmî kaynak',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text(
                'Bu önizleme yalnız destek engeli çözülmeden önceki '
                'frontend entegrasyonunu doğrulamak içindir.',
              ),
              const SizedBox(height: 18),
              TextFormField(
                key: publicLiteRiskScanBrandFieldKey,
                controller: _brandController,
                enabled: !_operation.isBusy,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Marka adı',
                  hintText: 'Örnek: MarkaKalkan',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Marka adı gereklidir.'
                    : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                key: publicLiteRiskScanWebsiteFieldKey,
                controller: _websiteController,
                enabled: !_operation.isBusy,
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'Resmî internet adresi',
                  hintText: 'https://ornek.com',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  final uri = Uri.tryParse(value?.trim() ?? '');
                  if (uri == null ||
                      (uri.scheme != 'http' && uri.scheme != 'https') ||
                      uri.host.isEmpty ||
                      uri.userInfo.isNotEmpty) {
                    return 'Geçerli bir HTTP(S) adresi girin.';
                  }
                  return null;
                },
                onFieldSubmitted: (_) {
                  _start();
                },
              ),
              const SizedBox(height: 18),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  key: publicLiteRiskScanStartButtonKey,
                  onPressed: _operation.isBusy ? null : _start,
                  icon: _operation.isBusy
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.radar),
                  label: Text(
                    _operation.isBusy ? 'İşlem sürüyor' : 'Taramayı başlat',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProjection(
    BuildContext context,
    PublicLiteRiskScanProjection projection,
  ) {
    final report = projection.report;
    final remaining = _operation.remainingAccess;

    return Semantics(
      key: publicLiteRiskScanStatusRegionKey,
      container: true,
      liveRegion: true,
      label: _operation.accessibilityStatus,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _OperationTimeline(
            key: publicLiteRiskScanTimelineKey,
            status: projection.status,
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        projection.isReportReady
                            ? Icons.task_alt
                            : Icons.manage_search,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _operation.outcome == 'idempotent_success'
                                  ? 'Mevcut tarama güvenli biçimde geri getirildi'
                                  : 'Tarama oluşturuldu',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 4),
                            Text('Durum: ${_statusLabel(projection.status)}'),
                            Text(
                              'Kapsama: '
                              '${_coverageLabel(projection.coverageStatus)}',
                            ),
                            Text('Tarama no: ${projection.scanRunId}'),
                            if (remaining != null)
                              Text(
                                'Erişim süresi: '
                                '${_remainingLabel(remaining)}',
                              ),
                            Text(
                              _operation.isForeground
                                  ? 'Otomatik izleme etkin'
                                  : 'Otomatik izleme duraklatıldı',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      OutlinedButton.icon(
                        key: publicLiteRiskScanRefreshButtonKey,
                        onPressed:
                            _operation.isBusy ||
                                !_operation.isForeground ||
                                _operation.state ==
                                    PublicLiteRiskScanOperationState.expired
                            ? null
                            : _operation.refreshNow,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Şimdi yenile'),
                      ),
                      FilledButton.tonalIcon(
                        key: publicLiteRiskScanReportButtonKey,
                        onPressed:
                            _operation.isBusy ||
                                !projection.isReportReady ||
                                report != null
                            ? null
                            : _operation.loadReportNow,
                        icon: const Icon(Icons.description_outlined),
                        label: Text(
                          report == null ? 'Raporu getir' : 'Rapor hazır',
                        ),
                      ),
                      if (_operation.state ==
                              PublicLiteRiskScanOperationState.terminal ||
                          _operation.state ==
                              PublicLiteRiskScanOperationState.expired)
                        FilledButton.icon(
                          key: publicLiteRiskScanRestartButtonKey,
                          onPressed: _operation.isBusy ? null : _start,
                          icon: const Icon(Icons.restart_alt),
                          label: const Text('Yeni tarama başlat'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Erişim anahtarı yalnız controller belleğinde tutulur; '
                    'ekranda gösterilmez ve kalıcı depoya yazılmaz.',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _ChannelCard(channels: projection.channels),
          if (report != null) ...[
            const SizedBox(height: 16),
            _ReportCard(report: report),
          ],
        ],
      ),
    );
  }
}

final class _PreviewNotice extends StatelessWidget {
  const _PreviewNotice();

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: const Padding(
        padding: EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.science_outlined),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'İzole frontend önizlemesi: Firebase Rules UpdateRelease '
                'destek engeli çözülene kadar bu ekran ana sayfa veya kamu '
                'navigasyonunda yayımlanmayacaktır.',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final class _TrustNotice extends StatelessWidget {
  const _TrustNotice();

  @override
  Widget build(BuildContext context) {
    return Card(
      key: publicLiteRiskScanTrustNoticeKey,
      child: const Padding(
        padding: EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.privacy_tip_outlined),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Veri kullanımı ve gizlilik',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Bu Public Lite akışı hesap girişi veya kişisel profil '
                    'bilgisi istemez. Marka adı ve resmî internet adresi '
                    'yalnız taramanın oluşturulması, durumunun izlenmesi ve '
                    'maskelenmiş raporun sunulması amacıyla işlenir. Erişim '
                    'anahtarı cihazda kalıcı olarak saklanmaz ve bu ekran '
                    'sonuçları kendiliğinden kamuya yayımlamaz.',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final class _PurposeGrid extends StatelessWidget {
  const _PurposeGrid();

  @override
  Widget build(BuildContext context) {
    const items = <_PurposeItem>[
      _PurposeItem(
        Icons.shield_outlined,
        'Bu bölüm ne işe yarar?',
        'Marka adı ve resmî internet kaynağı üzerinden hızlı kamu risk '
            'taramasını başlatır.',
      ),
      _PurposeItem(
        Icons.schedule_outlined,
        'Ne zaman kullanmalısınız?',
        'Markanızın açık web, benzer alan adı ve sınırlı pazaryeri '
            'kanallarındaki ilk risk görünümünü görmek istediğinizde.',
      ),
      _PurposeItem(
        Icons.fact_check_outlined,
        'Bu işlem için ne gerekir?',
        'Marka adı, doğrulanabilir resmî HTTP(S) adresi ve geçerli App Check '
            'güvenlik bağlamı.',
      ),
      _PurposeItem(
        Icons.summarize_outlined,
        'İşlem sonunda ne elde edersiniz?',
        'Kanal kapsamı, gözlem ve bulgu sayaçları ile hazır olduğunda '
            'maskelenmiş Public Lite risk raporu.',
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth >= 760
            ? (constraints.maxWidth - 16) / 2
            : constraints.maxWidth;

        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            for (final item in items)
              SizedBox(
                width: width,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(item.icon),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.title,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 6),
                              Text(item.body),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

final class _PurposeItem {
  const _PurposeItem(this.icon, this.title, this.body);

  final IconData icon;
  final String title;
  final String body;
}

final class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Wrap(
          spacing: 16,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Icon(Icons.error_outline),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Text(message),
            ),
            OutlinedButton.icon(
              key: publicLiteRiskScanRetryButtonKey,
              onPressed: onRetry,
              icon: const Icon(Icons.replay),
              label: const Text('Tekrar dene'),
            ),
          ],
        ),
      ),
    );
  }
}

final class _ChannelCard extends StatelessWidget {
  const _ChannelCard({required this.channels});

  final List<PublicLiteRiskScanChannel> channels;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Tarama kanalları',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            for (final channel in channels)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.travel_explore_outlined),
                  title: Text(_channelLabel(channel.channelCode)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Durum: ${_statusLabel(channel.status)} · '
                        'Kapsama: '
                        '${_coverageLabel(channel.coverageStatus)}',
                      ),
                      if (channel.limitReasonCodes.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Sınırlama nedenleri: '
                          '${channel.limitReasonCodes.map(_limitReasonLabel).join(' · ')}',
                        ),
                      ],
                    ],
                  ),
                  trailing: Text(
                    '${channel.observationCount} gözlem\n'
                    '${channel.findingCount} bulgu',
                    textAlign: TextAlign.end,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

final class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.report});

  final PublicLiteRiskScanReport report;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Public Lite risk raporu',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text('Rapor üretim zamanı: ${_dateTimeLabel(report.generatedAt)}'),
            const SizedBox(height: 10),
            Text(report.summary ?? 'Rapor özeti bulunmuyor.'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                Text(
                  'Genel risk: '
                  '${_riskLevelLabel(report.overallRiskLevel)}',
                ),
                Text(
                  'Güven: '
                  '${_confidenceLabel(report.overallConfidenceLevel)}',
                ),
                Text('Bulgu: ${report.findingCount}'),
                Text('Gözlem: ${report.observationCount}'),
              ],
            ),
            const SizedBox(height: 16),
            DecoratedBox(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.next_plan_outlined),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Önerilen sonraki adım: '
                        '${_recommendedActionLabel(report.recommendedAction)}',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (report.channelDistribution.isNotEmpty) ...[
              const Divider(height: 32),
              Text(
                'Rapor kanal dağılımı',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              for (final channel in report.channelDistribution)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.donut_small_outlined),
                  title: Text(_channelLabel(channel.channelCode)),
                  subtitle: Text(
                    'Kapsama: '
                    '${_coverageLabel(channel.coverageStatus)} · '
                    'Durum: ${_statusLabel(channel.status)}',
                  ),
                  trailing: Text(
                    '${channel.observationCount} gözlem\n'
                    '${channel.findingCount} bulgu',
                    textAlign: TextAlign.end,
                  ),
                ),
            ],
            if (report.topFindingSnapshots.isNotEmpty) ...[
              const Divider(height: 32),
              Text(
                'Öne çıkan bulgular',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              for (final finding in report.topFindingSnapshots)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.warning_amber_outlined),
                  title: Text(finding.title ?? 'Başlıksız bulgu'),
                  subtitle: Text(finding.summary ?? 'Özet bulunmuyor.'),
                  trailing: Text(_riskLevelLabel(finding.riskLevel)),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

final class _OperationTimeline extends StatelessWidget {
  const _OperationTimeline({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    const stages = <String>[
      'Hazırlık',
      'Kaynak tarama',
      'Risk değerlendirme',
      'Raporlama',
      'Sonuç',
    ];
    final currentIndex = _operationStageIndex(status);
    final terminal =
        status == 'failedTerminal' ||
        status == 'cancelled' ||
        status == 'expired';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Tarama ilerlemesi',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final itemWidth = constraints.maxWidth >= 850
                    ? (constraints.maxWidth - 48) / 5
                    : constraints.maxWidth >= 520
                    ? (constraints.maxWidth - 12) / 2
                    : constraints.maxWidth;

                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (var index = 0; index < stages.length; index += 1)
                      SizedBox(
                        width: itemWidth,
                        child: _ProgressStage(
                          label: index == stages.length - 1 && terminal
                              ? 'Sonlandırıldı'
                              : stages[index],
                          completed: index < currentIndex,
                          active: index == currentIndex,
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

final class _ProgressStage extends StatelessWidget {
  const _ProgressStage({
    required this.label,
    required this.completed,
    required this.active,
  });

  final String label;
  final bool completed;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final icon = completed
        ? Icons.check_circle
        : active
        ? Icons.radio_button_checked
        : Icons.radio_button_unchecked;
    final color = completed || active
        ? colorScheme.primary
        : colorScheme.outline;

    return Semantics(
      label:
          '$label: '
          '${completed
              ? 'tamamlandı'
              : active
              ? 'şu anda yürütülüyor'
              : 'bekliyor'}',
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: color),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 8),
              Expanded(child: Text(label)),
            ],
          ),
        ),
      ),
    );
  }
}

String _statusLabel(String? value) {
  const labels = <String, String>{
    'created': 'Oluşturuldu',
    'validatingTarget': 'Hedef doğrulanıyor',
    'queued': 'Kuyrukta',
    'acquiring': 'Kaynaklar taranıyor',
    'assessing': 'Risk değerlendiriliyor',
    'reporting': 'Rapor hazırlanıyor',
    'completed': 'Tamamlandı',
    'completedWithLimits': 'Sınırlı kapsamla tamamlandı',
    'failedRetryable': 'Yeniden denenebilir hata',
    'failedTerminal': 'Tamamlanamayan hata',
    'cancelled': 'İptal edildi',
    'expired': 'Süresi doldu',
  };
  if (value == null) return 'Bilinmiyor';
  return labels[value] ?? value;
}

String _coverageLabel(String? value) {
  const labels = <String, String>{
    'complete': 'Tam',
    'limited': 'Sınırlı',
    'insufficient': 'Yetersiz',
  };
  if (value == null) return 'Bilinmiyor';
  return labels[value] ?? value;
}

String _channelLabel(String? value) {
  const labels = <String, String>{
    'similarDomains': 'Benzer alan adları',
    'openWeb': 'Açık web',
    'marketplaceLimited': 'Sınırlı pazaryeri',
  };
  if (value == null) return 'Bilinmeyen kanal';
  return labels[value] ?? value;
}

String _limitReasonLabel(String value) {
  const labels = <String, String>{
    'public_lite_scope': 'Public Lite kapsam sınırı',
    'marketplace_limited': 'Pazaryeri erişimi sınırlı',
    'robots_restricted': 'Kaynak otomatik erişimi sınırlandırdı',
    'rate_limited': 'Kaynak sorgu hızını sınırladı',
    'source_unavailable': 'Kaynak geçici olarak kullanılamadı',
    'insufficient_public_data': 'Yeterli kamuya açık veri bulunamadı',
    'timeout': 'Kaynak zamanında yanıt vermedi',
  };
  return labels[value] ?? value;
}

String _recommendedActionLabel(String? value) {
  const labels = <String, String>{
    'review_top_findings': 'Öne çıkan bulguları inceleyin',
    'claim_scan': 'Taramayı hesabınıza bağlayın',
    'start_human_review': 'Uzman incelemesi başlatın',
    'no_immediate_action': 'Şimdilik acil işlem gerekmiyor',
  };
  if (value == null) return 'Belirtilmedi';
  return labels[value] ?? value;
}

String _riskLevelLabel(String? value) {
  const labels = <String, String>{
    'low': 'Düşük',
    'medium': 'Orta',
    'high': 'Yüksek',
    'critical': 'Kritik',
  };
  if (value == null) return 'Belirtilmedi';
  return labels[value] ?? value;
}

String _confidenceLabel(String? value) {
  const labels = <String, String>{
    'low': 'Düşük',
    'medium': 'Orta',
    'high': 'Yüksek',
  };
  if (value == null) return 'Belirtilmedi';
  return labels[value] ?? value;
}

String _dateTimeLabel(DateTime? value) {
  if (value == null) return 'Belirtilmedi';
  final utc = value.toUtc();
  String twoDigits(int number) => number.toString().padLeft(2, '0');

  return '${twoDigits(utc.day)}.${twoDigits(utc.month)}.${utc.year} '
      '${twoDigits(utc.hour)}:${twoDigits(utc.minute)} UTC';
}

int _operationStageIndex(String status) {
  if (status == 'created' ||
      status == 'validatingTarget' ||
      status == 'queued') {
    return 0;
  }
  if (status == 'acquiring') return 1;
  if (status == 'assessing' || status == 'failedRetryable') return 2;
  if (status == 'reporting') return 3;
  if (status == 'completed' ||
      status == 'completedWithLimits' ||
      status == 'failedTerminal' ||
      status == 'cancelled' ||
      status == 'expired') {
    return 4;
  }
  return 0;
}

String _remainingLabel(Duration value) {
  if (value <= Duration.zero) return 'Süre doldu';
  final hours = value.inHours;
  final minutes = value.inMinutes.remainder(60);
  final seconds = value.inSeconds.remainder(60);

  if (hours > 0) {
    return '$hours sa $minutes dk';
  }
  if (minutes > 0) {
    return '$minutes dk $seconds sn';
  }
  return '$seconds sn';
}

String _newUuidV4() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes
      .map((value) => value.toRadixString(16).padLeft(2, '0'))
      .join();

  return '${hex.substring(0, 8)}-'
      '${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-'
      '${hex.substring(16, 20)}-'
      '${hex.substring(20)}';
}

String _newClientNonce() {
  final random = Random.secure();
  final bytes = List<int>.generate(32, (_) => random.nextInt(256));
  return base64UrlEncode(bytes).replaceAll('=', '');
}

import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:markakalkan/features/risk_scan/data/public_lite_risk_scan_repository.dart';

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

final class PublicLiteRiskScanPreviewPage extends StatefulWidget {
  const PublicLiteRiskScanPreviewPage({
    super.key,
    this.repository,
    this.requestIdFactory,
    this.clientNonceFactory,
  });

  final PublicLiteRiskScanRepository? repository;
  final String Function()? requestIdFactory;
  final String Function()? clientNonceFactory;

  @override
  State<PublicLiteRiskScanPreviewPage> createState() =>
      _PublicLiteRiskScanPreviewPageState();
}

final class _PublicLiteRiskScanPreviewPageState
    extends State<PublicLiteRiskScanPreviewPage> {
  final _formKey = GlobalKey<FormState>();
  final _brandController = TextEditingController();
  final _websiteController = TextEditingController();

  late final PublicLiteRiskScanRepository _repository;
  late final String Function() _requestIdFactory;
  late final String Function() _clientNonceFactory;

  String? _accessKey;
  String? _outcome;
  String? _errorMessage;
  PublicLiteRiskScanProjection? _projection;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? CallablePublicLiteRiskScanRepository();
    _requestIdFactory = widget.requestIdFactory ?? _newUuidV4;
    _clientNonceFactory = widget.clientNonceFactory ?? _newClientNonce;
  }

  @override
  void dispose() {
    _accessKey = null;
    _brandController.dispose();
    _websiteController.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    if (_busy || !(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _busy = true;
      _errorMessage = null;
      _projection = null;
      _accessKey = null;
      _outcome = null;
    });

    try {
      final result = await _repository.start(
        PublicLiteRiskScanStartRequest(
          requestId: _requestIdFactory(),
          brandName: _brandController.text,
          officialWebsiteUrl: _websiteController.text,
          anonymousClientNonce: _clientNonceFactory(),
        ),
      );
      if (!mounted) return;
      setState(() {
        _accessKey = result.accessKey;
        _projection = result.projection;
        _outcome = result.outcome;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = _messageFor(error);
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _refreshStatus() async {
    final accessKey = _accessKey;
    if (_busy || accessKey == null) return;

    setState(() {
      _busy = true;
      _errorMessage = null;
    });

    try {
      final projection = await _repository.getStatus(accessKey);
      if (!mounted) return;
      setState(() {
        _projection = projection;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = _messageFor(error);
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _loadReport() async {
    final accessKey = _accessKey;
    if (_busy || accessKey == null) return;

    setState(() {
      _busy = true;
      _errorMessage = null;
    });

    try {
      final projection = await _repository.getReport(accessKey);
      if (!mounted) return;
      setState(() {
        _projection = projection;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = _messageFor(error);
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  String _messageFor(Object error) {
    if (error is PublicLiteRiskScanRepositoryException) {
      return error.message;
    }
    if (error is FormatException) {
      return error.message.toString();
    }
    return 'Risk taraması işlemi tamamlanamadı.';
  }

  @override
  Widget build(BuildContext context) {
    final projection = _projection;

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
                    const SizedBox(height: 24),
                    _buildForm(context),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 16),
                      _ErrorCard(message: _errorMessage!),
                    ],
                    if (projection != null) ...[
                      const SizedBox(height: 24),
                      _buildProjection(context, projection),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
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
                enabled: !_busy,
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
                enabled: !_busy,
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
                  onPressed: _busy ? null : _start,
                  icon: _busy
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.radar),
                  label: Text(_busy ? 'İşlem sürüyor' : 'Taramayı başlat'),
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
                            _outcome == 'idempotent_success'
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
                      onPressed: _busy ? null : _refreshStatus,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Durumu yenile'),
                    ),
                    FilledButton.tonalIcon(
                      key: publicLiteRiskScanReportButtonKey,
                      onPressed: _busy || !projection.isReportReady
                          ? null
                          : _loadReport,
                      icon: const Icon(Icons.description_outlined),
                      label: const Text('Raporu getir'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Erişim anahtarı yalnız bu sayfanın geçici belleğinde '
                  'tutulur; ekranda gösterilmez ve kalıcı depoya yazılmaz.',
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
  const _ErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            const Icon(Icons.error_outline),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
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
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.travel_explore_outlined),
                title: Text(_channelLabel(channel.channelCode)),
                subtitle: Text(
                  'Durum: ${_statusLabel(channel.status)} · '
                  'Kapsama: ${_coverageLabel(channel.coverageStatus)}',
                ),
                trailing: Text(
                  '${channel.observationCount} gözlem\n'
                  '${channel.findingCount} bulgu',
                  textAlign: TextAlign.end,
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
            const SizedBox(height: 10),
            Text(report.summary ?? 'Rapor özeti bulunmuyor.'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                Text('Genel risk: ${_nullableLabel(report.overallRiskLevel)}'),
                Text('Güven: ${_nullableLabel(report.overallConfidenceLevel)}'),
                Text('Bulgu: ${report.findingCount}'),
                Text('Gözlem: ${report.observationCount}'),
              ],
            ),
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
                  trailing: Text(_nullableLabel(finding.riskLevel)),
                ),
            ],
          ],
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

String _nullableLabel(String? value) =>
    value == null || value.trim().isEmpty ? 'Belirtilmedi' : value;

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

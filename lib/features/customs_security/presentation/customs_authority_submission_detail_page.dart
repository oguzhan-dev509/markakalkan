import 'package:flutter/material.dart';
import 'package:markakalkan/core/theme/markakalkan_theme.dart';
import 'package:markakalkan/features/customs_security/data/customs_authority_submission_repository.dart';
import 'package:markakalkan/features/customs_security/presentation/customs_authority_submission_labels.dart';

class CustomsAuthoritySubmissionDetailPage extends StatefulWidget {
  const CustomsAuthoritySubmissionDetailPage({
    super.key,
    required this.submissionId,
    this.repository,
  });

  final String submissionId;
  final CustomsAuthoritySubmissionRepository? repository;

  @override
  State<CustomsAuthoritySubmissionDetailPage> createState() =>
      _CustomsAuthoritySubmissionDetailPageState();
}

class _CustomsAuthoritySubmissionDetailPageState
    extends State<CustomsAuthoritySubmissionDetailPage> {
  late final CustomsAuthoritySubmissionRepository _repository;
  bool _loading = true;
  String? _error;
  CustomsAuthoritySubmissionDetail? _detail;

  @override
  void initState() {
    super.initState();
    _repository =
        widget.repository ?? CallableCustomsAuthoritySubmissionRepository();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final detail = await _repository.getSubmissionDetail(widget.submissionId);
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = customsAuthoritySubmissionErrorMessage(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MarkaKalkanTheme.background,
      appBar: AppBar(
        title: const Text('Resmî Başvuru ve Kurum İletimi'),
        actions: [
          IconButton(
            tooltip: 'Yenile',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                key: ValueKey('authority-submission-detail-loading'),
              ),
            )
          : _error != null
          ? _AuthorityDetailError(message: _error!, onRetry: _load)
          : _AuthoritySubmissionDetailView(detail: _detail!),
    );
  }
}

class _AuthoritySubmissionDetailView extends StatelessWidget {
  const _AuthoritySubmissionDetailView({required this.detail});

  final CustomsAuthoritySubmissionDetail detail;

  @override
  Widget build(BuildContext context) {
    final submission = detail.submission;
    final currentPackage = detail.packages.isEmpty
        ? null
        : detail.packages.last;
    return ListView(
      key: const ValueKey('customs-authority-submission-detail'),
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 48),
      children: [
        _AuthorityHeader(submission: submission),
        const SizedBox(height: 16),
        const _LegalNotice(),
        const SizedBox(height: 16),
        _AuthoritySection(
          title: 'İletim kimliği ve yönlendirme',
          children: [
            _AuthorityRow(
              label: 'İletim türü',
              value: customsAuthoritySubmissionTypeLabel(
                submission.submissionType,
              ),
            ),
            _AuthorityRow(
              label: 'Hedef kurum',
              value: customsAuthorityTargetLabel(submission.targetAuthority),
            ),
            _AuthorityRow(
              label: 'Hedef birim',
              value: submission.targetUnit ?? 'Belirtilmedi',
            ),
            _AuthorityRow(
              label: 'İletim kanalı',
              value: submission.channelType == null
                  ? 'Henüz seçilmedi'
                  : customsAuthorityChannelLabel(submission.channelType!),
            ),
            _AuthorityRow(
              label: 'Olay / kaynak referansı',
              value: submission.incidentReference,
            ),
            _AuthorityRow(
              label: 'Koruma profili',
              value: submission.protectionProfileId ?? 'Bağlı değil',
            ),
            _AuthorityRow(
              label: 'Sınır müdahalesi',
              value: submission.interventionId ?? 'Bağlı değil',
            ),
          ],
        ),
        _AuthoritySection(
          title: 'Kuruma sunulacak özet',
          children: [
            Text(
              submission.authoritySummary,
              style: const TextStyle(height: 1.5),
            ),
          ],
        ),
        _AuthoritySection(
          title: 'İnsan kontrolü ve hak sahibi kapıları',
          children: [
            _GateRow(
              label: 'İnsan incelemesi',
              passed: submission.humanReviewReference != null,
              detail: submission.humanReviewReference ?? 'Henüz kaydedilmedi',
            ),
            _GateRow(
              label: 'Hak sahibi / temsilci onayı',
              passed: submission.rightsHolderApprovalReference != null,
              detail:
                  submission.rightsHolderApprovalReference ??
                  'Henüz kaydedilmedi',
            ),
            _GateRow(
              label: 'Veri minimizasyonu',
              passed: submission.dataMinimizationConfirmed,
              detail: submission.dataMinimizationConfirmed
                  ? 'Kontrol edildi'
                  : 'Kontrol bekleniyor',
            ),
            _GateRow(
              label: 'Hukuken nötr dil',
              passed: submission.nonAccusatoryLanguageConfirmed,
              detail: submission.nonAccusatoryLanguageConfirmed
                  ? 'Kontrol edildi'
                  : 'Kontrol bekleniyor',
            ),
          ],
        ),
        _AuthoritySection(
          title: 'Paket ve resmî teslim durumu',
          children: [
            _AuthorityRow(
              label: 'Paket sayısı',
              value: '${submission.packageCount}',
            ),
            _AuthorityRow(
              label: 'Güncel paket sürümü',
              value: submission.currentPackageVersion == 0
                  ? 'Henüz yok'
                  : 'v${submission.currentPackageVersion}',
            ),
            _AuthorityRow(
              label: 'Güncel paket hash’i',
              value: submission.currentPackageHash ?? 'Henüz yok',
              monospace: true,
            ),
            _AuthorityRow(
              label: 'Resmî başvuru / ihbar numarası',
              value: submission.officialReferenceNumber ?? 'Henüz kaydedilmedi',
            ),
            _AuthorityRow(
              label: 'Paket bütünlüğü',
              value: currentPackage == null
                  ? 'Paket hazırlanmadı'
                  : '${currentPackage.aggregateHashAlgorithm} · ${currentPackage.aggregateHash}',
              monospace: currentPackage != null,
            ),
            _AuthorityRow(
              label: 'Detay bütünlüğü',
              value: detail.integrityStatus,
            ),
          ],
        ),
        _AuthoritySection(
          title: 'Kurum yanıtları',
          children: detail.responses.isEmpty
              ? const [Text('Henüz kurum yanıtı veya teslim kaydı yok.')]
              : detail.responses
                    .map(
                      (response) => _TimelineCard(
                        title: response.responseType,
                        subtitle: response.summary,
                        meta:
                            '${_formatDateTime(response.receivedAt)} · ${response.outcomeCode ?? 'Sonuç bekleniyor'}',
                      ),
                    )
                    .toList(),
        ),
        _AuthoritySection(
          title: 'Değiştirilemez olay zaman çizelgesi',
          children: detail.events.isEmpty
              ? const [Text('Henüz olay kaydı yok.')]
              : detail.events
                    .map(
                      (event) => _TimelineCard(
                        title: '#${event.sequence} · ${event.eventType}',
                        subtitle: event.summary,
                        meta:
                            '${event.actorLabel} · ${_formatDateTime(event.recordedAt)}',
                      ),
                    )
                    .toList(),
        ),
      ],
    );
  }
}

class _AuthorityHeader extends StatelessWidget {
  const _AuthorityHeader({required this.submission});

  final CustomsAuthoritySubmission submission;

  @override
  Widget build(BuildContext context) {
    final color = customsAuthoritySubmissionStatusColor(submission.status);
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFFE0E7EC)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: const Color(0xFFE8F6F4),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.account_balance_outlined,
                color: MarkaKalkanTheme.teal,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    submission.submissionNumber,
                    style: const TextStyle(
                      color: Color(0xFF687580),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    submission.title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.11),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      customsAuthoritySubmissionStatusLabel(submission.status),
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
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

class _LegalNotice extends StatelessWidget {
  const _LegalNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF0D9A2)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.balance_outlined, size: 21),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'MarkaKalkan bu dosyayı otomatik olarak resmî kuruma göndermez, suç isnadı üretmez ve insan veya hak sahibi onayının yerine geçmez.',
              style: TextStyle(height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthoritySection extends StatelessWidget {
  const _AuthoritySection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 16),
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFE0E7EC)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 14),
            ..._separated(children),
          ],
        ),
      ),
    );
  }
}

class _AuthorityRow extends StatelessWidget {
  const _AuthorityRow({
    required this.label,
    required this.value,
    this.monospace = false,
  });

  final String label;
  final String value;
  final bool monospace;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 210,
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFF687580),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: SelectableText(
            value,
            style: TextStyle(
              height: 1.4,
              fontFamily: monospace ? 'monospace' : null,
            ),
          ),
        ),
      ],
    );
  }
}

class _GateRow extends StatelessWidget {
  const _GateRow({
    required this.label,
    required this.passed,
    required this.detail,
  });

  final String label;
  final bool passed;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          passed ? Icons.check_circle_outline : Icons.schedule_outlined,
          color: passed ? const Color(0xFF1F7A69) : const Color(0xFFB56B18),
          size: 21,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text('$label: $detail', style: const TextStyle(height: 1.4)),
        ),
      ],
    );
  }
}

class _TimelineCard extends StatelessWidget {
  const _TimelineCard({
    required this.title,
    required this.subtitle,
    required this.meta,
  });

  final String title;
  final String subtitle;
  final String meta;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FA),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 5),
          Text(subtitle, style: const TextStyle(height: 1.4)),
          const SizedBox(height: 5),
          Text(meta, style: const TextStyle(color: Color(0xFF687580))),
        ],
      ),
    );
  }
}

class _AuthorityDetailError extends StatelessWidget {
  const _AuthorityDetailError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Yeniden dene'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

List<Widget> _separated(List<Widget> children) {
  if (children.length < 2) return children;
  return [
    for (var index = 0; index < children.length; index++) ...[
      children[index],
      if (index < children.length - 1) const SizedBox(height: 12),
    ],
  ];
}

String _formatDateTime(String value) {
  final parsed = DateTime.tryParse(value)?.toLocal();
  if (parsed == null) return value;
  String two(int number) => number.toString().padLeft(2, '0');
  return '${two(parsed.day)}.${two(parsed.month)}.${parsed.year} ${two(parsed.hour)}:${two(parsed.minute)}';
}

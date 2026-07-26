import 'package:flutter/material.dart';
import 'package:markakalkan/core/theme/markakalkan_theme.dart';
import 'package:markakalkan/features/customs_security/data/customs_authority_submission_repository.dart';
import 'package:markakalkan/features/customs_security/presentation/customs_authority_submission_labels.dart';
import 'package:url_launcher/url_launcher.dart';

typedef CustomsArtifactUrlOpener = Future<bool> Function(Uri uri);

class CustomsAuthoritySubmissionDetailPage extends StatefulWidget {
  const CustomsAuthoritySubmissionDetailPage({
    super.key,
    required this.submissionId,
    this.repository,
    this.urlOpener,
    this.requestIdFactory,
  });

  final String submissionId;
  final CustomsAuthoritySubmissionRepository? repository;
  final CustomsArtifactUrlOpener? urlOpener;
  final String Function()? requestIdFactory;

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
  bool _materializing = false;
  bool _downloadingPdf = false;
  bool _downloadingManifest = false;
  String? _materializationRequestId;

  @override
  void initState() {
    super.initState();
    _repository =
        widget.repository ?? CallableCustomsAuthoritySubmissionRepository();
    _load();
  }

  Future<void> _load({bool newOperation = true}) async {
    if (newOperation) _materializationRequestId = null;
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

  Future<bool> _defaultUrlOpener(Uri uri) =>
      launchUrl(uri, webOnlyWindowName: '_self');

  String _newRequestId() =>
      (widget.requestIdFactory ??
      generateCustomsAuthoritySubmissionRequestId)();

  Future<void> _materialize(CustomsSubmissionPackage package) async {
    if (_materializing) return;
    final scope = _detail?.artifactScope;
    if (scope == null) return;
    setState(() => _materializing = true);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(materializePackage),
        content: const Text(
          'Güncel resmî paket güvenli indirme dosyalarına dönüştürülsün mü?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            key: const ValueKey('confirm-materialize-package'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Oluştur'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (confirmed != true) {
      setState(() => _materializing = false);
      return;
    }
    _materializationRequestId ??= _newRequestId();
    try {
      final result = await _repository.materializePackageArtifact(
        tenantId: scope.tenantId,
        canonicalBrandId: scope.canonicalBrandId,
        submissionId: detail.submission.submissionId,
        packageId: package.packageId,
        requestId: _materializationRequestId!,
      );
      if (!mounted) return;
      if (result.artifactStatus == CustomsSubmissionArtifactStatus.ready) {
        _materializationRequestId = null;
      } else if (result.artifactStatus ==
              CustomsSubmissionArtifactStatus.integrityFailed ||
          result.artifactStatus == CustomsSubmissionArtifactStatus.disabled) {
        _materializationRequestId = null;
      }
      await _load(newOperation: false);
    } catch (error) {
      if (!mounted) return;
      if (!customsArtifactErrorIsRetryable(error)) {
        _materializationRequestId = null;
      }
      _showMessage(customsArtifactErrorMessage(error));
    } finally {
      if (mounted) setState(() => _materializing = false);
    }
  }

  CustomsAuthoritySubmissionDetail get detail => _detail!;

  Future<void> _download(
    CustomsSubmissionPackage package,
    CustomsArtifactType type,
  ) async {
    final isPdf = type == CustomsArtifactType.pdf;
    if ((isPdf ? _downloadingPdf : _downloadingManifest)) return;
    final scope = _detail?.artifactScope;
    final descriptor = isPdf
        ? package.pdfArtifact
        : package.jsonManifestArtifact;
    if (scope == null ||
        package.artifactStatus != CustomsSubmissionArtifactStatus.ready ||
        descriptor?.ready != true) {
      return;
    }
    setState(() {
      if (isPdf) {
        _downloadingPdf = true;
      } else {
        _downloadingManifest = true;
      }
    });
    try {
      final authorization = await _repository.authorizePackageDownload(
        tenantId: scope.tenantId,
        canonicalBrandId: scope.canonicalBrandId,
        submissionId: detail.submission.submissionId,
        packageId: package.packageId,
        artifactType: type,
        requestId: _newRequestId(),
      );
      final opened = await (widget.urlOpener ?? _defaultUrlOpener)(
        authorization.downloadUri,
      );
      if (!mounted) return;
      _showMessage(opened ? 'İndirme bağlantısı açıldı.' : downloadOpenFailed);
    } catch (error) {
      if (!mounted) return;
      _showMessage(customsArtifactErrorMessage(error));
    } finally {
      if (mounted) {
        setState(() {
          if (isPdf) {
            _downloadingPdf = false;
          } else {
            _downloadingManifest = false;
          }
        });
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
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
          : _AuthoritySubmissionDetailView(
              detail: _detail!,
              materializing: _materializing,
              downloadingPdf: _downloadingPdf,
              downloadingManifest: _downloadingManifest,
              onMaterialize: _materialize,
              onDownload: _download,
            ),
    );
  }
}

class _AuthoritySubmissionDetailView extends StatelessWidget {
  const _AuthoritySubmissionDetailView({
    required this.detail,
    required this.materializing,
    required this.downloadingPdf,
    required this.downloadingManifest,
    required this.onMaterialize,
    required this.onDownload,
  });

  final CustomsAuthoritySubmissionDetail detail;
  final bool materializing;
  final bool downloadingPdf;
  final bool downloadingManifest;
  final ValueChanged<CustomsSubmissionPackage> onMaterialize;
  final void Function(
    CustomsSubmissionPackage package,
    CustomsArtifactType type,
  )
  onDownload;

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
        if (currentPackage != null)
          _ArtifactSection(
            package: currentPackage,
            scopeAvailable: detail.artifactScope != null,
            materializing: materializing,
            downloadingPdf: downloadingPdf,
            downloadingManifest: downloadingManifest,
            onMaterialize: () => onMaterialize(currentPackage),
            onDownloadPdf: () =>
                onDownload(currentPackage, CustomsArtifactType.pdf),
            onDownloadManifest: () =>
                onDownload(currentPackage, CustomsArtifactType.jsonManifest),
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

class _ArtifactSection extends StatelessWidget {
  const _ArtifactSection({
    required this.package,
    required this.scopeAvailable,
    required this.materializing,
    required this.downloadingPdf,
    required this.downloadingManifest,
    required this.onMaterialize,
    required this.onDownloadPdf,
    required this.onDownloadManifest,
  });

  final CustomsSubmissionPackage package;
  final bool scopeAvailable;
  final bool materializing;
  final bool downloadingPdf;
  final bool downloadingManifest;
  final VoidCallback onMaterialize;
  final VoidCallback onDownloadPdf;
  final VoidCallback onDownloadManifest;

  @override
  Widget build(BuildContext context) {
    if (!scopeAvailable) {
      return const _AuthoritySection(
        title: artifactSectionTitle,
        children: [Text(scopeUnavailableDescription)],
      );
    }
    final status = package.artifactStatus;
    return _AuthoritySection(
      title: artifactSectionTitle,
      children: switch (status) {
        CustomsSubmissionArtifactStatus.legacyNotMaterialized => [
          const Text(legacyArtifactDescription),
          FilledButton.icon(
            key: const ValueKey('materialize-package'),
            onPressed: materializing ? null : onMaterialize,
            icon: materializing
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.picture_as_pdf_outlined),
            label: const Text(materializePackage),
          ),
        ],
        CustomsSubmissionArtifactStatus.materializationPending => const [
          LinearProgressIndicator(),
          Text(pendingArtifactDescription),
        ],
        CustomsSubmissionArtifactStatus.materializing => const [
          LinearProgressIndicator(),
          Text(materializingArtifactDescription),
        ],
        CustomsSubmissionArtifactStatus.ready => [
          _ArtifactDescriptor(label: 'PDF', descriptor: package.pdfArtifact),
          FilledButton.icon(
            key: const ValueKey('download-package-pdf'),
            onPressed: package.pdfArtifact?.ready == true && !downloadingPdf
                ? onDownloadPdf
                : null,
            icon: downloadingPdf
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download_rounded),
            label: const Text(downloadPdf),
          ),
          _ArtifactDescriptor(
            label: 'JSON manifest',
            descriptor: package.jsonManifestArtifact,
          ),
          OutlinedButton.icon(
            key: const ValueKey('download-package-manifest'),
            onPressed:
                package.jsonManifestArtifact?.ready == true &&
                    !downloadingManifest
                ? onDownloadManifest
                : null,
            icon: downloadingManifest
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download_rounded),
            label: const Text(downloadManifest),
          ),
        ],
        CustomsSubmissionArtifactStatus.failedRecoverable => [
          const Text(failedRecoverableArtifactDescription),
          FilledButton.icon(
            key: const ValueKey('retry-materialize-package'),
            onPressed: materializing ? null : onMaterialize,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text(retryMaterialization),
          ),
        ],
        CustomsSubmissionArtifactStatus.integrityFailed => const [
          Text(integrityFailedArtifactDescription),
          Text(integrityFailedArtifactActionDescription),
        ],
        CustomsSubmissionArtifactStatus.disabled => const [
          Text(disabledArtifactDescription),
        ],
        CustomsSubmissionArtifactStatus.unknown => const [
          Text(unknownArtifactDescription),
        ],
      },
    );
  }
}

class _ArtifactDescriptor extends StatelessWidget {
  const _ArtifactDescriptor({required this.label, required this.descriptor});

  final String label;
  final CustomsSubmissionArtifactDescriptor? descriptor;

  @override
  Widget build(BuildContext context) {
    final value = descriptor;
    if (value?.ready != true) {
      return Text('$label dosyası hazır değil.');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value!.safeFileName ?? label,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        if (value.sizeBytes != null) Text(_formatBytes(value.sizeBytes!)),
        if (value.sha256 != null)
          SelectableText(
            'SHA-256: ${value.sha256}',
            style: const TextStyle(fontFamily: 'monospace'),
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

String _formatBytes(int value) {
  if (value < 1024) return '$value bayt';
  if (value < 1024 * 1024) return '${(value / 1024).toStringAsFixed(1)} KB';
  return '${(value / (1024 * 1024)).toStringAsFixed(1)} MB';
}

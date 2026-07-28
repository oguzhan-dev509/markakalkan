import 'package:flutter/material.dart';
import 'package:markakalkan/core/theme/markakalkan_theme.dart';
import 'package:markakalkan/features/customs_security/data/customs_authority_submission_repository.dart';
import 'package:markakalkan/features/customs_security/presentation/customs_authority_submission_labels.dart';
import 'package:url_launcher/url_launcher.dart';

typedef CustomsArtifactUrlOpener = Future<bool> Function(Uri uri);

enum CustomsAuthoritySubmissionStage {
  submissionContent,
  submissionPackage,
  downloadableOfficialFile,
  authorityDelivery,
  deliveryResponseOutcome,
}

class CustomsAuthoritySubmissionDetailPage extends StatefulWidget {
  const CustomsAuthoritySubmissionDetailPage({
    super.key,
    required this.submissionId,
    this.repository,
    this.urlOpener,
    this.requestIdFactory,
    this.initialStage = CustomsAuthoritySubmissionStage.submissionContent,
  });

  final String submissionId;
  final CustomsAuthoritySubmissionRepository? repository;
  final CustomsArtifactUrlOpener? urlOpener;
  final String Function()? requestIdFactory;
  final CustomsAuthoritySubmissionStage initialStage;

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
  bool _generatingPackage = false;
  bool _materializing = false;
  bool _downloadingPdf = false;
  bool _downloadingManifest = false;
  String? _materializationRequestId;
  bool _recordingExternalSubmission = false;
  String? _externalSubmissionRequestId;
  CustomsExternalSubmissionDraft? _externalSubmissionRetryDraft;
  String? _externalSubmissionPackageId;
  int? _externalSubmissionPackageVersion;
  String? _externalSubmissionPackageHash;
  bool _recordingReceipt = false;
  String? _receiptRequestId;
  CustomsSubmissionReceiptDraft? _receiptRetryDraft;
  bool _appendingAuthorityResponse = false;
  String? _authorityResponseRequestId;
  CustomsAuthorityResponseDraft? _authorityResponseRetryDraft;
  bool _recordingAuthorityOutcome = false;
  String? _authorityOutcomeRequestId;
  CustomsAuthorityOutcomeDraft? _authorityOutcomeRetryDraft;
  final Map<CustomsAuthoritySubmissionStage, GlobalKey> _stageKeys = {
    for (final stage in CustomsAuthoritySubmissionStage.values)
      stage: GlobalKey(debugLabel: 'customs-authority-stage-${stage.name}'),
  };
  bool _initialStageApplied = false;

  @override
  void initState() {
    super.initState();
    _repository =
        widget.repository ?? CallableCustomsAuthoritySubmissionRepository();
    _load();
  }

  Future<void> _load({bool newOperation = true}) async {
    if (newOperation) {
      _materializationRequestId = null;
      _clearExternalSubmissionRetry();
      _clearAuthorityOperationRetries();
    }
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
      _scheduleInitialStageScroll();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = customsAuthoritySubmissionErrorMessage(error);
      });
    }
  }

  void _scheduleInitialStageScroll() {
    if (_initialStageApplied) return;
    _initialStageApplied = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final targetContext = _stageKeys[widget.initialStage]?.currentContext;
      if (targetContext == null) return;
      await Scrollable.ensureVisible(
        targetContext,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        alignment: 0.05,
      );
    });
  }

  Future<bool> _defaultUrlOpener(Uri uri) =>
      launchUrl(uri, webOnlyWindowName: '_self');

  String _newRequestId() =>
      (widget.requestIdFactory ??
      generateCustomsAuthoritySubmissionRequestId)();

  Future<void> _generatePackage() async {
    if (_generatingPackage) return;
    final currentDetail = _detail;
    final scope = currentDetail?.artifactScope;
    if (currentDetail == null ||
        scope == null ||
        !_packageGenerationAllowed(currentDetail.submission)) {
      return;
    }

    try {
      final draft = await showDialog<CustomsSubmissionPackageDraft>(
        context: context,
        barrierDismissible: false,
        builder: (context) =>
            _GeneratePackageDialog(submission: currentDetail.submission),
      );
      if (!mounted || draft == null) return;

      final itemCount =
          draft.documentManifest.length + draft.evidenceManifest.length;
      final confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Başvuru paketini üret'),
          content: Text(
            'Bu işlem $itemCount belge/delil kaydını değiştirilemez bir '
            'başvuru paketine dönüştürür. Paket üretildikten sonra içerik '
            'bu sürüm üzerinde değiştirilemez. Devam edilsin mi?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              key: const ValueKey('confirm-generate-customs-package'),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Paketi üret'),
            ),
          ],
        ),
      );
      if (!mounted || confirmed != true) return;

      setState(() => _generatingPackage = true);
      final requestId = _newRequestId();
      final result = await _repository.generatePackage(
        tenantId: scope.tenantId,
        canonicalBrandId: scope.canonicalBrandId,
        submissionId: currentDetail.submission.submissionId,
        draft: draft,
        requestId: requestId,
      );
      if (!mounted) return;
      _showMessage(
        result.duplicate
            ? 'Aynı paket isteği daha önce uygulanmıştı; güncel kayıt yüklendi.'
            : 'Başvuru paketi hazırlandı',
      );
      await _load(newOperation: false);
    } catch (error) {
      if (!mounted) return;
      _showMessage(customsAuthoritySubmissionErrorMessage(error));
    } finally {
      if (mounted && _generatingPackage) {
        setState(() => _generatingPackage = false);
      }
    }
  }

  void _clearExternalSubmissionRetry() {
    _externalSubmissionRequestId = null;
    _externalSubmissionRetryDraft = null;
    _externalSubmissionPackageId = null;
    _externalSubmissionPackageVersion = null;
    _externalSubmissionPackageHash = null;
  }

  Future<void> _recordExternalSubmission({bool retry = false}) async {
    if (_recordingExternalSubmission) return;
    final currentDetail = _detail;
    final currentPackage = _currentSubmissionPackage(currentDetail);
    final scope = currentDetail?.artifactScope;
    if (currentDetail == null ||
        currentPackage == null ||
        scope == null ||
        _externalSubmissionBlockers(currentDetail, currentPackage).isNotEmpty) {
      return;
    }

    CustomsExternalSubmissionDraft? draft;
    if (retry) {
      final retryDraft = _externalSubmissionRetryDraft;
      final retryRequestId = _externalSubmissionRequestId;
      final retryMatchesPackage =
          _externalSubmissionPackageId == currentPackage.packageId &&
          _externalSubmissionPackageVersion == currentPackage.version &&
          _externalSubmissionPackageHash == currentPackage.aggregateHash;
      if (retryDraft == null ||
          retryRequestId == null ||
          !retryMatchesPackage) {
        _clearExternalSubmissionRetry();
        _showMessage(
          'Yeniden deneme bilgileri güncel paketle eşleşmiyor. '
          'Sayfayı yenileyip teslim kaydını yeniden hazırlayın.',
        );
        return;
      }
      draft = retryDraft;
    } else {
      draft = await showDialog<CustomsExternalSubmissionDraft>(
        context: context,
        barrierDismissible: false,
        builder: (context) => _ExternalSubmissionDialog(
          submission: currentDetail.submission,
          package: currentPackage,
        ),
      );
      if (!mounted || draft == null) return;
    }

    final submissionDraft = draft;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(
          retry ? 'Dış teslim kaydını yeniden dene' : 'Dış teslimi kaydet',
        ),
        content: Text(
          retry
              ? 'Aynı teslim beyanı ve aynı güvenli işlem kimliğiyle yeniden '
                    'denenecek. Güncel paket v${currentPackage.version} ile '
                    'eşleşen kayıt değiştirilemez olay zincirine yazılsın mı?'
              : 'Paket v${currentPackage.version}, '
                    '${customsAuthorityChannelLabel(submissionDraft.submissionChannel.wireValue)} '
                    'kanalından gerçekten teslim edilmiş olarak kaydedilecek. '
                    'Bu kayıt değiştirilemez olay zincirine eklenir ve işlem '
                    'geri alınamaz. Devam edilsin mi?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            key: ValueKey(
              retry
                  ? 'confirm-retry-external-submission'
                  : 'confirm-record-external-submission',
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(retry ? 'Yeniden dene' : 'Teslimi kaydet'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;

    if (!retry) {
      _externalSubmissionRequestId = _newRequestId();
      _externalSubmissionRetryDraft = submissionDraft;
      _externalSubmissionPackageId = currentPackage.packageId;
      _externalSubmissionPackageVersion = currentPackage.version;
      _externalSubmissionPackageHash = currentPackage.aggregateHash;
    }

    setState(() => _recordingExternalSubmission = true);
    try {
      final result = await _repository.recordExternalSubmission(
        tenantId: scope.tenantId,
        canonicalBrandId: scope.canonicalBrandId,
        submissionId: currentDetail.submission.submissionId,
        packageId: currentPackage.packageId,
        packageVersion: currentPackage.version,
        packageHash: currentPackage.aggregateHash,
        draft: submissionDraft,
        requestId: _externalSubmissionRequestId!,
      );
      if (!mounted) return;
      _clearExternalSubmissionRetry();
      _showMessage(
        result.duplicate
            ? 'Aynı dış teslim kaydı daha önce uygulanmıştı; güncel kayıt yüklendi.'
            : 'Kuruma dış teslim kaydedildi',
      );
      await _load(newOperation: false);
    } catch (error) {
      if (!mounted) return;
      if (!customsAuthoritySubmissionErrorIsRetryable(error)) {
        _clearExternalSubmissionRetry();
      }
      _showMessage(customsAuthoritySubmissionErrorMessage(error));
    } finally {
      if (mounted && _recordingExternalSubmission) {
        setState(() => _recordingExternalSubmission = false);
      }
    }
  }

  void _clearAuthorityOperationRetries() {
    _receiptRequestId = null;
    _receiptRetryDraft = null;
    _authorityResponseRequestId = null;
    _authorityResponseRetryDraft = null;
    _authorityOutcomeRequestId = null;
    _authorityOutcomeRetryDraft = null;
  }

  Future<void> _recordReceipt({bool retry = false}) async {
    if (_recordingReceipt) return;
    final currentDetail = _detail;
    final scope = currentDetail?.artifactScope;
    if (currentDetail == null ||
        scope == null ||
        _authorityReceiptBlockers(currentDetail).isNotEmpty) {
      return;
    }

    CustomsSubmissionReceiptDraft? draft;
    if (retry) {
      draft = _receiptRetryDraft;
      if (draft == null || _receiptRequestId == null) {
        _receiptRequestId = null;
        _receiptRetryDraft = null;
        _showMessage(
          'Yeniden deneme bilgileri bulunamadı. Sayfayı yenileyip alındı kaydını yeniden hazırlayın.',
        );
        return;
      }
    } else {
      draft = await showDialog<CustomsSubmissionReceiptDraft>(
        context: context,
        barrierDismissible: false,
        builder: (context) =>
            _AuthorityReceiptDialog(submission: currentDetail.submission),
      );
      if (!mounted || draft == null) return;
    }

    final receiptDraft = draft;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(
          retry ? 'Resmî alındıyı yeniden dene' : 'Resmî alındıyı kaydet',
        ),
        content: Text(
          retry
              ? 'Aynı alındı bilgileri ve aynı güvenli işlem kimliğiyle yeniden denenecek. Değiştirilemez kayıt oluşturulsun mu?'
              : 'Kurumun başvuruyu fiilen teslim aldığına ilişkin bu bilgi değiştirilemez cevap ve olay zincirine yazılacaktır. Devam edilsin mi?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            key: ValueKey(
              retry
                  ? 'confirm-retry-authority-receipt'
                  : 'confirm-record-authority-receipt',
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(retry ? 'Yeniden dene' : 'Alındıyı kaydet'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;

    if (!retry) {
      _receiptRequestId = _newRequestId();
      _receiptRetryDraft = receiptDraft;
    }

    setState(() => _recordingReceipt = true);
    try {
      final result = await _repository.recordReceipt(
        tenantId: scope.tenantId,
        canonicalBrandId: scope.canonicalBrandId,
        submissionId: currentDetail.submission.submissionId,
        draft: receiptDraft,
        requestId: _receiptRequestId!,
      );
      if (!mounted) return;
      _receiptRequestId = null;
      _receiptRetryDraft = null;
      _showMessage(
        result.duplicate
            ? 'Aynı alındı kaydı daha önce uygulanmıştı; güncel kayıt yüklendi.'
            : 'Resmî alındı kaydedildi',
      );
      await _load(newOperation: false);
    } catch (error) {
      if (!mounted) return;
      if (!customsAuthoritySubmissionErrorIsRetryable(error)) {
        _receiptRequestId = null;
        _receiptRetryDraft = null;
      }
      _showMessage(customsAuthoritySubmissionErrorMessage(error));
    } finally {
      if (mounted && _recordingReceipt) {
        setState(() => _recordingReceipt = false);
      }
    }
  }

  Future<void> _appendAuthorityResponse({bool retry = false}) async {
    if (_appendingAuthorityResponse) return;
    final currentDetail = _detail;
    final scope = currentDetail?.artifactScope;
    if (currentDetail == null ||
        scope == null ||
        _authorityResponseBlockers(currentDetail).isNotEmpty) {
      return;
    }

    CustomsAuthorityResponseDraft? draft;
    if (retry) {
      draft = _authorityResponseRetryDraft;
      if (draft == null || _authorityResponseRequestId == null) {
        _authorityResponseRequestId = null;
        _authorityResponseRetryDraft = null;
        _showMessage(
          'Yeniden deneme bilgileri bulunamadı. Sayfayı yenileyip kurum cevabını yeniden hazırlayın.',
        );
        return;
      }
    } else {
      draft = await showDialog<CustomsAuthorityResponseDraft>(
        context: context,
        barrierDismissible: false,
        builder: (context) => _AuthorityInterimResponseDialog(
          submission: currentDetail.submission,
        ),
      );
      if (!mounted || draft == null) return;
    }

    final responseDraft = draft;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(
          retry ? 'Kurum cevabını yeniden dene' : 'Kurum ara cevabını kaydet',
        ),
        content: Text(
          retry
              ? 'Aynı ara cevap ve aynı güvenli işlem kimliğiyle yeniden denenecek. Değiştirilemez kayıt oluşturulsun mu?'
              : 'Kurumdan gelen bu ara cevap aynı kanonik dosyada değiştirilemez kayıt olarak saklanacaktır. Devam edilsin mi?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            key: ValueKey(
              retry
                  ? 'confirm-retry-authority-response'
                  : 'confirm-append-authority-response',
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(retry ? 'Yeniden dene' : 'Cevabı kaydet'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;

    if (!retry) {
      _authorityResponseRequestId = _newRequestId();
      _authorityResponseRetryDraft = responseDraft;
    }

    setState(() => _appendingAuthorityResponse = true);
    try {
      final result = await _repository.appendAuthorityResponse(
        tenantId: scope.tenantId,
        canonicalBrandId: scope.canonicalBrandId,
        submissionId: currentDetail.submission.submissionId,
        draft: responseDraft,
        requestId: _authorityResponseRequestId!,
      );
      if (!mounted) return;
      _authorityResponseRequestId = null;
      _authorityResponseRetryDraft = null;
      _showMessage(
        result.duplicate
            ? 'Aynı kurum cevabı daha önce uygulanmıştı; güncel kayıt yüklendi.'
            : 'Kurum ara cevabı kaydedildi',
      );
      await _load(newOperation: false);
    } catch (error) {
      if (!mounted) return;
      if (!customsAuthoritySubmissionErrorIsRetryable(error)) {
        _authorityResponseRequestId = null;
        _authorityResponseRetryDraft = null;
      }
      _showMessage(customsAuthoritySubmissionErrorMessage(error));
    } finally {
      if (mounted && _appendingAuthorityResponse) {
        setState(() => _appendingAuthorityResponse = false);
      }
    }
  }

  Future<void> _recordAuthorityOutcome({bool retry = false}) async {
    if (_recordingAuthorityOutcome) return;
    final currentDetail = _detail;
    final scope = currentDetail?.artifactScope;
    if (currentDetail == null ||
        scope == null ||
        _authorityOutcomeBlockers(currentDetail).isNotEmpty) {
      return;
    }

    CustomsAuthorityOutcomeDraft? draft;
    if (retry) {
      draft = _authorityOutcomeRetryDraft;
      if (draft == null || _authorityOutcomeRequestId == null) {
        _authorityOutcomeRequestId = null;
        _authorityOutcomeRetryDraft = null;
        _showMessage(
          'Yeniden deneme bilgileri bulunamadı. Sayfayı yenileyip nihai sonucu yeniden hazırlayın.',
        );
        return;
      }
    } else {
      draft = await showDialog<CustomsAuthorityOutcomeDraft>(
        context: context,
        barrierDismissible: false,
        builder: (context) => _AuthorityOutcomeDialog(detail: currentDetail),
      );
      if (!mounted || draft == null) return;
    }

    final outcomeDraft = draft;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(
          retry ? 'Nihai sonucu yeniden dene' : 'Dosyayı sonuçlandır',
        ),
        content: Text(
          retry
              ? 'Aynı nihai sonuç ve aynı güvenli işlem kimliğiyle yeniden denenecek. Başarılı olursa dosya sonuçlandırılır ve kayıt değiştirilemez.'
              : 'Bu işlem dosyayı sonuçlandırır. Kurum belgesi, sonuç sınıflandırması ve kapanış olayları sonradan değiştirilemez. Devam edilsin mi?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            key: ValueKey(
              retry
                  ? 'confirm-retry-authority-outcome'
                  : 'confirm-record-authority-outcome',
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(retry ? 'Yeniden dene' : 'Dosyayı sonuçlandır'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;

    if (!retry) {
      _authorityOutcomeRequestId = _newRequestId();
      _authorityOutcomeRetryDraft = outcomeDraft;
    }

    setState(() => _recordingAuthorityOutcome = true);
    try {
      final result = await _repository.recordAuthorityOutcome(
        tenantId: scope.tenantId,
        canonicalBrandId: scope.canonicalBrandId,
        submissionId: currentDetail.submission.submissionId,
        draft: outcomeDraft,
        requestId: _authorityOutcomeRequestId!,
      );
      if (!mounted) return;
      _authorityOutcomeRequestId = null;
      _authorityOutcomeRetryDraft = null;
      _showMessage(
        result.duplicate
            ? 'Aynı nihai sonuç daha önce uygulanmıştı; güncel kapanış kaydı yüklendi.'
            : 'Nihai kurum sonucu kaydedildi ve dosya sonuçlandırıldı',
      );
      await _load(newOperation: false);
    } catch (error) {
      if (!mounted) return;
      if (!customsAuthoritySubmissionErrorIsRetryable(error)) {
        _authorityOutcomeRequestId = null;
        _authorityOutcomeRetryDraft = null;
      }
      _showMessage(customsAuthoritySubmissionErrorMessage(error));
    } finally {
      if (mounted && _recordingAuthorityOutcome) {
        setState(() => _recordingAuthorityOutcome = false);
      }
    }
  }

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
              generatingPackage: _generatingPackage,
              recordingExternalSubmission: _recordingExternalSubmission,
              externalSubmissionRetryAvailable:
                  _externalSubmissionRetryDraft != null &&
                  _externalSubmissionRequestId != null,
              recordingReceipt: _recordingReceipt,
              receiptRetryAvailable:
                  _receiptRetryDraft != null && _receiptRequestId != null,
              appendingAuthorityResponse: _appendingAuthorityResponse,
              authorityResponseRetryAvailable:
                  _authorityResponseRetryDraft != null &&
                  _authorityResponseRequestId != null,
              recordingAuthorityOutcome: _recordingAuthorityOutcome,
              authorityOutcomeRetryAvailable:
                  _authorityOutcomeRetryDraft != null &&
                  _authorityOutcomeRequestId != null,
              materializing: _materializing,
              downloadingPdf: _downloadingPdf,
              downloadingManifest: _downloadingManifest,
              onGeneratePackage: _generatePackage,
              onRecordExternalSubmission: () => _recordExternalSubmission(),
              onRetryExternalSubmission: () =>
                  _recordExternalSubmission(retry: true),
              onRecordReceipt: () => _recordReceipt(),
              onRetryReceipt: () => _recordReceipt(retry: true),
              onAppendAuthorityResponse: () => _appendAuthorityResponse(),
              onRetryAuthorityResponse: () =>
                  _appendAuthorityResponse(retry: true),
              onRecordAuthorityOutcome: () => _recordAuthorityOutcome(),
              onRetryAuthorityOutcome: () =>
                  _recordAuthorityOutcome(retry: true),
              stageKeys: _stageKeys,
              onMaterialize: _materialize,
              onDownload: _download,
            ),
    );
  }
}

class _AuthoritySubmissionDetailView extends StatelessWidget {
  const _AuthoritySubmissionDetailView({
    required this.detail,
    required this.generatingPackage,
    required this.recordingExternalSubmission,
    required this.externalSubmissionRetryAvailable,
    required this.recordingReceipt,
    required this.receiptRetryAvailable,
    required this.appendingAuthorityResponse,
    required this.authorityResponseRetryAvailable,
    required this.recordingAuthorityOutcome,
    required this.authorityOutcomeRetryAvailable,
    required this.materializing,
    required this.downloadingPdf,
    required this.downloadingManifest,
    required this.onGeneratePackage,
    required this.onRecordExternalSubmission,
    required this.onRetryExternalSubmission,
    required this.onRecordReceipt,
    required this.onRetryReceipt,
    required this.onAppendAuthorityResponse,
    required this.onRetryAuthorityResponse,
    required this.onRecordAuthorityOutcome,
    required this.onRetryAuthorityOutcome,
    required this.stageKeys,
    required this.onMaterialize,
    required this.onDownload,
  });

  final CustomsAuthoritySubmissionDetail detail;
  final bool generatingPackage;
  final bool recordingExternalSubmission;
  final bool externalSubmissionRetryAvailable;
  final bool recordingReceipt;
  final bool receiptRetryAvailable;
  final bool appendingAuthorityResponse;
  final bool authorityResponseRetryAvailable;
  final bool recordingAuthorityOutcome;
  final bool authorityOutcomeRetryAvailable;
  final bool materializing;
  final bool downloadingPdf;
  final bool downloadingManifest;
  final VoidCallback onGeneratePackage;
  final VoidCallback onRecordExternalSubmission;
  final VoidCallback onRetryExternalSubmission;
  final VoidCallback onRecordReceipt;
  final VoidCallback onRetryReceipt;
  final VoidCallback onAppendAuthorityResponse;
  final VoidCallback onRetryAuthorityResponse;
  final VoidCallback onRecordAuthorityOutcome;
  final VoidCallback onRetryAuthorityOutcome;
  final Map<CustomsAuthoritySubmissionStage, GlobalKey> stageKeys;
  final ValueChanged<CustomsSubmissionPackage> onMaterialize;
  final void Function(
    CustomsSubmissionPackage package,
    CustomsArtifactType type,
  )
  onDownload;

  @override
  Widget build(BuildContext context) {
    final submission = detail.submission;
    final currentPackage = _currentSubmissionPackage(detail);
    return SingleChildScrollView(
      key: const ValueKey('customs-authority-submission-detail'),
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _AuthorityStageAnchor(
            key: stageKeys[CustomsAuthoritySubmissionStage.submissionContent],
            stage: CustomsAuthoritySubmissionStage.submissionContent,
          ),
          _AuthorityHeader(submission: submission),
          const SizedBox(height: 16),
          _NextStepGuidancePanel(
            data: _nextStepGuidance(detail, currentPackage),
          ),
          const SizedBox(height: 16),
          const _LegalNotice(),
          const SizedBox(height: 16),
          if (currentPackage == null) ...[
            _AuthorityStageAnchor(
              key: stageKeys[CustomsAuthoritySubmissionStage.submissionPackage],
              stage: CustomsAuthoritySubmissionStage.submissionPackage,
            ),
            _PackageGenerationSection(
              submission: submission,
              scopeAvailable: detail.artifactScope != null,
              generating: generatingPackage,
              onGenerate: onGeneratePackage,
            ),
          ],
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
          if (currentPackage != null)
            _AuthorityStageAnchor(
              key: stageKeys[CustomsAuthoritySubmissionStage.submissionPackage],
              stage: CustomsAuthoritySubmissionStage.submissionPackage,
            ),
          if (currentPackage == null)
            _AuthorityStageAnchor(
              key:
                  stageKeys[CustomsAuthoritySubmissionStage
                      .downloadableOfficialFile],
              stage: CustomsAuthoritySubmissionStage.downloadableOfficialFile,
            ),
          if (currentPackage == null ||
              submission.status != 'package_generated')
            _AuthorityStageAnchor(
              key: stageKeys[CustomsAuthoritySubmissionStage.authorityDelivery],
              stage: CustomsAuthoritySubmissionStage.authorityDelivery,
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
                value:
                    submission.officialReferenceNumber ?? 'Henüz kaydedilmedi',
              ),
              if (submission.submittedAt != null)
                _AuthorityRow(
                  label: 'Kuruma dış teslim zamanı',
                  value: _formatDateTime(submission.submittedAt!),
                ),
              if (submission.externalSubmissionStatement != null)
                _AuthorityRow(
                  label: 'Dış teslim beyanı',
                  value: submission.externalSubmissionStatement!,
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
          if (currentPackage != null) ...[
            _AuthorityStageAnchor(
              key:
                  stageKeys[CustomsAuthoritySubmissionStage
                      .downloadableOfficialFile],
              stage: CustomsAuthoritySubmissionStage.downloadableOfficialFile,
            ),
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
          ],
          if (currentPackage != null &&
              submission.status == 'package_generated') ...[
            _AuthorityStageAnchor(
              key: stageKeys[CustomsAuthoritySubmissionStage.authorityDelivery],
              stage: CustomsAuthoritySubmissionStage.authorityDelivery,
            ),
            _ExternalSubmissionSection(
              detail: detail,
              package: currentPackage,
              recording: recordingExternalSubmission,
              retryAvailable: externalSubmissionRetryAvailable,
              onRecord: onRecordExternalSubmission,
              onRetry: onRetryExternalSubmission,
            ),
          ],
          _AuthorityStageAnchor(
            key:
                stageKeys[CustomsAuthoritySubmissionStage
                    .deliveryResponseOutcome],
            stage: CustomsAuthoritySubmissionStage.deliveryResponseOutcome,
          ),
          _AuthorityOperationsWorkspace(
            detail: detail,
            recordingReceipt: recordingReceipt,
            receiptRetryAvailable: receiptRetryAvailable,
            appendingAuthorityResponse: appendingAuthorityResponse,
            authorityResponseRetryAvailable: authorityResponseRetryAvailable,
            recordingAuthorityOutcome: recordingAuthorityOutcome,
            authorityOutcomeRetryAvailable: authorityOutcomeRetryAvailable,
            onRecordReceipt: onRecordReceipt,
            onRetryReceipt: onRetryReceipt,
            onAppendAuthorityResponse: onAppendAuthorityResponse,
            onRetryAuthorityResponse: onRetryAuthorityResponse,
            onRecordAuthorityOutcome: onRecordAuthorityOutcome,
            onRetryAuthorityOutcome: onRetryAuthorityOutcome,
          ),
          _AuthoritySection(
            title: 'Kurum cevapları zaman çizelgesi',
            children: detail.responses.isEmpty
                ? const [Text('Henüz kurum yanıtı veya teslim kaydı yok.')]
                : detail.responses
                      .map(
                        (response) =>
                            _AuthorityResponseTimelineCard(response: response),
                      )
                      .toList(),
          ),
          if (submission.outcomeResponseId != null ||
              submission.status == 'concluded')
            _AuthorityOutcomeSummary(submission: submission),
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
      ),
    );
  }
}

class _NextStepGuidanceData {
  const _NextStepGuidanceData({
    required this.title,
    required this.message,
    required this.result,
    required this.icon,
  });

  final String title;
  final String message;
  final String result;
  final IconData icon;
}

_NextStepGuidanceData _nextStepGuidance(
  CustomsAuthoritySubmissionDetail detail,
  CustomsSubmissionPackage? currentPackage,
) {
  final submission = detail.submission;
  if (submission.status == 'concluded') {
    return const _NextStepGuidanceData(
      title: 'Dosya sonucunu ve kapanış kaydını inceleyin',
      message:
          'Nihai sonuç kaydedildi. Kurum cevaplarını, karar dayanaklarını ve değiştirilemez olay zaman çizelgesini kontrol edin.',
      result:
          'Tamamlanmış ve denetlenebilir bir kurum süreci ile kapanış kaydı.',
      icon: Icons.task_alt_rounded,
    );
  }

  if (submission.status == 'additional_information_requested') {
    return const _NextStepGuidanceData(
      title: 'Kurumun ek bilgi talebini inceleyin',
      message:
          'Kurum ek bilgi veya belge istedi. Talebi, son tarihi ve sonraki kurum cevaplarını aynı kanonik dosyada takip edin.',
      result:
          'Ek bilgi talebi görünür, izlenebilir ve nihai sonuç kaydına hazır bir kurum süreci.',
      icon: Icons.playlist_add_check_circle_outlined,
    );
  }

  if (submission.status == 'receipt_recorded' ||
      submission.status == 'authority_review') {
    return const _NextStepGuidanceData(
      title: 'Kurumun ara cevabını veya nihai sonucunu izleyin',
      message:
          'Resmî alındı kaydedildi. Kurumun inceleme teyidini, bilgi talebini, durum güncellemesini veya nihai sonucunu aynı dosyada kaydedin.',
      result:
          'Alındıdan sonuca kadar değiştirilemez ve denetlenebilir kurum işlem geçmişi.',
      icon: Icons.mark_email_read_outlined,
    );
  }

  if (submission.status == 'submitted_externally' ||
      submission.submittedAt != null) {
    return const _NextStepGuidanceData(
      title: 'Kurum alındısını veya gelen cevabı kaydedin',
      message:
          'Dış teslim kaydedildi. Kurumdan gelen resmî alındı, bilgi talebi veya durum güncellemesini bu dosyada değiştirilemez biçimde kaydedin.',
      result:
          'Kuruma teslim edildiği doğrulanmış ve cevap sürecine hazır bir dosya.',
      icon: Icons.schedule_send_outlined,
    );
  }

  if (currentPackage != null) {
    final artifactsReady =
        currentPackage.artifactStatus ==
            CustomsSubmissionArtifactStatus.ready &&
        currentPackage.pdfArtifact?.ready == true &&
        currentPackage.jsonManifestArtifact?.ready == true;
    if (artifactsReady) {
      return const _NextStepGuidanceData(
        title: 'Resmî dosyaları indirin veya dış teslimi kaydedin',
        message:
            'Değiştirilemez paket ile PDF ve JSON dosyaları hazır. Dosyaları güvenli biçimde indirin ya da insan tarafından yapılmış gerçek teslimi kaydedin.',
        result:
            'İndirilebilir resmî dosyalar veya izlenebilir dış teslim kaydı.',
        icon: Icons.picture_as_pdf_outlined,
      );
    }
    return const _NextStepGuidanceData(
      title: 'Resmî dosyaları hazırlayın veya dış teslimi kaydedin',
      message:
          'Başvuru paketi hazır. PDF/JSON üretimini başlatabilirsiniz. Güvenli indirme dosyalarının hazır olması, insan tarafından yapılmış dış teslimi kaydetmek için zorunlu değildir.',
      result:
          'Güvenli resmî dosyalar veya aynı paket üzerinden doğrulanmış dış teslim kaydı.',
      icon: Icons.inventory_2_outlined,
    );
  }

  final missingControls = <String>[
    if (submission.humanReviewReference == null) 'insan incelemesi',
    if (submission.rightsHolderApprovalReference == null)
      'hak sahibi veya temsilci onayı',
    if (!submission.dataMinimizationConfirmed) 'veri minimizasyonu',
    if (!submission.nonAccusatoryLanguageConfirmed) 'hukuken nötr dil',
  ];
  if (missingControls.isNotEmpty) {
    return _NextStepGuidanceData(
      title: 'Başvuru ve insan kontrol kapılarını tamamlayın',
      message:
          'Eksik kontroller: ${missingControls.join(', ')}. Bu kontroller tamamlanmadan değiştirilemez başvuru paketi oluşturulamaz.',
      result:
          'Paket hazırlama onayına taşınabilecek doğrulanmış başvuru içeriği.',
      icon: Icons.fact_check_outlined,
    );
  }

  if (submission.status != 'approved_for_package') {
    return const _NextStepGuidanceData(
      title: 'Başvuruyu paket hazırlama onayına taşıyın',
      message:
          'İnsan ve hak sahibi kontrolleri tamamlanmış görünüyor. Dosyanın yetkili insan incelemesiyle paket hazırlama onayına geçirilmesi gerekir.',
      result:
          'Değiştirilemez paket üretimine hazır ve onaylanmış resmî iletim dosyası.',
      icon: Icons.approval_outlined,
    );
  }

  return const _NextStepGuidanceData(
    title: 'Başvuru paketini oluşturun',
    message:
        'Kontrol kapıları ve paket hazırlama onayı tamamlandı. En az bir belge veya delil kaydı ekleyerek değiştirilemez paketi oluşturun.',
    result: 'Sürüm ve hash ile korunan kanonik bir resmî başvuru paketi.',
    icon: Icons.inventory_2_outlined,
  );
}

class _NextStepGuidancePanel extends StatelessWidget {
  const _NextStepGuidancePanel({required this.data});

  final _NextStepGuidanceData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('authority-next-step-guidance'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF6F4),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: MarkaKalkanTheme.teal.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(data.icon, color: MarkaKalkanTheme.teal),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Şimdi ne yapmalısınız?',
                  style: TextStyle(
                    color: MarkaKalkanTheme.teal,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  data.title,
                  style: const TextStyle(
                    color: MarkaKalkanTheme.navy,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  data.message,
                  style: const TextStyle(
                    color: Color(0xFF44535E),
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 9),
                Text(
                  'Bu adımın çıktısı: ${data.result}',
                  style: const TextStyle(
                    color: MarkaKalkanTheme.navy,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    height: 1.4,
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

class _AuthorityStageAnchor extends StatelessWidget {
  const _AuthorityStageAnchor({super.key, required this.stage});

  final CustomsAuthoritySubmissionStage stage;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 1,
      child: SizedBox(key: ValueKey('authority-stage-anchor-${stage.name}')),
    );
  }
}

CustomsSubmissionPackage? _currentSubmissionPackage(
  CustomsAuthoritySubmissionDetail? detail,
) {
  if (detail == null || detail.packages.isEmpty) return null;
  final currentPackageId = detail.submission.currentPackageId;
  if (currentPackageId != null) {
    for (final package in detail.packages.reversed) {
      if (package.packageId == currentPackageId) return package;
    }
  }
  return detail.packages.last;
}

List<String> _externalSubmissionBlockers(
  CustomsAuthoritySubmissionDetail detail,
  CustomsSubmissionPackage package,
) {
  final submission = detail.submission;
  final currentHash = submission.currentPackageHash?.toLowerCase();
  final packageHash = package.aggregateHash.toLowerCase();
  return <String>[
    if (detail.artifactScope == null) 'Tenant ve marka kapsamı doğrulanamadı.',
    if (submission.status != 'package_generated')
      'Dosya “Başvuru paketi hazırlandı” durumunda olmalıdır.',
    if (submission.currentPackageId != package.packageId)
      'Güncel paket kimliği doğrulanamadı.',
    if (submission.currentPackageVersion != package.version)
      'Güncel paket sürümü doğrulanamadı.',
    if (currentHash == null || currentHash != packageHash)
      'Güncel paket hash’i doğrulanamadı.',
    if (package.submissionId != submission.submissionId)
      'Paket ile resmî iletim dosyası eşleşmiyor.',
    if (!package.immutable) 'Paket değiştirilemez olarak doğrulanamadı.',
  ];
}

class _ExternalSubmissionSection extends StatelessWidget {
  const _ExternalSubmissionSection({
    required this.detail,
    required this.package,
    required this.recording,
    required this.retryAvailable,
    required this.onRecord,
    required this.onRetry,
  });

  final CustomsAuthoritySubmissionDetail detail;
  final CustomsSubmissionPackage package;
  final bool recording;
  final bool retryAvailable;
  final VoidCallback onRecord;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final blockers = _externalSubmissionBlockers(detail, package);
    final allowed = blockers.isEmpty;

    return _AuthoritySection(
      title: externalSubmissionSectionTitle,
      children: [
        const Text(
          externalSubmissionNotAutomaticDescription,
          style: TextStyle(height: 1.5),
        ),
        _AuthorityRow(label: 'Güncel paket', value: package.packageId),
        _AuthorityRow(label: 'Paket sürümü', value: 'v${package.version}'),
        _AuthorityRow(
          label: 'Paket hash’i',
          value: package.aggregateHash,
          monospace: true,
        ),
        Text(
          package.artifactStatus == CustomsSubmissionArtifactStatus.ready
              ? 'Güvenli indirme dosyaları hazır. Dış teslim kaydı yine insan '
                    'beyanı ve açık teyitle yapılır.'
              : 'Güvenli indirme dosyalarının hazır olması bu kayıt için '
                    'zorunlu değildir. Kurum dışında gerçekten tamamlanan '
                    'teslimi kaydedin.',
          style: const TextStyle(height: 1.45),
        ),
        if (blockers.isNotEmpty)
          Container(
            key: const ValueKey('external-submission-blockers'),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8E8),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFF0D9A2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Dış teslim kaydı için tamamlanması gerekenler:',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                for (final blocker in blockers)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('• '),
                        Expanded(child: Text(blocker)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        if (retryAvailable)
          OutlinedButton.icon(
            key: const ValueKey('retry-external-submission'),
            onPressed: allowed && !recording ? onRetry : null,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text(retryExternalSubmission),
          )
        else
          FilledButton.icon(
            key: const ValueKey('record-external-submission'),
            onPressed: allowed && !recording ? onRecord : null,
            icon: recording
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.outbox_outlined),
            label: Text(
              recording ? 'Dış teslim kaydediliyor…' : recordExternalSubmission,
            ),
          ),
      ],
    );
  }
}

const _authorityResponseStatuses = <String>{
  'submitted_externally',
  'receipt_recorded',
  'authority_review',
  'additional_information_requested',
};

List<String> _authorityReceiptBlockers(
  CustomsAuthoritySubmissionDetail detail,
) {
  final submission = detail.submission;
  return <String>[
    if (detail.artifactScope == null) 'Tenant ve marka kapsamı doğrulanamadı.',
    if (submission.status != 'submitted_externally')
      'Resmî alındı yalnız dış teslim kaydından sonra işlenebilir.',
    if (submission.officialReferenceNumber != null ||
        submission.receiptRecordedAt != null)
      'Bu dosyada resmî alındı daha önce kaydedilmiş.',
  ];
}

List<String> _authorityResponseBlockers(
  CustomsAuthoritySubmissionDetail detail,
) {
  final submission = detail.submission;
  return <String>[
    if (detail.artifactScope == null) 'Tenant ve marka kapsamı doğrulanamadı.',
    if (!_authorityResponseStatuses.contains(submission.status))
      submission.status == 'concluded'
          ? 'Sonuçlandırılmış dosyaya yeni ara cevap eklenemez.'
          : 'Kurum cevabı yalnız dış teslim sonrasındaki açık süreçte kaydedilebilir.',
  ];
}

List<String> _authorityOutcomeBlockers(
  CustomsAuthoritySubmissionDetail detail,
) {
  final submission = detail.submission;
  return <String>[
    if (detail.artifactScope == null) 'Tenant ve marka kapsamı doğrulanamadı.',
    if (!_authorityResponseStatuses.contains(submission.status))
      submission.status == 'concluded'
          ? 'Bu dosya daha önce sonuçlandırılmış.'
          : 'Nihai sonuç yalnız dış teslim sonrasındaki açık süreçte kaydedilebilir.',
    if (submission.submittedAt == null)
      'Doğrulanmış dış teslim zamanı bulunamadı.',
    if (submission.currentPackageId == null ||
        submission.currentPackageHash == null ||
        submission.currentPackageVersion < 1)
      'Dış teslimle ilişkili değiştirilemez paket doğrulanamadı.',
  ];
}

class _AuthorityOperationsWorkspace extends StatelessWidget {
  const _AuthorityOperationsWorkspace({
    required this.detail,
    required this.recordingReceipt,
    required this.receiptRetryAvailable,
    required this.appendingAuthorityResponse,
    required this.authorityResponseRetryAvailable,
    required this.recordingAuthorityOutcome,
    required this.authorityOutcomeRetryAvailable,
    required this.onRecordReceipt,
    required this.onRetryReceipt,
    required this.onAppendAuthorityResponse,
    required this.onRetryAuthorityResponse,
    required this.onRecordAuthorityOutcome,
    required this.onRetryAuthorityOutcome,
  });

  final CustomsAuthoritySubmissionDetail detail;
  final bool recordingReceipt;
  final bool receiptRetryAvailable;
  final bool appendingAuthorityResponse;
  final bool authorityResponseRetryAvailable;
  final bool recordingAuthorityOutcome;
  final bool authorityOutcomeRetryAvailable;
  final VoidCallback onRecordReceipt;
  final VoidCallback onRetryReceipt;
  final VoidCallback onAppendAuthorityResponse;
  final VoidCallback onRetryAuthorityResponse;
  final VoidCallback onRecordAuthorityOutcome;
  final VoidCallback onRetryAuthorityOutcome;

  @override
  Widget build(BuildContext context) {
    final submission = detail.submission;
    CustomsAuthorityResponse? receipt;
    for (final response in detail.responses) {
      if (response.responseType == 'receipt') {
        receipt = response;
        break;
      }
    }
    final receiptBlockers = _authorityReceiptBlockers(detail);
    final responseBlockers = _authorityResponseBlockers(detail);
    final outcomeBlockers = _authorityOutcomeBlockers(detail);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _AuthoritySection(
          title: 'Dış teslim özeti',
          children: [
            _AuthorityRow(
              label: 'Teslim durumu',
              value: submission.submittedAt == null
                  ? 'Henüz dış teslim kaydı yok'
                  : 'İnsan tarafından dış kanalda teslim edildi',
            ),
            if (submission.submittedAt != null)
              _AuthorityRow(
                label: 'Teslim zamanı',
                value: _formatDateTime(submission.submittedAt!),
              ),
            if (submission.externalReferenceType != null)
              _AuthorityRow(
                label: 'Dış referans türü',
                value: customsExternalReferenceTypeLabel(
                  submission.externalReferenceType!,
                ),
              ),
            if (submission.externalReferenceValue != null)
              _AuthorityRow(
                label: 'Dış referans',
                value: submission.externalReferenceValue!,
              ),
            if (submission.externalSubmissionStatement != null)
              _AuthorityRow(
                label: 'Teslim beyanı',
                value: submission.externalSubmissionStatement!,
              ),
          ],
        ),
        KeyedSubtree(
          key: const ValueKey('authority-receipt-workspace'),
          child: _AuthoritySection(
            title: authorityReceiptSectionTitle,
            children: [
              const Text(
                authorityReceiptDescription,
                style: TextStyle(height: 1.5),
              ),
              if (receipt != null ||
                  submission.officialReferenceNumber != null) ...[
                _AuthorityRow(
                  label: 'Resmî referans',
                  value:
                      submission.officialReferenceNumber ??
                      receipt?.authorityReference ??
                      'Belirtilmedi',
                ),
                if (submission.receiptRecordedAt != null)
                  _AuthorityRow(
                    label: 'Alındı zamanı',
                    value: _formatDateTime(submission.receiptRecordedAt!),
                  ),
                if (receipt != null)
                  _AuthorityRow(label: 'Alındı özeti', value: receipt.summary),
                const _ImmutableRecordNotice(
                  text: 'Resmî alındı kaydı değiştirilemez.',
                ),
              ] else ...[
                if (receiptBlockers.isNotEmpty)
                  _AuthorityOperationBlockers(
                    key: const ValueKey('authority-receipt-blockers'),
                    title: 'Resmî alındı için tamamlanması gerekenler:',
                    blockers: receiptBlockers,
                  ),
                if (receiptRetryAvailable)
                  OutlinedButton.icon(
                    key: const ValueKey('retry-customs-submission-receipt'),
                    onPressed: receiptBlockers.isEmpty && !recordingReceipt
                        ? onRetryReceipt
                        : null,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text(retryAuthorityReceipt),
                  )
                else
                  FilledButton.icon(
                    key: const ValueKey('record-customs-submission-receipt'),
                    onPressed: receiptBlockers.isEmpty && !recordingReceipt
                        ? onRecordReceipt
                        : null,
                    icon: recordingReceipt
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.mark_email_read_outlined),
                    label: Text(
                      recordingReceipt
                          ? 'Resmî alındı kaydediliyor…'
                          : recordAuthorityReceipt,
                    ),
                  ),
              ],
            ],
          ),
        ),
        KeyedSubtree(
          key: const ValueKey('authority-interim-response-workspace'),
          child: _AuthoritySection(
            title: authorityInterimResponseSectionTitle,
            children: [
              const Text(
                authorityInterimResponseDescription,
                style: TextStyle(height: 1.5),
              ),
              if (responseBlockers.isNotEmpty)
                _AuthorityOperationBlockers(
                  key: const ValueKey('authority-response-blockers'),
                  title: 'Ara cevap için tamamlanması gerekenler:',
                  blockers: responseBlockers,
                ),
              if (authorityResponseRetryAvailable)
                OutlinedButton.icon(
                  key: const ValueKey('retry-customs-authority-response'),
                  onPressed:
                      responseBlockers.isEmpty && !appendingAuthorityResponse
                      ? onRetryAuthorityResponse
                      : null,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text(retryAuthorityInterimResponse),
                )
              else
                FilledButton.icon(
                  key: const ValueKey('append-customs-authority-response'),
                  onPressed:
                      responseBlockers.isEmpty && !appendingAuthorityResponse
                      ? onAppendAuthorityResponse
                      : null,
                  icon: appendingAuthorityResponse
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add_comment_outlined),
                  label: Text(
                    appendingAuthorityResponse
                        ? 'Kurum cevabı kaydediliyor…'
                        : appendAuthorityInterimResponse,
                  ),
                ),
            ],
          ),
        ),
        KeyedSubtree(
          key: const ValueKey('authority-outcome-workspace'),
          child: _AuthoritySection(
            title: authorityOutcomeSectionTitle,
            children: [
              const Text(
                authorityOutcomeDescription,
                style: TextStyle(height: 1.5),
              ),
              if (outcomeBlockers.isNotEmpty)
                _AuthorityOperationBlockers(
                  key: const ValueKey('authority-outcome-blockers'),
                  title: 'Nihai sonuç için tamamlanması gerekenler:',
                  blockers: outcomeBlockers,
                ),
              if (authorityOutcomeRetryAvailable)
                OutlinedButton.icon(
                  key: const ValueKey('retry-customs-authority-outcome'),
                  onPressed:
                      outcomeBlockers.isEmpty && !recordingAuthorityOutcome
                      ? onRetryAuthorityOutcome
                      : null,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text(retryAuthorityOutcome),
                )
              else
                FilledButton.icon(
                  key: const ValueKey('record-customs-authority-outcome'),
                  onPressed:
                      outcomeBlockers.isEmpty && !recordingAuthorityOutcome
                      ? onRecordAuthorityOutcome
                      : null,
                  icon: recordingAuthorityOutcome
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.task_alt_outlined),
                  label: Text(
                    recordingAuthorityOutcome
                        ? 'Dosya sonuçlandırılıyor…'
                        : recordAuthorityOutcome,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ImmutableRecordNotice extends StatelessWidget {
  const _ImmutableRecordNotice({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF6F4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_outline_rounded, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _AuthorityOperationBlockers extends StatelessWidget {
  const _AuthorityOperationBlockers({
    super.key,
    required this.title,
    required this.blockers,
  });

  final String title;
  final List<String> blockers;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF0D9A2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          for (final blocker in blockers)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• '),
                  Expanded(child: Text(blocker)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _AuthorityResponseTimelineCard extends StatelessWidget {
  const _AuthorityResponseTimelineCard({required this.response});

  final CustomsAuthorityResponse response;

  @override
  Widget build(BuildContext context) {
    final metadata = <String>[
      _formatDateTime(response.receivedAt),
      if (response.authorityReference != null) response.authorityReference!,
      if (response.outcomeCode != null)
        customsAuthorityOutcomeCodeLabel(response.outcomeCode!),
      if (response.outcomeFinalityLevel != null)
        customsAuthorityOutcomeFinalityLabel(response.outcomeFinalityLevel!),
      if (response.attachmentReferences.isNotEmpty)
        '${response.attachmentReferences.length} ek',
      response.immutable ? 'Değiştirilemez' : 'Bütünlük doğrulanamadı',
    ];
    return KeyedSubtree(
      key: ValueKey('authority-response-${response.responseId}'),
      child: _TimelineCard(
        title: customsAuthorityResponseTypeLabel(response.responseType),
        subtitle: response.summary,
        meta: metadata.join(' · '),
      ),
    );
  }
}

class _AuthorityOutcomeSummary extends StatelessWidget {
  const _AuthorityOutcomeSummary({required this.submission});

  final CustomsAuthoritySubmission submission;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: const ValueKey('authority-outcome-summary'),
      child: _AuthoritySection(
        title: 'Nihai sonuç ve kapanış özeti',
        children: [
          _AuthorityRow(
            label: 'Dosya durumu',
            value: customsAuthoritySubmissionStatusLabel(submission.status),
          ),
          _AuthorityRow(
            label: 'Sonuç kodu',
            value: submission.outcomeCode == null
                ? 'Belirtilmedi'
                : customsAuthorityOutcomeCodeLabel(submission.outcomeCode!),
          ),
          _AuthorityRow(
            label: 'Kesinlik seviyesi',
            value: submission.outcomeFinalityLevel == null
                ? 'Belirtilmedi'
                : customsAuthorityOutcomeFinalityLabel(
                    submission.outcomeFinalityLevel!,
                  ),
          ),
          _AuthorityRow(
            label: 'Kurum referansı',
            value: submission.authorityReferenceNumber ?? 'Belirtilmedi',
          ),
          if (submission.officialDocumentDate != null)
            _AuthorityRow(
              label: 'Resmî belge tarihi',
              value: _formatDateTime(submission.officialDocumentDate!),
            ),
          if (submission.outcomeReceivedAt != null)
            _AuthorityRow(
              label: 'Sonucun alındığı zaman',
              value: _formatDateTime(submission.outcomeReceivedAt!),
            ),
          _AuthorityRow(
            label: 'Kurum',
            value: submission.authorityNameSnapshot ?? 'Belirtilmedi',
          ),
          if (submission.authorityUnitSnapshot != null)
            _AuthorityRow(
              label: 'Kurum birimi',
              value: submission.authorityUnitSnapshot!,
            ),
          _AuthorityRow(
            label: 'Sonuç özeti',
            value: submission.outcomeSummary ?? 'Belirtilmedi',
          ),
          const _ImmutableRecordNotice(
            text:
                'Bu kapanış kaydı kurum belgesinin kullanıcı tarafından yapılan sınıflandırmasıdır; MarkaKalkan tarafından verilmiş hukukî karar değildir.',
          ),
        ],
      ),
    );
  }
}

bool _isSha256(String value) =>
    RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(value.trim());

String? _requiredTextValidator(
  String? value,
  String label, {
  int minimum = 2,
  int maximum = 500,
}) {
  final clean = value?.trim() ?? '';
  if (clean.length < minimum) {
    return '$label en az $minimum karakter olmalıdır.';
  }
  if (clean.length > maximum) {
    return '$label $maximum karakteri aşamaz.';
  }
  return null;
}

String? _authorityDateTimeError(DateTime value, String label) {
  final now = DateTime.now();
  if (value.isAfter(now.add(const Duration(minutes: 5)))) {
    return '$label 5 dakikadan fazla ileride olamaz.';
  }
  if (value.isBefore(now.subtract(const Duration(days: 3650)))) {
    return '$label 10 yıldan daha eski olamaz.';
  }
  return null;
}

Future<DateTime?> _pickAuthorityDate(
  BuildContext context,
  DateTime current,
) async {
  final selected = await showDatePicker(
    context: context,
    initialDate: current,
    firstDate: DateTime.now().subtract(const Duration(days: 3650)),
    lastDate: DateTime.now().add(const Duration(days: 1)),
  );
  if (selected == null) return null;
  return DateTime(
    selected.year,
    selected.month,
    selected.day,
    current.hour,
    current.minute,
  );
}

Future<DateTime?> _pickAuthorityTime(
  BuildContext context,
  DateTime current,
) async {
  final selected = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(current),
  );
  if (selected == null) return null;
  return DateTime(
    current.year,
    current.month,
    current.day,
    selected.hour,
    selected.minute,
  );
}

class _AuthorityAttachmentDraft {
  _AuthorityAttachmentDraft()
    : referenceController = TextEditingController(),
      hashController = TextEditingController();

  final TextEditingController referenceController;
  final TextEditingController hashController;

  void dispose() {
    referenceController.dispose();
    hashController.dispose();
  }
}

class _AuthorityReceiptDialog extends StatefulWidget {
  const _AuthorityReceiptDialog({required this.submission});

  final CustomsAuthoritySubmission submission;

  @override
  State<_AuthorityReceiptDialog> createState() =>
      _AuthorityReceiptDialogState();
}

class _AuthorityReceiptDialogState extends State<_AuthorityReceiptDialog> {
  final _formKey = GlobalKey<FormState>();
  final _referenceController = TextEditingController();
  final _summaryController = TextEditingController();
  final _documentReferenceController = TextEditingController();
  final _documentHashController = TextEditingController();
  late CustomsSubmissionChannel _channel;
  DateTime _receivedAt = DateTime.now();
  bool _confirmed = false;
  String? _dateError;
  String? _confirmationError;

  @override
  void initState() {
    super.initState();
    _channel = _submissionChannelFromWire(widget.submission.channelType);
    _referenceController.text = widget.submission.externalReferenceValue ?? '';
  }

  @override
  void dispose() {
    _referenceController.dispose();
    _summaryController.dispose();
    _documentReferenceController.dispose();
    _documentHashController.dispose();
    super.dispose();
  }

  String? _documentReferenceValidator(String? value) {
    final reference = value?.trim() ?? '';
    final hash = _documentHashController.text.trim();
    if (reference.isEmpty && hash.isEmpty) {
      return null;
    }
    if (reference.isEmpty) {
      return 'Belge referansı hash ile birlikte girilmelidir.';
    }
    if (reference.length > 500) {
      return 'Belge referansı 500 karakteri aşamaz.';
    }
    return null;
  }

  String? _documentHashValidator(String? value) {
    final hash = value?.trim() ?? '';
    final reference = _documentReferenceController.text.trim();
    if (hash.isEmpty && reference.isEmpty) {
      return null;
    }
    if (hash.isEmpty) {
      return 'Belge SHA-256 değeri referansla birlikte girilmelidir.';
    }
    if (!_isSha256(hash)) {
      return 'Belge SHA-256 değeri 64 haneli hex olmalıdır.';
    }
    return null;
  }

  void _submit() {
    final formValid = _formKey.currentState?.validate() == true;
    final dateError = _authorityDateTimeError(_receivedAt, 'Alındı zamanı');
    setState(() {
      _dateError = dateError;
      _confirmationError = _confirmed
          ? null
          : 'Fiilî kurum alındısı teyidi zorunludur.';
    });
    if (!formValid || dateError != null || !_confirmed) return;

    Navigator.pop(
      context,
      CustomsSubmissionReceiptDraft(
        officialReferenceNumber: _referenceController.text,
        receivedAt: _receivedAt.toUtc().toIso8601String(),
        channelType: _channel,
        summary: _summaryController.text,
        receiptDocumentReference:
            _documentReferenceController.text.trim().isEmpty
            ? null
            : _documentReferenceController.text.trim(),
        receiptDocumentHash: _documentHashController.text.trim().isEmpty
            ? null
            : _documentHashController.text.trim().toLowerCase(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      title: const Text('Resmî alındı kaydı'),
      content: SizedBox(
        width: 720,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(authorityReceiptDescription),
                const SizedBox(height: 16),
                TextFormField(
                  key: const ValueKey('authority-receipt-reference'),
                  controller: _referenceController,
                  maxLength: 500,
                  decoration: const InputDecoration(
                    labelText: 'Kurum resmî referans numarası',
                  ),
                  validator: (value) => _requiredTextValidator(
                    value,
                    'Resmî referans',
                    minimum: 2,
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<CustomsSubmissionChannel>(
                  key: const ValueKey('authority-receipt-channel'),
                  initialValue: _channel,
                  decoration: const InputDecoration(labelText: 'Alındı kanalı'),
                  items: CustomsSubmissionChannel.values
                      .map(
                        (channel) => DropdownMenuItem(
                          value: channel,
                          child: Text(
                            customsAuthorityChannelLabel(channel.wireValue),
                          ),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) {
                    if (value != null) setState(() => _channel = value);
                  },
                ),
                const SizedBox(height: 12),
                const Text(
                  'Alındı tarihi ve saati',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    OutlinedButton.icon(
                      key: const ValueKey('authority-receipt-pick-date'),
                      onPressed: () async {
                        final value = await _pickAuthorityDate(
                          context,
                          _receivedAt,
                        );
                        if (value != null && mounted) {
                          setState(() {
                            _receivedAt = value;
                            _dateError = null;
                          });
                        }
                      },
                      icon: const Icon(Icons.calendar_today_outlined),
                      label: Text(_formatLocalDate(_receivedAt)),
                    ),
                    OutlinedButton.icon(
                      key: const ValueKey('authority-receipt-pick-time'),
                      onPressed: () async {
                        final value = await _pickAuthorityTime(
                          context,
                          _receivedAt,
                        );
                        if (value != null && mounted) {
                          setState(() {
                            _receivedAt = value;
                            _dateError = null;
                          });
                        }
                      },
                      icon: const Icon(Icons.schedule_outlined),
                      label: Text(_formatLocalTime(_receivedAt)),
                    ),
                  ],
                ),
                if (_dateError != null)
                  Text(
                    _dateError!,
                    key: const ValueKey('authority-receipt-date-error'),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const ValueKey('authority-receipt-summary'),
                  controller: _summaryController,
                  minLines: 3,
                  maxLines: 6,
                  maxLength: 3000,
                  decoration: const InputDecoration(labelText: 'Alındı özeti'),
                  validator: (value) => _requiredTextValidator(
                    value,
                    'Alındı özeti',
                    minimum: 10,
                    maximum: 3000,
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const ValueKey('authority-receipt-document-reference'),
                  controller: _documentReferenceController,
                  maxLength: 500,
                  decoration: const InputDecoration(
                    labelText: 'Alındı belgesi referansı (isteğe bağlı)',
                  ),
                  validator: _documentReferenceValidator,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const ValueKey('authority-receipt-document-hash'),
                  controller: _documentHashController,
                  maxLength: 64,
                  decoration: const InputDecoration(
                    labelText: 'Alındı belgesi SHA-256 (isteğe bağlı)',
                  ),
                  validator: _documentHashValidator,
                ),
                CheckboxListTile(
                  key: const ValueKey('authority-receipt-confirmation'),
                  contentPadding: EdgeInsets.zero,
                  value: _confirmed,
                  onChanged: (value) {
                    setState(() {
                      _confirmed = value == true;
                      if (_confirmed) _confirmationError = null;
                    });
                  },
                  title: const Text(
                    'Bu bilgiler kurumdan fiilen alınan resmî alındıya dayanır ve kayıt sonradan değiştirilemez.',
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                if (_confirmationError != null)
                  Text(
                    _confirmationError!,
                    key: const ValueKey('authority-receipt-confirmation-error'),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Vazgeç'),
        ),
        FilledButton(
          key: const ValueKey('review-authority-receipt'),
          onPressed: _submit,
          child: const Text('Kaydı gözden geçir'),
        ),
      ],
    );
  }
}

class _AuthorityInterimResponseDialog extends StatefulWidget {
  const _AuthorityInterimResponseDialog({required this.submission});

  final CustomsAuthoritySubmission submission;

  @override
  State<_AuthorityInterimResponseDialog> createState() =>
      _AuthorityInterimResponseDialogState();
}

class _AuthorityInterimResponseDialogState
    extends State<_AuthorityInterimResponseDialog> {
  final _formKey = GlobalKey<FormState>();
  final _authorityReferenceController = TextEditingController();
  final _summaryController = TextEditingController();
  final List<_AuthorityAttachmentDraft> _attachments = [];
  CustomsInterimAuthorityResponseType _responseType =
      CustomsInterimAuthorityResponseType.acknowledgement;
  CustomsAuthorityOutcomeCode? _outcomeCode;
  DateTime _receivedAt = DateTime.now();
  DateTime? _requestedDueAt;
  String? _receivedAtError;
  String? _dueAtError;

  static const _interimCodes = <CustomsAuthorityOutcomeCode>[
    CustomsAuthorityOutcomeCode.acceptedForReview,
    CustomsAuthorityOutcomeCode.temporaryMeasureRecorded,
    CustomsAuthorityOutcomeCode.goodsDetainedOrSuspended,
    CustomsAuthorityOutcomeCode.goodsSeizureReported,
    CustomsAuthorityOutcomeCode.additionalProcedureRequired,
  ];

  @override
  void dispose() {
    _authorityReferenceController.dispose();
    _summaryController.dispose();
    for (final attachment in _attachments) {
      attachment.dispose();
    }
    super.dispose();
  }

  void _addAttachment() {
    setState(() => _attachments.add(_AuthorityAttachmentDraft()));
  }

  void _removeAttachment(int index) {
    final removed = _attachments.removeAt(index);
    removed.dispose();
    setState(() {});
  }

  void _submit() {
    final formValid = _formKey.currentState?.validate() == true;
    final receivedAtError = _authorityDateTimeError(
      _receivedAt,
      'Cevabın alınma zamanı',
    );
    String? dueAtError;
    if (_requestedDueAt != null && !_requestedDueAt!.isAfter(_receivedAt)) {
      dueAtError = 'Talep edilen son tarih cevap zamanından sonra olmalıdır.';
    }
    setState(() {
      _receivedAtError = receivedAtError;
      _dueAtError = dueAtError;
    });
    if (!formValid || receivedAtError != null || dueAtError != null) return;

    Navigator.pop(
      context,
      CustomsAuthorityResponseDraft(
        responseType: _responseType,
        authorityReference: _authorityReferenceController.text.trim().isEmpty
            ? null
            : _authorityReferenceController.text.trim(),
        receivedAt: _receivedAt.toUtc().toIso8601String(),
        summary: _summaryController.text,
        attachmentReferences: _attachments
            .map((item) => item.referenceController.text.trim())
            .toList(growable: false),
        attachmentHashes: _attachments
            .map((item) => item.hashController.text.trim().toLowerCase())
            .toList(growable: false),
        requestedDueAt: _requestedDueAt?.toUtc().toIso8601String(),
        outcomeCode: _outcomeCode,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      title: const Text('Kurum ara cevabı'),
      content: SizedBox(
        width: 760,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(authorityInterimResponseDescription),
                const SizedBox(height: 16),
                DropdownButtonFormField<CustomsInterimAuthorityResponseType>(
                  key: const ValueKey('authority-response-type'),
                  initialValue: _responseType,
                  decoration: const InputDecoration(labelText: 'Cevap türü'),
                  items: CustomsInterimAuthorityResponseType.values
                      .map(
                        (type) => DropdownMenuItem(
                          value: type,
                          child: Text(
                            customsAuthorityResponseTypeLabel(type.wireValue),
                          ),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _responseType = value;
                      if (value !=
                          CustomsInterimAuthorityResponseType
                              .informationRequest) {
                        _requestedDueAt = null;
                        _dueAtError = null;
                      }
                    });
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const ValueKey('authority-response-reference'),
                  controller: _authorityReferenceController,
                  maxLength: 500,
                  decoration: const InputDecoration(
                    labelText: 'Kurum referansı (isteğe bağlı)',
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Cevabın alınma tarihi ve saati',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    OutlinedButton.icon(
                      key: const ValueKey('authority-response-pick-date'),
                      onPressed: () async {
                        final value = await _pickAuthorityDate(
                          context,
                          _receivedAt,
                        );
                        if (value != null && mounted) {
                          setState(() {
                            _receivedAt = value;
                            _receivedAtError = null;
                          });
                        }
                      },
                      icon: const Icon(Icons.calendar_today_outlined),
                      label: Text(_formatLocalDate(_receivedAt)),
                    ),
                    OutlinedButton.icon(
                      key: const ValueKey('authority-response-pick-time'),
                      onPressed: () async {
                        final value = await _pickAuthorityTime(
                          context,
                          _receivedAt,
                        );
                        if (value != null && mounted) {
                          setState(() {
                            _receivedAt = value;
                            _receivedAtError = null;
                          });
                        }
                      },
                      icon: const Icon(Icons.schedule_outlined),
                      label: Text(_formatLocalTime(_receivedAt)),
                    ),
                  ],
                ),
                if (_receivedAtError != null)
                  Text(
                    _receivedAtError!,
                    key: const ValueKey('authority-response-date-error'),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const ValueKey('authority-response-summary'),
                  controller: _summaryController,
                  minLines: 3,
                  maxLines: 7,
                  maxLength: 5000,
                  decoration: const InputDecoration(labelText: 'Cevap özeti'),
                  validator: (value) => _requiredTextValidator(
                    value,
                    'Cevap özeti',
                    minimum: 10,
                    maximum: 5000,
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<CustomsAuthorityOutcomeCode>(
                  key: const ValueKey('authority-response-outcome-code'),
                  initialValue: _outcomeCode,
                  decoration: const InputDecoration(
                    labelText: 'Ara sonuç sınıflandırması (isteğe bağlı)',
                  ),
                  items: <DropdownMenuItem<CustomsAuthorityOutcomeCode>>[
                    const DropdownMenuItem(
                      value: null,
                      child: Text('Ara sonuç sınıflandırması yok'),
                    ),
                    ..._interimCodes.map(
                      (code) => DropdownMenuItem(
                        value: code,
                        child: Text(
                          customsAuthorityOutcomeCodeLabel(code.wireValue),
                        ),
                      ),
                    ),
                  ],
                  onChanged: (value) => setState(() => _outcomeCode = value),
                ),
                if (_responseType ==
                    CustomsInterimAuthorityResponseType.informationRequest) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Talep edilen son tarih',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  if (_requestedDueAt == null)
                    OutlinedButton.icon(
                      key: const ValueKey('authority-response-add-due-date'),
                      onPressed: () => setState(() {
                        _requestedDueAt = DateTime.now().add(
                          const Duration(days: 7),
                        );
                      }),
                      icon: const Icon(Icons.event_available_outlined),
                      label: const Text('Son tarih ekle'),
                    )
                  else
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        OutlinedButton.icon(
                          key: const ValueKey(
                            'authority-response-pick-due-date',
                          ),
                          onPressed: () async {
                            final value = await _pickAuthorityDate(
                              context,
                              _requestedDueAt!,
                            );
                            if (value != null && mounted) {
                              setState(() {
                                _requestedDueAt = value;
                                _dueAtError = null;
                              });
                            }
                          },
                          icon: const Icon(Icons.calendar_today_outlined),
                          label: Text(_formatLocalDate(_requestedDueAt!)),
                        ),
                        OutlinedButton.icon(
                          key: const ValueKey(
                            'authority-response-pick-due-time',
                          ),
                          onPressed: () async {
                            final value = await _pickAuthorityTime(
                              context,
                              _requestedDueAt!,
                            );
                            if (value != null && mounted) {
                              setState(() {
                                _requestedDueAt = value;
                                _dueAtError = null;
                              });
                            }
                          },
                          icon: const Icon(Icons.schedule_outlined),
                          label: Text(_formatLocalTime(_requestedDueAt!)),
                        ),
                        TextButton(
                          key: const ValueKey(
                            'authority-response-clear-due-date',
                          ),
                          onPressed: () => setState(() {
                            _requestedDueAt = null;
                            _dueAtError = null;
                          }),
                          child: const Text('Kaldır'),
                        ),
                      ],
                    ),
                  if (_dueAtError != null)
                    Text(
                      _dueAtError!,
                      key: const ValueKey('authority-response-due-date-error'),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Ekler ve bütünlük değerleri',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    OutlinedButton.icon(
                      key: const ValueKey('add-authority-response-attachment'),
                      onPressed: _addAttachment,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Ek ekle'),
                    ),
                  ],
                ),
                for (var index = 0; index < _attachments.length; index++)
                  _AuthorityAttachmentFields(
                    key: ValueKey('authority-response-attachment-$index'),
                    prefix: 'authority-response-attachment',
                    index: index,
                    draft: _attachments[index],
                    onRemove: () => _removeAttachment(index),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Vazgeç'),
        ),
        FilledButton(
          key: const ValueKey('review-authority-response'),
          onPressed: _submit,
          child: const Text('Kaydı gözden geçir'),
        ),
      ],
    );
  }
}

class _AuthorityAttachmentFields extends StatelessWidget {
  const _AuthorityAttachmentFields({
    super.key,
    required this.prefix,
    required this.index,
    required this.draft,
    required this.onRemove,
  });

  final String prefix;
  final int index;
  final _AuthorityAttachmentDraft draft;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD8E1E7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Ek ${index + 1}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              IconButton(
                key: ValueKey('$prefix-remove-$index'),
                tooltip: 'Eki kaldır',
                onPressed: onRemove,
                icon: const Icon(Icons.delete_outline_rounded),
              ),
            ],
          ),
          TextFormField(
            key: ValueKey('$prefix-reference-$index'),
            controller: draft.referenceController,
            maxLength: 500,
            decoration: const InputDecoration(labelText: 'Ek referansı'),
            validator: (value) =>
                _requiredTextValidator(value, 'Ek referansı', minimum: 1),
          ),
          const SizedBox(height: 8),
          TextFormField(
            key: ValueKey('$prefix-hash-$index'),
            controller: draft.hashController,
            maxLength: 64,
            decoration: const InputDecoration(labelText: 'Ek SHA-256'),
            validator: (value) => _isSha256(value ?? '')
                ? null
                : 'Ek SHA-256 değeri 64 haneli hex olmalıdır.',
          ),
        ],
      ),
    );
  }
}

List<CustomsAuthorityOutcomeCode> _terminalOutcomeCodes(
  CustomsFinalAuthorityResponseType type,
) => switch (type) {
  CustomsFinalAuthorityResponseType.decision => const [
    CustomsAuthorityOutcomeCode.actionTaken,
    CustomsAuthorityOutcomeCode.noAction,
    CustomsAuthorityOutcomeCode.referredToOtherAuthority,
    CustomsAuthorityOutcomeCode.closed,
    CustomsAuthorityOutcomeCode.rejected,
    CustomsAuthorityOutcomeCode.other,
  ],
  CustomsFinalAuthorityResponseType.closureNotice => const [
    CustomsAuthorityOutcomeCode.closed,
    CustomsAuthorityOutcomeCode.noAction,
    CustomsAuthorityOutcomeCode.referredToOtherAuthority,
    CustomsAuthorityOutcomeCode.other,
  ],
  CustomsFinalAuthorityResponseType.rejectionNotice => const [
    CustomsAuthorityOutcomeCode.rejected,
  ],
};

List<CustomsAuthorityOutcomeFinalityLevel> _terminalFinalityLevels(
  CustomsFinalAuthorityResponseType type,
) => switch (type) {
  CustomsFinalAuthorityResponseType.decision => const [
    CustomsAuthorityOutcomeFinalityLevel.administrativeFinal,
    CustomsAuthorityOutcomeFinalityLevel.judicialFinal,
  ],
  CustomsFinalAuthorityResponseType.closureNotice ||
  CustomsFinalAuthorityResponseType.rejectionNotice => const [
    CustomsAuthorityOutcomeFinalityLevel.administrativeFinal,
    CustomsAuthorityOutcomeFinalityLevel.judicialFinal,
    CustomsAuthorityOutcomeFinalityLevel.notStated,
  ],
};

class _AuthorityOutcomeDialog extends StatefulWidget {
  const _AuthorityOutcomeDialog({required this.detail});

  final CustomsAuthoritySubmissionDetail detail;

  @override
  State<_AuthorityOutcomeDialog> createState() =>
      _AuthorityOutcomeDialogState();
}

class _AuthorityOutcomeDialogState extends State<_AuthorityOutcomeDialog> {
  final _formKey = GlobalKey<FormState>();
  final _referenceController = TextEditingController();
  final _authorityNameController = TextEditingController();
  final _authorityUnitController = TextEditingController();
  final _summaryController = TextEditingController();
  final _notesController = TextEditingController();
  final List<_AuthorityAttachmentDraft> _attachments = [];
  CustomsFinalAuthorityResponseType _responseType =
      CustomsFinalAuthorityResponseType.decision;
  CustomsAuthorityOutcomeCode _outcomeCode =
      CustomsAuthorityOutcomeCode.actionTaken;
  CustomsAuthorityOutcomeFinalityLevel _finality =
      CustomsAuthorityOutcomeFinalityLevel.administrativeFinal;
  DateTime _officialDocumentDate = DateTime.now();
  DateTime _receivedAt = DateTime.now();
  String? _previousResponseId;
  bool _humanEntryConfirmed = false;
  bool _legalNeutralityConfirmed = false;
  String? _officialDateError;
  String? _receivedAtError;
  String? _confirmationError;

  @override
  void initState() {
    super.initState();
    final submission = widget.detail.submission;
    _referenceController.text = submission.officialReferenceNumber ?? '';
    _authorityNameController.text =
        submission.targetUnit ??
        customsAuthorityTargetLabel(submission.targetAuthority);
    _authorityUnitController.text = submission.targetUnit ?? '';
  }

  @override
  void dispose() {
    _referenceController.dispose();
    _authorityNameController.dispose();
    _authorityUnitController.dispose();
    _summaryController.dispose();
    _notesController.dispose();
    for (final attachment in _attachments) {
      attachment.dispose();
    }
    super.dispose();
  }

  void _changeResponseType(CustomsFinalAuthorityResponseType? value) {
    if (value == null) return;
    setState(() {
      _responseType = value;
      _outcomeCode = _terminalOutcomeCodes(value).first;
      _finality = _terminalFinalityLevels(value).first;
    });
  }

  void _addAttachment() {
    setState(() => _attachments.add(_AuthorityAttachmentDraft()));
  }

  void _removeAttachment(int index) {
    final removed = _attachments.removeAt(index);
    removed.dispose();
    setState(() {});
  }

  void _submit() {
    final formValid = _formKey.currentState?.validate() == true;
    final officialDateError = _authorityDateTimeError(
      _officialDocumentDate,
      'Resmî belge tarihi',
    );
    final receivedAtError = _authorityDateTimeError(
      _receivedAt,
      'Sonucun alınma zamanı',
    );
    String? orderError;
    if (_officialDocumentDate.isAfter(
      _receivedAt.add(const Duration(days: 1)),
    )) {
      orderError =
          'Resmî belge tarihi alınma zamanından bir günden fazla sonra olamaz.';
    }
    setState(() {
      _officialDateError = officialDateError ?? orderError;
      _receivedAtError = receivedAtError;
      _confirmationError = _humanEntryConfirmed && _legalNeutralityConfirmed
          ? null
          : 'İnsan girişi ve hukukî tarafsızlık teyitleri zorunludur.';
    });
    if (!formValid ||
        officialDateError != null ||
        receivedAtError != null ||
        orderError != null ||
        !_humanEntryConfirmed ||
        !_legalNeutralityConfirmed) {
      return;
    }

    Navigator.pop(
      context,
      CustomsAuthorityOutcomeDraft(
        responseType: _responseType,
        outcomeCode: _outcomeCode,
        outcomeFinalityLevel: _finality,
        authorityReferenceNumber: _referenceController.text,
        officialDocumentDate: _officialDocumentDate.toUtc().toIso8601String(),
        receivedAt: _receivedAt.toUtc().toIso8601String(),
        authorityNameSnapshot: _authorityNameController.text,
        authorityUnitSnapshot: _authorityUnitController.text.trim().isEmpty
            ? null
            : _authorityUnitController.text.trim(),
        summary: _summaryController.text,
        previousResponseId: _previousResponseId,
        attachmentReferences: _attachments
            .map((item) => item.referenceController.text.trim())
            .toList(growable: false),
        attachmentHashes: _attachments
            .map((item) => item.hashController.text.trim().toLowerCase())
            .toList(growable: false),
        additionalNotes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        humanEntryConfirmed: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final outcomeCodes = _terminalOutcomeCodes(_responseType);
    final finalityLevels = _terminalFinalityLevels(_responseType);
    final responses = widget.detail.responses;
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      title: const Text('Nihai kurum sonucu'),
      content: SizedBox(
        width: 780,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(authorityOutcomeDescription),
                const SizedBox(height: 16),
                DropdownButtonFormField<CustomsFinalAuthorityResponseType>(
                  key: const ValueKey('authority-outcome-response-type'),
                  initialValue: _responseType,
                  decoration: const InputDecoration(
                    labelText: 'Nihai cevap türü',
                  ),
                  items: CustomsFinalAuthorityResponseType.values
                      .map(
                        (type) => DropdownMenuItem(
                          value: type,
                          child: Text(
                            customsAuthorityResponseTypeLabel(type.wireValue),
                          ),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: _changeResponseType,
                ),
                const SizedBox(height: 12),
                InputDecorator(
                  decoration: const InputDecoration(labelText: 'Sonuç kodu'),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<CustomsAuthorityOutcomeCode>(
                      key: const ValueKey('authority-outcome-code'),
                      value: _outcomeCode,
                      isExpanded: true,
                      items: outcomeCodes
                          .map(
                            (code) => DropdownMenuItem(
                              value: code,
                              child: Text(
                                customsAuthorityOutcomeCodeLabel(
                                  code.wireValue,
                                ),
                              ),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _outcomeCode = value);
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Kesinlik seviyesi',
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<CustomsAuthorityOutcomeFinalityLevel>(
                      key: const ValueKey('authority-outcome-finality'),
                      value: _finality,
                      isExpanded: true,
                      items: finalityLevels
                          .map(
                            (level) => DropdownMenuItem(
                              value: level,
                              child: Text(
                                customsAuthorityOutcomeFinalityLabel(
                                  level.wireValue,
                                ),
                              ),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: (value) {
                        if (value != null) setState(() => _finality = value);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const ValueKey('authority-outcome-reference'),
                  controller: _referenceController,
                  maxLength: 500,
                  decoration: const InputDecoration(
                    labelText: 'Kurum referans numarası',
                  ),
                  validator: (value) => _requiredTextValidator(
                    value,
                    'Kurum referansı',
                    minimum: 2,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Resmî belge tarihi',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  key: const ValueKey('authority-outcome-pick-document-date'),
                  onPressed: () async {
                    final value = await _pickAuthorityDate(
                      context,
                      _officialDocumentDate,
                    );
                    if (value != null && mounted) {
                      setState(() {
                        _officialDocumentDate = value;
                        _officialDateError = null;
                      });
                    }
                  },
                  icon: const Icon(Icons.calendar_today_outlined),
                  label: Text(_formatLocalDate(_officialDocumentDate)),
                ),
                if (_officialDateError != null)
                  Text(
                    _officialDateError!,
                    key: const ValueKey(
                      'authority-outcome-document-date-error',
                    ),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                const SizedBox(height: 12),
                const Text(
                  'Sonucun alındığı tarih ve saat',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    OutlinedButton.icon(
                      key: const ValueKey('authority-outcome-pick-date'),
                      onPressed: () async {
                        final value = await _pickAuthorityDate(
                          context,
                          _receivedAt,
                        );
                        if (value != null && mounted) {
                          setState(() {
                            _receivedAt = value;
                            _receivedAtError = null;
                          });
                        }
                      },
                      icon: const Icon(Icons.calendar_today_outlined),
                      label: Text(_formatLocalDate(_receivedAt)),
                    ),
                    OutlinedButton.icon(
                      key: const ValueKey('authority-outcome-pick-time'),
                      onPressed: () async {
                        final value = await _pickAuthorityTime(
                          context,
                          _receivedAt,
                        );
                        if (value != null && mounted) {
                          setState(() {
                            _receivedAt = value;
                            _receivedAtError = null;
                          });
                        }
                      },
                      icon: const Icon(Icons.schedule_outlined),
                      label: Text(_formatLocalTime(_receivedAt)),
                    ),
                  ],
                ),
                if (_receivedAtError != null)
                  Text(
                    _receivedAtError!,
                    key: const ValueKey('authority-outcome-date-error'),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const ValueKey('authority-outcome-authority-name'),
                  controller: _authorityNameController,
                  maxLength: 300,
                  decoration: const InputDecoration(labelText: 'Kurum adı'),
                  validator: (value) => _requiredTextValidator(
                    value,
                    'Kurum adı',
                    minimum: 2,
                    maximum: 300,
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const ValueKey('authority-outcome-authority-unit'),
                  controller: _authorityUnitController,
                  maxLength: 300,
                  decoration: const InputDecoration(
                    labelText: 'Kurum birimi (isteğe bağlı)',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const ValueKey('authority-outcome-summary'),
                  controller: _summaryController,
                  minLines: 3,
                  maxLines: 7,
                  maxLength: 5000,
                  decoration: const InputDecoration(labelText: 'Sonuç özeti'),
                  validator: (value) => _requiredTextValidator(
                    value,
                    'Sonuç özeti',
                    minimum: 10,
                    maximum: 5000,
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  key: const ValueKey('authority-outcome-previous-response'),
                  initialValue: _previousResponseId,
                  decoration: const InputDecoration(
                    labelText: 'Önceki cevap bağlantısı (isteğe bağlı)',
                  ),
                  items: <DropdownMenuItem<String>>[
                    const DropdownMenuItem(
                      value: null,
                      child: Text('Bağlantı yok'),
                    ),
                    ...responses.map(
                      (response) => DropdownMenuItem(
                        value: response.responseId,
                        child: Text(
                          '${customsAuthorityResponseTypeLabel(response.responseType)} · ${_formatDateTime(response.receivedAt)}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                  onChanged: (value) =>
                      setState(() => _previousResponseId = value),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const ValueKey('authority-outcome-notes'),
                  controller: _notesController,
                  minLines: 2,
                  maxLines: 5,
                  maxLength: 3000,
                  decoration: const InputDecoration(
                    labelText: 'İlave notlar (isteğe bağlı)',
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Resmî belge ekleri',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    OutlinedButton.icon(
                      key: const ValueKey('add-authority-outcome-attachment'),
                      onPressed: _addAttachment,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Ek ekle'),
                    ),
                  ],
                ),
                for (var index = 0; index < _attachments.length; index++)
                  _AuthorityAttachmentFields(
                    key: ValueKey('authority-outcome-attachment-$index'),
                    prefix: 'authority-outcome-attachment',
                    index: index,
                    draft: _attachments[index],
                    onRemove: () => _removeAttachment(index),
                  ),
                const SizedBox(height: 12),
                CheckboxListTile(
                  key: const ValueKey('authority-outcome-human-confirmation'),
                  contentPadding: EdgeInsets.zero,
                  value: _humanEntryConfirmed,
                  onChanged: (value) {
                    setState(() {
                      _humanEntryConfirmed = value == true;
                      if (_humanEntryConfirmed && _legalNeutralityConfirmed) {
                        _confirmationError = null;
                      }
                    });
                  },
                  title: const Text(
                    'Bu sonuç kurum tarafından düzenlenen belgeye dayanarak bir insan tarafından girilmiştir.',
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                CheckboxListTile(
                  key: const ValueKey(
                    'authority-outcome-neutrality-confirmation',
                  ),
                  contentPadding: EdgeInsets.zero,
                  value: _legalNeutralityConfirmed,
                  onChanged: (value) {
                    setState(() {
                      _legalNeutralityConfirmed = value == true;
                      if (_humanEntryConfirmed && _legalNeutralityConfirmed) {
                        _confirmationError = null;
                      }
                    });
                  },
                  title: const Text(
                    'Seçilen sonuç kodunun MarkaKalkan tarafından verilmiş hukukî karar olmadığını; kurum belgesinin kullanıcı sınıflandırması olduğunu anlıyorum.',
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                if (_confirmationError != null)
                  Text(
                    _confirmationError!,
                    key: const ValueKey('authority-outcome-confirmation-error'),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Vazgeç'),
        ),
        FilledButton(
          key: const ValueKey('review-authority-outcome'),
          onPressed: _submit,
          child: const Text('Sonucu gözden geçir'),
        ),
      ],
    );
  }
}

bool _packageGenerationAllowed(CustomsAuthoritySubmission submission) =>
    submission.status == 'approved_for_package' &&
    submission.humanReviewReference != null &&
    submission.rightsHolderApprovalReference != null &&
    submission.dataMinimizationConfirmed &&
    submission.nonAccusatoryLanguageConfirmed;

class _PackageGenerationSection extends StatelessWidget {
  const _PackageGenerationSection({
    required this.submission,
    required this.scopeAvailable,
    required this.generating,
    required this.onGenerate,
  });

  final CustomsAuthoritySubmission submission;
  final bool scopeAvailable;
  final bool generating;
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) {
    final blockers = <String>[
      if (!scopeAvailable) 'Tenant ve marka kapsamı doğrulanamadı.',
      if (submission.status != 'approved_for_package')
        'Dosya “Paket hazırlamaya onaylandı” durumunda olmalıdır.',
      if (submission.humanReviewReference == null)
        'İnsan incelemesi referansı eksik.',
      if (submission.rightsHolderApprovalReference == null)
        'Hak sahibi veya temsilci onayı eksik.',
      if (!submission.dataMinimizationConfirmed)
        'Veri minimizasyonu teyidi eksik.',
      if (!submission.nonAccusatoryLanguageConfirmed)
        'Hukuken nötr dil teyidi eksik.',
    ];
    final allowed = blockers.isEmpty;

    return _AuthoritySection(
      title: 'Başvuru paketi üretimi',
      children: [
        const Text(
          'Onaylanmış başvuru veya ihbar içeriğini; üst yazı, kurum özeti, '
          'belge/delil manifesti ve hukuken nötr dil beyanıyla değiştirilemez '
          'bir paket sürümüne dönüştürün. Bu işlem kuruma otomatik gönderim '
          'yapmaz.',
          style: TextStyle(height: 1.5),
        ),
        if (blockers.isNotEmpty)
          Container(
            key: const ValueKey('customs-package-generation-blockers'),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8E8),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFF0D9A2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Paket üretimi için tamamlanması gerekenler:',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                for (final blocker in blockers)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('• '),
                        Expanded(child: Text(blocker)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        FilledButton.icon(
          key: const ValueKey('generate-customs-submission-package'),
          onPressed: allowed && !generating ? onGenerate : null,
          icon: generating
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.inventory_2_outlined),
          label: Text(
            generating ? 'Paket üretiliyor…' : 'Başvuru Paketini Üret',
          ),
        ),
      ],
    );
  }
}

class _ExternalSubmissionDialog extends StatefulWidget {
  const _ExternalSubmissionDialog({
    required this.submission,
    required this.package,
  });

  final CustomsAuthoritySubmission submission;
  final CustomsSubmissionPackage package;

  @override
  State<_ExternalSubmissionDialog> createState() =>
      _ExternalSubmissionDialogState();
}

class _ExternalSubmissionDialogState extends State<_ExternalSubmissionDialog> {
  final _formKey = GlobalKey<FormState>();
  final _statementController = TextEditingController();
  final _referenceController = TextEditingController();
  late CustomsSubmissionChannel _channel;
  CustomsExternalReferenceType _referenceType =
      CustomsExternalReferenceType.none;
  DateTime _submittedAt = DateTime.now();
  bool _confirmed = false;
  String? _confirmationError;
  String? _submittedAtError;

  @override
  void initState() {
    super.initState();
    _channel = _submissionChannelFromWire(widget.submission.channelType);
  }

  @override
  void dispose() {
    _statementController.dispose();
    _referenceController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _submittedAt,
      firstDate: DateTime.now().subtract(const Duration(days: 3650)),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (selected == null || !mounted) return;
    setState(() {
      _submittedAt = DateTime(
        selected.year,
        selected.month,
        selected.day,
        _submittedAt.hour,
        _submittedAt.minute,
      );
      _submittedAtError = null;
    });
  }

  Future<void> _pickTime() async {
    final selected = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_submittedAt),
    );
    if (selected == null || !mounted) return;
    setState(() {
      _submittedAt = DateTime(
        _submittedAt.year,
        _submittedAt.month,
        _submittedAt.day,
        selected.hour,
        selected.minute,
      );
      _submittedAtError = null;
    });
  }

  void _changeChannel(CustomsSubmissionChannel? value) {
    if (value == null) return;
    final allowed = _externalReferenceTypesForChannel(value);
    setState(() {
      _channel = value;
      if (!allowed.contains(_referenceType)) {
        _referenceType = CustomsExternalReferenceType.none;
        _referenceController.clear();
      }
    });
  }

  void _changeReferenceType(CustomsExternalReferenceType? value) {
    if (value == null) return;
    setState(() {
      _referenceType = value;
      if (value == CustomsExternalReferenceType.none) {
        _referenceController.clear();
      }
    });
  }

  String? _statementValidator(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.length < 20) {
      return 'Teslim beyanı en az 20 karakter olmalıdır.';
    }
    if (trimmed.length > 2000) {
      return 'Teslim beyanı 2000 karakteri aşamaz.';
    }
    return null;
  }

  String? _referenceValidator(String? value) {
    if (_referenceType == CustomsExternalReferenceType.none) return null;
    final trimmed = value?.trim() ?? '';
    if (trimmed.length < 3) {
      return 'Dış referans en az 3 karakter olmalıdır.';
    }
    if (trimmed.length > 300) {
      return 'Dış referans 300 karakteri aşamaz.';
    }
    return null;
  }

  void _submit() {
    final now = DateTime.now();
    final oldestAccepted = now.subtract(const Duration(days: 3650));
    String? submittedAtError;
    if (_submittedAt.isAfter(now.add(const Duration(minutes: 5)))) {
      submittedAtError = 'Teslim zamanı 5 dakikadan fazla ileride olamaz.';
    } else if (_submittedAt.isBefore(oldestAccepted)) {
      submittedAtError = 'Teslim zamanı 10 yıldan daha eski olamaz.';
    }

    final formValid = _formKey.currentState?.validate() == true;
    setState(() {
      _submittedAtError = submittedAtError;
      _confirmationError = _confirmed
          ? null
          : 'Gerçek dış teslim teyidi zorunludur.';
    });
    if (!formValid || submittedAtError != null || !_confirmed) return;

    Navigator.pop(
      context,
      CustomsExternalSubmissionDraft(
        submissionChannel: _channel,
        submittedAt: _submittedAt.toUtc().toIso8601String(),
        externalSubmissionStatement: _statementController.text,
        externalReferenceType: _referenceType,
        externalReferenceValue:
            _referenceType == CustomsExternalReferenceType.none
            ? null
            : _referenceController.text.trim(),
        externalSubmissionConfirmed: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final referenceTypes = _externalReferenceTypesForChannel(_channel);
    return AlertDialog(
      title: const Text('Kuruma dış teslim kaydı'),
      content: SizedBox(
        width: 700,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  externalSubmissionNotAutomaticDescription,
                  style: TextStyle(height: 1.45),
                ),
                const SizedBox(height: 16),
                _AuthorityRow(
                  label: 'Güncel paket',
                  value:
                      '${widget.package.packageId} · v${widget.package.version}',
                ),
                _AuthorityRow(
                  label: 'Paket hash’i',
                  value: widget.package.aggregateHash,
                  monospace: true,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<CustomsSubmissionChannel>(
                  key: const ValueKey('external-submission-channel'),
                  initialValue: _channel,
                  decoration: const InputDecoration(labelText: 'Teslim kanalı'),
                  items: CustomsSubmissionChannel.values
                      .map(
                        (channel) => DropdownMenuItem(
                          value: channel,
                          child: Text(
                            customsAuthorityChannelLabel(channel.wireValue),
                          ),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: _changeChannel,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Teslim tarihi ve saati',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      key: const ValueKey('external-submission-pick-date'),
                      onPressed: _pickDate,
                      icon: const Icon(Icons.calendar_today_outlined),
                      label: Text(_formatLocalDate(_submittedAt)),
                    ),
                    OutlinedButton.icon(
                      key: const ValueKey('external-submission-pick-time'),
                      onPressed: _pickTime,
                      icon: const Icon(Icons.schedule_outlined),
                      label: Text(_formatLocalTime(_submittedAt)),
                    ),
                  ],
                ),
                if (_submittedAtError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      _submittedAtError!,
                      key: const ValueKey('external-submission-date-error'),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const ValueKey('external-submission-statement'),
                  controller: _statementController,
                  minLines: 3,
                  maxLines: 7,
                  maxLength: 2000,
                  decoration: const InputDecoration(
                    labelText: 'Dış teslim beyanı',
                    helperText:
                        'Teslimin kim tarafından, hangi kanaldan ve nasıl '
                        'tamamlandığını açıkça yazın.',
                  ),
                  validator: _statementValidator,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<CustomsExternalReferenceType>(
                  key: const ValueKey('external-reference-type'),
                  initialValue: _referenceType,
                  decoration: const InputDecoration(
                    labelText: 'Dış referans türü',
                  ),
                  items: referenceTypes
                      .map(
                        (type) => DropdownMenuItem(
                          value: type,
                          child: Text(
                            customsExternalReferenceTypeLabel(type.wireValue),
                          ),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: _changeReferenceType,
                ),
                if (_referenceType != CustomsExternalReferenceType.none) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const ValueKey('external-reference-value'),
                    controller: _referenceController,
                    maxLength: 300,
                    decoration: const InputDecoration(
                      labelText: 'Dış referans değeri',
                    ),
                    validator: _referenceValidator,
                  ),
                ],
                const SizedBox(height: 12),
                CheckboxListTile(
                  key: const ValueKey('external-submission-confirmation'),
                  contentPadding: EdgeInsets.zero,
                  value: _confirmed,
                  onChanged: (value) {
                    setState(() {
                      _confirmed = value == true;
                      if (_confirmed) _confirmationError = null;
                    });
                  },
                  title: const Text(
                    'Bu paketin seçilen kanaldan gerçekten teslim edildiğini '
                    've bu kaydın değiştirilemez olay zincirine yazılacağını '
                    'teyit ediyorum.',
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                if (_confirmationError != null)
                  Text(
                    _confirmationError!,
                    key: const ValueKey(
                      'external-submission-confirmation-error',
                    ),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Vazgeç'),
        ),
        FilledButton(
          key: const ValueKey('review-external-submission'),
          onPressed: _submit,
          child: const Text('Kaydı gözden geçir'),
        ),
      ],
    );
  }
}

CustomsSubmissionChannel _submissionChannelFromWire(String? value) {
  for (final channel in CustomsSubmissionChannel.values) {
    if (channel.wireValue == value) return channel;
  }
  return CustomsSubmissionChannel.other;
}

List<CustomsExternalReferenceType> _externalReferenceTypesForChannel(
  CustomsSubmissionChannel channel,
) => switch (channel) {
  CustomsSubmissionChannel.fsmhPortal ||
  CustomsSubmissionChannel.officialOnlineForm ||
  CustomsSubmissionChannel.electronicSignature => const [
    CustomsExternalReferenceType.none,
    CustomsExternalReferenceType.portalTransactionId,
  ],
  CustomsSubmissionChannel.registeredEmail => const [
    CustomsExternalReferenceType.none,
    CustomsExternalReferenceType.kepMessageId,
  ],
  CustomsSubmissionChannel.physicalDelivery => const [
    CustomsExternalReferenceType.none,
    CustomsExternalReferenceType.physicalDeliveryReference,
  ],
  CustomsSubmissionChannel.telephone136 ||
  CustomsSubmissionChannel.emergency112 => const [
    CustomsExternalReferenceType.none,
    CustomsExternalReferenceType.telephoneReference,
  ],
  CustomsSubmissionChannel.officialCorrespondence => const [
    CustomsExternalReferenceType.none,
    CustomsExternalReferenceType.officialCorrespondenceReference,
  ],
  CustomsSubmissionChannel.other => const [
    CustomsExternalReferenceType.none,
    CustomsExternalReferenceType.otherReference,
  ],
};

String _formatLocalDate(DateTime value) {
  String two(int number) => number.toString().padLeft(2, '0');
  return '${two(value.day)}.${two(value.month)}.${value.year}';
}

String _formatLocalTime(DateTime value) {
  String two(int number) => number.toString().padLeft(2, '0');
  return '${two(value.hour)}:${two(value.minute)}';
}

enum _PackageManifestKind { document, evidence }

class _PackageManifestDraft {
  const _PackageManifestDraft({required this.kind, required this.item});

  final _PackageManifestKind kind;
  final CustomsSubmissionManifestItem item;
}

class _PackageRedactionDraft {
  const _PackageRedactionDraft({required this.item});

  final CustomsSubmissionRedactionItem item;
}

class _GeneratePackageDialog extends StatefulWidget {
  const _GeneratePackageDialog({required this.submission});

  final CustomsAuthoritySubmission submission;

  @override
  State<_GeneratePackageDialog> createState() => _GeneratePackageDialogState();
}

class _GeneratePackageDialogState extends State<_GeneratePackageDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _coverLetterController;
  late final TextEditingController _summaryController;
  late final TextEditingController _neutralityController;
  late CustomsSubmissionPackageType _packageType;
  final List<_PackageManifestDraft> _manifestItems = [];
  final List<_PackageRedactionDraft> _redactionItems = [];
  String? _manifestError;

  @override
  void initState() {
    super.initState();
    final submission = widget.submission;
    _packageType = switch (submission.submissionType) {
      'fsmh_protection_application' =>
        CustomsSubmissionPackageType.fsmhApplicationPackage,
      'additional_information_response' =>
        CustomsSubmissionPackageType.additionalInformationPackage,
      _ => CustomsSubmissionPackageType.authorityReferralPackage,
    };
    _coverLetterController = TextEditingController(
      text:
          'Sayın Yetkili,\n\n${submission.authoritySummary}\n\n'
          'İlgili belge ve deliller değerlendirilmek üzere sunulmaktadır.',
    );
    _summaryController = TextEditingController(
      text: submission.authoritySummary,
    );
    _neutralityController = TextEditingController(
      text:
          'Bu paket mevcut kayıtlar ve insan incelemesine dayanır; kesin suç '
          'isnadı veya otomatik hüküm içermez.',
    );
  }

  @override
  void dispose() {
    _coverLetterController.dispose();
    _summaryController.dispose();
    _neutralityController.dispose();
    super.dispose();
  }

  Future<void> _addManifestItem() async {
    final item = await showDialog<_PackageManifestDraft>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const _PackageManifestItemDialog(),
    );
    if (item == null || !mounted) return;
    setState(() {
      _manifestItems.add(item);
      _manifestError = null;
    });
  }

  Future<void> _addRedactionItem() async {
    final item = await showDialog<_PackageRedactionDraft>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const _PackageRedactionItemDialog(),
    );
    if (item == null || !mounted) return;
    setState(() => _redactionItems.add(item));
  }

  void _submit() {
    final formValid = _formKey.currentState?.validate() == true;
    if (_manifestItems.isEmpty) {
      setState(() => _manifestError = 'En az bir belge veya delil ekleyin.');
    }
    if (!formValid || _manifestItems.isEmpty) return;

    Navigator.pop(
      context,
      CustomsSubmissionPackageDraft(
        packageType: _packageType,
        coverLetterText: _coverLetterController.text,
        authoritySummary: _summaryController.text,
        legalNeutralityStatement: _neutralityController.text,
        documentManifest: _manifestItems
            .where((entry) => entry.kind == _PackageManifestKind.document)
            .map((entry) => entry.item)
            .toList(growable: false),
        evidenceManifest: _manifestItems
            .where((entry) => entry.kind == _PackageManifestKind.evidence)
            .map((entry) => entry.item)
            .toList(growable: false),
        redactionManifest: _redactionItems
            .map((entry) => entry.item)
            .toList(growable: false),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Başvuru paketi hazırlama'),
      content: SizedBox(
        width: 720,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Bu form paket sürümünün değiştirilemez içeriğini hazırlar. '
                  'Üretilen paket ayrıca güvenli PDF ve JSON dosyalarına '
                  'dönüştürülebilir.',
                  style: TextStyle(height: 1.45),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<CustomsSubmissionPackageType>(
                  key: const ValueKey('customs-package-type'),
                  initialValue: _packageType,
                  decoration: const InputDecoration(labelText: 'Paket türü'),
                  items: CustomsSubmissionPackageType.values
                      .map(
                        (type) => DropdownMenuItem(
                          value: type,
                          child: Text(_packageTypeLabel(type)),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) {
                    if (value != null) setState(() => _packageType = value);
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const ValueKey('customs-package-cover-letter'),
                  controller: _coverLetterController,
                  minLines: 4,
                  maxLines: 8,
                  decoration: const InputDecoration(labelText: 'Üst yazı'),
                  validator: _requiredText,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const ValueKey('customs-package-authority-summary'),
                  controller: _summaryController,
                  minLines: 3,
                  maxLines: 6,
                  decoration: const InputDecoration(labelText: 'Kurum özeti'),
                  validator: _requiredText,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const ValueKey('customs-package-neutrality-statement'),
                  controller: _neutralityController,
                  minLines: 2,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'Hukuken nötr dil beyanı',
                  ),
                  validator: _requiredText,
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Belge ve delil manifesti',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    OutlinedButton.icon(
                      key: const ValueKey('add-customs-package-manifest-item'),
                      onPressed: _addManifestItem,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Belge / delil ekle'),
                    ),
                  ],
                ),
                if (_manifestError != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _manifestError!,
                    key: const ValueKey('customs-package-manifest-error'),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                if (_manifestItems.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 10),
                    child: Text('Henüz belge veya delil eklenmedi.'),
                  )
                else ...[
                  const SizedBox(height: 10),
                  for (var index = 0; index < _manifestItems.length; index++)
                    Card(
                      key: ValueKey('customs-package-manifest-item-$index'),
                      elevation: 0,
                      child: ListTile(
                        leading: Icon(
                          _manifestItems[index].kind ==
                                  _PackageManifestKind.document
                              ? Icons.description_outlined
                              : Icons.fact_check_outlined,
                        ),
                        title: Text(_manifestItems[index].item.title),
                        subtitle: Text(
                          '${_manifestItems[index].item.referenceId}\n'
                          '${_shortHashValue(_manifestItems[index].item.sha256)}',
                        ),
                        isThreeLine: true,
                        trailing: IconButton(
                          tooltip: 'Kaldır',
                          onPressed: () {
                            setState(() => _manifestItems.removeAt(index));
                          },
                          icon: const Icon(Icons.delete_outline_rounded),
                        ),
                      ),
                    ),
                ],
                const SizedBox(height: 18),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Veri minimizasyonu ve redaksiyon manifesti',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    OutlinedButton.icon(
                      key: const ValueKey('add-customs-package-redaction-item'),
                      onPressed: _addRedactionItem,
                      icon: const Icon(Icons.security_outlined),
                      label: const Text('Redaksiyon ekle'),
                    ),
                  ],
                ),
                if (_redactionItems.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 10),
                    child: Text(
                      'Bu paket için ayrıca bir redaksiyon kaydı eklenmedi.',
                    ),
                  )
                else ...[
                  const SizedBox(height: 10),
                  for (var index = 0; index < _redactionItems.length; index++)
                    Card(
                      key: ValueKey('customs-package-redaction-item-$index'),
                      elevation: 0,
                      child: ListTile(
                        leading: const Icon(Icons.security_outlined),
                        title: Text(_redactionItems[index].item.fieldPath),
                        subtitle: Text(
                          '${_redactionItems[index].item.action} · '
                          '${_redactionItems[index].item.reason}',
                        ),
                        trailing: IconButton(
                          tooltip: 'Kaldır',
                          onPressed: () {
                            setState(() => _redactionItems.removeAt(index));
                          },
                          icon: const Icon(Icons.delete_outline_rounded),
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Vazgeç'),
        ),
        FilledButton(
          key: const ValueKey('review-customs-package'),
          onPressed: _submit,
          child: const Text('İncele ve devam et'),
        ),
      ],
    );
  }
}

class _PackageManifestItemDialog extends StatefulWidget {
  const _PackageManifestItemDialog();

  @override
  State<_PackageManifestItemDialog> createState() =>
      _PackageManifestItemDialogState();
}

class _PackageManifestItemDialogState
    extends State<_PackageManifestItemDialog> {
  final _formKey = GlobalKey<FormState>();
  final _referenceController = TextEditingController();
  final _titleController = TextEditingController();
  final _hashController = TextEditingController();
  final _mimeController = TextEditingController();
  final _sizeController = TextEditingController();
  _PackageManifestKind _kind = _PackageManifestKind.document;

  @override
  void dispose() {
    _referenceController.dispose();
    _titleController.dispose();
    _hashController.dispose();
    _mimeController.dispose();
    _sizeController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() != true) return;
    Navigator.pop(
      context,
      _PackageManifestDraft(
        kind: _kind,
        item: CustomsSubmissionManifestItem(
          referenceId: _referenceController.text,
          title: _titleController.text,
          sha256: _hashController.text.toLowerCase(),
          mimeType: _optionalTrimmed(_mimeController.text),
          sizeBytes: _optionalPositiveInt(_sizeController.text),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Belge veya delil ekle'),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [
                DropdownButtonFormField<_PackageManifestKind>(
                  key: const ValueKey('customs-package-manifest-kind'),
                  initialValue: _kind,
                  decoration: const InputDecoration(labelText: 'Kayıt türü'),
                  items: const [
                    DropdownMenuItem(
                      value: _PackageManifestKind.document,
                      child: Text('Belge'),
                    ),
                    DropdownMenuItem(
                      value: _PackageManifestKind.evidence,
                      child: Text('Delil'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _kind = value);
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const ValueKey('customs-package-manifest-reference-id'),
                  controller: _referenceController,
                  decoration: const InputDecoration(
                    labelText: 'Kayıt / dosya referansı',
                  ),
                  validator: _requiredText,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const ValueKey('customs-package-manifest-title'),
                  controller: _titleController,
                  decoration: const InputDecoration(labelText: 'Başlık'),
                  validator: _requiredText,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const ValueKey('customs-package-manifest-sha256'),
                  controller: _hashController,
                  decoration: const InputDecoration(labelText: 'SHA-256'),
                  validator: (value) {
                    final normalized = value?.trim() ?? '';
                    if (!RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(normalized)) {
                      return '64 karakterlik geçerli SHA-256 girin.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const ValueKey('customs-package-manifest-mime'),
                  controller: _mimeController,
                  decoration: const InputDecoration(
                    labelText: 'MIME türü (isteğe bağlı)',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const ValueKey('customs-package-manifest-size'),
                  controller: _sizeController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Boyut, bayt (isteğe bağlı)',
                  ),
                  validator: (value) {
                    final trimmed = value?.trim() ?? '';
                    if (trimmed.isEmpty) return null;
                    final parsed = int.tryParse(trimmed);
                    if (parsed == null || parsed <= 0) {
                      return 'Pozitif bir bayt değeri girin.';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Vazgeç'),
        ),
        FilledButton(
          key: const ValueKey('confirm-customs-package-manifest-item'),
          onPressed: _submit,
          child: const Text('Ekle'),
        ),
      ],
    );
  }
}

class _PackageRedactionItemDialog extends StatefulWidget {
  const _PackageRedactionItemDialog();

  @override
  State<_PackageRedactionItemDialog> createState() =>
      _PackageRedactionItemDialogState();
}

class _PackageRedactionItemDialogState
    extends State<_PackageRedactionItemDialog> {
  final _formKey = GlobalKey<FormState>();
  final _fieldPathController = TextEditingController();
  final _reasonController = TextEditingController();
  CustomsRedactionAction _action = CustomsRedactionAction.mask;

  @override
  void dispose() {
    _fieldPathController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() != true) return;
    Navigator.pop(
      context,
      _PackageRedactionDraft(
        item: CustomsSubmissionRedactionItem(
          fieldPath: _fieldPathController.text,
          action: _action.wireValue,
          reason: _reasonController.text,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Redaksiyon kaydı ekle'),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                key: const ValueKey('customs-package-redaction-field-path'),
                controller: _fieldPathController,
                decoration: const InputDecoration(labelText: 'Alan yolu'),
                validator: _requiredText,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<CustomsRedactionAction>(
                key: const ValueKey('customs-package-redaction-action'),
                initialValue: _action,
                decoration: const InputDecoration(labelText: 'İşlem'),
                items: CustomsRedactionAction.values
                    .map(
                      (action) => DropdownMenuItem(
                        value: action,
                        child: Text(_redactionActionLabel(action)),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (value) {
                  if (value != null) setState(() => _action = value);
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const ValueKey('customs-package-redaction-reason'),
                controller: _reasonController,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'Gerekçe'),
                validator: _requiredText,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Vazgeç'),
        ),
        FilledButton(
          key: const ValueKey('confirm-customs-package-redaction-item'),
          onPressed: _submit,
          child: const Text('Ekle'),
        ),
      ],
    );
  }
}

String? _requiredText(String? value) =>
    (value?.trim().isEmpty ?? true) ? 'Bu alan zorunludur.' : null;

String? _optionalTrimmed(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

int? _optionalPositiveInt(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : int.parse(trimmed);
}

String _packageTypeLabel(CustomsSubmissionPackageType type) => switch (type) {
  CustomsSubmissionPackageType.fsmhApplicationPackage =>
    'FSMH koruma başvuru paketi',
  CustomsSubmissionPackageType.authorityReferralPackage =>
    'Yetkili kuruma sevk paketi',
  CustomsSubmissionPackageType.additionalInformationPackage =>
    'Ek bilgi paketi',
};

String _redactionActionLabel(CustomsRedactionAction action) => switch (action) {
  CustomsRedactionAction.remove => 'Kaldır',
  CustomsRedactionAction.mask => 'Maskele',
  CustomsRedactionAction.generalize => 'Genelleştir',
  CustomsRedactionAction.retain => 'Aynen koru',
};

String _shortHashValue(String value) =>
    value.length <= 12 ? value : '${value.substring(0, 12)}…';

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

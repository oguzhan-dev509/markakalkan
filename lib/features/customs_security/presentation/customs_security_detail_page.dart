import 'package:flutter/material.dart';
import 'package:markakalkan/app/router.dart';
import 'package:markakalkan/core/theme/markakalkan_theme.dart';
import 'package:markakalkan/features/customs_security/data/customs_authority_submission_repository.dart';
import 'package:markakalkan/features/customs_security/data/customs_security_repository.dart';
import 'package:markakalkan/features/customs_security/presentation/customs_authority_submission_labels.dart';
import 'package:markakalkan/features/customs_security/presentation/customs_security_labels.dart';

typedef CustomsAuthoritySubmissionDetailOpener =
    Future<void> Function(BuildContext context, String submissionId);

enum CustomsSecurityDetailType { profile, intervention }

class CustomsSecurityDetailPage extends StatefulWidget {
  const CustomsSecurityDetailPage.profile({
    super.key,
    required String profileId,
    this.repository,
    this.authorityRepository,
    this.submissionDetailOpener,
  }) : detailType = CustomsSecurityDetailType.profile,
       recordId = profileId;

  const CustomsSecurityDetailPage.intervention({
    super.key,
    required String interventionId,
    this.repository,
    this.authorityRepository,
    this.submissionDetailOpener,
  }) : detailType = CustomsSecurityDetailType.intervention,
       recordId = interventionId;

  final CustomsSecurityDetailType detailType;
  final String recordId;
  final CustomsSecurityRepository? repository;
  final CustomsAuthoritySubmissionRepository? authorityRepository;
  final CustomsAuthoritySubmissionDetailOpener? submissionDetailOpener;

  @override
  State<CustomsSecurityDetailPage> createState() =>
      _CustomsSecurityDetailPageState();
}

class _CustomsSecurityDetailPageState extends State<CustomsSecurityDetailPage> {
  late final CustomsSecurityRepository _repository;
  late final CustomsAuthoritySubmissionRepository _authorityRepository;
  bool _loading = true;
  bool _transitioning = false;
  bool _creatingSubmission = false;
  String? _error;
  CustomsProtectionProfile? _profile;
  CustomsBorderInterventionDetail? _interventionDetail;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? CallableCustomsSecurityRepository();
    _authorityRepository =
        widget.authorityRepository ??
        (widget.repository == null
            ? CallableCustomsAuthoritySubmissionRepository()
            : const EmptyCustomsAuthoritySubmissionRepository());
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (widget.detailType == CustomsSecurityDetailType.profile) {
        final detail = await _repository.getProfileDetail(widget.recordId);
        if (!mounted) return;
        setState(() {
          _profile = detail.profile;
          _interventionDetail = null;
          _loading = false;
        });
      } else {
        final detail = await _repository.getInterventionDetail(widget.recordId);
        if (!mounted) return;
        setState(() {
          _profile = null;
          _interventionDetail = detail;
          _loading = false;
        });
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = customsSecurityErrorMessage(error);
      });
    }
  }

  Future<void> _transitionProfile(CustomsProtectionProfile profile) async {
    final nextStatuses = customsProfileTransitions[profile.status] ?? const [];
    if (nextStatuses.isEmpty) return;
    final request = await showDialog<_TransitionRequest>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _TransitionDialog(
        title: 'Profil durumunu değiştir',
        currentStatus: customsProfileStatusLabel(profile.status),
        nextStatuses: nextStatuses,
        labeler: customsProfileStatusLabel,
      ),
    );
    if (request == null || !mounted) return;
    setState(() => _transitioning = true);
    try {
      await _repository.transitionProfile(
        profileId: profile.profileId,
        nextStatus: request.nextStatus,
        reason: request.reason,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Profil durumu ${customsProfileStatusLabel(request.nextStatus)} olarak güncellendi.',
          ),
        ),
      );
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(customsSecurityErrorMessage(error))),
      );
    } finally {
      if (mounted) setState(() => _transitioning = false);
    }
  }

  Future<void> _transitionIntervention(
    CustomsBorderIntervention intervention,
  ) async {
    final nextStatuses =
        customsInterventionTransitions[intervention.status] ?? const [];
    if (nextStatuses.isEmpty) return;
    final request = await showDialog<_TransitionRequest>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _TransitionDialog(
        title: 'Müdahale durumunu değiştir',
        currentStatus: customsInterventionStatusLabel(intervention.status),
        nextStatuses: nextStatuses,
        labeler: customsInterventionStatusLabel,
        interventionMode: true,
      ),
    );
    if (request == null || !mounted) return;
    setState(() => _transitioning = true);
    try {
      await _repository.transitionIntervention(
        interventionId: intervention.interventionId,
        nextStatus: request.nextStatus,
        reason: request.reason,
        decisionReference: request.decisionReference,
        humanAssessmentReference: request.humanAssessmentReference,
        authorityReference: request.authorityReference,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Müdahale durumu ${customsInterventionStatusLabel(request.nextStatus)} olarak güncellendi.',
          ),
        ),
      );
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(customsSecurityErrorMessage(error))),
      );
    } finally {
      if (mounted) setState(() => _transitioning = false);
    }
  }

  Future<void> _openAuthoritySubmission(
    CustomsAuthoritySubmission submission,
  ) async {
    final opener = widget.submissionDetailOpener;
    if (opener != null) {
      await opener(context, submission.submissionId);
    } else {
      await AppRouter.openCustomsAuthoritySubmissionDetail(
        context,
        submissionId: submission.submissionId,
      );
    }
  }

  Future<void> _createProfileSubmission(
    CustomsProtectionProfile profile,
  ) async {
    if (profile.status != 'active') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'FSMH başvuru taslağı için koruma profili aktif olmalıdır.',
          ),
        ),
      );
      return;
    }
    final draft = await showDialog<CustomsAuthoritySubmissionDraft>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          _CreateAuthoritySubmissionDialog.forProfile(profile: profile),
    );
    if (draft == null || !mounted) return;
    setState(() => _creatingSubmission = true);
    try {
      final created = await _authorityRepository.createSubmission(draft);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${created.submissionNumber} resmî başvuru taslağı oluşturuldu.',
          ),
        ),
      );
      await _openAuthoritySubmission(created);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(customsAuthoritySubmissionErrorMessage(error))),
      );
    } finally {
      if (mounted) setState(() => _creatingSubmission = false);
    }
  }

  Future<void> _createInterventionSubmission(
    CustomsBorderIntervention intervention,
  ) async {
    final draft = await showDialog<CustomsAuthoritySubmissionDraft>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _CreateAuthoritySubmissionDialog.forIntervention(
        intervention: intervention,
      ),
    );
    if (draft == null || !mounted) return;
    setState(() => _creatingSubmission = true);
    try {
      final created = await _authorityRepository.createSubmission(draft);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${created.submissionNumber} yetkili makam iletim taslağı oluşturuldu.',
          ),
        ),
      );
      await _openAuthoritySubmission(created);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(customsAuthoritySubmissionErrorMessage(error))),
      );
    } finally {
      if (mounted) setState(() => _creatingSubmission = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isProfile = widget.detailType == CustomsSecurityDetailType.profile;
    return Scaffold(
      backgroundColor: MarkaKalkanTheme.background,
      appBar: AppBar(
        title: Text(
          isProfile ? 'Gümrük Koruma Profili' : 'Sınır Müdahale Dosyası',
        ),
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
                key: ValueKey('customs-detail-loading'),
              ),
            )
          : _error != null
          ? _DetailError(message: _error!, onRetry: _load)
          : isProfile
          ? _ProfileDetailView(
              profile: _profile!,
              transitioning: _transitioning,
              creatingSubmission: _creatingSubmission,
              onTransition: () => _transitionProfile(_profile!),
              onCreateSubmission: () => _createProfileSubmission(_profile!),
            )
          : _InterventionDetailView(
              detail: _interventionDetail!,
              transitioning: _transitioning,
              creatingSubmission: _creatingSubmission,
              onTransition: () =>
                  _transitionIntervention(_interventionDetail!.intervention),
              onCreateSubmission: () => _createInterventionSubmission(
                _interventionDetail!.intervention,
              ),
            ),
    );
  }
}

class _ProfileDetailView extends StatelessWidget {
  const _ProfileDetailView({
    required this.profile,
    required this.transitioning,
    required this.creatingSubmission,
    required this.onTransition,
    required this.onCreateSubmission,
  });

  final CustomsProtectionProfile profile;
  final bool transitioning;
  final bool creatingSubmission;
  final VoidCallback onTransition;
  final VoidCallback onCreateSubmission;

  @override
  Widget build(BuildContext context) {
    final transitions = customsProfileTransitions[profile.status] ?? const [];
    return _DetailScroll(
      key: const ValueKey('customs-profile-detail'),
      header: _DetailHeader(
        icon: Icons.policy_outlined,
        number: profile.profileNumber,
        title: profile.profileName,
        statusLabel: customsProfileStatusLabel(profile.status),
        statusCode: profile.status,
        subtitle: profile.rightHolderName,
      ),
      action: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          OutlinedButton.icon(
            key: const ValueKey('create-fsmh-authority-submission'),
            onPressed: creatingSubmission || profile.status != 'active'
                ? null
                : onCreateSubmission,
            icon: creatingSubmission
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.description_outlined),
            label: const Text('FSMH Resmî Başvuru Paketi Hazırla'),
          ),
          if (transitions.isNotEmpty)
            FilledButton.icon(
              key: const ValueKey('transition-customs-profile'),
              onPressed: transitioning ? null : onTransition,
              icon: transitioning
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.sync_alt_rounded),
              label: const Text('Durumu değiştir'),
            ),
        ],
      ),
      sections: [
        _InfoSection(
          title: 'Hak ve ürün kapsamı',
          children: [
            _InfoRow(label: 'Hak sahibi', value: profile.rightHolderName),
            _ListRow(
              label: 'Hak/tescil referansları',
              values: profile.rightHolderReferenceIds,
            ),
            _ListRow(
              label: 'Korunan ürünler',
              values: profile.protectedProductIds,
            ),
            _ListRow(label: 'HS/GTİP kodları', values: profile.hsCodes),
            _ListRow(
              label: 'Ürün kategorileri',
              values: profile.productCategories,
            ),
          ],
        ),
        _InfoSection(
          title: 'Orijinal ürün doğrulama kiti',
          children: [
            _InfoRow(
              label: 'Doğrulama talimatı',
              value: profile.authenticationInstructions,
            ),
            _ListRow(
              label: 'Seri doğrulama yöntemleri',
              values: profile.serialVerificationMethods,
            ),
            _ListRow(
              label: 'Güvenlik özellikleri',
              values: profile.securityFeatureSummaries,
            ),
            _ListRow(
              label: 'Sahte ikiz kayıtları',
              values: profile.counterfeitTwinRecordIds,
            ),
            _ListRow(
              label: 'Üretim varlıkları',
              values: profile.productionAssetIds,
            ),
          ],
        ),
        _InfoSection(
          title: 'Ülke, rota ve geçerlilik',
          children: [
            _ListRow(label: 'Menşe ülkeleri', values: profile.originCountries),
            _ListRow(
              label: 'Yetkili ithalat ülkeleri',
              values: profile.authorizedImportCountries,
            ),
            _ListRow(label: 'Risk ülkeleri', values: profile.riskCountryCodes),
            _ListRow(
              label: 'Riskli rotalar',
              values: profile.riskRouteSummaries,
            ),
            _InfoRow(
              label: 'Geçerlilik başlangıcı',
              value: _formatNullableDate(profile.validFrom),
            ),
            _InfoRow(
              label: 'Geçerlilik sonu',
              value: _formatNullableDate(profile.validUntil),
            ),
            _InfoRow(
              label: 'İnceleme tarihi',
              value: _formatNullableDate(profile.reviewDueAt),
            ),
          ],
        ),
        _InfoSection(
          title: 'Denetim özeti',
          children: [
            _InfoRow(label: 'Olay sayısı', value: '${profile.eventCount}'),
            _InfoRow(
              label: 'Son olay',
              value: profile.lastEventType ?? 'Kayıt yok',
            ),
            _InfoRow(
              label: 'Oluşturulma',
              value: _formatDateTime(profile.createdAt),
            ),
            _InfoRow(
              label: 'Son güncelleme',
              value: _formatDateTime(profile.updatedAt),
            ),
          ],
        ),
      ],
    );
  }
}

class _InterventionDetailView extends StatelessWidget {
  const _InterventionDetailView({
    required this.detail,
    required this.transitioning,
    required this.creatingSubmission,
    required this.onTransition,
    required this.onCreateSubmission,
  });

  final CustomsBorderInterventionDetail detail;
  final bool transitioning;
  final bool creatingSubmission;
  final VoidCallback onTransition;
  final VoidCallback onCreateSubmission;

  @override
  Widget build(BuildContext context) {
    final intervention = detail.intervention;
    final transitions =
        customsInterventionTransitions[intervention.status] ?? const [];
    final integrityFlags = <String>[
      if (intervention.unusualReleaseFlag) 'Olağandışı serbest bırakma sinyali',
      if (intervention.decisionEvidenceMismatchFlag)
        'Karar-delil uyumsuzluğu sinyali',
      if (intervention.missingRecordOrSampleFlag)
        'Eksik kayıt veya numune sinyali',
      if (intervention.postRecordModificationFlag)
        'Kayıt sonrası değişiklik sinyali',
      if (intervention.unexplainedAccelerationFlag)
        'Açıklanamayan hızlandırma sinyali',
      if (intervention.quantityOrDestructionMismatchFlag)
        'Miktar veya imha uyumsuzluğu sinyali',
      if (intervention.independentReviewRequired) 'Bağımsız inceleme gerekiyor',
    ];

    return _DetailScroll(
      key: const ValueKey('customs-intervention-detail'),
      header: _DetailHeader(
        icon: Icons.local_shipping_outlined,
        number: intervention.interventionNumber,
        title: intervention.declaredProductDescription,
        statusLabel: customsInterventionStatusLabel(intervention.status),
        statusCode: intervention.status,
        subtitle:
            '${intervention.countryCode} · ${intervention.customsAuthorityName}',
      ),
      action: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          OutlinedButton.icon(
            key: const ValueKey('create-intervention-authority-submission'),
            onPressed: creatingSubmission ? null : onCreateSubmission,
            icon: creatingSubmission
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.account_balance_outlined),
            label: const Text('Yetkili Makama İletim Dosyası Hazırla'),
          ),
          if (transitions.isNotEmpty)
            FilledButton.icon(
              key: const ValueKey('transition-customs-intervention'),
              onPressed: transitioning ? null : onTransition,
              icon: transitioning
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.sync_alt_rounded),
              label: const Text('Durumu değiştir'),
            ),
        ],
      ),
      sections: [
        _InfoSection(
          title: 'Sevkiyat ve sınır noktası',
          children: [
            _InfoRow(
              label: 'Koruma profili',
              value: intervention.protectionProfileId,
            ),
            _InfoRow(
              label: 'Sınır noktası',
              value:
                  '${customsBorderPointTypeLabel(intervention.borderPointType)} · ${intervention.borderPointName}',
            ),
            _InfoRow(
              label: 'Sevkiyat referansı',
              value: intervention.shipmentReference ?? 'Belirtilmedi',
            ),
            _InfoRow(
              label: 'Konteyner referansı',
              value: intervention.containerReference ?? 'Belirtilmedi',
            ),
            _InfoRow(
              label: 'Kargo referansı',
              value: intervention.cargoReference ?? 'Belirtilmedi',
            ),
            _ListRow(
              label: 'Takip referansları',
              values: intervention.trackingReferences,
            ),
          ],
        ),
        _InfoSection(
          title: 'Ürün beyanı ve doğrulama',
          children: [
            _InfoRow(
              label: 'Beyan edilen ürün',
              value: intervention.declaredProductDescription,
            ),
            _InfoRow(
              label: 'Beyan edilen HS/GTİP',
              value: intervention.declaredHsCode ?? 'Belirtilmedi',
            ),
            _InfoRow(
              label: 'Beyan edilen miktar',
              value: intervention.declaredQuantity == null
                  ? 'Belirtilmedi'
                  : '${intervention.declaredQuantity} ${intervention.declaredUnit == null ? '' : customsDeclaredUnitLabel(intervention.declaredUnit!)}',
            ),
            _InfoRow(
              label: 'Doğrulama sonucu',
              value: customsAuthenticationResultLabel(
                intervention.authenticationResult,
              ),
            ),
            _ListRow(
              label: 'Şüphe nedenleri',
              values: intervention.suspicionReasons,
            ),
          ],
        ),
        _InfoSection(
          title: 'Süreler ve karar dayanakları',
          children: [
            _InfoRow(
              label: 'Bildirim tarihi',
              value: _formatNullableDate(intervention.notificationReceivedAt),
            ),
            _InfoRow(
              label: 'Geçici alıkoyma tarihi',
              value: _formatNullableDate(intervention.detainedAt),
            ),
            _InfoRow(
              label: 'Yanıt son tarihi',
              value: _formatNullableDate(intervention.responseDeadlineAt),
            ),
            _InfoRow(
              label: 'İşlem son tarihi',
              value: _formatNullableDate(intervention.actionDeadlineAt),
            ),
            _InfoRow(
              label: 'Karar özeti',
              value: intervention.decisionSummary ?? 'Belirtilmedi',
            ),
            _InfoRow(
              label: 'Karar gerekçesi',
              value: intervention.decisionReason ?? 'Belirtilmedi',
            ),
            _InfoRow(
              label: 'Vaka bağlantısı',
              value: intervention.caseId ?? 'Henüz bağlanmadı',
            ),
            _InfoRow(
              label: 'Hukuki iş bağlantısı',
              value: intervention.legalMatterId ?? 'Henüz bağlanmadı',
            ),
          ],
        ),
        _InfoSection(
          title: 'İşlem bütünlüğü',
          warning: intervention.hasIntegritySignal,
          children: [
            _InfoRow(
              label: 'Bütünlük durumu',
              value: customsIntegrityStatusLabel(intervention.integrityStatus),
            ),
            _InfoRow(
              label: 'Olay zinciri',
              value: detail.integrityStatus == 'verified'
                  ? 'Doğrulandı'
                  : 'Olay sayısı uyuşmazlığı',
            ),
            _ListRow(label: 'İnceleme sinyalleri', values: integrityFlags),
            const _InfoRow(
              label: 'Hukuki dil',
              value:
                  'Bütünlük sinyalleri otomatik rüşvet veya suç sonucu üretmez; bağımsız insan incelemesi gerektirir.',
            ),
          ],
        ),
        _InfoSection(
          title: 'Değiştirilemez olay zinciri',
          children: detail.events.isEmpty
              ? const [_InfoRow(label: 'Olaylar', value: 'Olay kaydı yok')]
              : detail.events
                    .map((event) => _TimelineEvent(event: event))
                    .toList(growable: false),
        ),
      ],
    );
  }
}

class _DetailScroll extends StatelessWidget {
  const _DetailScroll({
    super.key,
    required this.header,
    required this.sections,
    this.action,
  });

  final Widget header;
  final List<Widget> sections;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1040),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              header,
              if (action != null) ...[
                const SizedBox(height: 16),
                Align(alignment: Alignment.centerRight, child: action),
              ],
              const SizedBox(height: 18),
              ...sections.map(
                (section) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: section,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailHeader extends StatelessWidget {
  const _DetailHeader({
    required this.icon,
    required this.number,
    required this.title,
    required this.statusLabel,
    required this.statusCode,
    required this.subtitle,
  });

  final IconData icon;
  final String number;
  final String title;
  final String statusLabel;
  final String statusCode;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final color = customsStatusColor(statusCode);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [MarkaKalkanTheme.navy, Color(0xFF183B4E)],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: MarkaKalkanTheme.teal, size: 32),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    Text(
                      number,
                      style: const TextStyle(
                        color: MarkaKalkanTheme.teal,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        statusLabel,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  subtitle,
                  style: const TextStyle(color: Color(0xFFD9E5EA), height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoSection extends StatelessWidget {
  const _InfoSection({
    required this.title,
    required this.children,
    this.warning = false,
  });

  final String title;
  final List<Widget> children;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: warning ? const Color(0xFFE2B36F) : const Color(0xFFE0E7EC),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: MarkaKalkanTheme.navy,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 190,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF687580),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: MarkaKalkanTheme.navy, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _ListRow extends StatelessWidget {
  const _ListRow({required this.label, required this.values});

  final String label;
  final List<String> values;

  @override
  Widget build(BuildContext context) {
    return _InfoRow(
      label: label,
      value: values.isEmpty ? 'Belirtilmedi' : values.join(' · '),
    );
  }
}

class _TimelineEvent extends StatelessWidget {
  const _TimelineEvent({required this.event});

  final CustomsSecurityEvent event;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Color(0xFFE8F6F4),
              shape: BoxShape.circle,
            ),
            child: Text(
              '${event.sequence}',
              style: const TextStyle(
                color: MarkaKalkanTheme.teal,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.summary,
                  style: const TextStyle(
                    color: MarkaKalkanTheme.navy,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  event.reason,
                  style: const TextStyle(color: Color(0xFF687580), height: 1.4),
                ),
                const SizedBox(height: 3),
                Text(
                  '${event.actorLabel} · ${_formatDateTime(event.recordedAt)}',
                  style: const TextStyle(
                    color: Color(0xFF87939C),
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

class _DetailError extends StatelessWidget {
  const _DetailError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Color(0xFFB33A3A)),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton(onPressed: onRetry, child: const Text('Yeniden dene')),
        ],
      ),
    );
  }
}

class _TransitionRequest {
  const _TransitionRequest({
    required this.nextStatus,
    required this.reason,
    this.decisionReference,
    this.humanAssessmentReference,
    this.authorityReference,
  });

  final String nextStatus;
  final String reason;
  final String? decisionReference;
  final String? humanAssessmentReference;
  final String? authorityReference;
}

class _TransitionDialog extends StatefulWidget {
  const _TransitionDialog({
    required this.title,
    required this.currentStatus,
    required this.nextStatuses,
    required this.labeler,
    this.interventionMode = false,
  });

  final String title;
  final String currentStatus;
  final List<String> nextStatuses;
  final String Function(String) labeler;
  final bool interventionMode;

  @override
  State<_TransitionDialog> createState() => _TransitionDialogState();
}

class _TransitionDialogState extends State<_TransitionDialog> {
  final _formKey = GlobalKey<FormState>();
  late String _nextStatus;
  final _reason = TextEditingController();
  final _decision = TextEditingController();
  final _humanAssessment = TextEditingController();
  final _authority = TextEditingController();

  @override
  void initState() {
    super.initState();
    _nextStatus = widget.nextStatuses.first;
  }

  @override
  void dispose() {
    _reason.dispose();
    _decision.dispose();
    _humanAssessment.dispose();
    _authority.dispose();
    super.dispose();
  }

  bool get _decisionRequired => ['destroyed', 'released'].contains(_nextStatus);
  bool get _humanRequired => _nextStatus == 'infringement_confirmed';
  bool get _authorityRequired => _nextStatus == 'referred_to_authority';

  String? _optionalRequired(String? value, bool required) {
    if (!required) return null;
    return (value?.trim().isNotEmpty ?? false)
        ? null
        : 'Bu dayanak zorunludur.';
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      _TransitionRequest(
        nextStatus: _nextStatus,
        reason: _reason.text.trim(),
        decisionReference: _nullable(_decision.text),
        humanAssessmentReference: _nullable(_humanAssessment.text),
        authorityReference: _nullable(_authority.text),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 560,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Mevcut durum: ${widget.currentStatus}'),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  key: const ValueKey('customs-next-status'),
                  initialValue: _nextStatus,
                  decoration: const InputDecoration(labelText: 'Yeni durum'),
                  items: widget.nextStatuses
                      .map(
                        (status) => DropdownMenuItem(
                          value: status,
                          child: Text(widget.labeler(status)),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) {
                    if (value != null) setState(() => _nextStatus = value);
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const ValueKey('customs-transition-reason'),
                  controller: _reason,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Gerekçe',
                    hintText: 'En az 10 karakterlik denetlenebilir gerekçe',
                  ),
                  validator: (value) => (value?.trim().length ?? 0) >= 10
                      ? null
                      : 'Gerekçe en az 10 karakter olmalıdır.',
                ),
                if (widget.interventionMode) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const ValueKey('customs-decision-reference'),
                    controller: _decision,
                    decoration: InputDecoration(
                      labelText: _decisionRequired
                          ? 'Karar referansı (zorunlu)'
                          : 'Karar referansı',
                    ),
                    validator: (value) =>
                        _optionalRequired(value, _decisionRequired),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const ValueKey('customs-human-assessment-reference'),
                    controller: _humanAssessment,
                    decoration: InputDecoration(
                      labelText: _humanRequired
                          ? 'İnsan değerlendirmesi referansı (zorunlu)'
                          : 'İnsan değerlendirmesi referansı',
                    ),
                    validator: (value) =>
                        _optionalRequired(value, _humanRequired),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const ValueKey('customs-authority-reference'),
                    controller: _authority,
                    decoration: InputDecoration(
                      labelText: _authorityRequired
                          ? 'Yetkili makam referansı (zorunlu)'
                          : 'Yetkili makam referansı',
                    ),
                    validator: (value) =>
                        _optionalRequired(value, _authorityRequired),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Durum değişikliği kişi veya kuruluş hakkında otomatik suç isnadı oluşturmaz; yalnız dosyanın operasyon aşamasını kaydeder.',
                    style: TextStyle(color: Color(0xFF687580), height: 1.4),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Vazgeç'),
        ),
        FilledButton(
          key: const ValueKey('confirm-customs-transition'),
          onPressed: _submit,
          child: const Text('Durumu güncelle'),
        ),
      ],
    );
  }
}

String? _nullable(String value) {
  final clean = value.trim();
  return clean.isEmpty ? null : clean;
}

String _formatNullableDate(String? value) {
  if (value == null) return 'Belirtilmedi';
  return _formatDateTime(value);
}

String _formatDateTime(String value) {
  final parsed = DateTime.tryParse(value)?.toLocal();
  if (parsed == null) return value;
  String two(int number) => number.toString().padLeft(2, '0');
  return '${two(parsed.day)}.${two(parsed.month)}.${parsed.year} '
      '${two(parsed.hour)}:${two(parsed.minute)}';
}

class _CreateAuthoritySubmissionDialog extends StatefulWidget {
  _CreateAuthoritySubmissionDialog.forProfile({
    required CustomsProtectionProfile profile,
  }) : submissionType = 'fsmh_protection_application',
       targetAuthority = 'fsmh_program',
       channelType = 'fsmh_portal',
       protectionProfileId = profile.profileId,
       interventionId = null,
       defaultIncidentReference = profile.profileNumber,
       defaultTitle = '${profile.profileName} FSMH koruma başvurusu',
       defaultSummary =
           '${profile.rightHolderName} adına aktif Gümrük Koruma Profili kapsamındaki hak, ürün ve doğrulama bilgilerinin insan incelemesine sunulması için resmî başvuru taslağıdır.';

  _CreateAuthoritySubmissionDialog.forIntervention({
    required CustomsBorderIntervention intervention,
  }) : submissionType = 'customs_smuggling_notification',
       targetAuthority = 'customs_enforcement',
       channelType = 'official_online_form',
       protectionProfileId = intervention.protectionProfileId,
       interventionId = intervention.interventionId,
       defaultIncidentReference = intervention.interventionNumber,
       defaultTitle =
           '${intervention.declaredProductDescription} yetkili makam iletimi',
       defaultSummary =
           '${intervention.interventionNumber} numaralı sınır müdahale dosyasındaki sevkiyat, ürün beyanı, şüphe nedenleri ve doğrulama durumu hakkında hukuken nötr resmî iletim taslağıdır.';

  final String submissionType;
  final String targetAuthority;
  final String channelType;
  final String protectionProfileId;
  final String? interventionId;
  final String defaultIncidentReference;
  final String defaultTitle;
  final String defaultSummary;

  @override
  State<_CreateAuthoritySubmissionDialog> createState() =>
      _CreateAuthoritySubmissionDialogState();
}

class _CreateAuthoritySubmissionDialogState
    extends State<_CreateAuthoritySubmissionDialog> {
  final _formKey = GlobalKey<FormState>();
  final _targetUnit = TextEditingController();
  late final TextEditingController _incidentReference;
  late final TextEditingController _title;
  late final TextEditingController _summary;
  bool _dataMinimizationConfirmed = false;
  bool _nonAccusatoryLanguageConfirmed = false;

  @override
  void initState() {
    super.initState();
    _incidentReference = TextEditingController(
      text: widget.defaultIncidentReference,
    );
    _title = TextEditingController(text: widget.defaultTitle);
    _summary = TextEditingController(text: widget.defaultSummary);
  }

  @override
  void dispose() {
    _targetUnit.dispose();
    _incidentReference.dispose();
    _title.dispose();
    _summary.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop(
      CustomsAuthoritySubmissionDraft(
        submissionType: widget.submissionType,
        targetAuthority: widget.targetAuthority,
        targetUnit: _authorityOptional(_targetUnit.text),
        channelType: widget.channelType,
        protectionProfileId: widget.protectionProfileId,
        interventionId: widget.interventionId,
        incidentReference: _incidentReference.text.trim(),
        title: _title.text.trim(),
        authoritySummary: _summary.text.trim(),
        dataMinimizationConfirmed: _dataMinimizationConfirmed,
        nonAccusatoryLanguageConfirmed: _nonAccusatoryLanguageConfirmed,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isProfile = widget.submissionType == 'fsmh_protection_application';
    return AlertDialog(
      title: Text(
        isProfile
            ? 'FSMH resmî başvuru taslağı'
            : 'Yetkili makam iletim taslağı',
      ),
      content: SizedBox(
        width: 660,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _AuthorityNotice(
                  text:
                      'Bu adım yalnız taslak oluşturur. MarkaKalkan, dosyayı otomatik olarak kuruma göndermez; insan incelemesi ve hak sahibi onayı ayrı aşamalardır.',
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: const ValueKey(
                    'authority-submission-incident-reference',
                  ),
                  controller: _incidentReference,
                  decoration: const InputDecoration(
                    labelText: 'Olay / kaynak referansı',
                  ),
                  validator: (value) => _requiredLength(
                    value,
                    minimum: 3,
                    label: 'Olay referansı',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const ValueKey('authority-submission-title'),
                  controller: _title,
                  decoration: const InputDecoration(
                    labelText: 'İletim başlığı',
                  ),
                  validator: (value) =>
                      _requiredLength(value, minimum: 5, label: 'Başlık'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const ValueKey('authority-submission-target-unit'),
                  controller: _targetUnit,
                  decoration: const InputDecoration(
                    labelText: 'Hedef birim (isteğe bağlı)',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const ValueKey('authority-submission-summary'),
                  controller: _summary,
                  minLines: 5,
                  maxLines: 9,
                  decoration: const InputDecoration(
                    labelText: 'Kuruma sunulacak hukuken nötr özet',
                  ),
                  validator: (value) =>
                      _requiredLength(value, minimum: 20, label: 'Özet'),
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  key: const ValueKey('authority-submission-data-minimization'),
                  value: _dataMinimizationConfirmed,
                  onChanged: (value) => setState(
                    () => _dataMinimizationConfirmed = value == true,
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text(
                    'Taslakta veri minimizasyonu kontrol edildi',
                  ),
                  subtitle: const Text(
                    'Bu işaret paket üretme onayı değildir.',
                  ),
                ),
                CheckboxListTile(
                  key: const ValueKey('authority-submission-neutral-language'),
                  value: _nonAccusatoryLanguageConfirmed,
                  onChanged: (value) => setState(
                    () => _nonAccusatoryLanguageConfirmed = value == true,
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text(
                    'Kesinleşmemiş olgular için suç isnadı içermeyen dil kullanıldı',
                  ),
                  subtitle: const Text(
                    'Şüphe, doğrulama ve kesin sonuç ayrı tutulur.',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Vazgeç'),
        ),
        FilledButton(
          key: const ValueKey('confirm-create-customs-authority-submission'),
          onPressed: _submit,
          child: const Text('Taslak oluştur'),
        ),
      ],
    );
  }
}

class _AuthorityNotice extends StatelessWidget {
  const _AuthorityNotice({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F7F8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD7E4E8)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

String? _requiredLength(
  String? value, {
  required int minimum,
  required String label,
}) {
  final clean = value?.trim() ?? '';
  if (clean.length < minimum) {
    return '$label en az $minimum karakter olmalıdır.';
  }
  return null;
}

String? _authorityOptional(String value) {
  final clean = value.trim();
  return clean.isEmpty ? null : clean;
}

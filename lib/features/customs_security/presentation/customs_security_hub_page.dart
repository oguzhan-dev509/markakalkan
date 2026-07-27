import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:markakalkan/app/router.dart';
import 'package:markakalkan/core/security/app_check_bootstrap.dart';
import 'package:markakalkan/core/theme/markakalkan_theme.dart';
import 'package:markakalkan/features/customs_security/data/customs_authority_submission_repository.dart';
import 'package:markakalkan/features/customs_security/data/customs_security_repository.dart';
import 'package:markakalkan/features/customs_security/presentation/customs_authority_submission_labels.dart';
import 'package:markakalkan/features/customs_security/presentation/customs_security_labels.dart';

typedef CustomsProfileDetailOpener =
    Future<void> Function(BuildContext context, String profileId);
typedef CustomsInterventionDetailOpener =
    Future<void> Function(BuildContext context, String interventionId);
typedef CustomsAuthoritySubmissionDetailOpener =
    Future<void> Function(BuildContext context, String submissionId);

class CustomsSecurityHubPage extends StatefulWidget {
  const CustomsSecurityHubPage({
    super.key,
    this.repository,
    this.authorityRepository,
    this.profileDetailOpener,
    this.interventionDetailOpener,
    this.submissionDetailOpener,
  });

  final CustomsSecurityRepository? repository;
  final CustomsAuthoritySubmissionRepository? authorityRepository;
  final CustomsProfileDetailOpener? profileDetailOpener;
  final CustomsInterventionDetailOpener? interventionDetailOpener;
  final CustomsAuthoritySubmissionDetailOpener? submissionDetailOpener;

  @override
  State<CustomsSecurityHubPage> createState() => _CustomsSecurityHubPageState();
}

class _CustomsSecurityHubPageState extends State<CustomsSecurityHubPage>
    with SingleTickerProviderStateMixin {
  late final CustomsSecurityRepository _repository;
  late final CustomsAuthoritySubmissionRepository _authorityRepository;
  late final TabController _tabController;

  bool _loading = true;
  bool _submitting = false;
  bool _compactLayout = true;
  String? _error;
  String? _profileStatus;
  String? _interventionStatus;
  String? _submissionStatus;
  List<CustomsProtectionProfile> _profiles = const [];
  List<CustomsBorderIntervention> _interventions = const [];
  List<CustomsAuthoritySubmission> _submissions = const [];

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? CallableCustomsSecurityRepository();
    _authorityRepository =
        widget.authorityRepository ??
        (widget.repository == null
            ? CallableCustomsAuthoritySubmissionRepository()
            : const EmptyCustomsAuthoritySubmissionRepository());
    _tabController = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait<Object>([
        _repository.listProfiles(status: _profileStatus, pageSize: 50),
        _repository.listInterventions(
          status: _interventionStatus,
          pageSize: 50,
        ),
        _authorityRepository.listSubmissions(
          status: _submissionStatus,
          pageSize: 50,
        ),
      ]);
      if (!mounted) return;
      setState(() {
        _profiles = (results[0] as CustomsProtectionProfileList).items;
        _interventions = (results[1] as CustomsBorderInterventionList).items;
        _submissions = (results[2] as CustomsAuthoritySubmissionList).items;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = customsSecurityErrorMessage(error);
      });
    }
  }

  Future<void> _openProfile(CustomsProtectionProfile profile) async {
    final opener = widget.profileDetailOpener;
    if (opener != null) {
      await opener(context, profile.profileId);
    } else {
      await AppRouter.openCustomsProtectionProfileDetail(
        context,
        profileId: profile.profileId,
      );
    }
    if (mounted) await _load();
  }

  Future<void> _openIntervention(CustomsBorderIntervention intervention) async {
    final opener = widget.interventionDetailOpener;
    if (opener != null) {
      await opener(context, intervention.interventionId);
    } else {
      await AppRouter.openCustomsBorderInterventionDetail(
        context,
        interventionId: intervention.interventionId,
      );
    }
    if (mounted) await _load();
  }

  Future<void> _openSubmission(CustomsAuthoritySubmission submission) async {
    final opener = widget.submissionDetailOpener;
    if (opener != null) {
      await opener(context, submission.submissionId);
    } else {
      await AppRouter.openCustomsAuthoritySubmissionDetail(
        context,
        submissionId: submission.submissionId,
      );
    }
    if (mounted) await _load();
  }

  Future<void> _createProfile() async {
    final result = await showDialog<_ProfileCreationResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _CreateProfileDialog(repository: _repository),
    );
    if (result == null || !mounted) return;
    if (result.activated) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${result.profile.profileNumber} profili aktifleştirildi.',
          ),
        ),
      );
      await _openProfile(result.profile);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${result.profile.profileNumber} taslak profili oluşturuldu.',
          ),
        ),
      );
      await _load();
    }
  }

  Future<void> _createIntervention() async {
    setState(() => _submitting = true);
    try {
      final activeProfiles = await _repository.listProfiles(
        status: 'active',
        pageSize: 50,
      );
      if (!mounted) return;
      if (activeProfiles.items.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Sınır müdahale dosyası için önce aktif bir Gümrük Koruma Profili gerekir.',
            ),
          ),
        );
        return;
      }
      final draft = await showDialog<CustomsBorderInterventionDraft>(
        context: context,
        barrierDismissible: false,
        builder: (_) =>
            _CreateInterventionDialog(activeProfiles: activeProfiles.items),
      );
      if (draft == null || !mounted) return;
      final created = await _repository.createIntervention(draft);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${created.interventionNumber} taslak müdahale dosyası oluşturuldu.',
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
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MarkaKalkanTheme.background,
      appBar: AppBar(
        title: const Text('Kaçakçılık, Taklit ve Gümrük Güvenliği'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(kTextTabBarHeight),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 600;
              return TabBar(
                key: const ValueKey('customs-security-tab-bar'),
                controller: _tabController,
                isScrollable: compact,
                tabAlignment: compact ? TabAlignment.start : TabAlignment.fill,
                labelPadding: compact
                    ? const EdgeInsets.symmetric(horizontal: 20)
                    : null,
                tabs: const [
                  Tab(
                    key: ValueKey('customs-profile-tab'),
                    text: 'Koruma Profilleri',
                  ),
                  Tab(
                    key: ValueKey('customs-intervention-tab'),
                    text: 'Sınır Müdahaleleri',
                  ),
                  Tab(
                    key: ValueKey('customs-authority-submission-tab'),
                    text: 'Resmî İletimler',
                  ),
                ],
              );
            },
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Yenile',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      floatingActionButton: _loading || _compactLayout
          ? null
          : AnimatedBuilder(
              animation: _tabController,
              builder: (context, _) {
                final tabIndex = _tabController.index;
                if (tabIndex == 2) return const SizedBox.shrink();
                final profilesTab = tabIndex == 0;
                return FloatingActionButton.extended(
                  key: ValueKey(
                    profilesTab
                        ? 'create-customs-profile'
                        : 'create-customs-intervention',
                  ),
                  onPressed: _submitting
                      ? null
                      : profilesTab
                      ? _createProfile
                      : _createIntervention,
                  icon: Icon(
                    _submitting
                        ? Icons.hourglass_top_rounded
                        : Icons.add_rounded,
                  ),
                  label: Text(profilesTab ? 'Yeni profil' : 'Yeni müdahale'),
                );
              },
            ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 600;
          if (_compactLayout != compact) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted || _compactLayout == compact) return;
              setState(() => _compactLayout = compact);
            });
          }

          return SingleChildScrollView(
            key: const ValueKey('customs-security-scroll-shell'),
            child: Column(
              children: [
                const _CustomsHero(),
                const _CustomsOperationInformationBand(),
                if (compact && !_loading)
                  AnimatedBuilder(
                    animation: _tabController,
                    builder: (context, _) {
                      final tabIndex = _tabController.index;
                      if (tabIndex == 2) return const SizedBox.shrink();
                      final profilesTab = tabIndex == 0;
                      return Padding(
                        key: const ValueKey(
                          'customs-mobile-create-action-region',
                        ),
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: FilledButton.icon(
                            key: ValueKey(
                              profilesTab
                                  ? 'mobile-create-customs-profile'
                                  : 'mobile-create-customs-intervention',
                            ),
                            onPressed: _submitting
                                ? null
                                : profilesTab
                                ? _createProfile
                                : _createIntervention,
                            icon: Icon(
                              _submitting
                                  ? Icons.hourglass_top_rounded
                                  : Icons.add_rounded,
                            ),
                            label: Text(
                              profilesTab ? 'Yeni profil' : 'Yeni müdahale',
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                SizedBox(
                  key: const ValueKey('customs-security-workspace-viewport'),
                  height: constraints.maxHeight,
                  child: _loading
                      ? const Center(
                          child: CircularProgressIndicator(
                            key: ValueKey('customs-security-loading'),
                          ),
                        )
                      : _error != null
                      ? _ErrorPanel(message: _error!, onRetry: _load)
                      : TabBarView(
                          controller: _tabController,
                          children: [
                            _ProfileWorkspace(
                              profiles: _profiles,
                              selectedStatus: _profileStatus,
                              onStatusChanged: (value) {
                                setState(() => _profileStatus = value);
                                _load();
                              },
                              onOpen: _openProfile,
                            ),
                            _InterventionWorkspace(
                              interventions: _interventions,
                              selectedStatus: _interventionStatus,
                              onStatusChanged: (value) {
                                setState(() => _interventionStatus = value);
                                _load();
                              },
                              onOpen: _openIntervention,
                            ),
                            _AuthoritySubmissionWorkspace(
                              submissions: _submissions,
                              selectedStatus: _submissionStatus,
                              onStatusChanged: (value) {
                                setState(() => _submissionStatus = value);
                                _load();
                              },
                              onOpen: _openSubmission,
                            ),
                          ],
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _CustomsHero extends StatelessWidget {
  const _CustomsHero();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('customs-security-hero'),
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(24, 24, 24, 12),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [MarkaKalkanTheme.navy, Color(0xFF183B4E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sınırda sinyali yakala, delili koru, müdahaleyi yönet.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w900,
              height: 1.2,
            ),
          ),
          SizedBox(height: 10),
          Text(
            'Gümrük koruma profillerini ve şüpheli sevkiyat müdahalelerini insan incelemesi, tenant izolasyonu ve değiştirilemez olay zinciriyle yönetin.',
            style: TextStyle(color: Color(0xFFD9E5EA), height: 1.5),
          ),
          SizedBox(height: 14),
          _LegalLanguageNotice(),
        ],
      ),
    );
  }
}

class _LegalLanguageNotice extends StatelessWidget {
  const _LegalLanguageNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.balance_outlined, color: MarkaKalkanTheme.teal, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Bu çalışma alanı kişi veya kuruluşlar hakkında otomatik suç isnadı üretmez. Şüphe, doğrulama ve kesinleşmiş sonuçlar ayrı tutulur.',
              style: TextStyle(color: Color(0xFFE9F0F3), height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomsOperationInformationBand extends StatelessWidget {
  const _CustomsOperationInformationBand();

  static const _stages = <({IconData icon, String label})>[
    (icon: Icons.description_outlined, label: 'Başvuru içeriği'),
    (icon: Icons.inventory_2_outlined, label: 'Başvuru paketi'),
    (icon: Icons.picture_as_pdf_outlined, label: 'İndirilebilir resmî dosya'),
    (icon: Icons.send_outlined, label: 'Kuruma iletim'),
    (icon: Icons.fact_check_outlined, label: 'Teslim, cevap ve sonuç'),
  ];

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'Gümrük operasyon bilgi bandı',
      child: Container(
        key: const ValueKey('customs-operation-information-band'),
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(24, 0, 24, 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFDDE6EB)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A0B2239),
              blurRadius: 18,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.account_tree_outlined,
                  color: MarkaKalkanTheme.teal,
                  size: 21,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Operasyon Bilgi Bandı',
                        style: TextStyle(
                          color: MarkaKalkanTheme.navy,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Başvurudan kurum cevabı ve nihai sonuca kadar beş aşamayı aynı operasyon zincirinde izleyin.',
                        style: TextStyle(
                          color: Color(0xFF687580),
                          fontSize: 13,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth >= 980) {
                  return Row(
                    key: const ValueKey(
                      'customs-operation-information-wide-row',
                    ),
                    children: [
                      for (var index = 0; index < _stages.length; index++) ...[
                        Expanded(
                          child: _CustomsOperationInformationStage(
                            index: index + 1,
                            icon: _stages[index].icon,
                            label: _stages[index].label,
                          ),
                        ),
                        if (index != _stages.length - 1)
                          const SizedBox(width: 10),
                      ],
                    ],
                  );
                }

                return SizedBox(
                  height: 64,
                  child: ListView.separated(
                    key: const ValueKey(
                      'customs-operation-information-horizontal-list',
                    ),
                    scrollDirection: Axis.horizontal,
                    itemCount: _stages.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 10),
                    itemBuilder: (context, index) => SizedBox(
                      width: 210,
                      child: _CustomsOperationInformationStage(
                        index: index + 1,
                        icon: _stages[index].icon,
                        label: _stages[index].label,
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _CustomsOperationInformationStage extends StatelessWidget {
  const _CustomsOperationInformationStage({
    required this.index,
    required this.icon,
    required this.label,
  });

  final int index;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: ValueKey('customs-operation-information-stage-$index'),
      constraints: const BoxConstraints(minHeight: 64),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F8FA),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E9ED)),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: MarkaKalkanTheme.teal,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$index',
              style: const TextStyle(
                color: MarkaKalkanTheme.navy,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Icon(icon, color: MarkaKalkanTheme.navy, size: 18),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: MarkaKalkanTheme.navy,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileWorkspace extends StatelessWidget {
  const _ProfileWorkspace({
    required this.profiles,
    required this.selectedStatus,
    required this.onStatusChanged,
    required this.onOpen,
  });

  final List<CustomsProtectionProfile> profiles;
  final String? selectedStatus;
  final ValueChanged<String?> onStatusChanged;
  final ValueChanged<CustomsProtectionProfile> onOpen;

  @override
  Widget build(BuildContext context) {
    return _WorkspaceShell(
      title: 'Gümrük Koruma Profilleri',
      description:
          'Hak sahipliği, ürün doğrulama yöntemi, GTİP/HS kodu, riskli rota ve acil temas bilgilerini sınır müdahalesine hazır tutun.',
      filter: DropdownButtonFormField<String?>(
        key: const ValueKey('customs-profile-status-filter'),
        initialValue: selectedStatus,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Durum filtresi'),
        items: [
          const DropdownMenuItem<String?>(value: null, child: Text('Tümü')),
          ...customsProfileStatuses.map(
            (status) => DropdownMenuItem<String?>(
              value: status,
              child: Text(customsProfileStatusLabel(status)),
            ),
          ),
        ],
        onChanged: onStatusChanged,
      ),
      child: profiles.isEmpty
          ? const _EmptyPanel(
              key: ValueKey('customs-profiles-empty'),
              icon: Icons.policy_outlined,
              title: 'Henüz Gümrük Koruma Profili yok',
              description:
                  'İlk profil taslak olarak oluşturulur; inceleme ve aktivasyon kontrollü durum geçişleriyle yapılır.',
            )
          : ListView.separated(
              padding: EdgeInsets.zero,
              itemCount: profiles.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final profile = profiles[index];
                return _RecordCard(
                  key: ValueKey('customs-profile-${profile.profileId}'),
                  icon: Icons.policy_outlined,
                  title: profile.profileName,
                  number: profile.profileNumber,
                  status: customsProfileStatusLabel(profile.status),
                  statusCode: profile.status,
                  lines: [
                    profile.rightHolderName,
                    '${profile.protectedProductIds.length} korunan ürün · ${profile.hsCodes.length} HS/GTİP kodu',
                    'Son güncelleme: ${_formatDateTime(profile.updatedAt)}',
                  ],
                  onTap: () => onOpen(profile),
                );
              },
            ),
    );
  }
}

class _InterventionWorkspace extends StatelessWidget {
  const _InterventionWorkspace({
    required this.interventions,
    required this.selectedStatus,
    required this.onStatusChanged,
    required this.onOpen,
  });

  final List<CustomsBorderIntervention> interventions;
  final String? selectedStatus;
  final ValueChanged<String?> onStatusChanged;
  final ValueChanged<CustomsBorderIntervention> onOpen;

  @override
  Widget build(BuildContext context) {
    return _WorkspaceShell(
      title: 'Sınır Müdahale Dosyaları',
      description:
          'Sevkiyat, sınır noktası, ürün beyanı, doğrulama sonucu, süreler ve karar dayanaklarını tek operasyon dosyasında izleyin.',
      filter: DropdownButtonFormField<String?>(
        key: const ValueKey('customs-intervention-status-filter'),
        initialValue: selectedStatus,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Durum filtresi'),
        items: [
          const DropdownMenuItem<String?>(value: null, child: Text('Tümü')),
          ...customsInterventionStatuses.map(
            (status) => DropdownMenuItem<String?>(
              value: status,
              child: Text(customsInterventionStatusLabel(status)),
            ),
          ),
        ],
        onChanged: onStatusChanged,
      ),
      child: interventions.isEmpty
          ? const _EmptyPanel(
              key: ValueKey('customs-interventions-empty'),
              icon: Icons.local_shipping_outlined,
              title: 'Henüz sınır müdahale dosyası yok',
              description:
                  'Müdahale dosyası yalnız aktif bir Gümrük Koruma Profili üzerinden açılır.',
            )
          : ListView.separated(
              padding: EdgeInsets.zero,
              itemCount: interventions.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final intervention = interventions[index];
                return _RecordCard(
                  key: ValueKey(
                    'customs-intervention-${intervention.interventionId}',
                  ),
                  icon: Icons.local_shipping_outlined,
                  title: intervention.declaredProductDescription,
                  number: intervention.interventionNumber,
                  status: customsInterventionStatusLabel(intervention.status),
                  statusCode: intervention.status,
                  warning: intervention.hasIntegritySignal
                      ? 'İşlem bütünlüğü sinyali insan incelemesi gerektiriyor.'
                      : null,
                  lines: [
                    '${intervention.countryCode} · ${intervention.customsAuthorityName}',
                    '${customsBorderPointTypeLabel(intervention.borderPointType)} · ${intervention.borderPointName}',
                    '${customsPriorityLabel(intervention.priority)} öncelik · ${customsAuthenticationResultLabel(intervention.authenticationResult)}',
                  ],
                  onTap: () => onOpen(intervention),
                );
              },
            ),
    );
  }
}

class _AuthoritySubmissionWorkspace extends StatelessWidget {
  const _AuthoritySubmissionWorkspace({
    required this.submissions,
    required this.selectedStatus,
    required this.onStatusChanged,
    required this.onOpen,
  });

  final List<CustomsAuthoritySubmission> submissions;
  final String? selectedStatus;
  final ValueChanged<String?> onStatusChanged;
  final ValueChanged<CustomsAuthoritySubmission> onOpen;

  @override
  Widget build(BuildContext context) {
    return _WorkspaceShell(
      title: 'Resmî Başvuru ve Kurum İletimleri',
      description:
          'İnsan incelemesi, hak sahibi onayı, veri minimizasyonu, hukuken nötr anlatım, paket bütünlüğü ve resmî teslim kayıtlarını tek zaman çizelgesinde izleyin.',
      filter: DropdownButtonFormField<String?>(
        key: const ValueKey('customs-authority-submission-status-filter'),
        initialValue: selectedStatus,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Durum filtresi'),
        items: [
          const DropdownMenuItem<String?>(value: null, child: Text('Tümü')),
          ...customsAuthoritySubmissionStatuses.map(
            (status) => DropdownMenuItem<String?>(
              value: status,
              child: Text(customsAuthoritySubmissionStatusLabel(status)),
            ),
          ),
        ],
        onChanged: onStatusChanged,
      ),
      child: submissions.isEmpty
          ? const _EmptyPanel(
              key: ValueKey('customs-authority-submissions-empty'),
              icon: Icons.account_balance_outlined,
              title: 'Henüz resmî iletim taslağı yok',
              description:
                  'Aktif koruma profili veya sınır müdahale dosyası detayından kontrollü bir resmî iletim taslağı hazırlayın.',
            )
          : ListView.separated(
              padding: EdgeInsets.zero,
              itemCount: submissions.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final submission = submissions[index];
                final packageLine = submission.currentPackageHash == null
                    ? 'Paket henüz hazırlanmadı'
                    : 'Paket v${submission.currentPackageVersion} · ${_shortHash(submission.currentPackageHash!)}';
                final officialLine = submission.officialReferenceNumber == null
                    ? 'Resmî referans henüz kaydedilmedi'
                    : 'Resmî referans: ${submission.officialReferenceNumber}';
                return _RecordCard(
                  key: ValueKey(
                    'customs-authority-submission-${submission.submissionId}',
                  ),
                  icon: Icons.account_balance_outlined,
                  title: submission.title,
                  number: submission.submissionNumber,
                  status: customsAuthoritySubmissionStatusLabel(
                    submission.status,
                  ),
                  statusCode: submission.status,
                  statusColorResolver: customsAuthoritySubmissionStatusColor,
                  lines: [
                    '${customsAuthoritySubmissionTypeLabel(submission.submissionType)} · ${customsAuthorityTargetLabel(submission.targetAuthority)}',
                    packageLine,
                    officialLine,
                  ],
                  onTap: () => onOpen(submission),
                );
              },
            ),
    );
  }
}

String _shortHash(String value) =>
    value.length <= 12 ? value : '${value.substring(0, 12)}…';

class _WorkspaceShell extends StatelessWidget {
  const _WorkspaceShell({
    required this.title,
    required this.description,
    required this.filter,
    required this.child,
  });

  final String title;
  final String description;
  final Widget filter;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final heading = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: MarkaKalkanTheme.navy,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    description,
                    style: const TextStyle(
                      color: Color(0xFF687580),
                      height: 1.45,
                    ),
                  ),
                ],
              );
              if (constraints.maxWidth < 720) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [heading, const SizedBox(height: 14), filter],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: heading),
                  const SizedBox(width: 20),
                  SizedBox(width: 280, child: filter),
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _RecordCard extends StatelessWidget {
  const _RecordCard({
    super.key,
    required this.icon,
    required this.title,
    required this.number,
    required this.status,
    required this.statusCode,
    required this.lines,
    required this.onTap,
    this.warning,
    this.statusColorResolver,
  });

  final IconData icon;
  final String title;
  final String number;
  final String status;
  final String statusCode;
  final List<String> lines;
  final VoidCallback onTap;
  final String? warning;
  final Color Function(String status)? statusColorResolver;

  @override
  Widget build(BuildContext context) {
    final color =
        statusColorResolver?.call(statusCode) ?? customsStatusColor(statusCode);
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFE0E7EC)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F6F4),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: MarkaKalkanTheme.teal),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          number,
                          style: const TextStyle(
                            color: MarkaKalkanTheme.blue,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        _StatusPill(label: status, color: color),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: MarkaKalkanTheme.navy,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...lines.map(
                      (line) => Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Text(
                          line,
                          style: const TextStyle(
                            color: Color(0xFF687580),
                            height: 1.35,
                          ),
                        ),
                      ),
                    ),
                    if (warning != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        warning!,
                        style: const TextStyle(
                          color: Color(0xFF9A5B12),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 54, color: const Color(0xFF9AA6AE)),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: MarkaKalkanTheme.navy,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF687580), height: 1.45),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Color(0xFFB33A3A)),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Yeniden dene'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileCreationResult {
  const _ProfileCreationResult({
    required this.profile,
    required this.activated,
  });

  final CustomsProtectionProfile profile;
  final bool activated;
}

class _CreateProfileDialog extends StatefulWidget {
  const _CreateProfileDialog({required this.repository});

  final CustomsSecurityRepository repository;

  @override
  State<_CreateProfileDialog> createState() => _CreateProfileDialogState();
}

class _CreateProfileDialogState extends State<_CreateProfileDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _rightHolder = TextEditingController();
  final _rights = TextEditingController();
  final _products = TextEditingController();
  final _productCategory = TextEditingController();
  final _hsCodes = TextEditingController();
  final _instructions = TextEditingController();
  final _serialVerificationMethod = TextEditingController();
  final _features = TextEditingController();
  final _originCountry = TextEditingController();
  final _authorizedImportCountry = TextEditingController();
  final _riskCountries = TextEditingController();
  final _riskRoutes = TextEditingController();
  final _validUntil = TextEditingController();
  final List<String> _productCategories = [];
  final List<String> _serialVerificationMethods = [];
  final List<String> _originCountries = [];
  final List<String> _authorizedImportCountries = [];
  String? _productCategoryError;
  String? _serialVerificationMethodError;
  String? _originCountryError;
  String? _authorizedImportCountryError;
  late final String _activationRequestId;
  bool _activationConfirmed = false;
  bool _submitting = false;
  String? _submissionError;
  List<String> _activationMissing = const [];

  @override
  void initState() {
    super.initState();
    _activationRequestId = generateCustomsRequestId();
  }

  @override
  void dispose() {
    for (final controller in [
      _name,
      _rightHolder,
      _rights,
      _products,
      _productCategory,
      _hsCodes,
      _instructions,
      _serialVerificationMethod,
      _features,
      _originCountry,
      _authorizedImportCountry,
      _riskCountries,
      _riskRoutes,
      _validUntil,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  DateTime? _date(String value) {
    final clean = value.trim();
    if (clean.isEmpty) return null;
    return DateTime.tryParse('${clean}T23:59:59.000Z');
  }

  bool _addListValue({
    required TextEditingController controller,
    required List<String> values,
    required int maximumLength,
    required void Function(String?) setError,
    String Function(String)? normalize,
    bool Function(String)? validate,
    String? validationMessage,
  }) {
    final raw = controller.text.trim();
    if (raw.isEmpty) {
      setState(() => setError(null));
      return true;
    }
    final value = normalize?.call(raw) ?? raw;
    if (validate != null && !validate(value)) {
      setState(() => setError(validationMessage));
      return false;
    }
    if (value.length > maximumLength) {
      setState(
        () => setError('Değer en fazla $maximumLength karakter olabilir.'),
      );
      return false;
    }
    if (!values.contains(value) && values.length >= 50) {
      setState(() => setError('En fazla 50 değer eklenebilir.'));
      return false;
    }
    setState(() {
      if (!values.contains(value)) values.add(value);
      controller.clear();
      setError(null);
    });
    return true;
  }

  bool _addProductCategory() => _addListValue(
    controller: _productCategory,
    values: _productCategories,
    maximumLength: 300,
    setError: (value) => _productCategoryError = value,
  );

  bool _addSerialVerificationMethod() => _addListValue(
    controller: _serialVerificationMethod,
    values: _serialVerificationMethods,
    maximumLength: 500,
    setError: (value) => _serialVerificationMethodError = value,
  );

  bool _addOriginCountry() => _addCountry(
    controller: _originCountry,
    values: _originCountries,
    setError: (value) => _originCountryError = value,
  );

  bool _addAuthorizedImportCountry() => _addCountry(
    controller: _authorizedImportCountry,
    values: _authorizedImportCountries,
    setError: (value) => _authorizedImportCountryError = value,
  );

  bool _addCountry({
    required TextEditingController controller,
    required List<String> values,
    required void Function(String?) setError,
  }) => _addListValue(
    controller: controller,
    values: values,
    maximumLength: 2,
    setError: setError,
    normalize: (value) => value.toUpperCase(),
    validate: (value) => RegExp(r'^[A-Z]{2}$').hasMatch(value),
    validationMessage: 'Ülke kodu iki harfli ISO biçiminde olmalıdır. Örn. TR',
  );

  bool _flushPendingValues() {
    var pendingValuesValid = true;
    pendingValuesValid = _addProductCategory() && pendingValuesValid;
    pendingValuesValid = _addSerialVerificationMethod() && pendingValuesValid;
    pendingValuesValid = _addOriginCountry() && pendingValuesValid;
    pendingValuesValid = _addAuthorizedImportCountry() && pendingValuesValid;
    return pendingValuesValid;
  }

  CustomsProtectionProfileDraft _draft() => CustomsProtectionProfileDraft(
    profileName: _name.text,
    rightHolderName: _rightHolder.text,
    rightHolderReferenceIds: _split(_rights.text),
    protectedProductIds: _split(_products.text),
    productCategories: List.unmodifiable(_productCategories),
    hsCodes: _split(_hsCodes.text),
    authenticationInstructions: _instructions.text,
    serialVerificationMethods: List.unmodifiable(_serialVerificationMethods),
    securityFeatureSummaries: _split(_features.text),
    originCountries: List.unmodifiable(_originCountries),
    authorizedImportCountries: List.unmodifiable(_authorizedImportCountries),
    riskCountryCodes: _split(
      _riskCountries.text,
    ).map((value) => value.toUpperCase()).toList(growable: false),
    riskRouteSummaries: _split(_riskRoutes.text),
    validUntil: _date(_validUntil.text),
  );

  List<String> _missingForActivation() {
    final missing = <String>[];
    if (_name.text.trim().isEmpty) missing.add('Profil adı');
    if (_rightHolder.text.trim().isEmpty) missing.add('Hak sahibi adı');
    if (_split(_rights.text).isEmpty) {
      missing.add('En az bir hak/tescil referansı');
    }
    if (_split(_products.text).isEmpty) {
      missing.add('En az bir korunan ürün');
    }
    if (_instructions.text.trim().isEmpty) {
      missing.add('Doğrulama talimatı');
    }
    final validUntil = _date(_validUntil.text);
    if (_validUntil.text.trim().isNotEmpty &&
        (validUntil == null || validUntil.isBefore(DateTime.now().toUtc()))) {
      missing.add('Geçerlilik sonu geçmiş tarih olmamalı');
    }
    if (!_activationConfirmed) missing.add('Aktivasyon onayı');
    return missing;
  }

  Future<void> _submit({required bool activate}) async {
    if (_submitting) return;
    if (!_flushPendingValues()) return;
    final formValid = _formKey.currentState!.validate();
    if (activate) {
      final missing = _missingForActivation();
      if (missing.isNotEmpty) {
        setState(() {
          _activationMissing = missing;
          _submissionError = !_activationConfirmed
              ? 'Aktivasyon için bilgilerin doğruluğunu açıkça onaylamalısınız.'
              : null;
        });
        return;
      }
    }
    if (!formValid) return;
    final draft = _draft();
    setState(() {
      _submitting = true;
      _submissionError = null;
      _activationMissing = const [];
    });
    try {
      final profile = activate
          ? (await widget.repository.createAndActivateProfile(
              draft,
              requestId: _activationRequestId,
            )).profile
          : await widget.repository.createProfile(draft);
      if (!mounted) return;
      Navigator.of(
        context,
      ).pop(_ProfileCreationResult(profile: profile, activated: activate));
    } catch (error) {
      if (!mounted) return;
      final message =
          !activate ||
              error is AppCheckUnavailableException ||
              (error is FirebaseFunctionsException &&
                  error.code == 'unauthenticated')
          ? customsSecurityErrorMessage(error)
          : 'Profil oluşturulamadı ve hiçbir aktivasyon değişikliği '
                'kaydedilmedi. Bilgilerinizi kontrol edip yeniden deneyin.';
      setState(() => _submissionError = message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Yeni Gümrük Koruma Profili'),
      content: SizedBox(
        width: 680,
        height: MediaQuery.sizeOf(context).height * 0.58,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _field(
                  key: 'customs-profile-name',
                  controller: _name,
                  label: 'Profil adı',
                  minimum: 3,
                  onChanged: (_) => setState(() {}),
                ),
                _field(
                  key: 'customs-right-holder-name',
                  controller: _rightHolder,
                  label: 'Hak sahibi adı',
                  minimum: 2,
                  onChanged: (_) => setState(() {}),
                ),
                _field(
                  key: 'customs-right-holder-references',
                  controller: _rights,
                  label: 'Hak sahipliği/tescil referansları',
                  hint: 'Virgül veya yeni satırla ayırın',
                  onChanged: (_) => setState(() {}),
                ),
                _field(
                  key: 'customs-protected-products',
                  controller: _products,
                  label: 'Korunan ürün kimlikleri',
                  hint: 'Aktivasyon için en az bir ürün gerekir',
                  onChanged: (_) => setState(() {}),
                ),
                _chipListField(
                  keyName: 'customs-product-categories',
                  controller: _productCategory,
                  label: 'Ürün kategorileri',
                  hint: 'Örn. Otomotiv yedek parçası',
                  values: _productCategories,
                  errorText: _productCategoryError,
                  onAdd: _addProductCategory,
                  onRemove: (value) =>
                      setState(() => _productCategories.remove(value)),
                ),
                _field(
                  key: 'customs-hs-codes',
                  controller: _hsCodes,
                  label: 'HS/GTİP kodları',
                ),
                _field(
                  key: 'customs-authentication-instructions',
                  controller: _instructions,
                  label: 'Orijinal ürün doğrulama talimatı',
                  minimum: 10,
                  maxLines: 4,
                  onChanged: (_) => setState(() {}),
                ),
                _chipListField(
                  keyName: 'customs-serial-verification-methods',
                  controller: _serialVerificationMethod,
                  label: 'Seri doğrulama yöntemleri',
                  hint: 'Örn. Üretici seri numarası ve doğrulama kaydı',
                  values: _serialVerificationMethods,
                  errorText: _serialVerificationMethodError,
                  onAdd: _addSerialVerificationMethod,
                  onRemove: (value) =>
                      setState(() => _serialVerificationMethods.remove(value)),
                ),
                _field(
                  key: 'customs-security-features',
                  controller: _features,
                  label: 'Güvenlik özellikleri',
                ),
                _chipListField(
                  keyName: 'customs-origin-countries',
                  controller: _originCountry,
                  label: 'Menşe ülkeleri',
                  hint: 'TR',
                  values: _originCountries,
                  errorText: _originCountryError,
                  onAdd: _addOriginCountry,
                  onRemove: (value) =>
                      setState(() => _originCountries.remove(value)),
                ),
                _chipListField(
                  keyName: 'customs-authorized-import-countries',
                  controller: _authorizedImportCountry,
                  label: 'Yetkili ithalat ülkeleri',
                  hint: 'TR',
                  values: _authorizedImportCountries,
                  errorText: _authorizedImportCountryError,
                  onAdd: _addAuthorizedImportCountry,
                  onRemove: (value) =>
                      setState(() => _authorizedImportCountries.remove(value)),
                ),
                _field(
                  key: 'customs-risk-countries',
                  controller: _riskCountries,
                  label: 'Risk ülke kodları',
                  hint: 'TR, CN, AE gibi iki harfli kodlar',
                ),
                _field(
                  key: 'customs-risk-routes',
                  controller: _riskRoutes,
                  label: 'Riskli rota özetleri',
                ),
                _field(
                  key: 'customs-valid-until',
                  controller: _validUntil,
                  label: 'Geçerlilik sonu',
                  hint: 'YYYY-AA-GG',
                  validator: (value) {
                    final clean = value?.trim() ?? '';
                    if (clean.isEmpty) return null;
                    return _date(clean) == null
                        ? 'Tarih YYYY-AA-GG olmalıdır.'
                        : null;
                  },
                  onChanged: (_) => setState(() {}),
                ),
                _ActivationChecklist(missing: _missingForActivation().toSet()),
                CheckboxListTile(
                  key: const ValueKey(
                    'customs-profile-activation-confirmation',
                  ),
                  contentPadding: EdgeInsets.zero,
                  value: _activationConfirmed,
                  onChanged: _submitting
                      ? null
                      : (value) => setState(() {
                          _activationConfirmed = value == true;
                          _activationMissing = const [];
                          _submissionError = null;
                        }),
                  title: const Text(
                    'Profil bilgilerinin doğru, güncel ve resmî başvuru '
                    'hazırlığında kullanılmaya uygun olduğunu onaylıyorum.',
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                if (_activationMissing.isNotEmpty)
                  _ActivationMissingPanel(items: _activationMissing),
                if (_submissionError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      _submissionError!,
                      key: const ValueKey('customs-profile-submit-error'),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Vazgeç'),
        ),
        OutlinedButton(
          key: const ValueKey('save-customs-profile-draft'),
          onPressed: _submitting ? null : () => _submit(activate: false),
          child: const Text('Taslak olarak sakla'),
        ),
        FilledButton.icon(
          key: const ValueKey('create-and-activate-customs-profile'),
          onPressed: _submitting ? null : () => _submit(activate: true),
          icon: _submitting
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.verified_outlined),
          label: const Text('Kaydet ve aktifleştir'),
        ),
      ],
    );
  }

  Widget _chipListField({
    required String keyName,
    required TextEditingController controller,
    required String label,
    required String hint,
    required List<String> values,
    required String? errorText,
    required bool Function() onAdd,
    required void Function(String value) onRemove,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextFormField(
                  key: ValueKey('$keyName-input'),
                  controller: controller,
                  decoration: InputDecoration(
                    labelText: label,
                    hintText: hint,
                    errorText: errorText,
                  ),
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => onAdd(),
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: OutlinedButton.icon(
                  key: ValueKey('$keyName-add'),
                  onPressed: onAdd,
                  icon: const Icon(Icons.add),
                  label: const Text('Ekle'),
                ),
              ),
            ],
          ),
          if (values.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: values
                  .map(
                    (value) => InputChip(
                      key: ValueKey('$keyName-chip-$value'),
                      label: Text(value),
                      deleteIcon: Icon(
                        Icons.close,
                        key: ValueKey('$keyName-remove-$value'),
                      ),
                      onDeleted: () => onRemove(value),
                    ),
                  )
                  .toList(growable: false),
            ),
          ],
        ],
      ),
    );
  }
}

class _ActivationChecklist extends StatelessWidget {
  const _ActivationChecklist({required this.missing});

  final Set<String> missing;

  @override
  Widget build(BuildContext context) {
    const items = [
      'Profil adı',
      'Hak sahibi adı',
      'En az bir hak/tescil referansı',
      'En az bir korunan ürün',
      'Doğrulama talimatı',
      'Geçerlilik sonu geçmiş tarih olmamalı',
      'Aktivasyon onayı',
    ];
    return Container(
      key: const ValueKey('customs-profile-activation-checklist'),
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8, bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Aktivasyon kontrol listesi'),
          const SizedBox(height: 6),
          for (final item in items)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  missing.contains(item)
                      ? Icons.radio_button_unchecked
                      : Icons.check_circle,
                  size: 18,
                  color: missing.contains(item)
                      ? Theme.of(context).colorScheme.onSurfaceVariant
                      : Colors.green.shade700,
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(item)),
              ],
            ),
        ],
      ),
    );
  }
}

class _ActivationMissingPanel extends StatelessWidget {
  const _ActivationMissingPanel({required this.items});

  final List<String> items;

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('customs-profile-activation-missing'),
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    color: Theme.of(context).colorScheme.errorContainer,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Profili aktifleştirmek için aşağıdaki bilgileri tamamlayın:',
        ),
        for (final item in items) Text('• $item'),
      ],
    ),
  );
}

class _CreateInterventionDialog extends StatefulWidget {
  const _CreateInterventionDialog({required this.activeProfiles});

  final List<CustomsProtectionProfile> activeProfiles;

  @override
  State<_CreateInterventionDialog> createState() =>
      _CreateInterventionDialogState();
}

class _CreateInterventionDialogState extends State<_CreateInterventionDialog> {
  final _formKey = GlobalKey<FormState>();
  late String _profileId;
  String _priority = 'normal';
  String _sourceType = 'customs_notification';
  String _borderPointType = 'seaport';
  String _authenticationResult = 'not_started';
  final _country = TextEditingController();
  final _authority = TextEditingController();
  final _borderName = TextEditingController();
  final _shipment = TextEditingController();
  final _description = TextEditingController();
  final _hsCode = TextEditingController();
  final _quantity = TextEditingController();
  String? _unit;
  final _suspicionReasons = TextEditingController();
  final _responseDeadline = TextEditingController();
  final _actionDeadline = TextEditingController();
  bool _unusualRelease = false;
  bool _evidenceMismatch = false;
  bool _missingRecord = false;
  bool _independentReview = false;

  @override
  void initState() {
    super.initState();
    _profileId = widget.activeProfiles.first.profileId;
  }

  @override
  void dispose() {
    for (final controller in [
      _country,
      _authority,
      _borderName,
      _shipment,
      _description,
      _hsCode,
      _quantity,
      _suspicionReasons,
      _responseDeadline,
      _actionDeadline,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  DateTime? _date(String value) {
    final clean = value.trim();
    if (clean.isEmpty) return null;
    return DateTime.tryParse('${clean}T23:59:59.000Z');
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final quantity = _quantity.text.trim().isEmpty
        ? null
        : double.tryParse(_quantity.text.trim().replaceAll(',', '.'));
    if (_quantity.text.trim().isNotEmpty && quantity == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Miktar sayısal olmalıdır.')),
      );
      return;
    }
    if ((quantity == null) != (_unit == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Miktar ve birim birlikte girilmelidir.')),
      );
      return;
    }
    Navigator.of(context).pop(
      CustomsBorderInterventionDraft(
        protectionProfileId: _profileId,
        priority: _priority,
        sourceType: _sourceType,
        countryCode: _country.text,
        customsAuthorityName: _authority.text,
        borderPointType: _borderPointType,
        borderPointName: _borderName.text,
        shipmentReference: _shipment.text,
        declaredProductDescription: _description.text,
        declaredHsCode: _hsCode.text,
        declaredQuantity: quantity,
        declaredUnit: _unit,
        suspicionReasons: _split(_suspicionReasons.text),
        authenticationResult: _authenticationResult,
        responseDeadlineAt: _date(_responseDeadline.text),
        actionDeadlineAt: _date(_actionDeadline.text),
        unusualReleaseFlag: _unusualRelease,
        decisionEvidenceMismatchFlag: _evidenceMismatch,
        missingRecordOrSampleFlag: _missingRecord,
        independentReviewRequired: _independentReview,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Yeni Sınır Müdahale Dosyası'),
      content: SizedBox(
        width: 760,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  key: const ValueKey('customs-intervention-profile'),
                  initialValue: _profileId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Aktif Gümrük Koruma Profili',
                  ),
                  items: widget.activeProfiles
                      .map(
                        (profile) => DropdownMenuItem(
                          value: profile.profileId,
                          child: Text(
                            '${profile.profileNumber} · ${profile.profileName}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) {
                    if (value != null) setState(() => _profileId = value);
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _dropdown(
                        key: 'customs-intervention-priority',
                        label: 'Öncelik',
                        value: _priority,
                        values: customsPriorities,
                        labeler: customsPriorityLabel,
                        onChanged: (value) => setState(() => _priority = value),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _dropdown(
                        key: 'customs-intervention-source',
                        label: 'Kaynak',
                        value: _sourceType,
                        values: customsSourceTypes,
                        labeler: customsSourceTypeLabel,
                        onChanged: (value) =>
                            setState(() => _sourceType = value),
                      ),
                    ),
                  ],
                ),
                _field(
                  key: 'customs-intervention-country',
                  controller: _country,
                  label: 'Ülke kodu',
                  hint: 'TR',
                  minimum: 2,
                  validator: (value) => (value?.trim().length == 2)
                      ? null
                      : 'İki harfli ülke kodu girin.',
                ),
                _field(
                  key: 'customs-intervention-authority',
                  controller: _authority,
                  label: 'Gümrük idaresi',
                  minimum: 2,
                ),
                _dropdown(
                  key: 'customs-border-point-type',
                  label: 'Sınır noktası türü',
                  value: _borderPointType,
                  values: customsBorderPointTypes,
                  labeler: customsBorderPointTypeLabel,
                  onChanged: (value) =>
                      setState(() => _borderPointType = value),
                ),
                _field(
                  key: 'customs-border-point-name',
                  controller: _borderName,
                  label: 'Sınır noktası adı',
                  minimum: 2,
                ),
                _field(
                  key: 'customs-shipment-reference',
                  controller: _shipment,
                  label: 'Sevkiyat/kargo referansı',
                ),
                _field(
                  key: 'customs-declared-product',
                  controller: _description,
                  label: 'Beyan edilen ürün açıklaması',
                  minimum: 3,
                  maxLines: 3,
                ),
                Row(
                  children: [
                    Expanded(
                      child: _field(
                        key: 'customs-declared-hs-code',
                        controller: _hsCode,
                        label: 'Beyan edilen HS/GTİP',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _field(
                        key: 'customs-declared-quantity',
                        controller: _quantity,
                        label: 'Miktar',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String?>(
                        key: const ValueKey('customs-declared-unit'),
                        initialValue: _unit,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Birim'),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('Seçilmedi'),
                          ),
                          ...customsDeclaredUnits.map(
                            (unit) => DropdownMenuItem<String?>(
                              value: unit,
                              child: Text(customsDeclaredUnitLabel(unit)),
                            ),
                          ),
                        ],
                        onChanged: (value) => setState(() => _unit = value),
                      ),
                    ),
                  ],
                ),
                _field(
                  key: 'customs-suspicion-reasons',
                  controller: _suspicionReasons,
                  label: 'Şüphe nedenleri',
                  hint: 'Virgül veya yeni satırla ayırın',
                  maxLines: 3,
                ),
                _dropdown(
                  key: 'customs-authentication-result',
                  label: 'Ürün doğrulama sonucu',
                  value: _authenticationResult,
                  values: customsAuthenticationResults,
                  labeler: customsAuthenticationResultLabel,
                  onChanged: (value) =>
                      setState(() => _authenticationResult = value),
                ),
                Row(
                  children: [
                    Expanded(
                      child: _field(
                        key: 'customs-response-deadline',
                        controller: _responseDeadline,
                        label: 'Yanıt son tarihi',
                        hint: 'YYYY-AA-GG',
                        validator: _dateValidator,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _field(
                        key: 'customs-action-deadline',
                        controller: _actionDeadline,
                        label: 'İşlem son tarihi',
                        hint: 'YYYY-AA-GG',
                        validator: _dateValidator,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                CheckboxListTile(
                  value: _unusualRelease,
                  onChanged: (value) =>
                      setState(() => _unusualRelease = value == true),
                  title: const Text('Olağandışı serbest bırakma sinyali'),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                CheckboxListTile(
                  value: _evidenceMismatch,
                  onChanged: (value) =>
                      setState(() => _evidenceMismatch = value == true),
                  title: const Text('Karar-delil uyumsuzluğu sinyali'),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                CheckboxListTile(
                  value: _missingRecord,
                  onChanged: (value) =>
                      setState(() => _missingRecord = value == true),
                  title: const Text('Eksik kayıt veya numune sinyali'),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                CheckboxListTile(
                  value: _independentReview,
                  onChanged: (value) =>
                      setState(() => _independentReview = value == true),
                  title: const Text('Bağımsız inceleme gerekiyor'),
                  controlAffinity: ListTileControlAffinity.leading,
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
          key: const ValueKey('confirm-create-customs-intervention'),
          onPressed: _submit,
          child: const Text('Taslak oluştur'),
        ),
      ],
    );
  }

  String? _dateValidator(String? value) {
    final clean = value?.trim() ?? '';
    if (clean.isEmpty) return null;
    return _date(clean) == null ? 'Tarih YYYY-AA-GG olmalıdır.' : null;
  }
}

Widget _field({
  required String key,
  required TextEditingController controller,
  required String label,
  String? hint,
  int minimum = 0,
  int maxLines = 1,
  String? Function(String?)? validator,
  ValueChanged<String>? onChanged,
}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      key: ValueKey(key),
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(labelText: label, hintText: hint),
      onChanged: onChanged,
      validator:
          validator ??
          (value) {
            if (minimum == 0) return null;
            return (value?.trim().length ?? 0) >= minimum
                ? null
                : 'En az $minimum karakter girin.';
          },
    ),
  );
}

Widget _dropdown({
  required String key,
  required String label,
  required String value,
  required List<String> values,
  required String Function(String) labeler,
  required ValueChanged<String> onChanged,
}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: DropdownButtonFormField<String>(
      key: ValueKey(key),
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: values
          .map(
            (item) => DropdownMenuItem(value: item, child: Text(labeler(item))),
          )
          .toList(growable: false),
      onChanged: (item) {
        if (item != null) onChanged(item);
      },
    ),
  );
}

List<String> _split(String value) {
  final seen = <String>{};
  return value
      .split(RegExp(r'[,;\n]'))
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty && seen.add(item))
      .toList(growable: false);
}

String _formatDateTime(String value) {
  final parsed = DateTime.tryParse(value)?.toLocal();
  if (parsed == null) return value;
  String two(int number) => number.toString().padLeft(2, '0');
  return '${two(parsed.day)}.${two(parsed.month)}.${parsed.year} '
      '${two(parsed.hour)}:${two(parsed.minute)}';
}

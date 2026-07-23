import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:markakalkan/core/theme/markakalkan_theme.dart';
import 'package:markakalkan/app/router.dart';
import 'package:markakalkan/features/case_evidence_center/presentation/case_evidence_presentation_labels.dart';

abstract interface class CaseEvidenceCenterRepository {
  Future<CaseEvidenceCenterResult> load();

  Future<CaseCreationResult> createCase(
    CaseEvidenceCandidate candidate, {
    required bool dryRun,
  });
}

class CallableCaseEvidenceCenterRepository
    implements CaseEvidenceCenterRepository {
  CallableCaseEvidenceCenterRepository({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'europe-west3');

  final FirebaseFunctions _functions;

  @override
  Future<CaseEvidenceCenterResult> load() async {
    final result = await _functions
        .httpsCallable('listCaseEvidenceCenter')
        .call({'pageSize': 25});
    return CaseEvidenceCenterResult.fromMap(_map(_normalize(result.data)));
  }

  @override
  Future<CaseCreationResult> createCase(
    CaseEvidenceCandidate candidate, {
    required bool dryRun,
  }) async {
    final result = await _functions
        .httpsCallable('createCaseFromRiskOperation')
        .call({
          'sourceSystem': candidate.sourceSystem,
          'sourceRecordId': candidate.sourceRecordId,
          'expectedSourceRecordVersion': candidate.sourceRecordVersion,
          'expectedProjectionFingerprint': candidate.projectionFingerprint,
          'correlationId':
              'case-${DateTime.now().microsecondsSinceEpoch}-${candidate.signalId}',
          'dryRun': dryRun,
        });
    return CaseCreationResult.fromMap(_map(_normalize(result.data)));
  }
}

class CaseEvidenceCenterResult {
  const CaseEvidenceCenterResult({
    required this.summary,
    required this.cases,
    required this.candidates,
    required this.partialSourceUnavailable,
  });

  final CaseCenterSummary summary;
  final List<CaseFileItem> cases;
  final List<CaseEvidenceCandidate> candidates;
  final bool partialSourceUnavailable;

  factory CaseEvidenceCenterResult.fromMap(Map<String, dynamic> map) {
    if (map['contractVersion'] != 'case-evidence-center-read-v1' ||
        map['readOnly'] != true ||
        map['writesPerformed'] != 0) {
      throw const FormatException('Geçersiz vaka merkezi yanıtı.');
    }
    return CaseEvidenceCenterResult(
      summary: CaseCenterSummary.fromMap(_map(map['summary'])),
      cases: _list(
        map['cases'],
      ).map((item) => CaseFileItem.fromMap(_map(item))).toList(growable: false),
      candidates: _list(map['caseCandidates'])
          .map((item) => CaseEvidenceCandidate.fromMap(_map(item)))
          .toList(growable: false),
      partialSourceUnavailable: _list(
        map['sourceAvailability'],
      ).any((item) => _map(item)['status'] != 'available'),
    );
  }
}

class CaseCenterSummary {
  const CaseCenterSummary({
    required this.openCases,
    required this.evidenceAwaitingReview,
    required this.expertReview,
    required this.legalHold,
    required this.reviewCandidates,
  });

  final int openCases;
  final int evidenceAwaitingReview;
  final int expertReview;
  final int legalHold;
  final int reviewCandidates;

  factory CaseCenterSummary.fromMap(Map<String, dynamic> map) =>
      CaseCenterSummary(
        openCases: _integer(map, 'openCases'),
        evidenceAwaitingReview: _integer(map, 'evidenceAwaitingReview'),
        expertReview: _integer(map, 'expertReview'),
        legalHold: _integer(map, 'legalHold'),
        reviewCandidates: _integer(map, 'reviewCandidates'),
      );
}

class CaseEvidenceCandidate {
  const CaseEvidenceCandidate({
    required this.signalId,
    required this.sourceSystem,
    required this.sourceRecordId,
    required this.sourceRecordVersion,
    required this.projectionFingerprint,
    required this.title,
    required this.summary,
    required this.severity,
    required this.evidenceQuality,
    this.existingCaseNumber,
    this.existingCaseId,
  });

  final String signalId;
  final String sourceSystem;
  final String sourceRecordId;
  final String sourceRecordVersion;
  final String projectionFingerprint;
  final String title;
  final String summary;
  final String severity;
  final String evidenceQuality;
  final String? existingCaseNumber;
  final String? existingCaseId;

  bool get hasCase => existingCaseNumber != null;

  factory CaseEvidenceCandidate.fromMap(Map<String, dynamic> map) =>
      CaseEvidenceCandidate(
        signalId: _string(map, 'signalId'),
        sourceSystem: _string(map, 'sourceSystem'),
        sourceRecordId: _string(map, 'sourceRecordId'),
        sourceRecordVersion: _string(map, 'sourceRecordVersion'),
        projectionFingerprint: _string(map, 'projectionFingerprint'),
        title: _string(map, 'title'),
        summary: _string(map, 'summary'),
        severity: _string(map, 'severity'),
        evidenceQuality: _string(_map(map['evidenceQuality']), 'level'),
        existingCaseNumber: _nullableString(map['existingCaseNumber']),
        existingCaseId: _nullableString(map['existingCaseId']),
      );
}

class CaseFileItem {
  const CaseFileItem({
    required this.caseNumber,
    required this.id,
    required this.title,
    required this.summary,
    required this.status,
    required this.priority,
    required this.sourceSystem,
    required this.events,
    required this.evidenceRefs,
  });

  final String caseNumber;
  final String id;
  final String title;
  final String summary;
  final String status;
  final String priority;
  final String sourceSystem;
  final List<Map<String, dynamic>> events;
  final List<Map<String, dynamic>> evidenceRefs;

  factory CaseFileItem.fromMap(Map<String, dynamic> map) => CaseFileItem(
    id: _string(map, 'caseId'),
    caseNumber: _string(map, 'caseNumber'),
    title: _string(map, 'title'),
    summary: _string(map, 'summary'),
    status: _string(map, 'status'),
    priority: _string(map, 'priority'),
    sourceSystem: _string(_map(map['sourceBinding']), 'sourceSystem'),
    events: _list(map['events']).map(_map).toList(growable: false),
    evidenceRefs: _list(map['evidenceRefs']).map(_map).toList(growable: false),
  );
}

class CaseCreationResult {
  const CaseCreationResult({
    required this.outcome,
    required this.transactionCommitted,
    this.caseNumber,
  });

  final String outcome;
  final bool transactionCommitted;
  final String? caseNumber;

  factory CaseCreationResult.fromMap(Map<String, dynamic> map) =>
      CaseCreationResult(
        outcome: _string(map, 'outcome'),
        transactionCommitted: map['transactionCommitted'] == true,
        caseNumber: _nullableString(map['caseNumber']),
      );
}

class CaseEvidenceCenterPage extends StatefulWidget {
  const CaseEvidenceCenterPage({super.key, this.repository, this.detailOpener});

  final CaseEvidenceCenterRepository? repository;
  final Future<void> Function(BuildContext context, String caseId)?
  detailOpener;

  @override
  State<CaseEvidenceCenterPage> createState() => _CaseEvidenceCenterPageState();
}

class _CaseEvidenceCenterPageState extends State<CaseEvidenceCenterPage> {
  late final CaseEvidenceCenterRepository _repository =
      widget.repository ?? CallableCaseEvidenceCenterRepository();

  CaseEvidenceCenterResult? _result;
  Object? _error;
  bool _loading = true;
  String? _processing;
  final GlobalKey _caseFilesKey = GlobalKey();
  final ScrollController _scrollController = ScrollController();

  Future<void> _openDetail(String? caseId) async {
    if (caseId == null || caseId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vaka ayrıntısı şu anda açılamıyor.')),
      );
      return;
    }
    final opener = widget.detailOpener;
    if (opener != null) return opener(context, caseId);
    return AppRouter.openCaseEvidenceDetail(context, caseId: caseId);
  }

  Future<void> _scrollToCases() async {
    if (_caseFilesKey.currentContext == null && _scrollController.hasClients) {
      final position = _scrollController.position;
      final destination = position.maxScrollExtent
          .clamp(position.minScrollExtent, position.maxScrollExtent)
          .toDouble();
      await _scrollController.animateTo(
        destination,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
      if (!mounted) return;
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
    }
    if (!mounted) return;
    final target = _caseFilesKey.currentContext;
    if (target != null && target.mounted) {
      await Scrollable.ensureVisible(
        target,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
        alignment: 0.08,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vaka dosyaları bölümüne ulaşıldı.')),
      );
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _repository.load();
      if (!mounted) return;
      setState(() {
        _result = result;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  Future<void> _create(
    CaseEvidenceCandidate candidate, {
    required bool dryRun,
  }) async {
    if (_processing != null) return;
    if (!dryRun) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Vaka dosyası açılsın mı?'),
          content: const Text(
            'Kaynak risk kaydı değiştirilmeyecek. Vaka dosyası, kaynak '
            'delil referansı, açılış olayı ve denetim kaydı atomik olarak '
            'oluşturulacaktır.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Vaka dosyası aç'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    setState(() => _processing = candidate.signalId);
    try {
      final result = await _repository.createCase(candidate, dryRun: dryRun);
      if (!mounted) return;
      final message = switch (result.outcome) {
        'dry_run_ready' =>
          'Yazısız doğrulama başarılı. Vaka dosyası oluşturulmadı.',
        'created' =>
          '${result.caseNumber ?? 'Vaka dosyası'} güvenli biçimde oluşturuldu.',
        'already_exists' =>
          '${result.caseNumber ?? 'Bu kaynak'} için vaka dosyası zaten mevcut.',
        'conflict' =>
          'Kaynak kayıt değişti. Görünümü yenileyip yeniden inceleyin.',
        _ => 'Vaka açılışı güvenlik politikası nedeniyle tamamlanmadı.',
      };
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      if (result.outcome == 'created' || result.outcome == 'already_exists') {
        await _load();
      }
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) return;
      final message = switch (error.code) {
        'failed-precondition' =>
          'Gerçek vaka açılışı için uygulama doğrulaması gereklidir.',
        'permission-denied' => 'Bu işlem için yeterli yetkiniz bulunmuyor.',
        'not-found' => 'Kaynak risk kaydı artık bulunamıyor.',
        _ => 'Vaka işlemi güvenli biçimde tamamlanamadı.',
      };
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vaka işlemi güvenli biçimde tamamlanamadı.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _processing = null);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: MarkaKalkanTheme.background,
    appBar: AppBar(title: const Text('Vaka ve Delil Merkezi')),
    body: RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.all(24),
        children: [
          const _Hero(),
          const SizedBox(height: 20),
          if (_loading)
            const Center(
              key: ValueKey('case-evidence-center-loading'),
              child: Padding(
                padding: EdgeInsets.all(42),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_error != null)
            _StateCard(
              key: const ValueKey('case-evidence-center-error'),
              title: 'Vaka ve delil görünümü yüklenemedi.',
              icon: Icons.error_outline,
              action: _load,
            )
          else
            ..._content(_result!),
        ],
      ),
    ),
  );

  List<Widget> _content(CaseEvidenceCenterResult result) => [
    if (result.partialSourceUnavailable) ...[
      const _StateCard(
        title: 'Bazı risk kaynakları geçici olarak kullanılamıyor.',
        icon: Icons.cloud_off_outlined,
      ),
      const SizedBox(height: 18),
    ],
    _SummaryGrid(summary: result.summary),
    const SizedBox(height: 22),
    _WorkspaceGrid(onCaseFilesTap: _scrollToCases),
    const SizedBox(height: 26),
    _SectionTitle(
      title: 'İnceleme Gerektiren Riskler',
      subtitle:
          'Sinyalleri yazmadan doğrulayın veya kontrollü biçimde vaka '
          'dosyasına dönüştürün.',
      count: result.candidates.where((item) => !item.hasCase).length,
    ),
    const SizedBox(height: 12),
    if (result.candidates.where((item) => !item.hasCase).isEmpty)
      const _StateCard(
        title: 'Vaka açılışı bekleyen risk sinyali bulunmuyor.',
        icon: Icons.fact_check_outlined,
      )
    else
      ...result.candidates
          .where((item) => !item.hasCase)
          .map(
            (candidate) => _CandidateCard(
              candidate: candidate,
              processing: _processing == candidate.signalId,
              onDryRun: () => _create(candidate, dryRun: true),
              onCreate: () => _create(candidate, dryRun: false),
              onOpenCase: () => _openDetail(candidate.existingCaseId),
            ),
          ),
    if (result.candidates.any((item) => item.hasCase)) ...[
      const SizedBox(height: 26),
      _SectionTitle(
        title: 'Vakaya Dönüştürülen Riskler',
        subtitle: 'Vaka dosyasına bağlanan risk sinyalleri.',
        count: result.candidates.where((item) => item.hasCase).length,
      ),
      const SizedBox(height: 12),
      ...result.candidates
          .where((item) => item.hasCase)
          .map(
            (candidate) => _CandidateCard(
              candidate: candidate,
              processing: false,
              onDryRun: () {},
              onCreate: () {},
              onOpenCase: () => _openDetail(candidate.existingCaseId),
            ),
          ),
    ],
    const SizedBox(height: 26),
    _SectionTitle(
      key: _caseFilesKey,
      title: 'Vaka Dosyaları',
      subtitle:
          'Kaynak risk, delil referansları ve olay zaman çizelgesiyle '
          'birlikte yönetilen dosyalar.',
      count: result.cases.length,
    ),
    const SizedBox(height: 12),
    if (result.cases.isEmpty)
      const _StateCard(
        key: ValueKey('case-evidence-center-empty'),
        title: 'Henüz vaka dosyası oluşturulmadı.',
        icon: Icons.folder_open_outlined,
      )
    else
      ...result.cases.map(
        (item) => _CaseCard(item: item, onOpen: () => _openDetail(item.id)),
      ),
  ];
}

class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('case-evidence-center-hero'),
    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 27),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF0B1F3A), Color(0xFF153B63)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(24),
      boxShadow: const [
        BoxShadow(
          color: Color(0x240B1F3A),
          blurRadius: 22,
          offset: Offset(0, 10),
        ),
      ],
    ),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 650;
        const icon = DecoratedBox(
          decoration: BoxDecoration(
            color: Color(0xFF244C73),
            shape: BoxShape.circle,
          ),
          child: SizedBox(
            width: 62,
            height: 62,
            child: Icon(
              Icons.folder_copy_outlined,
              color: Color(0xFF64D6C1),
              size: 34,
            ),
          ),
        );
        const content = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sinyali vakaya, delili savunmaya dönüştür.',
              style: TextStyle(
                color: Colors.white,
                fontSize: 25,
                height: 1.2,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 11),
            Text(
              'İnceleme gerektiren riskleri vaka dosyalarında '
              'birleştirin; delilleri, ilişkileri ve olay zaman '
              'çizelgesini bütünlüğü korunmuş tek bir merkezden yönetin.',
              style: TextStyle(
                color: Color(0xFFD9E6F2),
                fontSize: 15,
                height: 1.55,
              ),
            ),
          ],
        );
        return narrow
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [icon, const SizedBox(height: 17), content],
              )
            : const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  icon,
                  SizedBox(width: 20),
                  Expanded(child: content),
                ],
              );
      },
    ),
  );
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.summary});

  final CaseCenterSummary summary;

  @override
  Widget build(BuildContext context) {
    final values = [
      ('Açık Vakalar', summary.openCases, Icons.folder_open_outlined),
      (
        'İnceleme Bekleyen Deliller',
        summary.evidenceAwaitingReview,
        Icons.description_outlined,
      ),
      ('Uzman İncelemesi', summary.expertReview, Icons.groups_outlined),
      ('Hukuki Muhafaza Altında', summary.legalHold, Icons.lock_outline),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 620
            ? 1
            : constraints.maxWidth < 1000
            ? 2
            : 4;
        const spacing = 14.0;
        final width =
            (constraints.maxWidth - (columns - 1) * spacing) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: values
              .map(
                (value) => SizedBox(
                  width: width,
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFE1E7EC)),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: const Color(0xFFEAF1F8),
                          child: Icon(value.$3, color: const Color(0xFF183B63)),
                        ),
                        const SizedBox(width: 13),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${value.$2}',
                                style: const TextStyle(
                                  color: Color(0xFF17314D),
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                value.$1,
                                style: const TextStyle(
                                  color: Color(0xFF687580),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
              .toList(growable: false),
        );
      },
    );
  }
}

class _WorkspaceGrid extends StatelessWidget {
  const _WorkspaceGrid({required this.onCaseFilesTap});
  final VoidCallback onCaseFilesTap;

  @override
  Widget build(BuildContext context) {
    const values = [
      (
        'Vaka Dosyaları',
        'Durum, öncelik, sorumlu ve yaşam döngüsü',
        Icons.folder_copy_outlined,
      ),
      (
        'Delil Kasası ve Delil Zinciri',
        'Kaynak, sürüm, bütünlük ve teslim kayıtları',
        Icons.inventory_2_outlined,
      ),
      (
        'Görevler, Uzmanlar ve İncelemeler',
        'Saha, laboratuvar ve uzman değerlendirmeleri',
        Icons.assignment_ind_outlined,
      ),
      (
        'Taraflar, İlişkiler ve Olay Zaman Çizelgesi',
        'Bağlantılı varlıklar ve soruşturma anlatısı',
        Icons.hub_outlined,
      ),
      (
        'Hukuki Muhafaza, Saklama ve Dışa Aktarım',
        'Dosya kilidi, erişim denetimi ve delil paketi',
        Icons.gavel_outlined,
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 700
            ? 1
            : constraints.maxWidth < 1120
            ? 2
            : 5;
        const spacing = 14.0;
        final width =
            (constraints.maxWidth - (columns - 1) * spacing) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: values
              .map(
                (value) => SizedBox(
                  width: width,
                  child: InkWell(
                    key: value.$1 == 'Vaka Dosyaları'
                        ? const ValueKey('case-files-workspace')
                        : null,
                    onTap: value.$1 == 'Vaka Dosyaları' ? onCaseFilesTap : null,
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 168),
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFE1E7EC)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(value.$3, color: const Color(0xFF154E76)),
                          const SizedBox(height: 13),
                          Text(
                            value.$1,
                            style: const TextStyle(
                              color: Color(0xFF17314D),
                              fontSize: 15,
                              height: 1.25,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            value.$2,
                            style: const TextStyle(
                              color: Color(0xFF687580),
                              fontSize: 12.5,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              )
              .toList(growable: false),
        );
      },
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    super.key,
    required this.title,
    required this.subtitle,
    required this.count,
  });

  final String title;
  final String subtitle;
  final int count;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Color(0xFF17314D),
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              subtitle,
              style: const TextStyle(
                color: Color(0xFF687580),
                fontSize: 14,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
      Chip(label: Text('$count')),
    ],
  );
}

class _CandidateCard extends StatelessWidget {
  const _CandidateCard({
    required this.candidate,
    required this.processing,
    required this.onDryRun,
    required this.onCreate,
    required this.onOpenCase,
  });

  final CaseEvidenceCandidate candidate;
  final bool processing;
  final VoidCallback onDryRun;
  final VoidCallback onCreate;
  final VoidCallback onOpenCase;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Pill(label: _sourceLabel(candidate.sourceSystem)),
              _Pill(label: _severityLabel(candidate.severity)),
              _Pill(label: _evidenceLabel(candidate.evidenceQuality)),
              if (candidate.hasCase)
                _CaseLinkPill(
                  key: ValueKey('converted-case-code-${candidate.signalId}'),
                  label: candidate.existingCaseNumber!,
                  onPressed: onOpenCase,
                ),
            ],
          ),
          const SizedBox(height: 13),
          Text(
            caseEvidenceSignalLabel(candidate.title),
            style: const TextStyle(
              color: Color(0xFF17314D),
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            caseEvidenceSignalLabel(candidate.summary),
            style: const TextStyle(color: Color(0xFF596873), height: 1.45),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                OutlinedButton.icon(
                  onPressed: processing ? null : onDryRun,
                  icon: const Icon(Icons.fact_check_outlined),
                  label: const Text('Yazmadan doğrula'),
                ),
                FilledButton.icon(
                  onPressed: processing
                      ? null
                      : candidate.hasCase
                      ? onOpenCase
                      : onCreate,
                  icon: const Icon(Icons.create_new_folder_outlined),
                  label: Text(
                    candidate.hasCase
                        ? 'Vaka dosyası mevcut'
                        : 'Vaka dosyası aç',
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

class _CaseCard extends StatelessWidget {
  const _CaseCard({required this.item, required this.onOpen});

  final CaseFileItem item;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    child: ExpansionTile(
      leading: const CircleAvatar(
        backgroundColor: Color(0xFFE9F1FF),
        child: Icon(Icons.folder_outlined, color: Color(0xFF174F78)),
      ),
      title: Text(
        item.title,
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            TextButton(
              key: ValueKey('case-code-${item.id}'),
              onPressed: onOpen,
              child: Text(item.caseNumber),
            ),
            _Pill(label: _statusLabel(item.status)),
            _Pill(label: _priorityLabel(item.priority)),
            _Pill(label: _sourceLabel(item.sourceSystem)),
          ],
        ),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.summary),
              const SizedBox(height: 17),
              const Text(
                'Delil Referansları',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              if (item.evidenceRefs.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text('Henüz delil referansı bulunmuyor.'),
                )
              else
                ...item.evidenceRefs.map(
                  (evidence) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.link_outlined),
                    title: Text(_string(evidence, 'title')),
                    subtitle: Text(
                      '${_sourceLabel(_string(evidence, 'sourceSystem'))} · '
                      '${_reviewLabel(_string(evidence, 'reviewStatus'))}',
                    ),
                  ),
                ),
              const Divider(height: 28),
              const Text(
                'Olay Zaman Çizelgesi',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              if (item.events.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text('Henüz zaman çizelgesi olayı bulunmuyor.'),
                )
              else
                ...item.events.map(
                  (event) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.timeline_outlined),
                    title: Text(_string(event, 'summary')),
                    subtitle: Text(_dateLabel(event['occurredAt'])),
                  ),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: const Color(0xFFF1F4F6),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      label,
      style: TextStyle(
        color: const Color(0xFF52616B),
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _CaseLinkPill extends StatelessWidget {
  const _CaseLinkPill({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    link: true,
    label: '$label vaka ayrıntısını aç',
    child: TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: const Color(0xFF116149),
        backgroundColor: const Color(0xFFE4F7EF),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: const StadiumBorder(),
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      ),
      child: Text(label),
    ),
  );
}

class _StateCard extends StatelessWidget {
  const _StateCard({
    super.key,
    required this.title,
    required this.icon,
    this.action,
  });

  final String title;
  final IconData icon;
  final Future<void> Function()? action;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(22),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF174F78)),
          const SizedBox(width: 13),
          Expanded(child: Text(title)),
          if (action != null)
            TextButton(onPressed: action, child: const Text('Yeniden dene')),
        ],
      ),
    ),
  );
}

String _sourceLabel(String value) => switch (value) {
  'monitoring' => 'İzleme',
  'traceability' => 'İzlenebilirlik',
  'digital_detective' => 'Dijital Dedektif',
  'shared_risk' => 'Ortak Risk',
  _ => 'Diğer Kaynak',
};
String _severityLabel(String value) => switch (value) {
  'critical' => 'Kritik Risk',
  'high' => 'Yüksek Risk',
  'medium' => 'Orta Risk',
  'low' => 'Düşük Risk',
  _ => 'Bilgilendirme',
};
String _evidenceLabel(String value) => switch (value) {
  'verified_primary' => 'Doğrulanmış Birincil Delil',
  'corroborated' => 'Birden Fazla Kaynakla Desteklenmiş',
  'single_source' => 'Tek Kaynak',
  'insufficient' => 'Yetersiz Delil',
  _ => 'Değerlendirilemiyor',
};
String _statusLabel(String value) => switch (value) {
  'open' => 'Açık',
  'in_review' => 'İncelemede',
  'closed' => 'Kapalı',
  'archived' => 'Arşivlendi',
  _ => 'İlk İnceleme',
};
String _priorityLabel(String value) => switch (value) {
  'critical' => 'Kritik Öncelik',
  'high' => 'Yüksek Öncelik',
  'medium' => 'Orta Öncelik',
  _ => 'Düşük Öncelik',
};
String _reviewLabel(String value) => switch (value) {
  'pending' => 'İnceleme Bekliyor',
  'accepted' => 'Kabul Edildi',
  'rejected' => 'Reddedildi',
  _ => 'Değerlendiriliyor',
};

Object? _normalize(Object? value) {
  if (value == null || value is String || value is bool || value is num) {
    return value;
  }
  if (value is List) return value.map(_normalize).toList(growable: false);
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), _normalize(item)));
  }
  throw const FormatException('Desteklenmeyen callable değeri.');
}

Map<String, dynamic> _map(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  throw const FormatException('Beklenen nesne bulunamadı.');
}

List<dynamic> _list(Object? value) {
  if (value is List) return value;
  throw const FormatException('Beklenen liste bulunamadı.');
}

String _string(Map<String, dynamic> map, String field) {
  final value = map[field];
  if (value is String && value.trim().isNotEmpty) return value.trim();
  throw FormatException('$field alanı geçersiz.');
}

String? _nullableString(Object? value) {
  if (value == null) return null;
  if (value is String && value.trim().isNotEmpty) return value.trim();
  throw const FormatException('İsteğe bağlı metin alanı geçersiz.');
}

int _integer(Map<String, dynamic> map, String field) {
  final value = map[field];
  if (value is int && value >= 0) return value;
  throw FormatException('$field alanı geçersiz.');
}

String _dateLabel(Object? value) {
  if (value is! String) return 'Zaman bilinmiyor';
  final date = DateTime.tryParse(value)?.toLocal();
  if (date == null) return 'Zaman bilinmiyor';
  String two(int number) => number.toString().padLeft(2, '0');
  return '${two(date.day)}.${two(date.month)}.${date.year} '
      '${two(date.hour)}:${two(date.minute)}';
}

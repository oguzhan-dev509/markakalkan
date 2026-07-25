import 'dart:math';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:markakalkan/core/theme/markakalkan_theme.dart';

abstract interface class CaseLegalHoldRepository {
  Future<List<CaseLegalHoldCaseOption>> listCases();

  Future<CaseLegalHoldDetail> load(String caseId);

  Future<CaseLegalHoldMutation> start({
    required String caseId,
    required String reason,
    required String? authorityReference,
    required String requestId,
  });

  Future<CaseLegalHoldMutation> release({
    required String holdId,
    required String reason,
    required String requestId,
  });
}

class CallableCaseLegalHoldRepository implements CaseLegalHoldRepository {
  CallableCaseLegalHoldRepository({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'europe-west3');

  final FirebaseFunctions _functions;

  @override
  Future<List<CaseLegalHoldCaseOption>> listCases() async {
    final result = await _functions
        .httpsCallable('listCaseEvidenceCenter')
        .call({'pageSize': 25});
    final map = _legalMap(_normalizeLegal(result.data));
    if (map['contractVersion'] != 'case-evidence-center-read-v1' ||
        map['readOnly'] != true ||
        map['writesPerformed'] != 0) {
      throw const FormatException('Geçersiz vaka listesi yanıtı.');
    }
    return _legalList(map['cases'])
        .map((item) => CaseLegalHoldCaseOption.fromMap(_legalMap(item)))
        .toList(growable: false);
  }

  @override
  Future<CaseLegalHoldDetail> load(String caseId) async {
    final result = await _functions
        .httpsCallable('getCaseLegalHoldDetail')
        .call({
          'contractVersion': 'case-legal-hold-detail-request-v1',
          'caseId': caseId,
        });
    return CaseLegalHoldDetail.fromMap(_legalMap(_normalizeLegal(result.data)));
  }

  @override
  Future<CaseLegalHoldMutation> start({
    required String caseId,
    required String reason,
    required String? authorityReference,
    required String requestId,
  }) async {
    final request = <String, dynamic>{
      'contractVersion': 'case-legal-hold-start-request-v1',
      'caseId': caseId,
      'reason': reason,
      'requestId': requestId,
    };
    if (authorityReference != null && authorityReference.isNotEmpty) {
      request['authorityReference'] = authorityReference;
    }
    final result = await _functions
        .httpsCallable('startCaseLegalHold')
        .call(request);
    return CaseLegalHoldMutation.fromMap(
      _legalMap(_normalizeLegal(result.data)),
      expectedContract: 'case-legal-hold-start-result-v1',
    );
  }

  @override
  Future<CaseLegalHoldMutation> release({
    required String holdId,
    required String reason,
    required String requestId,
  }) async {
    final result = await _functions.httpsCallable('releaseCaseLegalHold').call({
      'contractVersion': 'case-legal-hold-release-request-v1',
      'holdId': holdId,
      'reason': reason,
      'requestId': requestId,
    });
    return CaseLegalHoldMutation.fromMap(
      _legalMap(_normalizeLegal(result.data)),
      expectedContract: 'case-legal-hold-release-result-v1',
    );
  }
}

class CaseLegalHoldCaseOption {
  const CaseLegalHoldCaseOption({
    required this.caseId,
    required this.caseNumber,
    required this.title,
    required this.status,
  });

  final String caseId;
  final String caseNumber;
  final String title;
  final String status;

  factory CaseLegalHoldCaseOption.fromMap(Map<String, dynamic> map) =>
      CaseLegalHoldCaseOption(
        caseId: _legalString(map, 'caseId'),
        caseNumber: _legalString(map, 'caseNumber'),
        title: _legalString(map, 'title'),
        status: _legalString(map, 'status'),
      );
}

class CaseLegalHoldProjection {
  const CaseLegalHoldProjection({
    required this.active,
    required this.activeCount,
    required this.latestHoldId,
    required this.startedAt,
    required this.releasedAt,
    required this.lastChangedAt,
  });

  final bool active;
  final int activeCount;
  final String? latestHoldId;
  final String? startedAt;
  final String? releasedAt;
  final String? lastChangedAt;

  factory CaseLegalHoldProjection.fromMap(Map<String, dynamic> map) =>
      CaseLegalHoldProjection(
        active: map['active'] == true,
        activeCount: _legalInteger(map, 'activeCount'),
        latestHoldId: _legalNullableString(map['latestHoldId']),
        startedAt: _legalNullableString(map['startedAt']),
        releasedAt: _legalNullableString(map['releasedAt']),
        lastChangedAt: _legalNullableString(map['lastChangedAt']),
      );
}

class CaseLegalHoldStats {
  const CaseLegalHoldStats({
    required this.totalHolds,
    required this.activeHolds,
    required this.releasedHolds,
  });

  final int totalHolds;
  final int activeHolds;
  final int releasedHolds;

  factory CaseLegalHoldStats.fromMap(Map<String, dynamic> map) =>
      CaseLegalHoldStats(
        totalHolds: _legalInteger(map, 'totalHolds'),
        activeHolds: _legalInteger(map, 'activeHolds'),
        releasedHolds: _legalInteger(map, 'releasedHolds'),
      );
}

class CaseLegalHoldRecord {
  const CaseLegalHoldRecord({
    required this.holdId,
    required this.holdNumber,
    required this.caseId,
    required this.scope,
    required this.status,
    required this.reason,
    required this.authorityReference,
    required this.startedAt,
    required this.releasedAt,
    required this.releaseReason,
    required this.eventCount,
  });

  final String holdId;
  final String holdNumber;
  final String caseId;
  final String scope;
  final String status;
  final String reason;
  final String? authorityReference;
  final String startedAt;
  final String? releasedAt;
  final String? releaseReason;
  final int eventCount;

  bool get isActive => status == 'active';

  factory CaseLegalHoldRecord.fromMap(Map<String, dynamic> map) =>
      CaseLegalHoldRecord(
        holdId: _legalString(map, 'holdId'),
        holdNumber: _legalString(map, 'holdNumber'),
        caseId: _legalString(map, 'caseId'),
        scope: _legalString(map, 'scope'),
        status: _legalString(map, 'status'),
        reason: _legalString(map, 'reason'),
        authorityReference: _legalNullableString(map['authorityReference']),
        startedAt: _legalString(map, 'startedAt'),
        releasedAt: _legalNullableString(map['releasedAt']),
        releaseReason: _legalNullableString(map['releaseReason']),
        eventCount: _legalInteger(map, 'eventCount'),
      );
}

class CaseLegalHoldEvent {
  const CaseLegalHoldEvent({
    required this.holdId,
    required this.sequence,
    required this.eventType,
    required this.note,
    required this.actorLabel,
    required this.recordedAt,
  });

  final String holdId;
  final int sequence;
  final String eventType;
  final String note;
  final String actorLabel;
  final String recordedAt;

  factory CaseLegalHoldEvent.fromMap(Map<String, dynamic> map) =>
      CaseLegalHoldEvent(
        holdId: _legalString(map, 'holdId'),
        sequence: _legalInteger(map, 'sequence'),
        eventType: _legalString(map, 'eventType'),
        note: _legalString(map, 'note'),
        actorLabel: _legalString(map, 'actorLabel'),
        recordedAt: _legalString(map, 'recordedAt'),
      );
}

class CaseLegalHoldDetail {
  const CaseLegalHoldDetail({
    required this.caseId,
    required this.caseNumber,
    required this.title,
    required this.caseStatus,
    required this.projection,
    required this.stats,
    required this.holds,
    required this.events,
    required this.integrityStatus,
  });

  final String caseId;
  final String caseNumber;
  final String title;
  final String caseStatus;
  final CaseLegalHoldProjection projection;
  final CaseLegalHoldStats stats;
  final List<CaseLegalHoldRecord> holds;
  final List<CaseLegalHoldEvent> events;
  final String integrityStatus;

  factory CaseLegalHoldDetail.fromMap(Map<String, dynamic> map) {
    if (map['contractVersion'] != 'case-legal-hold-detail-v1' ||
        map['readOnly'] != true ||
        map['writesPerformed'] != 0) {
      throw const FormatException('Geçersiz hukuki muhafaza yanıtı.');
    }
    final caseMap = _legalMap(map['case']);
    return CaseLegalHoldDetail(
      caseId: _legalString(caseMap, 'caseId'),
      caseNumber: _legalString(caseMap, 'caseNumber'),
      title: _legalString(caseMap, 'title'),
      caseStatus: _legalString(caseMap, 'status'),
      projection: CaseLegalHoldProjection.fromMap(_legalMap(map['legalHold'])),
      stats: CaseLegalHoldStats.fromMap(_legalMap(map['stats'])),
      holds: _legalList(map['holds'])
          .map((item) => CaseLegalHoldRecord.fromMap(_legalMap(item)))
          .toList(growable: false),
      events: _legalList(map['events'])
          .map((item) => CaseLegalHoldEvent.fromMap(_legalMap(item)))
          .toList(growable: false),
      integrityStatus: _legalString(map, 'integrityStatus'),
    );
  }
}

class CaseLegalHoldMutation {
  const CaseLegalHoldMutation({
    required this.holdId,
    required this.holdNumber,
    required this.status,
    required this.activeCount,
    required this.duplicate,
    required this.transactionCommitted,
  });

  final String holdId;
  final String holdNumber;
  final String status;
  final int activeCount;
  final bool duplicate;
  final bool transactionCommitted;

  factory CaseLegalHoldMutation.fromMap(
    Map<String, dynamic> map, {
    required String expectedContract,
  }) {
    if (map['contractVersion'] != expectedContract || map['ok'] != true) {
      throw const FormatException('Geçersiz hukuki muhafaza işlem yanıtı.');
    }
    return CaseLegalHoldMutation(
      holdId: _legalString(map, 'holdId'),
      holdNumber: _legalString(map, 'holdNumber'),
      status: _legalString(map, 'status'),
      activeCount: _legalInteger(map, 'activeCount'),
      duplicate: map['duplicate'] == true,
      transactionCommitted: map['transactionCommitted'] == true,
    );
  }
}

class CaseLegalHoldPage extends StatefulWidget {
  const CaseLegalHoldPage({super.key, this.initialCaseId, this.repository});

  final String? initialCaseId;
  final CaseLegalHoldRepository? repository;

  @override
  State<CaseLegalHoldPage> createState() => _CaseLegalHoldPageState();
}

class _CaseLegalHoldPageState extends State<CaseLegalHoldPage> {
  late final CaseLegalHoldRepository _repository =
      widget.repository ?? CallableCaseLegalHoldRepository();

  List<CaseLegalHoldCaseOption> _cases = const [];
  String? _selectedCaseId;
  CaseLegalHoldDetail? _detail;
  bool _loadingCases = true;
  bool _loadingDetail = false;
  bool _processing = false;
  String? _pageError;
  String? _detailError;

  @override
  void initState() {
    super.initState();
    _loadCases();
  }

  Future<void> _loadCases() async {
    setState(() {
      _loadingCases = true;
      _pageError = null;
    });
    try {
      final cases = await _repository.listCases();
      if (!mounted) return;
      final requested = widget.initialCaseId;
      final selected =
          requested != null &&
              requested.isNotEmpty &&
              cases.any((item) => item.caseId == requested)
          ? requested
          : cases.isEmpty
          ? null
          : cases.first.caseId;
      setState(() {
        _cases = cases;
        _selectedCaseId = selected;
        _loadingCases = false;
      });
      if (selected != null) await _loadDetail(selected);
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingCases = false;
        _pageError = error.code;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingCases = false;
        _pageError = 'generic';
      });
    }
  }

  Future<void> _loadDetail(String caseId) async {
    setState(() {
      _loadingDetail = true;
      _detail = null;
      _detailError = null;
    });
    try {
      final detail = await _repository.load(caseId);
      if (!mounted || _selectedCaseId != caseId) return;
      setState(() {
        _detail = detail;
        _loadingDetail = false;
      });
    } on FirebaseFunctionsException catch (error) {
      if (!mounted || _selectedCaseId != caseId) return;
      setState(() {
        _loadingDetail = false;
        _detailError = error.code;
      });
    } catch (_) {
      if (!mounted || _selectedCaseId != caseId) return;
      setState(() {
        _loadingDetail = false;
        _detailError = 'generic';
      });
    }
  }

  Future<void> _selectCase(String? caseId) async {
    if (caseId == null || caseId == _selectedCaseId) return;
    setState(() => _selectedCaseId = caseId);
    await _loadDetail(caseId);
  }

  Future<void> _startHold() async {
    final caseId = _selectedCaseId;
    if (caseId == null || _processing) return;
    final request = await _showStartDialog();
    if (request == null || !mounted) return;
    setState(() => _processing = true);
    try {
      final result = await _repository.start(
        caseId: caseId,
        reason: request.reason,
        authorityReference: request.authorityReference,
        requestId: _newRequestId(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.duplicate
                ? '${result.holdNumber} daha önce oluşturulmuş.'
                : '${result.holdNumber} hukuki muhafazası başlatıldı.',
          ),
        ),
      );
      await _loadDetail(caseId);
    } on FirebaseFunctionsException catch (error) {
      if (mounted) _showMutationError(error.code);
    } catch (_) {
      if (mounted) _showMutationError('generic');
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _releaseHold(CaseLegalHoldRecord hold) async {
    if (_processing) return;
    final reason = await _showReleaseDialog(hold);
    if (reason == null || !mounted) return;
    setState(() => _processing = true);
    try {
      final result = await _repository.release(
        holdId: hold.holdId,
        reason: reason,
        requestId: _newRequestId(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.duplicate
                ? '${result.holdNumber} daha önce kaldırılmış.'
                : '${result.holdNumber} hukuki muhafazası kaldırıldı.',
          ),
        ),
      );
      final caseId = _selectedCaseId;
      if (caseId != null) await _loadDetail(caseId);
    } on FirebaseFunctionsException catch (error) {
      if (mounted) _showMutationError(error.code);
    } catch (_) {
      if (mounted) _showMutationError('generic');
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<_StartHoldRequest?> _showStartDialog() {
    final formKey = GlobalKey<FormState>();
    var reason = '';
    var authorityReference = '';

    return showDialog<_StartHoldRequest>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hukuki muhafaza başlat'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Bu işlem vaka ve bağlı kayıtların saklama veya imha '
                    'değerlendirmesine karşı korunmasını sağlar.',
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const ValueKey('legal-hold-start-reason'),
                    minLines: 3,
                    maxLines: 5,
                    maxLength: 2000,
                    decoration: const InputDecoration(
                      labelText: 'Hukuki gerekçe',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) => reason = value,
                    validator: (value) => _validateReason(value, maximum: 2000),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    key: const ValueKey('legal-hold-authority-reference'),
                    maxLength: 500,
                    decoration: const InputDecoration(
                      labelText: 'Yetki veya dosya referansı (isteğe bağlı)',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) => authorityReference = value,
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            key: const ValueKey('confirm-start-legal-hold'),
            onPressed: () {
              if (formKey.currentState?.validate() != true) return;
              final normalizedAuthority = authorityReference.trim();
              Navigator.of(dialogContext).pop(
                _StartHoldRequest(
                  reason: reason.trim(),
                  authorityReference: normalizedAuthority.isEmpty
                      ? null
                      : normalizedAuthority,
                ),
              );
            },
            child: const Text('Muhafazayı başlat'),
          ),
        ],
      ),
    );
  }

  Future<String?> _showReleaseDialog(CaseLegalHoldRecord hold) {
    final formKey = GlobalKey<FormState>();
    var reason = '';

    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('${hold.holdNumber} muhafazasını kaldır'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: TextFormField(
                key: const ValueKey('legal-hold-release-reason'),
                minLines: 3,
                maxLines: 5,
                maxLength: 1000,
                decoration: const InputDecoration(
                  labelText: 'Kaldırma gerekçesi',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) => reason = value,
                validator: (value) => _validateReason(value, maximum: 1000),
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            key: const ValueKey('confirm-release-legal-hold'),
            onPressed: () {
              if (formKey.currentState?.validate() != true) return;
              Navigator.of(dialogContext).pop(reason.trim());
            },
            child: const Text('Muhafazayı kaldır'),
          ),
        ],
      ),
    );
  }

  void _showMutationError(String code) {
    final message = switch (code) {
      'failed-precondition' =>
        'İşlem için uygulama doğrulaması gerekir veya kayıt artık aktif değildir.',
      'permission-denied' =>
        'Hukuki muhafaza işlemleri için marka sahibi yetkisi gerekir.',
      'not-found' => 'Hukuki muhafaza kaydı artık bulunamıyor.',
      'resource-exhausted' => 'Hukuki muhafaza kapsamı güvenli sınırı aşıyor.',
      'unauthenticated' => 'Bu işlem için oturum açmanız gerekir.',
      _ => 'Hukuki muhafaza işlemi tamamlanamadı.',
    };
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: MarkaKalkanTheme.background,
    appBar: AppBar(title: const Text('Hukuki Muhafaza')),
    body: RefreshIndicator(
      onRefresh: _loadCases,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const _LegalHoldHero(),
          const SizedBox(height: 20),
          if (_loadingCases)
            const Center(
              key: ValueKey('legal-hold-loading'),
              child: Padding(
                padding: EdgeInsets.all(42),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_pageError != null)
            _LegalHoldErrorState(code: _pageError!, retry: _loadCases)
          else if (_cases.isEmpty)
            const _LegalHoldEmptyState()
          else ...[
            DropdownButtonFormField<String>(
              key: const ValueKey('legal-hold-case-selector'),
              initialValue: _selectedCaseId,
              decoration: const InputDecoration(
                labelText: 'Vaka dosyası',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.folder_outlined),
              ),
              items: _cases
                  .map(
                    (item) => DropdownMenuItem<String>(
                      value: item.caseId,
                      child: Text('${item.caseNumber} · ${item.title}'),
                    ),
                  )
                  .toList(growable: false),
              onChanged: _processing ? null : _selectCase,
            ),
            const SizedBox(height: 18),
            if (_loadingDetail)
              const Center(
                key: ValueKey('legal-hold-detail-loading'),
                child: Padding(
                  padding: EdgeInsets.all(36),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_detailError != null)
              _LegalHoldErrorState(
                code: _detailError!,
                retry: () {
                  final caseId = _selectedCaseId;
                  return caseId == null
                      ? Future<void>.value()
                      : _loadDetail(caseId);
                },
              )
            else if (_detail != null)
              ..._detailContent(_detail!),
          ],
        ],
      ),
    ),
  );

  List<Widget> _detailContent(CaseLegalHoldDetail detail) => [
    _CaseHeader(detail: detail),
    const SizedBox(height: 16),
    _LegalHoldSummary(detail: detail),
    if (detail.integrityStatus != 'verified') ...[
      const SizedBox(height: 14),
      const _IntegrityWarning(),
    ],
    const SizedBox(height: 18),
    Align(
      alignment: Alignment.centerRight,
      child: FilledButton.icon(
        key: const ValueKey('start-legal-hold'),
        onPressed: _processing ? null : _startHold,
        icon: _processing
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.lock_outline),
        label: const Text('Hukuki muhafaza başlat'),
      ),
    ),
    const SizedBox(height: 24),
    Text(
      'Muhafaza Kayıtları',
      style: Theme.of(
        context,
      ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
    ),
    const SizedBox(height: 10),
    if (detail.holds.isEmpty)
      const Card(
        child: Padding(
          padding: EdgeInsets.all(18),
          child: Text('Bu vaka için hukuki muhafaza kaydı bulunmuyor.'),
        ),
      )
    else
      ...detail.holds.map(
        (hold) => _HoldCard(
          hold: hold,
          processing: _processing,
          onRelease: () => _releaseHold(hold),
        ),
      ),
    const SizedBox(height: 24),
    Text(
      'Hukuki Muhafaza Olayları',
      style: Theme.of(
        context,
      ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
    ),
    const SizedBox(height: 10),
    if (detail.events.isEmpty)
      const Card(
        child: Padding(
          padding: EdgeInsets.all(18),
          child: Text('Henüz hukuki muhafaza olayı bulunmuyor.'),
        ),
      )
    else
      Card(
        child: Column(
          children: detail.events
              .map(
                (event) => ListTile(
                  leading: Icon(
                    event.eventType == 'legal_hold_started'
                        ? Icons.lock_outline
                        : Icons.lock_open_outlined,
                  ),
                  title: Text(_legalEventLabel(event.eventType)),
                  subtitle: Text(
                    '${event.note}\n${event.actorLabel} · ${_legalDate(event.recordedAt)}',
                  ),
                  isThreeLine: true,
                ),
              )
              .toList(growable: false),
        ),
      ),
  ];
}

class _StartHoldRequest {
  const _StartHoldRequest({
    required this.reason,
    required this.authorityReference,
  });

  final String reason;
  final String? authorityReference;
}

class _LegalHoldHero extends StatelessWidget {
  const _LegalHoldHero();

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('legal-hold-hero'),
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF271A3A), Color(0xFF56336D)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(22),
    ),
    child: const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 26,
          backgroundColor: Color(0xFF75558A),
          child: Icon(Icons.gavel_outlined, color: Colors.white),
        ),
        SizedBox(width: 18),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Vaka ve bağlı kayıtları hukuki süreç boyunca koruyun.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Aktif hukuki muhafaza, vaka ve bağlı deliller için saklama '
                've imha değerlendirmelerini bloke eder. Her başlatma ve '
                'kaldırma işlemi değiştirilemez olay kaydıyla izlenir.',
                style: TextStyle(color: Color(0xFFE9DFF0), height: 1.45),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _CaseHeader extends StatelessWidget {
  const _CaseHeader({required this.detail});

  final CaseLegalHoldDetail detail;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.folder_special_outlined, color: Color(0xFF56336D)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  detail.caseNumber,
                  style: const TextStyle(
                    color: Color(0xFF56336D),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  detail.title,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 7),
                Text('Vaka durumu: ${_legalCaseStatus(detail.caseStatus)}'),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _LegalHoldSummary extends StatelessWidget {
  const _LegalHoldSummary({required this.detail});

  final CaseLegalHoldDetail detail;

  @override
  Widget build(BuildContext context) {
    final values = [
      (
        'Koruma durumu',
        detail.projection.active ? 'Aktif' : 'Aktif değil',
        detail.projection.active ? Icons.lock : Icons.lock_open_outlined,
      ),
      ('Aktif muhafaza', '${detail.stats.activeHolds}', Icons.shield_outlined),
      (
        'Toplam kayıt',
        '${detail.stats.totalHolds}',
        Icons.receipt_long_outlined,
      ),
      ('Kaldırılan', '${detail.stats.releasedHolds}', Icons.task_alt_outlined),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 720 ? 2 : 4;
        const spacing = 12.0;
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
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE4DDEA)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(value.$3, color: const Color(0xFF56336D)),
                        const SizedBox(height: 9),
                        Text(
                          value.$2,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          value.$1,
                          style: const TextStyle(color: Color(0xFF6E6474)),
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

class _HoldCard extends StatelessWidget {
  const _HoldCard({
    required this.hold,
    required this.processing,
    required this.onRelease,
  });

  final CaseLegalHoldRecord hold;
  final bool processing;
  final VoidCallback onRelease;

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
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                hold.holdNumber,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Chip(
                avatar: Icon(
                  hold.isActive ? Icons.lock : Icons.lock_open_outlined,
                  size: 18,
                ),
                label: Text(hold.isActive ? 'Aktif' : 'Kaldırıldı'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(hold.reason),
          if (hold.authorityReference != null) ...[
            const SizedBox(height: 8),
            Text('Yetki referansı: ${hold.authorityReference}'),
          ],
          const SizedBox(height: 8),
          Text('Başlangıç: ${_legalDate(hold.startedAt)}'),
          if (hold.releasedAt != null)
            Text('Kaldırılma: ${_legalDate(hold.releasedAt!)}'),
          if (hold.releaseReason != null) ...[
            const SizedBox(height: 8),
            Text('Kaldırma gerekçesi: ${hold.releaseReason}'),
          ],
          if (hold.isActive) ...[
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                key: ValueKey('release-legal-hold-${hold.holdId}'),
                onPressed: processing ? null : onRelease,
                icon: const Icon(Icons.lock_open_outlined),
                label: const Text('Muhafazayı kaldır'),
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

class _IntegrityWarning extends StatelessWidget {
  const _IntegrityWarning();

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('legal-hold-integrity-warning'),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF4E5),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFFFFC46B)),
    ),
    child: const Row(
      children: [
        Icon(Icons.warning_amber_rounded, color: Color(0xFF9B5A00)),
        SizedBox(width: 12),
        Expanded(
          child: Text(
            'Hukuki muhafaza özeti ile kayıtlar arasında tutarsızlık '
            'algılandı. Yeni işlem yapmadan önce teknik inceleme gerekir.',
          ),
        ),
      ],
    ),
  );
}

class _LegalHoldErrorState extends StatelessWidget {
  const _LegalHoldErrorState({required this.code, required this.retry});

  final String code;
  final Future<void> Function() retry;

  @override
  Widget build(BuildContext context) {
    final message = switch (code) {
      'not-found' => 'Vaka veya hukuki muhafaza kaydı bulunamadı.',
      'permission-denied' =>
        'Bu hukuki muhafaza görünümüne erişim yetkiniz bulunmuyor.',
      'unauthenticated' => 'Bu görünüm için oturum açmanız gerekir.',
      'resource-exhausted' => 'Hukuki muhafaza kapsamı güvenli sınırı aşıyor.',
      _ => 'Hukuki muhafaza görünümü yüklenemedi.',
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          children: [
            const Icon(Icons.error_outline, size: 36),
            const SizedBox(height: 10),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            TextButton(onPressed: retry, child: const Text('Yeniden dene')),
          ],
        ),
      ),
    );
  }
}

class _LegalHoldEmptyState extends StatelessWidget {
  const _LegalHoldEmptyState();

  @override
  Widget build(BuildContext context) => const Card(
    child: Padding(
      padding: EdgeInsets.all(22),
      child: Column(
        children: [
          Icon(Icons.folder_off_outlined, size: 36),
          SizedBox(height: 10),
          Text('Hukuki muhafaza uygulanabilecek vaka dosyası bulunmuyor.'),
        ],
      ),
    ),
  );
}

String? _validateReason(String? value, {required int maximum}) {
  final clean = value?.trim() ?? '';
  if (clean.length < 10 || clean.length > maximum) {
    return 'Gerekçe en az 10 karakter olmalıdır.';
  }
  return null;
}

String _newRequestId() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0F) | 0x40;
  bytes[8] = (bytes[8] & 0x3F) | 0x80;
  String hex(int value) => value.toRadixString(16).padLeft(2, '0');
  final value = bytes.map(hex).join();
  return '${value.substring(0, 8)}-'
      '${value.substring(8, 12)}-'
      '${value.substring(12, 16)}-'
      '${value.substring(16, 20)}-'
      '${value.substring(20)}';
}

String _legalCaseStatus(String value) => switch (value) {
  'open' => 'Açık',
  'in_review' => 'İncelemede',
  'closed' => 'Kapalı',
  'archived' => 'Arşivlendi',
  _ => 'İlk inceleme',
};

String _legalEventLabel(String value) => switch (value) {
  'legal_hold_started' => 'Hukuki muhafaza başlatıldı',
  'legal_hold_released' => 'Hukuki muhafaza kaldırıldı',
  _ => 'Hukuki muhafaza olayı',
};

String _legalDate(String value) {
  final parsed = DateTime.tryParse(value)?.toLocal();
  if (parsed == null) return 'Tarih bilgisi yok';
  String two(int item) => item.toString().padLeft(2, '0');
  return '${two(parsed.day)}.${two(parsed.month)}.${parsed.year} '
      '${two(parsed.hour)}:${two(parsed.minute)}';
}

dynamic _normalizeLegal(dynamic value) {
  if (value is Map) return Map<String, dynamic>.from(value);
  return value;
}

Map<String, dynamic> _legalMap(dynamic value) {
  if (value is! Map) {
    throw const FormatException('Geçersiz hukuki muhafaza veri yapısı.');
  }
  return Map<String, dynamic>.from(value);
}

List<dynamic> _legalList(dynamic value) {
  if (value is! List) {
    throw const FormatException('Geçersiz hukuki muhafaza liste yapısı.');
  }
  return value;
}

String _legalString(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value is! String || value.isEmpty) {
    throw FormatException('Geçersiz hukuki muhafaza alanı: $key');
  }
  return value;
}

String? _legalNullableString(dynamic value) {
  if (value == null) return null;
  if (value is! String) {
    throw const FormatException('Geçersiz hukuki muhafaza metin alanı.');
  }
  return value.isEmpty ? null : value;
}

int _legalInteger(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value is int) return value;
  if (value is num) return value.toInt();
  throw FormatException('Geçersiz hukuki muhafaza sayı alanı: $key');
}

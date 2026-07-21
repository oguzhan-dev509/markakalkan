import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:markakalkan/core/security/app_check_bootstrap.dart';
import 'package:markakalkan/core/theme/markakalkan_theme.dart';

import '../data/risk_operations_models.dart';
import '../data/risk_operations_lifecycle.dart';
import '../data/risk_operations_repository.dart';
import '../data/shared_risk_promotion_service.dart';
import 'risk_operations_labels.dart';

class RiskOperationsConsolePage extends StatefulWidget {
  const RiskOperationsConsolePage({
    super.key,
    required this.navigationRequestId,
    required this.routeEntryCause,
    this.repository,
    this.lifecycleProvider,
    this.onStateCreated,
    this.promotionService,
    this.enablePromotion = const bool.fromEnvironment(
      'MARKAKALKAN_ENABLE_SHARED_RISK_PROMOTION',
      defaultValue: false,
    ),
    this.promotionAuthReady,
    this.promotionAppCheckReady,
  });
  final String navigationRequestId;
  final RiskOperationsRouteEntryCause routeEntryCause;
  final RiskOperationsRepository? repository;
  final RiskOperationsLifecycleProvider? lifecycleProvider;
  final VoidCallback? onStateCreated;
  final SharedRiskPromotionService? promotionService;
  final bool enablePromotion;
  final bool? promotionAuthReady;
  final bool? promotionAppCheckReady;
  @override
  State<RiskOperationsConsolePage> createState() =>
      _RiskOperationsConsolePageState();
}

class _RiskOperationsConsolePageState extends State<RiskOperationsConsolePage> {
  late final RiskOperationsRepository _repository;
  late final RiskOperationsLifecycleProvider _lifecycle;
  late final String _routeEntryId;
  late final String _pageInstanceId;
  int _attemptSequence = 0;
  RiskOperationsLoadState _state = RiskOperationsLoadState.loading;
  RiskOperationsPageResult? _result;
  String? _source;
  String? _riskClass;
  String? _severity;
  String? _evidence;
  String? _candidacy;
  DateTime? _occurredFrom;
  DateTime? _occurredTo;
  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? CallableRiskOperationsRepository();
    _lifecycle =
        widget.lifecycleProvider ?? RiskOperationsLifecycleProvider.instance;
    _routeEntryId = _lifecycle.createRouteEntryId();
    _pageInstanceId = _lifecycle.createPageInstanceId();
    widget.onStateCreated?.call();
    _load(trigger: RiskOperationsLoadTrigger.initialMount);
  }

  Future<void> _load({
    required RiskOperationsLoadTrigger trigger,
    String? pageToken,
  }) async {
    _attemptSequence += 1;
    final diagnostics = RiskOperationsReadDiagnostics(
      browserTabSessionId: _lifecycle.browserTabSessionId,
      appBootId: _lifecycle.appBootId,
      authEpoch: _lifecycle.authEpoch,
      navigationRequestId: widget.navigationRequestId,
      routeEntryId: _routeEntryId,
      navigationType: _lifecycle.browserContext.navigationType,
      routeEntryCause: widget.routeEntryCause,
      pageshowPersisted: _lifecycle.browserContext.pageshowPersisted,
      initialVisibilityState: _lifecycle.browserContext.initialVisibilityState,
      documentReferrerPresent:
          _lifecycle.browserContext.documentReferrerPresent,
      serviceWorkerControlled:
          _lifecycle.browserContext.serviceWorkerControlled,
      lifecycleQuality: _lifecycle.lifecycleQuality,
      pageInstanceId: _pageInstanceId,
      loadAttemptId: _lifecycle.createLoadAttemptId(),
      trigger: trigger,
      attemptSequence: _attemptSequence,
    );
    setState(() => _state = RiskOperationsLoadState.loading);
    try {
      final result = await _repository.list(
        RiskOperationsQuery(
          pageToken: pageToken,
          sourceSystem: _source,
          riskClass: _riskClass,
          severity: _severity,
          evidenceQuality: _evidence,
          caseCandidacy: _candidacy,
          occurredFrom: _occurredFrom,
          occurredTo: _occurredTo,
        ),
        diagnostics,
      );
      if (!mounted) return;
      setState(() {
        _result = result;
        _state = result.items.isEmpty
            ? RiskOperationsLoadState.empty
            : RiskOperationsLoadState.ready;
      });
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) return;
      setState(() {
        _state =
            error.code == 'permission-denied' || error.code == 'unauthenticated'
            ? RiskOperationsLoadState.permissionDenied
            : error.code == 'failed-precondition'
            ? RiskOperationsLoadState.noActiveTenant
            : RiskOperationsLoadState.error;
      });
    } catch (_) {
      if (mounted) setState(() => _state = RiskOperationsLoadState.error);
    }
  }

  Future<void> _pickDate({required bool from}) async {
    final selected = await showDatePicker(
      context: context,
      initialDate: (from ? _occurredFrom : _occurredTo) ?? DateTime.now(),
      firstDate: DateTime.utc(2000),
      lastDate: DateTime.now(),
    );
    if (selected == null) return;
    setState(() {
      if (from) {
        _occurredFrom = DateTime.utc(
          selected.year,
          selected.month,
          selected.day,
        );
      } else {
        _occurredTo = DateTime.utc(
          selected.year,
          selected.month,
          selected.day,
          23,
          59,
          59,
          999,
        );
      }
    });
    await _load(trigger: RiskOperationsLoadTrigger.dateChange);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: MarkaKalkanTheme.background,
    appBar: AppBar(title: const Text('Risk ve Şüpheli Taramalar')),
    body: RefreshIndicator(
      onRefresh: () => _load(trigger: RiskOperationsLoadTrigger.pullToRefresh),
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            'Salt-okunur operasyon konsolu',
            style: TextStyle(fontSize: 14, color: Color(0xFF687580)),
          ),
          const SizedBox(height: 16),
          _buildBody(),
        ],
      ),
    ),
  );
  Widget _buildBody() {
    if (_state == RiskOperationsLoadState.loading) {
      return const Center(
        key: ValueKey('risk-operations-loading'),
        child: CircularProgressIndicator(),
      );
    }
    if (_state == RiskOperationsLoadState.permissionDenied) {
      return const _StateCard(
        key: ValueKey('risk-operations-permission-denied'),
        title: 'Bu alana erişim yetkiniz yok.',
        icon: Icons.lock_outline,
      );
    }
    if (_state == RiskOperationsLoadState.noActiveTenant) {
      return const _StateCard(
        key: ValueKey('risk-operations-no-tenant'),
        title: 'Aktif tenant üyeliği bulunamadı.',
        icon: Icons.domain_disabled_outlined,
      );
    }
    if (_state == RiskOperationsLoadState.error) {
      return _StateCard(
        key: const ValueKey('risk-operations-error'),
        title: 'Risk görünümü yüklenemedi.',
        icon: Icons.error_outline,
        action: () => _load(trigger: RiskOperationsLoadTrigger.errorRetry),
      );
    }
    final result = _result!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SummaryGrid(summary: result.summary),
        const SizedBox(height: 18),
        if (result.partialSourceUnavailable)
          const _StateCard(
            key: ValueKey('risk-operations-partial-source'),
            title: 'Bazı kaynaklar geçici olarak kullanılamıyor.',
            icon: Icons.cloud_off_outlined,
          ),
        _Filters(
          source: _source,
          riskClass: _riskClass,
          severity: _severity,
          evidence: _evidence,
          candidacy: _candidacy,
          occurredFrom: _occurredFrom,
          occurredTo: _occurredTo,
          onPickFrom: () => _pickDate(from: true),
          onPickTo: () => _pickDate(from: false),
          onChanged: (source, riskClass, severity, evidence, candidacy) {
            if (source == _source &&
                riskClass == _riskClass &&
                severity == _severity &&
                evidence == _evidence &&
                candidacy == _candidacy) {
              return;
            }
            setState(() {
              _source = source;
              _riskClass = riskClass;
              _severity = severity;
              _evidence = evidence;
              _candidacy = candidacy;
            });
            _load(trigger: RiskOperationsLoadTrigger.filterChange);
          },
        ),
        const SizedBox(height: 18),
        if (_state == RiskOperationsLoadState.empty)
          const _StateCard(
            key: ValueKey('risk-operations-empty'),
            title: 'Bu filtrelerle görünür sinyal bulunmuyor.',
            icon: Icons.inbox_outlined,
          )
        else
          ...result.items.map(
            (item) => _RiskItemCard(
              item: item,
              enabled: widget.enablePromotion,
              service: widget.promotionService,
              authReady: widget.promotionAuthReady ?? _authReady,
              appCheckReady:
                  widget.promotionAppCheckReady ??
                  AppCheckBootstrap.instance.isReady,
            ),
          ),
        if (result.nextPageToken != null) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              key: const ValueKey('risk-operations-next-page'),
              onPressed: () => _load(
                trigger: RiskOperationsLoadTrigger.pagination,
                pageToken: result.nextPageToken,
              ),
              icon: const Icon(Icons.navigate_next),
              label: const Text('Sonraki sayfa'),
            ),
          ),
        ],
      ],
    );
  }

  bool get _authReady {
    try {
      return FirebaseAuth.instance.currentUser != null;
    } catch (_) {
      return false;
    }
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.summary});

  final RiskOperationsSummary summary;

  @override
  Widget build(BuildContext context) {
    final values = [
      ('Toplam görünür sinyal', summary.totalVisibleSignals),
      ('Yüksek / kritik risk', summary.highOrCriticalRisk),
      ('İnsan incelemesi bekleyen', summary.awaitingHumanReview),
      ('Güçlü vaka adayı', summary.strongCaseCandidates),
      ('Yetersiz delil', summary.insufficientEvidence),
    ];
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: values
          .map(
            (entry) => SizedBox(
              width: 210,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(entry.$1),
                      const SizedBox(height: 8),
                      Text(
                        '${entry.$2}',
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _Filters extends StatelessWidget {
  const _Filters({
    required this.source,
    required this.riskClass,
    required this.severity,
    required this.evidence,
    required this.candidacy,
    required this.occurredFrom,
    required this.occurredTo,
    required this.onPickFrom,
    required this.onPickTo,
    required this.onChanged,
  });
  final String? source, riskClass, severity, evidence, candidacy;
  final DateTime? occurredFrom, occurredTo;
  final VoidCallback onPickFrom, onPickTo;
  final void Function(String?, String?, String?, String?, String?) onChanged;
  @override
  Widget build(BuildContext context) => Card(
    key: const ValueKey('risk-operations-filters'),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          _drop(
            'Kaynak',
            source,
            RiskOperationsLabels.sourceSystems,
            RiskOperationsLabels.sourceSystem,
            (v) => onChanged(v, riskClass, severity, evidence, candidacy),
          ),
          _drop(
            'Risk sınıfı',
            riskClass,
            RiskOperationsLabels.riskClasses,
            RiskOperationsLabels.riskClass,
            (v) => onChanged(source, v, severity, evidence, candidacy),
          ),
          _drop(
            'Önem',
            severity,
            RiskOperationsLabels.severities,
            RiskOperationsLabels.severity,
            (v) => onChanged(source, riskClass, v, evidence, candidacy),
          ),
          _drop(
            'Delil kalitesi',
            evidence,
            RiskOperationsLabels.evidenceQualities,
            RiskOperationsLabels.evidenceQuality,
            (v) => onChanged(source, riskClass, severity, v, candidacy),
          ),
          _drop(
            'Vaka adaylığı',
            candidacy,
            RiskOperationsLabels.caseCandidacies,
            RiskOperationsLabels.caseCandidacy,
            (v) => onChanged(source, riskClass, severity, evidence, v),
          ),
          OutlinedButton.icon(
            key: const ValueKey('risk-operations-date-from'),
            onPressed: onPickFrom,
            icon: const Icon(Icons.calendar_today_outlined),
            label: Text(_dateLabel('Başlangıç', occurredFrom)),
          ),
          OutlinedButton.icon(
            key: const ValueKey('risk-operations-date-to'),
            onPressed: onPickTo,
            icon: const Icon(Icons.event_outlined),
            label: Text(_dateLabel('Bitiş', occurredTo)),
          ),
        ],
      ),
    ),
  );
  Widget _drop(
    String label,
    String? value,
    List<String> options,
    String Function(String) labelFor,
    ValueChanged<String?> onChanged,
  ) => SizedBox(
    width: 220,
    child: DropdownButtonFormField<String>(
      isExpanded: true,
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      items: [
        const DropdownMenuItem<String>(value: null, child: Text('Tümü')),
        ...options.map(
          (item) => DropdownMenuItem(
            value: item,
            child: Text(labelFor(item), overflow: TextOverflow.ellipsis),
          ),
        ),
      ],
      selectedItemBuilder: (context) => [
        const Text('Tümü'),
        ...options.map(
          (item) => Text(labelFor(item), overflow: TextOverflow.ellipsis),
        ),
      ],
      onChanged: onChanged,
    ),
  );
  String _dateLabel(String label, DateTime? date) => date == null
      ? label
      : '$label: ${date.year.toString().padLeft(4, '0')}-'
            '${date.month.toString().padLeft(2, '0')}-'
            '${date.day.toString().padLeft(2, '0')}';
}

class _RiskItemCard extends StatefulWidget {
  const _RiskItemCard({
    required this.item,
    required this.enabled,
    required this.authReady,
    required this.appCheckReady,
    this.service,
  });
  final RiskOperationItem item;
  final bool enabled;
  final SharedRiskPromotionService? service;
  final bool authReady;
  final bool appCheckReady;
  @override
  State<_RiskItemCard> createState() => _RiskItemCardState();
}

class _RiskItemCardState extends State<_RiskItemCard> {
  bool _busy = false;
  bool _submitted = false;
  String? _message;
  RiskOperationItem get item => widget.item;

  Future<void> _promote() async {
    if (_busy || _submitted) return;
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ortak risk kaydı oluştur'),
        content: const Text(
          'Ortak risk kaydı oluşturulacaktır. Bu işlem gerçek vaka dosyası açmaz, hukuki hüküm oluşturmaz ve insan incelemesi zorunluluğu devam eder.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Onayla ve oluştur'),
          ),
        ],
      ),
    );
    if (approved != true || !mounted) return;
    setState(() {
      _busy = true;
      _submitted = true;
    });
    final result =
        await (widget.service ?? CallableSharedRiskPromotionService()).promote(
          item,
        );
    if (mounted) {
      setState(() {
        _busy = false;
        _message = result.turkishMessage;
      });
    }
  }

  @override
  Widget build(BuildContext context) => Card(
    key: ValueKey('risk-operation-${item.signalId}'),
    margin: const EdgeInsets.only(bottom: 14),
    child: ExpansionTile(
      title: Text(item.title),
      subtitle: Text(
        '${RiskOperationsLabels.sourceSystem(item.sourceSystem)} · '
        '${RiskOperationsLabels.riskClass(item.riskClass)} · '
        '${RiskOperationsLabels.severity(item.severity)}',
      ),
      childrenPadding: const EdgeInsets.all(18),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(RiskOperationsLabels.summary(item.summary)),
        ),
        const SizedBox(height: 12),
        _line(
          'Delil kalitesi',
          RiskOperationsLabels.evidenceQuality(item.evidenceQuality.level),
        ),
        _line(
          'Vaka adaylığı',
          RiskOperationsLabels.caseCandidacy(item.caseCandidacy.status),
        ),
        if (item.evidenceQuality.reasonCodes.isNotEmpty ||
            item.caseCandidacy.reasonCodes.isNotEmpty) ...[
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'İnceleme gerekçeleri',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          ...{
            ...item.evidenceQuality.reasonCodes,
            ...item.caseCandidacy.reasonCodes,
          }.map(
            (reason) => Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('• ${RiskOperationsLabels.reasonCode(reason)}'),
              ),
            ),
          ),
        ],
        _line('Durum', RiskOperationsLabels.status(item.currentStatus)),
        _line('Olay zamanı', RiskOperationsLabels.dateTime(item.occurredAt)),
        const Divider(),
        const Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Zaman çizelgesi',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        ...item.timeline.map(
          (event) => ListTile(
            dense: true,
            title: Text(
              '${RiskOperationsLabels.timelineEvent(event.eventType)} · '
              '${RiskOperationsLabels.sourceSystem(event.sourceSystem)}',
            ),
            subtitle: Text(
              '${RiskOperationsLabels.summary(event.summary)}\n'
              '${RiskOperationsLabels.dateTime(event.occurredAt)}',
            ),
          ),
        ),
        const Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'İlişkiler',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        ...item.relationshipNodes.map(
          (node) => ListTile(
            dense: true,
            title: Text(node.maskedLabel),
            subtitle: Text(
              '${RiskOperationsLabels.relationshipNode(node.type)} · '
              '${RiskOperationsLabels.sourceSystem(node.sourceSystem)} · '
              '${RiskOperationsLabels.evidenceQuality(node.evidenceQuality)}',
            ),
          ),
        ),
        const SizedBox(height: 8),
        if (widget.enabled &&
            widget.authReady &&
            widget.appCheckReady &&
            item.caseCandidacy.requiresHumanReview &&
            item.sourceRecordVersion.isNotEmpty &&
            item.projectionFingerprint.isNotEmpty) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              key: ValueKey('shared-risk-promote-${item.signalId}'),
              onPressed: _busy || _submitted ? null : _promote,
              icon: const Icon(Icons.playlist_add_check_circle_outlined),
              label: Text(
                _busy ? 'İşlem doğrulanıyor…' : 'Ortak risk kaydı oluştur',
              ),
            ),
          ),
          if (_message != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(_message!),
              ),
            ),
        ],
        const Text(
          'Bu değerlendirme hukuki geçerlilik veya suçluluk kararı değildir; insan incelemesi zorunludur.',
          style: TextStyle(color: Color(0xFF687580)),
        ),
      ],
    ),
  );
  Widget _line(String label, String value) => Align(
    alignment: Alignment.centerLeft,
    child: Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text('$label: $value'),
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
  final VoidCallback? action;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        children: [
          Icon(icon, size: 42),
          const SizedBox(height: 12),
          Text(title),
          if (action != null)
            TextButton(onPressed: action, child: const Text('Yeniden dene')),
        ],
      ),
    ),
  );
}

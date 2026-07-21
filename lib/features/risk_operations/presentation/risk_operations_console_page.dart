import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:markakalkan/core/theme/markakalkan_theme.dart';

import '../data/risk_operations_models.dart';
import '../data/risk_operations_lifecycle.dart';
import '../data/risk_operations_repository.dart';
import 'risk_operations_labels.dart';

class RiskOperationsConsolePage extends StatefulWidget {
  const RiskOperationsConsolePage({
    super.key,
    required this.navigationRequestId,
    required this.routeEntryCause,
    this.repository,
    this.lifecycleProvider,
    this.onStateCreated,
  });
  final String navigationRequestId;
  final RiskOperationsRouteEntryCause routeEntryCause;
  final RiskOperationsRepository? repository;
  final RiskOperationsLifecycleProvider? lifecycleProvider;
  final VoidCallback? onStateCreated;
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
          ...result.items.map((item) => _RiskItemCard(item: item)),
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
      onChanged: onChanged,
    ),
  );
  String _dateLabel(String label, DateTime? date) => date == null
      ? label
      : '$label: ${date.year.toString().padLeft(4, '0')}-'
            '${date.month.toString().padLeft(2, '0')}-'
            '${date.day.toString().padLeft(2, '0')}';
}

class _RiskItemCard extends StatelessWidget {
  const _RiskItemCard({required this.item});
  final RiskOperationItem item;
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
        Align(alignment: Alignment.centerLeft, child: Text(item.summary)),
        const SizedBox(height: 12),
        _line(
          'Delil kalitesi',
          RiskOperationsLabels.evidenceQuality(item.evidenceQuality.level),
        ),
        _line(
          'Vaka adaylığı',
          RiskOperationsLabels.caseCandidacy(item.caseCandidacy.status),
        ),
        _line('Durum', RiskOperationsLabels.status(item.currentStatus)),
        _line(
          'Olay zamanı',
          item.occurredAt?.toLocal().toString() ?? 'Bilinmiyor',
        ),
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
              '${event.summary}\n'
              '${event.occurredAt?.toLocal().toString() ?? 'Zaman bilinmiyor'}',
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
              '${RiskOperationsLabels.relationshipType(node.type)} · '
              '${RiskOperationsLabels.sourceSystem(node.sourceSystem)} · '
              '${RiskOperationsLabels.evidenceQuality(node.evidenceQuality)}',
            ),
          ),
        ),
        const SizedBox(height: 8),
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

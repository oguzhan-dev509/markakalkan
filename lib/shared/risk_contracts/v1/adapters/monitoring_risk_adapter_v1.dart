import '../../../../modules/marka_kalkan/dijital_pazar_izleme/constants/monitoring_enums.dart';
import '../../../../modules/marka_kalkan/dijital_pazar_izleme/models/monitoring_event_model.dart';
import '../../../../modules/marka_kalkan/dijital_pazar_izleme/models/monitoring_signal_model.dart';
import '../shared_risk_contracts_v1.dart';

final class MonitoringRiskAdapterV1 {
  const MonitoringRiskAdapterV1();

  RiskSignalContractV1 toSignal(
    MonitoringSignalModel signal, {
    required DateTime adaptedAt,
    MonitoringEventModel? event,
  }) {
    if (event != null) _requireMatchingEvent(signal, event);
    final eventType = event?.eventType.value ?? signal.eventType?.value;
    return RiskSignalContractV1(
      signalId: _required(signal.id, 'signal.id'),
      identityScope: IdentityScope(
        tenantId: _required(signal.tenantId, 'signal.tenantId'),
        brandId: _required(signal.brandId, 'signal.brandId'),
        resolutionStatus: IdentityResolutionStatus.resolved,
        resolutionSource: 'monitoring.signal',
      ),
      canonicalAssetRef: CanonicalAssetRef(
        assetType: 'monitored_page',
        assetId: _required(signal.pageId, 'signal.pageId'),
        module: 'digital_market_monitoring',
        brandId: signal.brandId,
      ),
      signalSource: SignalSource(
        module: 'digital_market_monitoring',
        sourceType: 'monitoring_signal',
        sourceId: signal.sourceId,
      ),
      signalType: NamespacedValue(
        namespace: 'digital_market_monitoring.event_type',
        value: eventType ?? 'rule_match',
      ),
      canonicalSeverity: canonicalSeverity(signal.signalLevel.value),
      originalSeverity: signal.signalLevel.value,
      summary: signal.summary,
      relatedEntityRefs: _relatedRefs(signal, event),
      reviewStatus: reviewStatus(signal.status.value),
      detectedAt: signal.detectedAt,
      createdAt: signal.createdAt,
      provenance: ProvenanceEnvelope(
        producerModule: 'digital_market_monitoring',
        producerVersion: 'monitoring-risk-adapter-v1',
        sourceRecordId: signal.id,
        sourceId: signal.sourceId,
        snapshotId: event?.currentSnapshotId,
        sourceCreatedAt: signal.createdAt,
        adaptedAt: adaptedAt,
      ),
    );
  }

  CanonicalSeverity canonicalSeverity(String sourceValue) =>
      switch (sourceValue.trim()) {
        'info' => CanonicalSeverity.info,
        'low' => CanonicalSeverity.low,
        'medium' => CanonicalSeverity.medium,
        'high' => CanonicalSeverity.high,
        'critical' => CanonicalSeverity.critical,
        _ => throw FormatException(
          'Unsupported monitoring signalLevel: $sourceValue',
        ),
      };

  RiskSignalReviewStatus reviewStatus(String sourceValue) =>
      switch (sourceValue.trim()) {
        'new' => RiskSignalReviewStatus.newSignal,
        'under_review' => RiskSignalReviewStatus.underReview,
        'confirmed' => RiskSignalReviewStatus.confirmed,
        'dismissed' => RiskSignalReviewStatus.dismissed,
        'escalated' => RiskSignalReviewStatus.escalated,
        'resolved' => RiskSignalReviewStatus.resolved,
        'archived' => RiskSignalReviewStatus.archived,
        _ => throw FormatException(
          'Unsupported monitoring signal status: $sourceValue',
        ),
      };

  List<CanonicalEntityRef> _relatedRefs(
    MonitoringSignalModel signal,
    MonitoringEventModel? event,
  ) => [
    _ref('monitoring_signal', signal.id),
    _ref('monitoring_event', signal.eventId),
    _ref('monitoring_source', signal.sourceId),
    _ref('monitored_page', signal.pageId),
    _ref('signal_rule', signal.ruleId, displayCode: signal.ruleName),
    if (_optional(signal.listingId) case final value?)
      _ref('product_listing', value),
    if (_optional(signal.sellerId) case final value?) _ref('seller', value),
    if (_optional(signal.storeId) case final value?)
      _ref('seller_store', value),
    if (event != null) ...[
      _ref('page_snapshot', event.previousSnapshotId),
      _ref('page_snapshot', event.currentSnapshotId),
      _ref('event_type', event.eventType.value),
      _ref('event_category', event.eventCategory.value),
    ],
  ];

  CanonicalEntityRef _ref(String type, String id, {String? displayCode}) =>
      CanonicalEntityRef(
        module: 'digital_market_monitoring',
        entityType: type,
        entityId: _required(id, type),
        displayCode: _optional(displayCode),
      );

  void _requireMatchingEvent(
    MonitoringSignalModel signal,
    MonitoringEventModel event,
  ) {
    if (event.id != signal.eventId ||
        event.tenantId != signal.tenantId ||
        event.brandId != signal.brandId ||
        event.sourceId != signal.sourceId ||
        event.pageId != signal.pageId) {
      throw const FormatException('Monitoring event does not match signal');
    }
  }

  String _required(String value, String field) {
    final clean = value.trim();
    if (clean.isEmpty) throw FormatException('$field is required');
    return clean;
  }

  String? _optional(String? value) {
    final clean = value?.trim();
    return clean == null || clean.isEmpty ? null : clean;
  }
}

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:markakalkan/modules/marka_kalkan/dijital_pazar_izleme/constants/monitoring_enums.dart';
import 'package:markakalkan/modules/marka_kalkan/dijital_pazar_izleme/models/monitoring_event_model.dart';
import 'package:markakalkan/modules/marka_kalkan/dijital_pazar_izleme/models/monitoring_signal_model.dart';
import 'package:markakalkan/shared/risk_contracts/v1/adapters/monitoring_risk_adapter_v1.dart';
import 'package:markakalkan/shared/risk_contracts/v1/shared_risk_contracts_v1.dart';

void main() {
  const adapter = MonitoringRiskAdapterV1();
  final adaptedAt = DateTime.parse('2026-07-19T12:00:00Z');

  test('monitoring signal maps with tenant and brand intact', () {
    final output = adapter.toSignal(
      signal(),
      adaptedAt: adaptedAt,
      event: event(),
    );
    expect(output.identityScope.tenantId, 'tenant-1');
    expect(output.identityScope.brandId, 'brand-1');
    expect(
      output.identityScope.resolutionStatus,
      IdentityResolutionStatus.resolved,
    );
    expect(output.signalType.value, 'price_decreased');
  });

  test('all source severity values have explicit canonical mappings', () {
    const expected = {
      'info': CanonicalSeverity.info,
      'low': CanonicalSeverity.low,
      'medium': CanonicalSeverity.medium,
      'high': CanonicalSeverity.high,
      'critical': CanonicalSeverity.critical,
    };
    for (final entry in expected.entries) {
      expect(adapter.canonicalSeverity(entry.key), entry.value);
    }
    expect(() => adapter.canonicalSeverity('urgent'), throwsFormatException);
  });

  test('source severity is retained beside canonical value', () {
    final output = adapter.toSignal(signal(), adaptedAt: adaptedAt);
    expect(output.canonicalSeverity, CanonicalSeverity.medium);
    expect(output.originalSeverity, 'medium');
  });

  test('all source lifecycle values map explicitly', () {
    const expected = {
      'new': RiskSignalReviewStatus.newSignal,
      'under_review': RiskSignalReviewStatus.underReview,
      'confirmed': RiskSignalReviewStatus.confirmed,
      'dismissed': RiskSignalReviewStatus.dismissed,
      'escalated': RiskSignalReviewStatus.escalated,
      'resolved': RiskSignalReviewStatus.resolved,
      'archived': RiskSignalReviewStatus.archived,
    };
    for (final entry in expected.entries) {
      expect(adapter.reviewStatus(entry.key), entry.value);
    }
  });

  test('unknown lifecycle fails closed', () {
    expect(() => adapter.reviewStatus('forwarded'), throwsFormatException);
  });

  test('event and source entity references remain lossless', () {
    final refs = adapter
        .toSignal(signal(), adaptedAt: adaptedAt, event: event())
        .relatedEntityRefs;
    final pairs = refs.map((item) => '${item.entityType}:${item.entityId}');
    expect(
      pairs,
      containsAll([
        'monitoring_signal:signal-1',
        'monitoring_event:event-1',
        'monitoring_source:source-1',
        'monitored_page:page-1',
        'product_listing:listing-1',
        'seller:seller-1',
        'seller_store:store-1',
        'page_snapshot:snapshot-before',
        'page_snapshot:snapshot-after',
      ]),
    );
  });

  test('timestamps are not substituted for each other', () {
    final input = signal();
    final output = adapter.toSignal(input, adaptedAt: adaptedAt);
    expect(output.detectedAt, input.detectedAt);
    expect(output.createdAt, input.createdAt);
    expect(output.detectedAt, isNot(output.createdAt));
    expect(output.provenance.adaptedAt, adaptedAt);
  });

  test('mismatched event is rejected', () {
    expect(
      () => adapter.toSignal(
        signal(),
        adaptedAt: adaptedAt,
        event: event(id: 'other'),
      ),
      throwsFormatException,
    );
  });

  test('same input produces byte-semantically equal JSON', () {
    final first = adapter.toSignal(
      signal(),
      adaptedAt: adaptedAt,
      event: event(),
    );
    final second = adapter.toSignal(
      signal(),
      adaptedAt: adaptedAt,
      event: event(),
    );
    expect(jsonEncode(first.toJson()), jsonEncode(second.toJson()));
  });
}

MonitoringSignalModel signal() => MonitoringSignalModel(
  id: 'signal-1',
  tenantId: 'tenant-1',
  brandId: 'brand-1',
  sourceId: 'source-1',
  pageId: 'page-1',
  listingId: 'listing-1',
  sellerId: 'seller-1',
  storeId: 'store-1',
  eventId: 'event-1',
  ruleId: 'rule-1',
  ruleName: 'Price drop',
  eventType: MonitoringEventType.priceDecreased,
  eventCategory: MonitoringEventCategory.price,
  signalLevel: MonitoringSignalLevel.medium,
  status: MonitoringSignalStatus.underReview,
  forwardingStatus: MonitoringSignalForwardingStatus.notForwarded,
  title: 'Synthetic price signal',
  summary: 'Synthetic listing price decreased.',
  detectedAt: DateTime.parse('2026-07-19T10:00:00Z'),
  createdAt: DateTime.parse('2026-07-19T10:01:00Z'),
);

MonitoringEventModel event({String id = 'event-1'}) => MonitoringEventModel(
  id: id,
  tenantId: 'tenant-1',
  brandId: 'brand-1',
  sourceId: 'source-1',
  pageId: 'page-1',
  listingId: 'listing-1',
  sellerId: 'seller-1',
  storeId: 'store-1',
  eventType: MonitoringEventType.priceDecreased,
  eventCategory: MonitoringEventCategory.price,
  previousSnapshotId: 'snapshot-before',
  currentSnapshotId: 'snapshot-after',
  oldValue: 120,
  newValue: 80,
  changeRate: -33.3,
  severity: MonitoringEventSeverity.medium,
  status: MonitoringEventStatus.newEvent,
  detectedAt: DateTime.parse('2026-07-19T09:59:00Z'),
  createdBySystem: true,
  createdAt: DateTime.parse('2026-07-19T10:00:30Z'),
);

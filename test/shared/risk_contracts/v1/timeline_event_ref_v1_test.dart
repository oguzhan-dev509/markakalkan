import 'package:flutter_test/flutter_test.dart';
import 'package:markakalkan/shared/risk_contracts/v1/shared_risk_contracts_v1.dart';

void main() {
  TimelineEventRefV1 event({
    CanonicalEntityRef? actorRef,
    CanonicalEntityRef? subjectRef,
    String? sourceSystemCode,
    String? sourceRecordId,
  }) => TimelineEventRefV1(
    eventId: 'event-001',
    eventType: NamespacedValue(
      namespace: 'markakalkan.case',
      value: 'evidence_object_bound',
    ),
    occurredAt: DateTime.utc(2026, 9, 2, 10, 15),
    actorRef: actorRef,
    subjectRef: subjectRef,
    sourceSystemCode: sourceSystemCode,
    sourceRecordId: sourceRecordId,
  );

  test('stores required event identity type and occurrence time', () {
    final value = event();

    expect(value.eventId, 'event-001');
    expect(value.eventType.namespace, 'markakalkan.case');
    expect(value.eventType.value, 'evidence_object_bound');
    expect(value.occurredAt, DateTime.utc(2026, 9, 2, 10, 15));
  });

  test('event type is a namespaced value rather than a global enum', () {
    final caseEvent = event().toJson();
    final riskEvent = TimelineEventRefV1(
      eventId: 'event-002',
      eventType: NamespacedValue(
        namespace: 'markakalkan.risk_operations',
        value: 'source_observed',
      ),
      occurredAt: DateTime.utc(2026, 9, 2, 10, 16),
    ).toJson();

    expect(
      (caseEvent['eventType'] as Map<String, Object?>)['namespace'],
      'markakalkan.case',
    );
    expect(
      (riskEvent['eventType'] as Map<String, Object?>)['namespace'],
      'markakalkan.risk_operations',
    );
  });

  test('JSON round-trip preserves the minimal timeline event reference', () {
    final original = event(
      actorRef: CanonicalEntityRef(
        module: 'identity',
        entityType: 'user',
        entityId: 'uid-001',
      ),
      subjectRef: CanonicalEntityRef(
        module: 'case_evidence_center',
        entityType: 'case',
        entityId: 'case-001',
      ),
      sourceSystemCode: 'case_evidence_center',
      sourceRecordId: 'case-event-001',
    );

    expect(
      TimelineEventRefV1.fromJson(original.toJson()).toJson(),
      original.toJson(),
    );
  });

  test('unknown contract version fails closed', () {
    final json = event().toJson();
    json['contractVersion'] = 'timeline-event-ref-v999';

    expect(
      () => TimelineEventRefV1.fromJson(Map<String, dynamic>.from(json)),
      throwsFormatException,
    );
  });

  test('missing or malformed occurrence time fails closed', () {
    final missing = event().toJson()..remove('occurredAt');
    final malformed = event().toJson()..['occurredAt'] = 'not-a-date';

    expect(
      () => TimelineEventRefV1.fromJson(Map<String, dynamic>.from(missing)),
      throwsFormatException,
    );
    expect(
      () => TimelineEventRefV1.fromJson(Map<String, dynamic>.from(malformed)),
      throwsFormatException,
    );
  });

  test('actorRef requires explicit canonical reference mapping', () {
    final value = event(
      actorRef: CanonicalEntityRef(
        module: 'identity',
        entityType: 'user',
        entityId: 'uid-002',
      ),
    );

    expect(value.actorRef!.module, 'identity');
    expect(value.actorRef!.entityType, 'user');
    expect(value.actorRef!.entityId, 'uid-002');
    expect(value.toJson().containsKey('actorUid'), isFalse);
  });

  test('subjectRef requires explicit canonical reference mapping', () {
    final value = event(
      subjectRef: CanonicalEntityRef(
        module: 'case_evidence_center',
        entityType: 'evidence_object',
        entityId: 'evidence-object-001',
      ),
    );

    expect(value.subjectRef!.module, 'case_evidence_center');
    expect(value.subjectRef!.entityType, 'evidence_object');
    expect(value.subjectRef!.entityId, 'evidence-object-001');
    expect(value.toJson().containsKey('caseId'), isFalse);
    expect(value.toJson().containsKey('evidenceObjectId'), isFalse);
  });

  test(
    'source system and source record remain optional provenance locators',
    () {
      final minimal = event().toJson();

      expect(minimal.containsKey('sourceSystemCode'), isFalse);
      expect(minimal.containsKey('sourceRecordId'), isFalse);

      final located = event(
        sourceSystemCode: 'risk_operations',
        sourceRecordId: 'source-event-001',
      ).toJson();

      expect(located['sourceSystemCode'], 'risk_operations');
      expect(located['sourceRecordId'], 'source-event-001');
    },
  );

  test(
    'domain event payload fields are excluded from the shared reference',
    () {
      final json = event().toJson();

      for (final field in [
        'summary',
        'category',
        'action',
        'note',
        'payload',
        'payloadSummary',
      ]) {
        expect(json.containsKey(field), isFalse);
      }
    },
  );

  test('empty optional source locators fail validation when provided', () {
    expect(() => event(sourceSystemCode: '   '), throwsFormatException);
    expect(() => event(sourceRecordId: ''), throwsFormatException);
  });

  test('timeline event truth contains no entitlement or payment fields', () {
    final json = event().toJson();

    for (final field in [
      'subscription',
      'payment',
      'accessRequirement',
      'verifiedBrand',
      'operationAuthority',
    ]) {
      expect(json.containsKey(field), isFalse);
    }
  });
}

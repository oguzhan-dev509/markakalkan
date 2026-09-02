import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markakalkan/features/admin/models/platform_admin_access.dart';
import 'package:markakalkan/features/risk_operations/data/risk_operations_lifecycle.dart';
import 'package:markakalkan/features/risk_operations/data/risk_operations_models.dart';
import 'package:markakalkan/shared/risk_contracts/v1/shared_risk_contracts_v1.dart';
import 'package:markakalkan/features/risk_operations/data/risk_operations_repository.dart';
import 'package:markakalkan/features/risk_operations/presentation/risk_operations_console_page.dart';

void main() {
  group('risk callable response normalization', () {
    test('preserves supported platform-neutral values recursively', () {
      final source = LinkedHashMap<Object?, Object?>.from({
        'string': 'değer',
        'bool': true,
        'int': 6,
        'double': 0.75,
        'null': null,
        'nested': <Object?, Object?>{
          'list': <Object?>[
            <Object?, Object?>{'count': 2},
            null,
          ],
        },
      });

      expect(normalizeRiskOperationsResponse(source), {
        'string': 'değer',
        'bool': true,
        'int': 6,
        'double': 0.75,
        'null': null,
        'nested': {
          'list': [
            {'count': 2},
            null,
          ],
        },
      });
    });

    test('accepts a normal Map<String, dynamic>', () {
      expect(normalizeRiskOperationsResponse(<String, dynamic>{'ok': true}), {
        'ok': true,
      });
    });

    test('fails closed for a non-map root', () {
      expect(
        () => normalizeRiskOperationsResponse(<Object?>[]),
        throwsA(isA<RiskOperationsResponseNormalizationException>()),
      );
    });

    test('fails closed for a non-string key', () {
      expect(
        () => normalizeRiskOperationsResponse(<Object?, Object?>{1: 'value'}),
        throwsA(isA<RiskOperationsResponseNormalizationException>()),
      );
    });

    test('fails closed for an unsupported nested object', () {
      expect(
        () => normalizeRiskOperationsResponse(<Object?, Object?>{
          'value': DateTime.utc(2026),
        }),
        throwsA(isA<RiskOperationsResponseNormalizationException>()),
      );
    });
  });

  group('callable repository boundary', () {
    test(
      'parses a six-item runtime-like response without partial sources',
      () async {
        final repository = CallableRiskOperationsRepository(
          transport: (_) async => _runtimeResponse(),
          failureLogger: (_) {},
        );

        final result = await repository.list(
          const RiskOperationsQuery(),
          _diagnostics(RiskOperationsRouteEntryCause.corporateHubCard),
        );

        expect(result.items, hasLength(6));
        expect(result.summary.totalVisibleSignals, 6);
        expect(result.partialSourceUnavailable, isFalse);
      },
    );

    test('separates normalization failure with safe telemetry only', () async {
      final logs = <Map<String, Object?>>[];
      final repository = CallableRiskOperationsRepository(
        transport: (_) async => <Object?, Object?>{1: 'raw-secret'},
        failureLogger: logs.add,
      );

      await expectLater(
        repository.list(
          const RiskOperationsQuery(),
          _diagnostics(RiskOperationsRouteEntryCause.directRoute),
        ),
        throwsA(
          isA<RiskOperationsRepositoryException>().having(
            (error) => error.failureStage,
            'failureStage',
            RiskOperationsRepositoryFailureStage.rootResponseNormalization,
          ),
        ),
      );

      expect(logs, hasLength(1));
      expect(logs.single.keys, {
        'event',
        'failureStage',
        'exceptionType',
        'lifecycleCorrelationHash',
        'routeEntryCause',
        'responseRootType',
        'fieldPath',
        'expectedType',
        'actualRuntimeType',
        'transactionCommitted',
        'writeAttempted',
      });
      expect(logs.single.values, isNot(contains('raw-secret')));
      expect(logs.single['transactionCommitted'], isFalse);
      expect(logs.single['writeAttempted'], isFalse);
    });

    test('separates callable and parser failures', () async {
      final callable = CallableRiskOperationsRepository(
        transport: (_) async => throw StateError('not logged'),
        failureLogger: (_) {},
      );
      await expectLater(
        callable.list(
          const RiskOperationsQuery(),
          _diagnostics(RiskOperationsRouteEntryCause.corporateHubCard),
        ),
        throwsA(
          isA<RiskOperationsRepositoryException>().having(
            (error) => error.failureStage,
            'failureStage',
            RiskOperationsRepositoryFailureStage.callableResultReceived,
          ),
        ),
      );

      final parser = CallableRiskOperationsRepository(
        transport: (_) async => <Object?, Object?>{
          ..._runtimeResponse(),
          'contractVersion': 'invalid',
        },
        failureLogger: (_) {},
      );
      await expectLater(
        parser.list(
          const RiskOperationsQuery(),
          _diagnostics(RiskOperationsRouteEntryCause.corporateHubCard),
        ),
        throwsA(
          isA<RiskOperationsRepositoryException>().having(
            (error) => error.failureStage,
            'failureStage',
            RiskOperationsRepositoryFailureStage.pageResultParsing,
          ),
        ),
      );
    });

    test('parser rejects missing required fields and wrong item types', () {
      final missing = _stringResponse();
      (missing['items'] as List).first.remove('signalId');
      expect(
        () => _parse(missing),
        throwsA(
          isA<RiskOperationsFieldTypeException>().having(
            (error) => error.fieldPath,
            'fieldPath',
            'items[0].signalId',
          ),
        ),
      );

      final wrongItem = _stringResponse()..['items'] = <Object?>['invalid'];
      expect(
        () => _parse(wrongItem),
        throwsA(isA<RiskOperationsFieldTypeException>()),
      );
    });

    for (final entry in const [
      (RiskOperationsRouteEntryCause.corporateHubCard, 'normal'),
      (RiskOperationsRouteEntryCause.directRoute, 'internal'),
    ]) {
      testWidgets('${entry.$2} route renders six runtime-response items', (
        tester,
      ) async {
        final repository = CallableRiskOperationsRepository(
          transport: (_) async => _runtimeResponse(),
          failureLogger: (_) {},
        );
        await tester.pumpWidget(
          MaterialApp(
            home: RiskOperationsConsolePage(
              navigationRequestId: '${entry.$2}-navigation',
              routeEntryCause: entry.$1,
              repository: repository,
              lifecycleProvider: _Lifecycle(),
              internalAdminAccess:
                  entry.$1 == RiskOperationsRouteEntryCause.directRoute
                  ? _verifiedAdmin
                  : null,
              enableDryRun: false,
              enablePromotion: false,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('risk-operations-error')),
          findsNothing,
        );
        expect(find.text('6'), findsWidgets);
        expect(find.byType(ExpansionTile), findsNWidgets(6));
        expect(find.text('Ortak risk kaydı oluştur'), findsNothing);
      });
    }
  });

  group('canonical relation edge read-model integration', () {
    Map<String, dynamic> explicitEdgeWire() => Map<String, dynamic>.from(
      RelationEdgeV1(
        edgeId: 'rel-read-001',
        sourceEntityRef: CanonicalEntityRef(
          module: 'brand_registry',
          entityType: 'brand',
          entityId: 'brand-001',
        ),
        targetEntityRef: CanonicalEntityRef(
          module: 'digital_market',
          entityType: 'listing',
          entityId: 'listing-009',
        ),
        relationType: NamespacedValue(
          namespace: 'markakalkan.relation',
          value: 'potential_counterfeit_of',
        ),
        directionality: RelationDirectionalityV1.directed,
        observedAt: DateTime.utc(2026, 9, 2, 14, 30),
        createdAt: DateTime.utc(2026, 9, 2, 14, 31),
        provenance: ProvenanceEnvelope(
          producerModule: 'risk_operations',
          adaptedAt: DateTime.utc(2026, 9, 2, 14, 31),
        ),
      ).toJson(),
    );

    test('parses only an explicit canonical relationship edge wire value', () {
      final response = _stringResponse();
      final first = (response['items'] as List).first as Map<String, dynamic>;
      final graph = first['relationshipGraph'] as Map<String, dynamic>;
      graph['edges'] = <Map<String, dynamic>>[explicitEdgeWire()];

      final parsed = _parse(response);
      final edge = parsed.items.first.relationshipEdges.single;

      expect(edge.edgeId, 'rel-read-001');
      expect(edge.sourceEntityRef.entityId, 'brand-001');
      expect(edge.targetEntityRef.entityId, 'listing-009');
      expect(edge.relationType.namespace, 'markakalkan.relation');
      expect(edge.relationType.value, 'potential_counterfeit_of');
      expect(edge.directionality, RelationDirectionalityV1.directed);
    });

    test('does not infer relation truth from graph node co-occurrence', () {
      final parsed = _parse(_stringResponse());

      expect(parsed.items.first.relationshipNodes, isNotEmpty);
      expect(parsed.items.first.relationshipEdges, isEmpty);
    });

    test('does not infer relation truth from risk fields', () {
      final response = _stringResponse();
      final first = (response['items'] as List).first as Map<String, dynamic>;
      first['riskClass'] = 'counterfeit';
      first['severity'] = 'critical';
      first['confidence'] = 1.0;

      final parsed = _parse(response);

      expect(parsed.items.first.relationshipEdges, isEmpty);
    });

    test('invalid explicit relation directionality fails closed', () {
      final response = _stringResponse();
      final first = (response['items'] as List).first as Map<String, dynamic>;
      final graph = first['relationshipGraph'] as Map<String, dynamic>;
      final edge = explicitEdgeWire()..['directionality'] = 'SIDEWAYS';
      graph['edges'] = <Map<String, dynamic>>[edge];

      expect(() => _parse(response), throwsFormatException);
    });

    test('invalid explicit relation contract version fails closed', () {
      final response = _stringResponse();
      final first = (response['items'] as List).first as Map<String, dynamic>;
      final graph = first['relationshipGraph'] as Map<String, dynamic>;
      final edge = explicitEdgeWire()
        ..['contractVersion'] = 'relation-edge-v999';
      graph['edges'] = <Map<String, dynamic>>[edge];

      expect(() => _parse(response), throwsFormatException);
    });
  });

  group('canonical timeline event reference integration', () {
    test(
      'known-time event projects to TimelineEventRefV1 without actor or subject inference',
      () {
        final response = _stringResponse();
        final first = (response['items'] as List).first as Map<String, dynamic>;
        final timeline = first['timeline'] as List;
        final event = timeline.first as Map<String, dynamic>;
        event['occurredAt'] = '2026-09-02T15:20:00.000Z';
        event['occurredAtStatus'] = 'known';
        event['sourceSystem'] = 'monitoring';
        event['sourceRecordId'] = 'monitoring-source-001';
        event['eventType'] = 'source_observed';

        final parsed = _parse(response);
        final ref = parsed.items.first.timeline.first.timelineEventRef;

        expect(ref, isNotNull);
        expect(ref!.eventId, parsed.items.first.timeline.first.eventId);
        expect(ref.eventType.namespace, 'monitoring');
        expect(ref.eventType.value, 'source_observed');
        expect(ref.sourceSystemCode, 'monitoring');
        expect(ref.sourceRecordId, 'monitoring-source-001');
        expect(ref.actorRef, isNull);
        expect(ref.subjectRef, isNull);
      },
    );

    test(
      'unknown-time event does not invent a canonical occurrence timestamp',
      () {
        final parsed = _parse(_stringResponse());

        expect(parsed.items.first.timeline.first.occurredAt, isNull);
        expect(parsed.items.first.timeline.first.timelineEventRef, isNull);
      },
    );

    test(
      'timeline canonical namespace reuses explicit sourceSystem without global event enum',
      () {
        final response = _stringResponse();
        final first = (response['items'] as List).first as Map<String, dynamic>;
        final timeline = first['timeline'] as List;
        final event = timeline.first as Map<String, dynamic>;
        event['occurredAt'] = '2026-09-02T15:21:00.000Z';
        event['occurredAtStatus'] = 'known';
        event['sourceSystem'] = 'traceability';
        event['sourceRecordId'] = 'scan-001';
        event['eventType'] = 'source_observed';

        final ref = _parse(
          response,
        ).items.first.timeline.first.timelineEventRef;

        expect(ref!.eventType.namespace, 'traceability');
        expect(ref.eventType.value, 'source_observed');
      },
    );

    test('malformed explicit timeline sourceRecordId fails closed', () {
      final response = _stringResponse();
      final first = (response['items'] as List).first as Map<String, dynamic>;
      final timeline = first['timeline'] as List;
      final event = timeline.first as Map<String, dynamic>;
      event['sourceRecordId'] = 42;

      expect(() => _parse(response), throwsFormatException);
    });
  });
}

RiskOperationsPageResult _parse(Map<String, dynamic> response) =>
    RiskOperationsPageResult.fromMap(normalizeRiskOperationsResponse(response));

class _Lifecycle extends RiskOperationsLifecycleProvider {
  _Lifecycle()
    : super(
        nextId: () => 'deterministic-id',
        browserContext: const RiskOperationsBrowserContext(),
      );
}

const _verifiedAdmin = PlatformAdminAccess(
  active: true,
  roles: ['super_admin'],
  displayName: 'Yönetici',
  email: 'masked@example.invalid',
);

RiskOperationsReadDiagnostics _diagnostics(
  RiskOperationsRouteEntryCause route,
) => RiskOperationsReadDiagnostics(
  browserTabSessionId: 'tab',
  appBootId: 'boot',
  authEpoch: 1,
  navigationRequestId: 'navigation',
  routeEntryId: 'route',
  navigationType: RiskOperationsNavigationType.navigate,
  routeEntryCause: route,
  pageshowPersisted: false,
  initialVisibilityState: 'visible',
  documentReferrerPresent: false,
  serviceWorkerControlled: false,
  lifecycleQuality: RiskOperationsLifecycleQuality.normal,
  pageInstanceId: 'page',
  loadAttemptId: 'attempt',
  trigger: RiskOperationsLoadTrigger.initialMount,
  attemptSequence: 1,
);

Map<Object?, Object?> _runtimeResponse() => _objectMap(_stringResponse());

Map<String, dynamic> _stringResponse() => <String, dynamic>{
  'contractVersion': 'risk-operations-read-v1',
  'readOnly': true,
  'writesPerformed': 0,
  'summary': <String, dynamic>{
    'totalVisibleSignals': 6,
    'highOrCriticalRisk': 0,
    'awaitingHumanReview': 6,
    'strongCaseCandidates': 0,
    'insufficientEvidence': 0,
  },
  'items': List<Map<String, dynamic>>.generate(6, _item),
  'nextPageToken': null,
  'sourceAvailability': <Map<String, dynamic>>[
    {'sourceSystem': 'monitoring', 'status': 'available'},
    {'sourceSystem': 'traceability', 'status': 'available'},
    {'sourceSystem': 'digital_detective', 'status': 'available'},
    {'sourceSystem': 'shared_risk', 'status': 'available'},
  ],
};

Map<String, dynamic> _item(int index) => <String, dynamic>{
  'signalId': 'signal-$index',
  'sourceSystem': 'traceability',
  'sourceRecordId': 'source-$index',
  'sourceRecordVersion': 'v1',
  'tenantId': 'tenant',
  'canonicalBrandId': 'brand',
  'canonicalSubjectId': 'subject-$index',
  'subjectType': 'product',
  'title': 'Risk sinyali ${index + 1}',
  'summary': 'İnsan incelemesi gereken güvenli özet.',
  'occurredAt': null,
  'observedAt': '2026-07-22T00:00:00.000Z',
  'ingestedAt': '2026-07-22T00:00:00.000Z',
  'currentStatus': 'new',
  'riskClass': 'traceability_anomaly',
  'severity': 'medium',
  'confidence': index.isEven ? 1 : 0.75,
  'evidenceQuality': <String, dynamic>{
    'level': 'verified_primary',
    'reasonCodes': <String>['evidence.primary_verified'],
    'evaluatorVersion': 'risk-operations-evaluator-v1',
  },
  'caseCandidacy': <String, dynamic>{
    'status': 'review_candidate',
    'reasonCodes': <String>['case.human_review_threshold'],
    'evaluatedAt': '2026-07-22T00:00:00.000Z',
    'evaluatorVersion': 'risk-operations-evaluator-v1',
    'requiresHumanReview': true,
  },
  'timeline': <Map<String, dynamic>>[
    {
      'eventId': 'event-$index',
      'eventType': 'source_observed',
      'occurredAt': null,
      'occurredAtStatus': 'unknown',
      'sourceSystem': 'traceability',
      'sourceRecordId': 'source-$index',
      'summary': 'Kaynak olayı',
      'evidenceReferenceCount': index,
      'immutableSource': true,
    },
  ],
  'relationshipGraph': <String, dynamic>{
    'nodes': <Map<String, dynamic>>[
      {
        'canonicalId': 'brand',
        'type': 'brand',
        'maskedLabel': 'Ma***an',
        'sourceSystem': 'traceability',
        'confidence': index.isEven ? null : 0.75,
        'evidenceQuality': 'verified_primary',
        'firstObservedAt': null,
        'lastObservedAt': null,
      },
    ],
    'edges': <Map<String, dynamic>>[],
  },
  'adapterVersion': 'risk-operations-read-adapter-v1',
  'projectionFingerprint': 'fingerprint-$index',
};

Map<Object?, Object?> _objectMap(Map<String, dynamic> source) => source
    .map<Object?, Object?>((key, value) => MapEntry(key, _objectValue(value)));

Object? _objectValue(Object? value) {
  if (value is Map<String, dynamic>) return _objectMap(value);
  if (value is List) {
    return value.map(_objectValue).toList(growable: false);
  }
  return value;
}

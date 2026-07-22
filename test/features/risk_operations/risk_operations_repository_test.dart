import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markakalkan/features/admin/models/platform_admin_access.dart';
import 'package:markakalkan/features/risk_operations/data/risk_operations_lifecycle.dart';
import 'package:markakalkan/features/risk_operations/data/risk_operations_models.dart';
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
      expect(() => _parse(missing), throwsA(isA<FormatException>()));

      final wrongItem = _stringResponse()..['items'] = <Object?>['invalid'];
      expect(() => _parse(wrongItem), throwsA(isA<FormatException>()));
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
        'confidence': 0.75,
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

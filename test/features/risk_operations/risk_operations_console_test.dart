import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markakalkan/features/risk_operations/data/risk_operations_models.dart';
import 'package:markakalkan/features/risk_operations/data/risk_operations_repository.dart';
import 'package:markakalkan/features/risk_operations/presentation/risk_operations_console_page.dart';

class FakeRepository implements RiskOperationsRepository {
  FakeRepository(this.response);
  final Future<RiskOperationsPageResult> Function(RiskOperationsQuery) response;
  @override
  Future<RiskOperationsPageResult> list(RiskOperationsQuery query) =>
      response(query);
}

Map<String, dynamic> responseMap({
  List<Map<String, dynamic>> items = const [],
  bool partial = false,
  String? nextPageToken,
}) => {
  'contractVersion': 'risk-operations-read-v1',
  'readOnly': true,
  'writesPerformed': 0,
  'summary': {
    'totalVisibleSignals': items.length,
    'highOrCriticalRisk': items.length,
    'awaitingHumanReview': items.length,
    'strongCaseCandidates': 0,
    'insufficientEvidence': 0,
  },
  'items': items,
  'nextPageToken': nextPageToken,
  'sourceAvailability': [
    {
      'sourceSystem': 'monitoring',
      'status': partial ? 'unavailable' : 'available',
    },
  ],
};

Map<String, dynamic> itemMap() => {
  'signalId': 'signal-1',
  'sourceSystem': 'monitoring',
  'sourceRecordId': 'source-1',
  'sourceRecordVersion': 'v1',
  'tenantId': 'tenant-1',
  'canonicalBrandId': 'brand-1',
  'canonicalSubjectId': 'subject-1',
  'subjectType': 'listing',
  'title': 'Şüpheli ilan sinyali',
  'summary': 'İnsan incelemesi gereken güvenli özet.',
  'occurredAt': '2026-07-21T00:00:00.000Z',
  'currentStatus': 'new',
  'riskClass': 'marketplace_abuse',
  'severity': 'high',
  'confidence': .8,
  'evidenceQuality': {
    'level': 'corroborated',
    'reasonCodes': ['evidence.multiple_independent_sources'],
    'evaluatorVersion': 'risk-operations-evaluator-v1',
  },
  'caseCandidacy': {
    'status': 'review_candidate',
    'reasonCodes': ['case.human_review_threshold'],
    'evaluatedAt': '2026-07-21T01:00:00.000Z',
    'evaluatorVersion': 'risk-operations-evaluator-v1',
    'requiresHumanReview': true,
  },
  'timeline': [
    {
      'eventId': 'event-1',
      'eventType': 'source_observed',
      'occurredAt': null,
      'occurredAtStatus': 'unknown',
      'sourceSystem': 'monitoring',
      'summary': 'Kaynak olayı',
      'evidenceReferenceCount': 2,
    },
  ],
  'relationshipGraph': {
    'nodes': [
      {
        'canonicalId': 'brand-1',
        'type': 'brand',
        'maskedLabel': 'Ma***an',
        'sourceSystem': 'monitoring',
        'confidence': .8,
        'evidenceQuality': 'corroborated',
      },
    ],
    'edges': [],
  },
  'adapterVersion': 'risk-operations-read-adapter-v1',
};

Widget app(RiskOperationsRepository repository) =>
    MaterialApp(home: RiskOperationsConsolePage(repository: repository));

void main() {
  test('response model rejects a non-read-only contract', () {
    expect(
      () => RiskOperationsPageResult.fromMap({
        ...responseMap(),
        'writesPerformed': 1,
      }),
      throwsFormatException,
    );
  });

  testWidgets('shows loading then empty state', (tester) async {
    final completer = Completer<RiskOperationsPageResult>();
    await tester.pumpWidget(app(FakeRepository((_) => completer.future)));
    expect(
      find.byKey(const ValueKey('risk-operations-loading')),
      findsOneWidget,
    );
    completer.complete(RiskOperationsPageResult.fromMap(responseMap()));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('risk-operations-empty')), findsOneWidget);
  });

  testWidgets('shows error, permission and no-tenant states', (tester) async {
    await tester.pumpWidget(
      app(FakeRepository((_) async => throw StateError('failed'))),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('risk-operations-error')), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      app(
        FakeRepository(
          (_) async => throw FirebaseFunctionsException(
            code: 'permission-denied',
            message: 'denied',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('risk-operations-permission-denied')),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      app(
        FakeRepository(
          (_) async => throw FirebaseFunctionsException(
            code: 'failed-precondition',
            message: 'no active tenant',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('risk-operations-no-tenant')),
      findsOneWidget,
    );
  });

  testWidgets(
    'renders filters, projection, evidence, candidacy, timeline and masked relationship',
    (tester) async {
      final result = RiskOperationsPageResult.fromMap(
        responseMap(items: [itemMap()], partial: true),
      );
      await tester.pumpWidget(app(FakeRepository((_) async => result)));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('risk-operations-filters')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('risk-operations-partial-source')),
        findsOneWidget,
      );
      expect(find.text('Şüpheli ilan sinyali'), findsOneWidget);
      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Şüpheli ilan sinyali'));
      await tester.pumpAndSettle();
      expect(find.text('Delil kalitesi: corroborated'), findsOneWidget);
      expect(find.text('Vaka adaylığı: review_candidate'), findsOneWidget);
      expect(find.text('Zaman bilinmiyor'), findsOneWidget);
      expect(find.text('Ma***an'), findsOneWidget);
      expect(find.textContaining('hukuki geçerlilik'), findsOneWidget);
    },
  );

  testWidgets('risk and date filters are exposed and query server', (
    tester,
  ) async {
    var calls = 0;
    RiskOperationsQuery? latest;
    await tester.pumpWidget(
      app(
        FakeRepository((query) async {
          calls++;
          latest = query;
          return RiskOperationsPageResult.fromMap(responseMap());
        }),
      ),
    );
    await tester.pumpAndSettle();
    final dropdowns = find.byType(DropdownButtonFormField<String>);
    expect(dropdowns, findsNWidgets(5));
    await tester.tap(dropdowns.at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('counterfeit').last);
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(latest?.riskClass, 'counterfeit');
    expect(
      find.byKey(const ValueKey('risk-operations-date-from')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('risk-operations-date-to')),
      findsOneWidget,
    );
  });

  testWidgets('pagination token triggers the next read-only query', (
    tester,
  ) async {
    final queries = <RiskOperationsQuery>[];
    await tester.pumpWidget(
      app(
        FakeRepository((query) async {
          queries.add(query);
          return RiskOperationsPageResult.fromMap(
            responseMap(
              items: [itemMap()],
              nextPageToken: queries.length == 1 ? 'safe-cursor' : null,
            ),
          );
        }),
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('risk-operations-next-page')));
    await tester.pumpAndSettle();
    expect(queries, hasLength(2));
    expect(queries.last.pageToken, 'safe-cursor');
  });
}

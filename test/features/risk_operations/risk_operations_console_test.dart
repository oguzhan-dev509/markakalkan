import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markakalkan/features/risk_operations/data/risk_operations_models.dart';
import 'package:markakalkan/features/risk_operations/data/risk_operations_lifecycle.dart';
import 'package:markakalkan/features/risk_operations/data/risk_operations_repository.dart';
import 'package:markakalkan/features/risk_operations/presentation/risk_operations_console_page.dart';

class FakeRepository implements RiskOperationsRepository {
  FakeRepository(this.response);
  final Future<RiskOperationsPageResult> Function(
    RiskOperationsQuery,
    RiskOperationsReadDiagnostics,
  )
  response;
  @override
  Future<RiskOperationsPageResult> list(
    RiskOperationsQuery query,
    RiskOperationsReadDiagnostics diagnostics,
  ) => response(query, diagnostics);
}

class DeterministicIds extends RiskOperationsLifecycleProvider {
  DeterministicIds()
    : super(
        nextId: _next,
        browserContext: const RiskOperationsBrowserContext(),
      );
  static int _value = 0;
  static String _next() => 'diagnostic-${++_value}';
}

class RecordingRepository implements RiskOperationsRepository {
  RecordingRepository({this.result, this.error, this.pending});
  final RiskOperationsPageResult? result;
  final Object? error;
  final Completer<RiskOperationsPageResult>? pending;
  final queries = <RiskOperationsQuery>[];
  final diagnostics = <RiskOperationsReadDiagnostics>[];

  @override
  Future<RiskOperationsPageResult> list(
    RiskOperationsQuery query,
    RiskOperationsReadDiagnostics diagnostic,
  ) async {
    queries.add(query);
    diagnostics.add(diagnostic);
    if (error != null) throw error!;
    if (pending != null) return pending!.future;
    return result ?? RiskOperationsPageResult.fromMap(responseMap());
  }
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

Widget app(RiskOperationsRepository repository) => MaterialApp(
  home: RiskOperationsConsolePage(
    navigationRequestId: 'navigation-test',
    routeEntryCause: RiskOperationsRouteEntryCause.corporateHubCard,
    repository: repository,
    lifecycleProvider: DeterministicIds(),
  ),
);

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
    await tester.pumpWidget(app(FakeRepository((_, _) => completer.future)));
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
      app(FakeRepository((_, _) async => throw StateError('failed'))),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('risk-operations-error')), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      app(
        FakeRepository(
          (_, _) async => throw FirebaseFunctionsException(
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
          (_, _) async => throw FirebaseFunctionsException(
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
      await tester.pumpWidget(app(FakeRepository((_, _) async => result)));
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
      expect(
        find.text('Delil kalitesi: Birden Fazla Kaynakla Desteklenmiş'),
        findsOneWidget,
      );
      expect(find.text('Vaka adaylığı: İnceleme Adayı'), findsOneWidget);
      expect(find.text('Durum: Yeni'), findsOneWidget);
      expect(find.text('Kaynakta Gözlemlendi · İzleme'), findsOneWidget);
      expect(
        find.text('Marka · İzleme · Birden Fazla Kaynakla Desteklenmiş'),
        findsOneWidget,
      );
      expect(find.textContaining('marketplace_abuse'), findsNothing);
      expect(find.textContaining('review_candidate'), findsNothing);
      expect(find.textContaining('Zaman bilinmiyor'), findsOneWidget);
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
        FakeRepository((query, _) async {
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
    await tester.tap(find.text('Sahtecilik').last);
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
        FakeRepository((query, _) async {
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

  testWidgets('initial mount is exactly one call and rebuilds add none', (
    tester,
  ) async {
    final repository = RecordingRepository();
    var stateInstances = 0;
    final ids = DeterministicIds();
    Widget page({double width = 900}) => MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: Size(width, 700)),
        child: RiskOperationsConsolePage(
          navigationRequestId: 'navigation-test',
          routeEntryCause: RiskOperationsRouteEntryCause.corporateHubCard,
          repository: repository,
          lifecycleProvider: ids,
          onStateCreated: () => stateInstances++,
        ),
      ),
    );
    await tester.pumpWidget(page());
    await tester.pumpAndSettle();
    expect(stateInstances, 1);
    expect(repository.diagnostics, hasLength(1));
    expect(
      repository.diagnostics.single.trigger,
      RiskOperationsLoadTrigger.initialMount,
    );
    expect(repository.diagnostics.single.attemptSequence, 1);
    await tester.pump();
    await tester.pumpWidget(page(width: 520));
    await tester.pumpAndSettle();
    expect(stateInstances, 1);
    expect(repository.diagnostics, hasLength(1));
  });

  testWidgets('external Auth and App Check style emissions do not reload', (
    tester,
  ) async {
    final repository = RecordingRepository();
    final authEmission = ValueNotifier<int>(0);
    final appCheckEmission = ValueNotifier<int>(0);
    await tester.pumpWidget(
      MaterialApp(
        home: ValueListenableBuilder<int>(
          valueListenable: authEmission,
          builder: (_, _, _) => ValueListenableBuilder<int>(
            valueListenable: appCheckEmission,
            builder: (_, _, _) => RiskOperationsConsolePage(
              navigationRequestId: 'navigation-test',
              routeEntryCause: RiskOperationsRouteEntryCause.corporateHubCard,
              repository: repository,
              lifecycleProvider: DeterministicIds(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    authEmission.value++;
    await tester.pump();
    appCheckEmission.value++;
    await tester.pump();
    expect(repository.diagnostics, hasLength(1));
  });

  testWidgets('filter actions are cardinal and carry exact triggers', (
    tester,
  ) async {
    final repository = RecordingRepository();
    await tester.pumpWidget(app(repository));
    await tester.pumpAndSettle();
    final dropdowns = find.byType(DropdownButtonFormField<String>);
    await tester.tap(dropdowns.first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tümü').last);
    await tester.pumpAndSettle();
    expect(repository.diagnostics, hasLength(1));
    await tester.tap(dropdowns.at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sahtecilik').last);
    await tester.pumpAndSettle();
    expect(repository.diagnostics, hasLength(2));
    expect(
      repository.diagnostics.last.trigger,
      RiskOperationsLoadTrigger.filterChange,
    );
    expect(repository.diagnostics.last.attemptSequence, 2);
  });

  testWidgets('refresh and error retry carry exact triggers', (tester) async {
    final repository = RecordingRepository();
    await tester.pumpWidget(app(repository));
    await tester.pumpAndSettle();
    final refresh = tester
        .state<RefreshIndicatorState>(find.byType(RefreshIndicator))
        .show();
    await tester.pumpAndSettle();
    await refresh;
    expect(
      repository.diagnostics.last.trigger,
      RiskOperationsLoadTrigger.pullToRefresh,
    );

    final failed = RecordingRepository(error: StateError('failed'));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(app(failed));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yeniden dene'));
    await tester.pumpAndSettle();
    expect(failed.diagnostics, hasLength(2));
    expect(
      failed.diagnostics.last.trigger,
      RiskOperationsLoadTrigger.errorRetry,
    );
  });

  testWidgets('date change carries exact trigger', (tester) async {
    final repository = RecordingRepository();
    await tester.pumpWidget(app(repository));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('risk-operations-date-from')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('20').last);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(repository.diagnostics, hasLength(2));
    expect(
      repository.diagnostics.last.trigger,
      RiskOperationsLoadTrigger.dateChange,
    );
  });

  testWidgets('pagination carries exact trigger and next sequence', (
    tester,
  ) async {
    final result = RiskOperationsPageResult.fromMap(
      responseMap(items: [itemMap()], nextPageToken: 'safe-cursor'),
    );
    final repository = RecordingRepository(result: result);
    await tester.pumpWidget(app(repository));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('risk-operations-next-page')));
    await tester.pump();
    expect(repository.diagnostics, hasLength(2));
    expect(
      repository.diagnostics.last.trigger,
      RiskOperationsLoadTrigger.pagination,
    );
    expect(repository.diagnostics.last.attemptSequence, 2);
  });

  testWidgets('completion after dispose neither reloads nor sets state', (
    tester,
  ) async {
    final completer = Completer<RiskOperationsPageResult>();
    final repository = RecordingRepository(pending: completer);
    await tester.pumpWidget(app(repository));
    expect(repository.diagnostics, hasLength(1));
    await tester.pumpWidget(const SizedBox.shrink());
    completer.complete(RiskOperationsPageResult.fromMap(responseMap()));
    await tester.pump();
    expect(repository.diagnostics, hasLength(1));
    expect(tester.takeException(), isNull);
  });
}

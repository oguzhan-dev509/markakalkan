import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markakalkan/features/risk_operations/data/risk_operations_models.dart';
import 'package:markakalkan/features/risk_operations/data/risk_operations_lifecycle.dart';
import 'package:markakalkan/features/risk_operations/data/risk_operations_repository.dart';
import 'package:markakalkan/features/risk_operations/data/shared_risk_promotion_service.dart';
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
  'projectionFingerprint':
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
};

Map<String, dynamic> traceabilityItemMap() => {
  ...itemMap(),
  'signalId': 'signal-traceability',
  'sourceSystem': 'traceability',
  'riskClass': 'traceability_anomaly',
  'severity': 'medium',
  'summary': 'repeat_scan_observed, rapid_repeat_scan',
  'currentStatus': 'escalated',
  'occurredAt': '2026-07-16T13:19:00.000Z',
  'evidenceQuality': {
    'level': 'verified_primary',
    'reasonCodes': ['evidence.primary_verified'],
    'evaluatorVersion': 'risk-operations-evaluator-v1',
  },
  'caseCandidacy': {
    'status': 'review_candidate',
    'reasonCodes': ['case.human_review_threshold'],
    'evaluatedAt': '2026-07-16T13:20:00.000Z',
    'evaluatorVersion': 'risk-operations-evaluator-v1',
    'requiresHumanReview': true,
  },
  'timeline': [
    {
      'eventId': 'event-traceability',
      'eventType': 'source_observed',
      'occurredAt': '2026-07-16T13:19:00.000Z',
      'occurredAtStatus': 'known',
      'sourceSystem': 'traceability',
      'summary': 'rapid_repeat_scan',
      'evidenceReferenceCount': 1,
    },
  ],
  'relationshipGraph': {
    'nodes': [
      {
        'canonicalId': 'brand-1',
        'type': 'brand',
        'maskedLabel': 'Ma***an',
        'sourceSystem': 'traceability',
        'confidence': .8,
        'evidenceQuality': 'verified_primary',
      },
    ],
    'edges': [],
  },
};

Widget app(RiskOperationsRepository repository) => MaterialApp(
  home: RiskOperationsConsolePage(
    navigationRequestId: 'navigation-test',
    routeEntryCause: RiskOperationsRouteEntryCause.corporateHubCard,
    repository: repository,
    lifecycleProvider: DeterministicIds(),
  ),
);

class FakePromotionService implements SharedRiskPromotionService {
  int calls = 0;
  @override
  Future<SharedRiskPromotionResult> promote(RiskOperationItem item) async {
    calls += 1;
    return const SharedRiskPromotionResult(SharedRiskPromotionOutcome.created);
  }
}

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

  testWidgets('human approval is Turkish, confirmed once and session locked', (
    tester,
  ) async {
    final promotion = FakePromotionService();
    await tester.pumpWidget(
      MaterialApp(
        home: RiskOperationsConsolePage(
          navigationRequestId: 'promotion-navigation',
          routeEntryCause: RiskOperationsRouteEntryCause.corporateHubCard,
          repository: RecordingRepository(
            result: RiskOperationsPageResult.fromMap(
              responseMap(items: [itemMap()]),
            ),
          ),
          lifecycleProvider: DeterministicIds(),
          promotionService: promotion,
          enablePromotion: true,
          promotionAuthReady: true,
          promotionAppCheckReady: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).first, const Offset(0, -500));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Şüpheli ilan sinyali'));
    await tester.pumpAndSettle();
    expect(find.text('Ortak risk kaydı oluştur'), findsOneWidget);
    await tester.drag(find.byType(ListView).first, const Offset(0, -700));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ortak risk kaydı oluştur'));
    await tester.pumpAndSettle();
    expect(find.textContaining('gerçek vaka dosyası açmaz'), findsOneWidget);
    expect(find.textContaining('hukuki hüküm oluşturmaz'), findsOneWidget);
    await tester.tap(find.text('Onayla ve oluştur'));
    await tester.pumpAndSettle();
    expect(promotion.calls, 1);
    expect(find.text('Ortak risk kaydı oluşturuldu.'), findsOneWidget);
    final button = tester.widget<FilledButton>(find.byType(FilledButton).last);
    expect(button.onPressed, isNull);
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

  testWidgets('every dropdown renders Turkish labels', (tester) async {
    final groups = <int, List<String>>{
      0: ['İzleme', 'İzlenebilirlik', 'Dijital Dedektif', 'Ortak Risk'],
      1: [
        'Sahtecilik',
        'İzlenebilirlik Anomalisi',
        'Dijital Pazar İhlali',
        'Kimlik Riski',
        'Güvenlik Riski',
        'Diğer',
      ],
      2: ['Bilgilendirme', 'Düşük', 'Orta', 'Yüksek', 'Kritik'],
      3: [
        'Doğrulanmış Birincil Delil',
        'Birden Fazla Kaynakla Desteklenmiş',
        'Tek Kaynak',
        'Yetersiz Delil',
        'Değerlendirilemiyor',
      ],
      4: [
        'Vaka Adayı Değil',
        'İnceleme Adayı',
        'Güçlü Vaka Adayı',
        'Yetersiz Delil Nedeniyle Engelli',
      ],
    };
    for (final entry in groups.entries) {
      await tester.pumpWidget(
        app(
          FakeRepository(
            (_, _) async => RiskOperationsPageResult.fromMap(responseMap()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final dropdowns = find.byType(DropdownButtonFormField<String>);
      await tester.tap(dropdowns.at(entry.key));
      await tester.pumpAndSettle();
      for (final label in entry.value) {
        expect(find.text(label), findsWidgets);
      }
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    }
  });

  testWidgets('Turkish filter labels preserve canonical request values', (
    tester,
  ) async {
    final repository = RecordingRepository();
    await tester.pumpWidget(app(repository));
    await tester.pumpAndSettle();
    var dropdowns = find.byType(DropdownButtonFormField<String>);
    await tester.tap(dropdowns.at(2));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Orta').last);
    await tester.pumpAndSettle();
    expect(repository.queries.last.severity, 'medium');
    dropdowns = find.byType(DropdownButtonFormField<String>);
    await tester.tap(dropdowns.at(4));
    await tester.pumpAndSettle();
    await tester.tap(find.text('İnceleme Adayı').last);
    await tester.pumpAndSettle();
    expect(repository.queries.last.severity, 'medium');
    expect(repository.queries.last.caseCandidacy, 'review_candidate');
  });

  testWidgets('rendered console contains no raw snake case presentation text', (
    tester,
  ) async {
    final result = RiskOperationsPageResult.fromMap(
      responseMap(items: [traceabilityItemMap()]),
    );
    await tester.pumpWidget(app(FakeRepository((_, _) async => result)));
    await tester.pumpAndSettle();
    expect(
      find.text('İzlenebilirlik · İzlenebilirlik Anomalisi · Orta'),
      findsOneWidget,
    );
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Şüpheli ilan sinyali'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Tekrarlanan Tarama Tespit Edildi · Kısa Sürede Tekrarlanan Tarama',
      ),
      findsOneWidget,
    );
    expect(
      find.text('Delil kalitesi: Doğrulanmış Birincil Delil'),
      findsOneWidget,
    );
    expect(find.text('Vaka adaylığı: İnceleme Adayı'), findsOneWidget);
    expect(find.text('Durum: Üst İncelemeye Aktarıldı'), findsOneWidget);
    expect(find.text('• Birincil Delil Doğrulandı'), findsOneWidget);
    expect(find.text('• İnsan İncelemesi Eşiğine Ulaştı'), findsOneWidget);
    expect(find.text('Kaynakta Gözlemlendi · İzlenebilirlik'), findsOneWidget);
    expect(
      find.text('Marka · İzlenebilirlik · Doğrulanmış Birincil Delil'),
      findsOneWidget,
    );
    expect(find.textContaining('16 Temmuz 2026, 16:19'), findsWidgets);
    final visibleText = tester
        .widgetList<Text>(find.byType(Text))
        .map((widget) => widget.data ?? '')
        .where((text) => text.isNotEmpty)
        .join('\n');
    expect(RegExp(r'\b[a-z]+(?:_[a-z]+)+\b').hasMatch(visibleText), isFalse);
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

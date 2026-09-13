import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markakalkan/features/odla/data/odla_workspace_repository.dart';
import 'package:markakalkan/features/odla/presentation/odla_workspace_page.dart';

void main() {
  test('ODLA UI remains routed and strictly read-only', () {
    final hub = File(
      'lib/features/dashboard/presentation/corporate_hub_page.dart',
    ).readAsStringSync();
    final router = File('lib/app/router.dart').readAsStringSync();
    final page = File(
      'lib/features/odla/presentation/odla_workspace_page.dart',
    ).readAsStringSync();
    final repository = File(
      'lib/features/odla/data/odla_workspace_repository.dart',
    ).readAsStringSync();

    expect(hub, contains("id: 'odla'"));
    expect(hub, contains("'odla-workspace-action'"));
    expect(router, contains('openOdlaWorkspace'));
    expect(router, contains("RouteSettings(name: '/odla')"));

    expect(repository, contains('getOdlaVerificationWorkspace'));
    expect(repository, isNot(contains('cloud_firestore')));
    expect(page, isNot(contains('cloud_firestore')));

    const forbidden = <String>[
      'createOdlaVerificationCase',
      'appendOdlaChainOfCustodyEvent',
      'createOdlaTestRequest',
      'recordOdlaTestResult',
      'adjudicateOdlaFinding',
      'openOdlaAppeal',
      'resolveOdlaAppeal',
    ];
    for (final name in forbidden) {
      expect(page, isNot(contains(name)), reason: '$name UI içinde olmamalı');
      expect(
        repository,
        isNot(contains(name)),
        reason: '$name repository içinde olmamalı',
      );
    }
  });

  test(
    'ODLA UI exposes full operational read workspace and responsive shell',
    () {
      final page = File(
        'lib/features/odla/presentation/odla_workspace_page.dart',
      ).readAsStringSync();
      final repository = File(
        'lib/features/odla/data/odla_workspace_repository.dart',
      ).readAsStringSync();

      for (final title in <String>[
        'ODLA Operasyon Merkezi',
        'Delil Zinciri',
        'Test Talepleri',
        'Test Sonuçları',
        'Bulgular',
        'İtirazlar',
        'Yetki kapsamı',
        'Salt okunur',
      ]) {
        expect(page, contains(title), reason: '$title görünümü eksik');
      }

      for (final token in <String>[
        'LayoutBuilder',
        'RefreshIndicator',
        '_OperationalWorkspace',
        '_RichEmptyState',
        '_OperationalCounters',
      ]) {
        expect(
          page,
          contains(token),
          reason: '$token responsive UI sözleşmesinde eksik',
        );
      }

      for (final token in <String>[
        'OdlaCustodyEvent',
        'OdlaTestRequest',
        'OdlaTestResult',
        'OdlaFinding',
        'OdlaAppeal',
        'custodyEvents',
        'testRequests',
        'testResults',
        'findings',
        'appeals',
        'odla-workspace-detail-v1',
      ]) {
        expect(
          repository,
          contains(token),
          reason: '$token typed model sözleşmesinde eksik',
        );
      }
    },
  );

  testWidgets(
    'desktop rich empty state renders authorization context without exceptions',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final repository = _FakeOdlaWorkspaceRepository(
        discovery: _discovery(cases: const <Object?>[]),
        detail: _detail(),
      );

      await tester.pumpWidget(_app(repository));
      await tester.pumpAndSettle();

      expect(find.text('ODLA Operasyon Merkezi'), findsOneWidget);
      expect(find.text('ODLA hazır — görüntülenebilir vaka henüz yok'), findsOneWidget);
      expect(find.text('Doğrulama akışı'), findsOneWidget);
      expect(find.text('Yetkili inceleyici'), findsOneWidget);
      expect(find.text('Salt okunur'), findsOneWidget);
      expect(find.text('Yetki kapsamı'), findsOneWidget);
      expect(find.text('Delil Zinciri'), findsOneWidget);
      expect(find.text('Laboratuvar'), findsOneWidget);
      expect(find.text('Bulgu'), findsOneWidget);
      expect(find.text('İtiraz'), findsOneWidget);
      _expectNoRenderException(tester);
    },
  );

  testWidgets(
    'mobile rich empty state renders without overflow',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final repository = _FakeOdlaWorkspaceRepository(
        discovery: _discovery(cases: const <Object?>[]),
        detail: _detail(),
      );

      await tester.pumpWidget(_app(repository));
      await tester.pumpAndSettle();

      expect(find.text('ODLA Operasyon Merkezi'), findsOneWidget);
      expect(find.text('Yetkili inceleyici'), findsOneWidget);

      final emptyStateTitle =
          find.text('ODLA hazır — görüntülenebilir vaka henüz yok');
      await tester.scrollUntilVisible(
        emptyStateTitle,
        260,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(emptyStateTitle, findsOneWidget);
      _expectNoRenderException(tester);
    },
  );

  testWidgets(
    'case card tap opens detail and renders all five operational domains',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final repository = _FakeOdlaWorkspaceRepository(
        discovery: _discovery(cases: <Object?>[_caseMap()]),
        detail: _detail(),
      );

      await tester.pumpWidget(_app(repository));
      await tester.pumpAndSettle();

      final caseFinder = find.byKey(const ValueKey('odla-case-c1'));
      expect(caseFinder, findsOneWidget);
      expect(find.text('Vaka c1'), findsOneWidget);
      _expectNoRenderException(tester);

      await tester.tap(caseFinder);
      await tester.pumpAndSettle();

      expect(repository.workspaceCalls, 1);
      expect(find.text('Vaka Operasyon Görünümü'), findsOneWidget);

      for (final title in <String>[
        'Delil Zinciri',
        'Test Talepleri',
        'Test Sonuçları',
        'Bulgular',
        'İtirazlar',
      ]) {
        expect(find.text(title), findsWidgets, reason: '$title render edilmedi');
      }

      for (final recordTitle in <String>[
        'sample_received',
        'AUTHENTICITY',
        'AUTHENTIC',
        'SECOND_LAB',
      ]) {
        expect(
          find.text(recordTitle),
          findsWidgets,
          reason: '$recordTitle operasyon kaydı render edilmedi',
        );
      }

      for (final label in <String>[
        'Delil zinciri',
        'Test talebi',
        'Test sonucu',
        'Bulgu',
        'İtiraz',
      ]) {
        final labelFinder = find.text(label);
        expect(labelFinder, findsOneWidget);
        final counterCard = find.ancestor(
          of: labelFinder,
          matching: find.byType(Card),
        );
        expect(counterCard, findsOneWidget);
        expect(
          find.descendant(of: counterCard, matching: find.text('1')),
          findsOneWidget,
          reason: '$label sayacı 1 olmalı',
        );
      }
      expect(find.textContaining('read_workspace'), findsOneWidget);
      _expectNoRenderException(tester);
    },
  );

  testWidgets(
    'mobile case detail renders operational workspace without overflow',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final repository = _FakeOdlaWorkspaceRepository(
        discovery: _discovery(cases: <Object?>[_caseMap()]),
        detail: _detail(),
      );

      await tester.pumpWidget(_app(repository));
      await tester.pumpAndSettle();

      final caseFinder = find.byKey(const ValueKey('odla-case-c1'));
      await tester.scrollUntilVisible(
        caseFinder,
        260,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(caseFinder, findsOneWidget);

      await tester.tap(caseFinder);
      await tester.pumpAndSettle();

      expect(find.text('Vaka Operasyon Görünümü'), findsOneWidget);

      for (final title in <String>[
        'Delil Zinciri',
        'Test Talepleri',
        'Test Sonuçları',
        'Bulgular',
        'İtirazlar',
      ]) {
        final sectionFinder = find.text(title);
        await tester.scrollUntilVisible(
          sectionFinder,
          260,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        expect(
          sectionFinder,
          findsWidgets,
          reason: '$title mobil detayda görünür olmalı',
        );
      }

      _expectNoRenderException(tester);
    },
  );

  testWidgets(
    'refresh button re-reads discovery using the injected repository',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(900, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final repository = _FakeOdlaWorkspaceRepository(
        discovery: _discovery(cases: const <Object?>[]),
        detail: _detail(),
      );

      await tester.pumpWidget(_app(repository));
      await tester.pumpAndSettle();
      expect(repository.discoveryCalls, 1);

      await tester.tap(find.byTooltip('Yenile'));
      await tester.pumpAndSettle();

      expect(repository.discoveryCalls, 2);
      _expectNoRenderException(tester);
    },
  );

  testWidgets(
    'permission error renders fail-closed ODLA error state',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(900, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final repository = _FakeOdlaWorkspaceRepository(
        discovery: _discovery(cases: const <Object?>[]),
        detail: _detail(),
        discoveryError: StateError('permission-denied'),
      );

      await tester.pumpWidget(_app(repository));
      await tester.pumpAndSettle();

      expect(find.text('ODLA çalışma alanı açılamadı'), findsOneWidget);
      expect(
        find.text('Bu ODLA çalışma alanı için yetkiniz bulunmuyor.'),
        findsOneWidget,
      );
      expect(find.text('Tekrar dene'), findsOneWidget);
      _expectNoRenderException(tester);
    },
  );
}

Widget _app(OdlaWorkspaceRepository repository) {
  return MaterialApp(
    theme: ThemeData(useMaterial3: true),
    home: OdlaWorkspacePage(repository: repository),
  );
}

void _expectNoRenderException(WidgetTester tester) {
  final exception = tester.takeException();
  expect(
    exception,
    isNull,
    reason: 'Widget render/overflow exception detected: $exception',
  );
}

Map<String, Object?> _discovery({required List<Object?> cases}) {
  return <String, Object?>{
    'contractVersion': odlaDiscoveryContractVersion,
    'mode': 'discovery',
    'tenantId': 'tenant-odla-1',
    'brandUids': <Object?>['brand-1'],
    'roles': <Object?>['authorized_reviewer'],
    'count': cases.length,
    'cases': cases,
  };
}

Map<String, Object?> _caseMap() {
  return <String, Object?>{
    'caseId': 'c1',
    'tenantId': 'tenant-odla-1',
    'brandUid': 'brand-1',
    'state': 'verification_in_progress',
    'profileCode': 'electronics',
    'profileVersion': 3,
    'productClassCode': 'ELEC',
    'countryCode': 'TR',
  };
}

Map<String, Object?> _detail() {
  return <String, Object?>{
    'contractVersion': odlaDetailContractVersion,
    'case': <String, Object?>{
      'caseId': 'c1',
      'tenantId': 'tenant-odla-1',
      'brandUid': 'brand-1',
      'state': 'verification_in_progress',
      'countryCode': 'TR',
      'profileCode': 'electronics',
      'profileVersion': 3,
      'productClassCode': 'ELEC',
    },
    'custodyEvents': <Object?>[
      <String, Object?>{
        'eventId': 'e1',
        'eventSequence': 1,
        'sampleId': 's1',
        'eventType': 'sample_received',
        'occurredAt': '2026-09-13T08:00:00Z',
        'actorType': 'laboratory',
        'locationCode': 'TR-34',
        'sealId': 'seal-1',
        'evidenceRefs': <Object?>['evidence-1'],
        'appendOnly': true,
      },
    ],
    'testRequests': <Object?>[
      <String, Object?>{
        'testRequestId': 'q1',
        'requestSequence': 1,
        'sampleId': 's1',
        'laboratoryId': 'lab-1',
        'testQuestionCode': 'AUTHENTICITY',
        'methodCode': 'M-1',
        'state': 'testing',
      },
    ],
    'testResults': <Object?>[
      <String, Object?>{
        'testResultId': 'r1',
        'testRequestId': 'q1',
        'sampleId': 's1',
        'laboratoryId': 'lab-1',
        'laboratoryReportId': 'report-1',
        'methodCode': 'M-1',
        'resultCode': 'MATCH',
        'resultSummaryCode': 'AUTHENTIC',
        'custodyIntegrityVerified': true,
        'referenceIntegrityVerified': true,
        'reportSha256': 'abc123',
      },
    ],
    'findings': <Object?>[
      <String, Object?>{
        'findingId': 'f1',
        'findingVersion': 1,
        'findingCode': 'AUTHENTIC',
        'confidenceBand': 'HIGH',
        'reasonCodes': <Object?>['LAB_MATCH'],
      },
    ],
    'appeals': <Object?>[
      <String, Object?>{
        'appealId': 'a1',
        'appealSequence': 1,
        'appellantType': 'brand',
        'challengedFindingId': 'f1',
        'requestedRemedyCode': 'SECOND_LAB',
        'reserveSampleId': 's2',
        'secondLaboratoryId': 'lab-2',
        'state': 'second_lab_in_progress',
      },
    ],
  };
}

final class _FakeOdlaWorkspaceRepository implements OdlaWorkspaceRepository {
  _FakeOdlaWorkspaceRepository({
    required Map<String, Object?> discovery,
    required Map<String, Object?> detail,
    this.discoveryError,
  })  : _discovery = discovery,
        _detail = detail;

  final Map<String, Object?> _discovery;
  final Map<String, Object?> _detail;
  final Object? discoveryError;

  int discoveryCalls = 0;
  int workspaceCalls = 0;

  @override
  Future<OdlaDiscoverySnapshot> loadDiscovery() async {
    discoveryCalls += 1;
    final error = discoveryError;
    if (error != null) {
      return Future<OdlaDiscoverySnapshot>.error(error);
    }
    await Future<void>.delayed(Duration.zero);
    return OdlaDiscoverySnapshot.fromMap(_discovery);
  }

  @override
  Future<OdlaWorkspaceDetail> loadWorkspace(OdlaCaseSummary summary) async {
    workspaceCalls += 1;
    await Future<void>.delayed(Duration.zero);
    return OdlaWorkspaceDetail.fromMap(_detail);
  }
}

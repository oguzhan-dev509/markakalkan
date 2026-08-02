import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markakalkan/features/intervention_legal/data/intervention_legal_workspace_repository.dart';
import 'package:markakalkan/features/intervention_legal/presentation/intervention_legal_hub_page.dart';

void main() {
  testWidgets(
    'hub renders the live legal matter and immutable approval chain',
    (tester) async {
      await _setDeterministicTestSurface(tester);
      final repository = _FakeWorkspaceRepository(_snapshot());

      await tester.pumpWidget(
        MaterialApp(home: InterventionLegalHubPage(repository: repository)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Müdahale ve Hukuk'), findsOneWidget);
      expect(
        find.text('Doğrulanmış vakadan denetlenebilir hukuki müdahaleye'),
        findsOneWidget,
      );
      final totalMatterLabel = find.text('Toplam dosya', skipOffstage: false);
      await tester.scrollUntilVisible(totalMatterLabel, 300);
      expect(totalMatterLabel, findsOneWidget);
      expect(find.text('Bekleyen onay', skipOffstage: false), findsOneWidget);

      final liveMatterTitle = find.text(
        'Canlı hukuki dosya',
        skipOffstage: false,
      );
      await tester.scrollUntilVisible(liveMatterTitle, 300);
      expect(liveMatterTitle, findsOneWidget);

      await tester.tap(liveMatterTitle);
      await tester.pumpAndSettle();

      expect(find.text('Müşteri işlem yetkilendirmesi'), findsOneWidget);
      expect(find.textContaining('Onaylandı · Talep sürümü 2'), findsOneWidget);
      expect(find.text('Değiştirilemez kararlar'), findsOneWidget);
      expect(find.textContaining('Değiştirilemez kayıt'), findsOneWidget);
    },
  );

  testWidgets('hub renders a deterministic empty state', (tester) async {
    await _setDeterministicTestSurface(tester);
    final repository = _FakeWorkspaceRepository(
      InterventionLegalWorkspaceSnapshot(
        generatedAt: DateTime.utc(2026, 8, 1, 18, 48),
        limit: 20,
        authorityScopeCount: 1,
        counts: const InterventionLegalWorkspaceCounts(
          legalMatterCount: 0,
          activeLegalMatterCount: 0,
          pendingApprovalCount: 0,
          approvedApprovalCount: 0,
          rejectedApprovalCount: 0,
        ),
        matters: const [],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(home: InterventionLegalHubPage(repository: repository)),
    );
    await tester.pumpAndSettle();

    final emptyState = find.byKey(
      const ValueKey<String>('intervention-legal-empty'),
      skipOffstage: false,
    );
    await tester.scrollUntilVisible(emptyState, 300);

    expect(
      find.byKey(const ValueKey<String>('intervention-legal-empty')),
      findsOneWidget,
    );
    expect(find.text('Henüz hukuki dosya bulunmuyor.'), findsOneWidget);
  });

  testWidgets(
    'hub waits for reactive authentication and follows sign-in and sign-out',
    (tester) async {
      await _setDeterministicTestSurface(tester);
      final authenticationChanges = StreamController<bool>.broadcast();
      addTearDown(authenticationChanges.close);
      final repository = _CountingWorkspaceRepository(_snapshot());

      await tester.pumpWidget(
        MaterialApp(
          home: InterventionLegalHubPage(
            repository: repository,
            authenticationChanges: authenticationChanges.stream,
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(repository.callCount, 0);

      authenticationChanges.add(false);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('intervention-legal-auth-required')),
        findsOneWidget,
      );
      expect(find.text('Marka Girişi'), findsOneWidget);
      expect(find.text('Yeniden dene'), findsOneWidget);
      expect(repository.callCount, 0);

      authenticationChanges.add(true);
      await tester.pumpAndSettle();

      expect(find.text('Canlı hukuki dosya'), findsOneWidget);
      expect(repository.callCount, 1);

      authenticationChanges.add(false);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('intervention-legal-auth-required')),
        findsOneWidget,
      );
      expect(find.text('Canlı hukuki dosya'), findsNothing);
    },
  );

  testWidgets('Marka Girişi action reloads after reactive sign-in', (
    tester,
  ) async {
    await _setDeterministicTestSurface(tester);
    final authenticationChanges = StreamController<bool>.broadcast();
    addTearDown(authenticationChanges.close);
    final repository = _CountingWorkspaceRepository(_snapshot());
    var loginCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: InterventionLegalHubPage(
          repository: repository,
          authenticationChanges: authenticationChanges.stream,
          loginOpener: (_) async {
            loginCalls += 1;
            authenticationChanges.add(true);
            return true;
          },
          authenticationResolver: (_) async => true,
        ),
      ),
    );
    await tester.pump();

    authenticationChanges.add(false);
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey<String>('intervention-legal-login-action')),
    );
    await tester.pumpAndSettle();

    expect(loginCalls, 1);
    expect(repository.callCount, 1);
    expect(find.text('Canlı hukuki dosya'), findsOneWidget);
  });

  testWidgets(
    'login completion reconciles auth when the stream misses the sign-in event',
    (tester) async {
      await _setDeterministicTestSurface(tester);
      final authenticationChanges = StreamController<bool>.broadcast();
      addTearDown(authenticationChanges.close);
      final repository = _CountingWorkspaceRepository(_snapshot());
      var loginCalls = 0;
      var resolverCalls = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: InterventionLegalHubPage(
            repository: repository,
            authenticationChanges: authenticationChanges.stream,
            loginOpener: (_) async {
              loginCalls += 1;
              return true;
            },
            authenticationResolver: (forceRefresh) async {
              resolverCalls += 1;
              expect(forceRefresh, isTrue);
              return true;
            },
          ),
        ),
      );
      await tester.pump();

      authenticationChanges.add(false);
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey<String>('intervention-legal-login-action')),
      );
      await tester.pumpAndSettle();

      expect(loginCalls, 1);
      expect(resolverCalls, 1);
      expect(repository.callCount, 1);
      expect(find.text('Canlı hukuki dosya'), findsOneWidget);
    },
  );

  testWidgets(
    'authenticated callable failure is not rendered as signed-out state',
    (tester) async {
      await _setDeterministicTestSurface(tester);
      final authenticationChanges = StreamController<bool>.broadcast();
      addTearDown(authenticationChanges.close);
      final repository = _UnauthenticatedWorkspaceRepository();

      await tester.pumpWidget(
        MaterialApp(
          home: InterventionLegalHubPage(
            repository: repository,
            authenticationChanges: authenticationChanges.stream,
          ),
        ),
      );
      await tester.pump();

      authenticationChanges.add(true);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('intervention-legal-auth-required')),
        findsNothing,
      );
      expect(
        find.text(
          'Oturum sunucu tarafından doğrulanamadı. '
          'Marka Girişi ile oturumu yenileyin.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'auth retry reconciles current session before loading workspace',
    (tester) async {
      await _setDeterministicTestSurface(tester);
      final authenticationChanges = StreamController<bool>.broadcast();
      addTearDown(authenticationChanges.close);
      final repository = _CountingWorkspaceRepository(_snapshot());
      var resolverCalls = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: InterventionLegalHubPage(
            repository: repository,
            authenticationChanges: authenticationChanges.stream,
            authenticationResolver: (forceRefresh) async {
              resolverCalls += 1;
              expect(forceRefresh, isTrue);
              return true;
            },
          ),
        ),
      );
      await tester.pump();

      authenticationChanges.add(false);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Yeniden dene'));
      await tester.pumpAndSettle();

      expect(resolverCalls, 1);
      expect(repository.callCount, 1);
      expect(find.text('Canlı hukuki dosya'), findsOneWidget);
    },
  );

  testWidgets('hub exposes retry after repository failure', (tester) async {
    await _setDeterministicTestSurface(tester);
    final repository = _RetryWorkspaceRepository(_snapshot());

    await tester.pumpWidget(
      MaterialApp(home: InterventionLegalHubPage(repository: repository)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Müdahale ve Hukuk Merkezi yüklenemedi.'), findsOneWidget);

    await tester.tap(find.text('Yeniden dene'));
    await tester.pumpAndSettle();

    final liveMatterTitle = find.text(
      'Canlı hukuki dosya',
      skipOffstage: false,
    );
    await tester.scrollUntilVisible(liveMatterTitle, 300);

    expect(liveMatterTitle, findsOneWidget);
    expect(repository.callCount, 2);
  });
}

Future<void> _setDeterministicTestSurface(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(1440, 2400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

final class _FakeWorkspaceRepository
    implements InterventionLegalWorkspaceRepository {
  _FakeWorkspaceRepository(this.snapshot);

  final InterventionLegalWorkspaceSnapshot snapshot;

  @override
  Future<InterventionLegalWorkspaceSnapshot> loadWorkspace({
    int limit = 20,
  }) async {
    return snapshot;
  }
}

final class _CountingWorkspaceRepository
    implements InterventionLegalWorkspaceRepository {
  _CountingWorkspaceRepository(this.snapshot);

  final InterventionLegalWorkspaceSnapshot snapshot;
  int callCount = 0;

  @override
  Future<InterventionLegalWorkspaceSnapshot> loadWorkspace({
    int limit = 20,
  }) async {
    callCount += 1;
    return snapshot;
  }
}

final class _UnauthenticatedWorkspaceRepository
    implements InterventionLegalWorkspaceRepository {
  @override
  Future<InterventionLegalWorkspaceSnapshot> loadWorkspace({int limit = 20}) {
    throw FirebaseFunctionsException(
      code: 'unauthenticated',
      message: 'test unauthenticated',
    );
  }
}

final class _RetryWorkspaceRepository
    implements InterventionLegalWorkspaceRepository {
  _RetryWorkspaceRepository(this.snapshot);

  final InterventionLegalWorkspaceSnapshot snapshot;
  int callCount = 0;

  @override
  Future<InterventionLegalWorkspaceSnapshot> loadWorkspace({
    int limit = 20,
  }) async {
    callCount += 1;
    if (callCount == 1) {
      throw StateError('temporary failure');
    }
    return snapshot;
  }
}

InterventionLegalWorkspaceSnapshot _snapshot() {
  final request = InterventionLegalApprovalRequestSummary(
    approvalRequestId: 'lar-1',
    legalMatterId: 'lm-1',
    approvalType: 'client_action_authorization',
    status: 'approved',
    version: 2,
    requestSequence: 2,
    requestReasonCode: 'legal_action_authorization_required',
    requestNote: 'Hukuki işlem yetkilendirme talebi.',
    preparedByUid: 'user-1',
    decisionId: 'lad-1',
    decidedByUid: 'user-1',
    createdAt: DateTime.utc(2026, 8, 1, 17, 45),
    updatedAt: DateTime.utc(2026, 8, 1, 18, 48),
    decidedAt: DateTime.utc(2026, 8, 1, 18, 48),
  );

  final decision = InterventionLegalApprovalDecisionSummary(
    decisionId: 'lad-1',
    approvalRequestId: 'lar-1',
    legalMatterId: 'lm-1',
    approvalType: 'client_action_authorization',
    decision: 'approved',
    decisionReasonCode: 'client_action_authorized',
    decisionNote: null,
    decidedByUid: 'user-1',
    decidedAt: DateTime.utc(2026, 8, 1, 18, 48),
    immutable: true,
  );

  final matter = InterventionLegalMatterSummary(
    legalMatterId: 'lm-1',
    caseId: 'case-1',
    tenantId: 'tenant-1',
    canonicalBrandId: 'brand-1',
    jurisdictionCode: 'tr.istanbul',
    countryCode: 'TR',
    matterScopeCode: 'platform_takedown',
    priorityCode: 'high',
    title: 'Canlı hukuki dosya',
    status: 'legal_review',
    version: 2,
    sourceSystemCode: 'case_evidence_center',
    sourceRecordId: 'case-1',
    createdAt: DateTime.utc(2026, 8, 1, 17, 40),
    updatedAt: DateTime.utc(2026, 8, 1, 18, 48),
    createdByUid: 'user-1',
    updatedByUid: 'user-1',
    statusChangedByUid: 'user-1',
    approvalRequests: [request],
    approvalDecisions: [decision],
  );

  return InterventionLegalWorkspaceSnapshot(
    generatedAt: DateTime.utc(2026, 8, 1, 18, 48),
    limit: 20,
    authorityScopeCount: 1,
    counts: const InterventionLegalWorkspaceCounts(
      legalMatterCount: 1,
      activeLegalMatterCount: 1,
      pendingApprovalCount: 0,
      approvedApprovalCount: 1,
      rejectedApprovalCount: 0,
    ),
    matters: [matter],
  );
}

import 'dart:io';
import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markakalkan/features/intervention_legal/data/intervention_legal_workspace_repository.dart';
import 'package:markakalkan/features/intervention_legal/data/intervention_legal_command_repository.dart';
import 'package:markakalkan/features/intervention_legal/presentation/intervention_legal_hub_page.dart';
import 'package:markakalkan/core/security/app_check_bootstrap.dart';

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

  testWidgets(
    'workspace waits for App Check readiness before repository load',
    (tester) async {
      await _setDeterministicTestSurface(tester);
      final authenticationChanges = StreamController<bool>.broadcast();
      addTearDown(authenticationChanges.close);
      final repository = _CountingWorkspaceRepository(_snapshot());
      final readiness = Completer<void>();
      var readinessCalls = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: InterventionLegalHubPage(
            repository: repository,
            authenticationChanges: authenticationChanges.stream,
            appCheckReadinessResolver: () async {
              readinessCalls += 1;
              await readiness.future;
            },
          ),
        ),
      );
      await tester.pump();

      authenticationChanges.add(true);
      await tester.pump();

      expect(readinessCalls, 1);
      expect(repository.callCount, 0);

      readiness.complete();
      await tester.pumpAndSettle();

      expect(repository.callCount, 1);
      expect(find.text('Canlı hukuki dosya'), findsOneWidget);
    },
  );

  testWidgets('App Check unavailable blocks workspace repository call', (
    tester,
  ) async {
    await _setDeterministicTestSurface(tester);
    final authenticationChanges = StreamController<bool>.broadcast();
    addTearDown(authenticationChanges.close);
    final repository = _CountingWorkspaceRepository(_snapshot());

    await tester.pumpWidget(
      MaterialApp(
        home: InterventionLegalHubPage(
          repository: repository,
          authenticationChanges: authenticationChanges.stream,
          appCheckReadinessResolver: () async {
            throw const AppCheckUnavailableException();
          },
        ),
      ),
    );
    await tester.pump();

    authenticationChanges.add(true);
    await tester.pumpAndSettle();

    expect(repository.callCount, 0);
    expect(
      find.text('Uygulama doğrulaması tamamlanamadı. Sayfayı yenileyin.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'injected workspace without command repository remains command-disabled',
    (tester) async {
      await _setDeterministicTestSurface(tester);
      final workspace = _Mhl3b3WorkspaceRepository(_snapshot());

      await tester.pumpWidget(
        MaterialApp(home: InterventionLegalHubPage(repository: workspace)),
      );
      await tester.pumpAndSettle();

      expect(workspace.callCount, 1);
      expect(
        find.byKey(const ValueKey<String>('legal-matter-command-panel-lm-1')),
        findsNothing,
      );
      expect(find.text('Hukuki işlemler'), findsNothing);
    },
  );

  testWidgets(
    'existing matter command surface renders without executing a command',
    (tester) async {
      await _setDeterministicTestSurface(tester);
      final workspace = _Mhl3b3WorkspaceRepository(_snapshot());
      final commands = _Mhl3b3RecordingCommandRepository();

      await tester.pumpWidget(
        MaterialApp(
          home: InterventionLegalHubPage(
            repository: workspace,
            commandRepository: commands,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('legal-matter-command-panel-lm-1')),
        findsOneWidget,
      );
      expect(commands.totalCalls, 0);
      expect(find.text('Yeni hukuki dosya'), findsNothing);
      expect(workspace.callCount, 1);
    },
  );

  testWidgets(
    'matter transition executes only after explicit submit and reloads workspace',
    (tester) async {
      await _setDeterministicTestSurface(tester);
      final workspace = _Mhl3b3WorkspaceRepository(_snapshot());
      final commands = _Mhl3b3RecordingCommandRepository();

      await tester.pumpWidget(
        MaterialApp(
          home: InterventionLegalHubPage(
            repository: workspace,
            commandRepository: commands,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final statusField = find.byKey(
        const ValueKey<String>('mhl-transition-status-lm-1'),
      );
      await tester.ensureVisible(statusField);
      await tester.tap(statusField);
      await tester.pumpAndSettle();
      await tester.tap(
        find
            .byKey(
              const ValueKey<String>(
                'mhl-transition-option-lm-1-evidence_required',
              ),
            )
            .last,
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey<String>('mhl-transition-reason-lm-1')),
        'evidence_gap_identified',
      );

      expect(commands.transitionCalls, 0);

      final submit = find.byKey(
        const ValueKey<String>('mhl-transition-submit-lm-1'),
      );
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();

      expect(commands.transitionCalls, 1);
      expect(commands.lastTransitionContext?.legalMatterId, 'lm-1');
      expect(commands.lastTransitionContext?.expectedVersion, 2);
      expect(commands.lastTransitionInput?.nextStatus, 'evidence_required');
      expect(
        commands.lastTransitionInput?.reasonCode,
        'evidence_gap_identified',
      );
      expect(workspace.callCount, 2);
      expect(commands.createMatterCalls, 0);
    },
  );

  testWidgets(
    'approval request uses matter id and version only after explicit submit',
    (tester) async {
      await _setDeterministicTestSurface(tester);
      final workspace = _Mhl3b3WorkspaceRepository(_snapshot());
      final commands = _Mhl3b3RecordingCommandRepository();

      await tester.pumpWidget(
        MaterialApp(
          home: InterventionLegalHubPage(
            repository: workspace,
            commandRepository: commands,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final typeField = find.byKey(
        const ValueKey<String>('mhl-approval-type-lm-1'),
      );
      await tester.ensureVisible(typeField);
      await tester.tap(typeField);
      await tester.pumpAndSettle();
      await tester.tap(
        find
            .byKey(
              const ValueKey<String>(
                'mhl-approval-type-option-lm-1-client_action_authorization',
              ),
            )
            .last,
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey<String>('mhl-approval-reason-lm-1')),
        'external_action_required',
      );

      expect(commands.approvalRequestCalls, 0);

      final submit = find.byKey(
        const ValueKey<String>('mhl-approval-submit-lm-1'),
      );
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();

      expect(commands.approvalRequestCalls, 1);
      expect(commands.lastApprovalRequestContext?.legalMatterId, 'lm-1');
      expect(
        commands.lastApprovalRequestContext?.expectedLegalMatterVersion,
        2,
      );
      expect(
        commands.lastApprovalRequestInput?.approvalType,
        'client_action_authorization',
      );
      expect(
        commands.lastApprovalRequestInput?.requestReasonCode,
        'external_action_required',
      );
      expect(workspace.callCount, 2);
      expect(commands.createMatterCalls, 0);
    },
  );

  testWidgets(
    'approval decision is pending-only and requires immutable confirmation',
    (tester) async {
      await _setDeterministicTestSurface(tester);

      final approvedWorkspace = _Mhl3b3WorkspaceRepository(_snapshot());
      final approvedCommands = _Mhl3b3RecordingCommandRepository();

      await tester.pumpWidget(
        MaterialApp(
          home: InterventionLegalHubPage(
            key: const ValueKey<String>('approved-workspace'),
            repository: approvedWorkspace,
            commandRepository: approvedCommands,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('mhl-approval-evaluate-lar-1')),
        findsNothing,
      );
      expect(approvedCommands.approvalDecisionCalls, 0);

      final pendingWorkspace = _Mhl3b3WorkspaceRepository(
        _snapshot(approvalStatus: 'pending'),
      );
      final pendingCommands = _Mhl3b3RecordingCommandRepository();

      await tester.pumpWidget(
        MaterialApp(
          home: InterventionLegalHubPage(
            key: const ValueKey<String>('pending-workspace'),
            repository: pendingWorkspace,
            commandRepository: pendingCommands,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final evaluate = find.byKey(
        const ValueKey<String>('mhl-approval-evaluate-lar-1'),
      );
      await tester.ensureVisible(evaluate);
      expect(evaluate, findsOneWidget);
      await tester.tap(evaluate);
      await tester.pumpAndSettle();

      expect(find.textContaining('değiştirilemez kayıt'), findsOneWidget);
      expect(pendingCommands.approvalDecisionCalls, 0);

      final decisionField = find.byKey(
        const ValueKey<String>('mhl-decision-value-lar-1'),
      );
      await tester.tap(decisionField);
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('mhl-decision-option-approved')).last,
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey<String>('mhl-decision-reason-lar-1')),
        'client_confirmed',
      );

      expect(pendingCommands.approvalDecisionCalls, 0);

      await tester.tap(
        find.byKey(const ValueKey<String>('mhl-decision-confirm-lar-1')),
      );
      await tester.pumpAndSettle();

      expect(pendingCommands.approvalDecisionCalls, 1);
      expect(
        pendingCommands.lastApprovalDecisionContext?.approvalRequestId,
        'lar-1',
      );
      expect(
        pendingCommands.lastApprovalDecisionContext?.legalMatterId,
        'lm-1',
      );
      expect(
        pendingCommands.lastApprovalDecisionContext?.approvalType,
        'client_action_authorization',
      );
      expect(
        pendingCommands
            .lastApprovalDecisionContext
            ?.expectedApprovalRequestVersion,
        2,
      );
      expect(pendingCommands.lastApprovalDecisionInput?.decision, 'approved');
      expect(
        pendingCommands.lastApprovalDecisionInput?.decisionReasonCode,
        'client_confirmed',
      );
      expect(pendingWorkspace.callCount, 2);
      expect(pendingCommands.createMatterCalls, 0);
    },
  );

  test('MHL-3C-3 create matter handoff surface contract', () {
    final source = File(
      'lib/features/intervention_legal/presentation/intervention_legal_hub_page.dart',
    ).readAsStringSync();

    expect(source, contains('InterventionLegalCreateMatterHandoff'));
    expect(
      source,
      contains('createMatterHandoff != null && commandRepository != null'),
    );
    expect(source, contains('class _CreateLegalMatterPanel'));
    expect(source, contains('InterventionLegalCreateMatterContext('));
    expect(source, contains('InterventionLegalCreateMatterInput('));
    expect(source, contains('await widget.repository.createLegalMatter('));
    expect(source, contains("ValueKey('create-matter-confirm')"));
    expect(source, contains("ValueKey('create-legal-matter-submit')"));
    expect(source, isNot(contains('FirebaseFirestore')));
    expect(source, isNot(contains('cloud_firestore')));
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

InterventionLegalWorkspaceSnapshot _snapshot({
  String approvalStatus = 'approved',
}) {
  final request = InterventionLegalApprovalRequestSummary(
    approvalRequestId: 'lar-1',
    legalMatterId: 'lm-1',
    approvalType: 'client_action_authorization',
    status: approvalStatus,
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

final class _Mhl3b3WorkspaceRepository
    implements InterventionLegalWorkspaceRepository {
  _Mhl3b3WorkspaceRepository(this.snapshot);

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

final class _Mhl3b3RecordingCommandRepository
    implements InterventionLegalCommandRepository {
  int createMatterCalls = 0;
  int transitionCalls = 0;
  int approvalRequestCalls = 0;
  int approvalDecisionCalls = 0;

  InterventionLegalMatterVersionContext? lastTransitionContext;
  InterventionLegalTransitionInput? lastTransitionInput;
  InterventionLegalApprovalRequestContext? lastApprovalRequestContext;
  InterventionLegalApprovalRequestInput? lastApprovalRequestInput;
  InterventionLegalApprovalDecisionContext? lastApprovalDecisionContext;
  InterventionLegalApprovalDecisionInput? lastApprovalDecisionInput;

  int get totalCalls =>
      createMatterCalls +
      transitionCalls +
      approvalRequestCalls +
      approvalDecisionCalls;

  @override
  Future<InterventionLegalCommandResponse> createLegalMatter({
    required InterventionLegalCreateMatterContext context,
    required InterventionLegalCreateMatterInput input,
  }) async {
    createMatterCalls += 1;
    return const InterventionLegalCommandResponse(
      resultType: 'legal_matter',
      idempotentReplay: false,
      data: <String, dynamic>{},
    );
  }

  @override
  Future<InterventionLegalCommandResponse> transitionLegalMatter({
    required InterventionLegalMatterVersionContext context,
    required InterventionLegalTransitionInput input,
  }) async {
    transitionCalls += 1;
    lastTransitionContext = context;
    lastTransitionInput = input;
    return const InterventionLegalCommandResponse(
      resultType: 'legal_matter',
      idempotentReplay: false,
      data: <String, dynamic>{},
    );
  }

  @override
  Future<InterventionLegalCommandResponse> createApprovalRequest({
    required InterventionLegalApprovalRequestContext context,
    required InterventionLegalApprovalRequestInput input,
  }) async {
    approvalRequestCalls += 1;
    lastApprovalRequestContext = context;
    lastApprovalRequestInput = input;
    return const InterventionLegalCommandResponse(
      resultType: 'legal_approval_request',
      idempotentReplay: false,
      data: <String, dynamic>{},
    );
  }

  @override
  Future<InterventionLegalCommandResponse> recordApprovalDecision({
    required InterventionLegalApprovalDecisionContext context,
    required InterventionLegalApprovalDecisionInput input,
  }) async {
    approvalDecisionCalls += 1;
    lastApprovalDecisionContext = context;
    lastApprovalDecisionInput = input;
    return const InterventionLegalCommandResponse(
      resultType: 'legal_approval_decision',
      idempotentReplay: false,
      data: <String, dynamic>{},
    );
  }
}

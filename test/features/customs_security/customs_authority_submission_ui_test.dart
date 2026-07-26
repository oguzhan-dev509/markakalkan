import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markakalkan/features/customs_security/presentation/customs_authority_submission_detail_page.dart';
import 'package:markakalkan/features/customs_security/presentation/customs_authority_submission_labels.dart';
import 'package:markakalkan/features/customs_security/presentation/customs_security_detail_page.dart';
import 'package:markakalkan/features/customs_security/presentation/customs_security_hub_page.dart';

import 'customs_authority_submission_test_fakes.dart';
import 'customs_security_test_fakes.dart';

void main() {
  Future<void> pumpArtifactDetail(
    WidgetTester tester,
    FakeCustomsAuthoritySubmissionRepository repository, {
    CustomsArtifactUrlOpener? opener,
  }) async {
    await tester.binding.setSurfaceSize(const Size(1100, 1800));
    await tester.pumpWidget(
      MaterialApp(
        home: CustomsAuthoritySubmissionDetailPage(
          submissionId: 'submission-1',
          repository: repository,
          urlOpener: opener,
          requestIdFactory: () => 'stable-request-id',
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('legacy artifact materializes once and reloads detail once', (
    tester,
  ) async {
    final repository = FakeCustomsAuthoritySubmissionRepository()
      ..detail = sampleAuthoritySubmissionDetail(
        includePackage: true,
        includeScope: true,
      );
    await tester.binding.setSurfaceSize(const Size(1100, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: CustomsAuthoritySubmissionDetailPage(
          submissionId: 'submission-1',
          repository: repository,
          requestIdFactory: () => 'stable-request-id',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Resmî Paket ve Güvenli İndirme'), findsOneWidget);
    expect(find.text('Resmî Paketi Oluştur'), findsOneWidget);

    final materialize = find.byKey(const ValueKey('materialize-package'));
    await tester.ensureVisible(materialize);
    await tester.tap(materialize);
    await tester.tap(materialize, warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 300));
    expect(repository.materializeCalls, 0);
    await tester.tap(find.byKey(const ValueKey('confirm-materialize-package')));
    await tester.pumpAndSettle();
    expect(repository.materializeCalls, 1);
    expect(repository.materializationRequestIds, ['stable-request-id']);
    expect(repository.detailCalls, 2);
  });

  testWidgets('missing scope and unknown status fail closed', (tester) async {
    final repository = FakeCustomsAuthoritySubmissionRepository()
      ..detail = sampleAuthoritySubmissionDetail(
        includePackage: true,
        artifactStatus: 'future_status',
      );
    await tester.binding.setSurfaceSize(const Size(1100, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: CustomsAuthoritySubmissionDetailPage(
          submissionId: 'submission-1',
          repository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('güvenli paket kapsamı'), findsOneWidget);
    expect(find.byKey(const ValueKey('materialize-package')), findsNothing);
    expect(repository.materializeCalls, 0);
    expect(repository.pdfAuthorizationCalls, 0);
  });

  testWidgets('ready artifacts authorize and open each URL once', (
    tester,
  ) async {
    final repository = FakeCustomsAuthoritySubmissionRepository()
      ..detail = sampleAuthoritySubmissionDetail(
        includePackage: true,
        includeScope: true,
        artifactStatus: 'ready',
        pdfReady: true,
        manifestReady: true,
      );
    var openerCalls = 0;
    await tester.binding.setSurfaceSize(const Size(1100, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: CustomsAuthoritySubmissionDetailPage(
          submissionId: 'submission-1',
          repository: repository,
          urlOpener: (_) async {
            openerCalls++;
            return true;
          },
          requestIdFactory: () => 'download-request',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('PDF İndir'), findsOneWidget);
    expect(find.text('Manifest İndir'), findsOneWidget);
    expect(find.textContaining('https://'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('download-package-pdf')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('download-package-manifest')));
    await tester.pumpAndSettle();
    expect(repository.pdfAuthorizationCalls, 1);
    expect(repository.manifestAuthorizationCalls, 1);
    expect(openerCalls, 2);
    expect(find.textContaining('https://'), findsNothing);
  });

  testWidgets('recoverable retry preserves its request id', (tester) async {
    final repository = FakeCustomsAuthoritySubmissionRepository()
      ..detail = sampleAuthoritySubmissionDetail(
        includePackage: true,
        includeScope: true,
        artifactStatus: 'failed_recoverable',
      )
      ..materializationError = FirebaseFunctionsException(
        code: 'unavailable',
        message: 'technical',
      );
    var ids = 0;
    await tester.binding.setSurfaceSize(const Size(1100, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: CustomsAuthoritySubmissionDetailPage(
          submissionId: 'submission-1',
          repository: repository,
          requestIdFactory: () => 'retry-${ids++}',
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (var attempt = 0; attempt < 2; attempt++) {
      await tester.tap(find.byKey(const ValueKey('retry-materialize-package')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('confirm-materialize-package')),
      );
      await tester.pumpAndSettle();
    }
    expect(repository.materializationRequestIds, ['retry-0', 'retry-0']);
  });

  testWidgets('artifact non-ready states are complete and fail closed', (
    tester,
  ) async {
    final cases = <String, String>{
      'materialization_pending': 'Paket oluşturma işlemi hazırlanıyor.',
      'materializing': 'Resmî paket güvenli biçimde oluşturuluyor.',
      'integrity_failed': 'Paket bütünlüğü doğrulanamadı.',
      'disabled': 'Güvenli paket oluşturma işlemi şu anda kapalı.',
      'future_status': 'Paket durumu doğrulanamadı.',
    };
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final entry in cases.entries) {
      await tester.pumpWidget(const SizedBox());
      final repository = FakeCustomsAuthoritySubmissionRepository()
        ..detail = sampleAuthoritySubmissionDetail(
          includePackage: true,
          includeScope: true,
          artifactStatus: entry.key,
        );
      await pumpArtifactDetail(tester, repository);
      expect(find.text(entry.value), findsOneWidget);
      expect(find.byKey(const ValueKey('download-package-pdf')), findsNothing);
      expect(
        find.byKey(const ValueKey('download-package-manifest')),
        findsNothing,
      );
      expect(repository.materializeCalls, 0);
      expect(repository.pdfAuthorizationCalls, 0);
      expect(repository.manifestAuthorizationCalls, 0);
    }
  });

  testWidgets('materialization confirmation cancellation invokes nothing', (
    tester,
  ) async {
    final repository = FakeCustomsAuthoritySubmissionRepository()
      ..detail = sampleAuthoritySubmissionDetail(
        includePackage: true,
        includeScope: true,
      );
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpArtifactDetail(tester, repository);
    final button = find.byKey(const ValueKey('materialize-package'));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Vazgeç'));
    await tester.pumpAndSettle();
    expect(repository.materializeCalls, 0);
  });

  testWidgets('missing descriptors cannot authorize a ready package', (
    tester,
  ) async {
    final repository = FakeCustomsAuthoritySubmissionRepository()
      ..detail = sampleAuthoritySubmissionDetail(
        includePackage: true,
        includeScope: true,
        artifactStatus: 'ready',
      );
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpArtifactDetail(tester, repository);
    final pdf = find.byKey(const ValueKey('download-package-pdf'));
    final manifest = find.byKey(const ValueKey('download-package-manifest'));
    expect(tester.widget<FilledButton>(pdf).onPressed, isNull);
    expect(tester.widget<OutlinedButton>(manifest).onPressed, isNull);
    expect(repository.pdfAuthorizationCalls, 0);
    expect(repository.manifestAuthorizationCalls, 0);
  });

  testWidgets('download lock blocks double submit and opener false is safe', (
    tester,
  ) async {
    final gate = Completer<void>();
    final repository = FakeCustomsAuthoritySubmissionRepository()
      ..detail = sampleAuthoritySubmissionDetail(
        includePackage: true,
        includeScope: true,
        artifactStatus: 'ready',
        pdfReady: true,
        manifestReady: true,
      )
      ..pdfAuthorizationGate = gate;
    var openerCalls = 0;
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpArtifactDetail(
      tester,
      repository,
      opener: (_) async {
        openerCalls++;
        return false;
      },
    );
    final pdf = find.byKey(const ValueKey('download-package-pdf'));
    await tester.ensureVisible(pdf);
    await tester.tap(pdf);
    await tester.tap(pdf, warnIfMissed: false);
    await tester.pump();
    expect(repository.pdfAuthorizationCalls, 1);
    expect(repository.manifestAuthorizationCalls, 0);
    gate.complete();
    await tester.pumpAndSettle();
    expect(openerCalls, 1);
    expect(find.text(downloadOpenFailed), findsOneWidget);
    expect(find.textContaining('https://'), findsNothing);
  });

  testWidgets('async artifact completion after dispose does not setState', (
    tester,
  ) async {
    final gate = Completer<void>();
    final repository = FakeCustomsAuthoritySubmissionRepository()
      ..detail = sampleAuthoritySubmissionDetail(
        includePackage: true,
        includeScope: true,
        artifactStatus: 'ready',
        pdfReady: true,
      )
      ..pdfAuthorizationGate = gate;
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpArtifactDetail(tester, repository, opener: (_) async => true);
    final pdf = find.byKey(const ValueKey('download-package-pdf'));
    await tester.ensureVisible(pdf);
    await tester.tap(pdf);
    await tester.pump();
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    gate.complete();
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('hub renders and opens the official submissions workspace', (
    tester,
  ) async {
    final repository = FakeCustomsSecurityRepository();
    final authorityRepository = FakeCustomsAuthoritySubmissionRepository();
    String? openedId;

    await tester.binding.setSurfaceSize(const Size(1100, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: CustomsSecurityHubPage(
          repository: repository,
          authorityRepository: authorityRepository,
          submissionDetailOpener: (context, submissionId) async {
            openedId = submissionId;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('customs-authority-submission-tab')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Resmî Başvuru ve Kurum İletimleri'), findsOneWidget);
    expect(find.text('KRI-2026-ABC12345'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('customs-authority-submission-submission-1')),
    );
    await tester.pumpAndSettle();
    expect(openedId, 'submission-1');
  });

  testWidgets('active profile creates an FSMH submission draft', (
    tester,
  ) async {
    final repository = FakeCustomsSecurityRepository();
    final authorityRepository = FakeCustomsAuthoritySubmissionRepository();
    String? openedId;

    await tester.binding.setSurfaceSize(const Size(1100, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: CustomsSecurityDetailPage.profile(
          profileId: 'profile-1',
          repository: repository,
          authorityRepository: authorityRepository,
          submissionDetailOpener: (context, submissionId) async {
            openedId = submissionId;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('create-fsmh-authority-submission')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('confirm-create-customs-authority-submission')),
    );
    await tester.pumpAndSettle();

    expect(authorityRepository.createCalls, 1);
    expect(
      authorityRepository.lastDraft?.submissionType,
      'fsmh_protection_application',
    );
    expect(authorityRepository.lastDraft?.protectionProfileId, 'profile-1');
    expect(openedId, 'submission-created');
  });

  testWidgets('intervention creates a customs authority submission draft', (
    tester,
  ) async {
    final repository = FakeCustomsSecurityRepository();
    final authorityRepository = FakeCustomsAuthoritySubmissionRepository();

    await tester.binding.setSurfaceSize(const Size(1100, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: CustomsSecurityDetailPage.intervention(
          interventionId: 'intervention-1',
          repository: repository,
          authorityRepository: authorityRepository,
          submissionDetailOpener: (context, submissionId) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('create-intervention-authority-submission')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('confirm-create-customs-authority-submission')),
    );
    await tester.pumpAndSettle();

    expect(authorityRepository.createCalls, 1);
    expect(
      authorityRepository.lastDraft?.submissionType,
      'customs_smuggling_notification',
    );
    expect(authorityRepository.lastDraft?.interventionId, 'intervention-1');
  });

  testWidgets('official submission detail keeps human gates visible', (
    tester,
  ) async {
    final authorityRepository = FakeCustomsAuthoritySubmissionRepository();

    await tester.binding.setSurfaceSize(const Size(1100, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: CustomsAuthoritySubmissionDetailPage(
          submissionId: 'submission-1',
          repository: authorityRepository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('customs-authority-submission-detail')),
      findsOneWidget,
    );
    expect(
      find.textContaining('otomatik olarak resmî kuruma göndermez'),
      findsOneWidget,
    );
    expect(find.text('İnsan incelemesi: Henüz kaydedilmedi'), findsOneWidget);
    expect(find.textContaining('Hak sahibi / temsilci onayı'), findsOneWidget);
    expect(find.text('verified'), findsOneWidget);
  });
}

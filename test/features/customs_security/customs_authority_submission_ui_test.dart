import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markakalkan/features/customs_security/data/customs_authority_submission_repository.dart';
import 'package:markakalkan/features/customs_security/presentation/customs_authority_submission_detail_page.dart';
import 'package:markakalkan/features/customs_security/presentation/customs_authority_submission_labels.dart';
import 'package:markakalkan/features/customs_security/presentation/customs_security_detail_page.dart';
import 'package:markakalkan/features/customs_security/presentation/customs_security_hub_page.dart';

import 'customs_authority_submission_test_fakes.dart';
import 'customs_security_test_fakes.dart';

void main() {
  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

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

  Future<void> addRequiredPackageManifestItem(WidgetTester tester) async {
    final addButton = find.byKey(
      const ValueKey('add-customs-package-manifest-item'),
    );
    await tester.ensureVisible(addButton);
    await tester.tap(addButton);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('customs-package-manifest-reference-id')),
      'document-1',
    );
    await tester.enterText(
      find.byKey(const ValueKey('customs-package-manifest-title')),
      'Marka tescil belgesi',
    );
    await tester.enterText(
      find.byKey(const ValueKey('customs-package-manifest-sha256')),
      List<String>.filled(64, 'a').join(),
    );
    await tester.enterText(
      find.byKey(const ValueKey('customs-package-manifest-mime')),
      'application/pdf',
    );
    await tester.enterText(
      find.byKey(const ValueKey('customs-package-manifest-size')),
      '2048',
    );
    await tester.tap(
      find.byKey(const ValueKey('confirm-customs-package-manifest-item')),
    );
    await tester.pumpAndSettle();
  }

  Future<void> addPackageRedactionItem(WidgetTester tester) async {
    final addButton = find.byKey(
      const ValueKey('add-customs-package-redaction-item'),
    );
    await tester.ensureVisible(addButton);
    await tester.tap(addButton);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('customs-package-redaction-field-path')),
      'contact.phone',
    );
    await tester.enterText(
      find.byKey(const ValueKey('customs-package-redaction-reason')),
      'Kişisel veri minimizasyonu.',
    );
    final confirm = find.byKey(
      const ValueKey('confirm-customs-package-redaction-item'),
    );
    await tester.ensureVisible(confirm);
    await tester.tap(confirm);
    await tester.pumpAndSettle();
  }

  Future<void> pumpExternalSubmissionDetail(
    WidgetTester tester,
    FakeCustomsAuthoritySubmissionRepository repository,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1100, 3200));
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
  }

  Future<void> completeExternalSubmissionForm(WidgetTester tester) async {
    await tester.enterText(
      find.byKey(const ValueKey('external-submission-statement')),
      'Paket FSMH Portalı üzerinden yetkili kullanıcı tarafından teslim edildi.',
    );

    await tester.tap(find.byKey(const ValueKey('external-reference-type')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Portal işlem numarası').last);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('external-reference-value')),
      'PORTAL-2026-0001',
    );
    await tester.tap(
      find.byKey(const ValueKey('external-submission-confirmation')),
    );
    await tester.pump();

    final review = find.byKey(const ValueKey('review-external-submission'));
    await tester.ensureVisible(review);
    await tester.tap(review);
    await tester.pumpAndSettle();
  }

  Future<void> pumpAuthorityOperationsDetail(
    WidgetTester tester,
    FakeCustomsAuthoritySubmissionRepository repository, {
    Size size = const Size(1100, 5200),
  }) async {
    await tester.binding.setSurfaceSize(size);
    await tester.pumpWidget(
      MaterialApp(
        home: CustomsAuthoritySubmissionDetailPage(
          submissionId: 'submission-1',
          repository: repository,
          requestIdFactory: () => 'stable-authority-operation-id',
          initialStage: CustomsAuthoritySubmissionStage.deliveryResponseOutcome,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> pumpReviewApprovalDetail(
    WidgetTester tester,
    FakeCustomsAuthoritySubmissionRepository repository, {
    List<String> requestIds = const ['review-operation-id'],
    Size size = const Size(1100, 2400),
  }) async {
    var requestIndex = 0;
    await tester.binding.setSurfaceSize(size);
    await tester.pumpWidget(
      MaterialApp(
        home: CustomsAuthoritySubmissionDetailPage(
          submissionId: 'submission-1',
          repository: repository,
          requestIdFactory: () {
            final index = requestIndex < requestIds.length
                ? requestIndex
                : requestIds.length - 1;
            requestIndex++;
            return requestIds[index];
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> completeSubmitHumanReviewForm(WidgetTester tester) async {
    await tester.enterText(
      find.byKey(const ValueKey('human-review-submission-reason')),
      'Kuruma sunulacak taslak insan incelemesine hazırlandı.',
    );
    await tester.tap(
      find.byKey(const ValueKey('human-review-submission-confirmation')),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('review-submit-human-review')));
    await tester.pumpAndSettle();
  }

  Future<void> completeHumanReviewForm(WidgetTester tester) async {
    await tester.enterText(
      find.byKey(const ValueKey('human-review-reference')),
      'HUMAN-REVIEW-2026-0001',
    );
    await tester.enterText(
      find.byKey(const ValueKey('human-review-completion-reason')),
      'İçerik insan tarafından incelendi ve hak sahibi onayına hazırlandı.',
    );
    await tester.tap(
      find.byKey(const ValueKey('human-review-completion-confirmation')),
    );
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('review-complete-human-review')),
    );
    await tester.pumpAndSettle();
  }

  Future<void> completeRightsHolderApprovalForm(
    WidgetTester tester, {
    bool confirmations = true,
  }) async {
    await tester.enterText(
      find.byKey(const ValueKey('rights-holder-approval-reference')),
      'RIGHTS-APPROVAL-2026-0001',
    );
    await tester.enterText(
      find.byKey(const ValueKey('rights-holder-approval-reason')),
      'Fiilî hak sahibi onayı alındı ve dosya paket üretimine hazırlandı.',
    );
    if (confirmations) {
      await tester.tap(
        find.byKey(
          const ValueKey('rights-holder-data-minimization-confirmation'),
        ),
      );
      await tester.tap(
        find.byKey(
          const ValueKey('rights-holder-neutral-language-confirmation'),
        ),
      );
      await tester.tap(
        find.byKey(const ValueKey('rights-holder-approval-confirmation')),
      );
      await tester.pump();
    }
    await tester.tap(find.byKey(const ValueKey('review-approve-for-package')));
    await tester.pumpAndSettle();
  }

  Future<void> completeAuthorityReceiptForm(
    WidgetTester tester, {
    bool includeDocumentPair = true,
    bool includeHash = true,
  }) async {
    await tester.enterText(
      find.byKey(const ValueKey('authority-receipt-reference')),
      'FSMH-2026-ALINDI-1',
    );
    await tester.enterText(
      find.byKey(const ValueKey('authority-receipt-summary')),
      'Başvurunun kurum sistemi tarafından teslim alındığı doğrulandı.',
    );
    if (includeDocumentPair) {
      await tester.enterText(
        find.byKey(const ValueKey('authority-receipt-document-reference')),
        'receipt-document-1',
      );
    }
    if (includeHash) {
      await tester.enterText(
        find.byKey(const ValueKey('authority-receipt-document-hash')),
        List<String>.filled(64, 'a').join(),
      );
    }
    await tester.tap(
      find.byKey(const ValueKey('authority-receipt-confirmation')),
    );
    await tester.pump();
  }

  Future<void> completeAuthorityResponseForm(
    WidgetTester tester, {
    bool informationRequest = false,
    bool addAttachment = false,
    bool validHash = true,
  }) async {
    if (informationRequest) {
      await tester.tap(find.byKey(const ValueKey('authority-response-type')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ek bilgi talebi').last);
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('authority-response-add-due-date')),
      );
      await tester.pump();
    }
    await tester.enterText(
      find.byKey(const ValueKey('authority-response-reference')),
      'FSMH-2026-CEVAP-1',
    );
    await tester.enterText(
      find.byKey(const ValueKey('authority-response-summary')),
      informationRequest
          ? 'Kurum ek ürün görseli ve yetki belgesi talep etti.'
          : 'Kurum başvurunun incelemeye alındığını bildirdi.',
    );
    if (addAttachment) {
      await tester.tap(
        find.byKey(const ValueKey('add-authority-response-attachment')),
      );
      await tester.pump();
      await tester.enterText(
        find.byKey(const ValueKey('authority-response-attachment-reference-0')),
        'authority-letter-1',
      );
      await tester.enterText(
        find.byKey(const ValueKey('authority-response-attachment-hash-0')),
        validHash ? List<String>.filled(64, 'b').join() : 'invalid-hash',
      );
    }
  }

  Future<void> completeAuthorityOutcomeForm(
    WidgetTester tester, {
    bool confirmHumanEntry = true,
    bool confirmNeutrality = true,
  }) async {
    await tester.enterText(
      find.byKey(const ValueKey('authority-outcome-reference')),
      'FSMH-2026-SONUC-1',
    );
    await tester.enterText(
      find.byKey(const ValueKey('authority-outcome-summary')),
      'Kurum inceleme sonunda işlem yapıldığını bildirdi ve dosyayı kapattı.',
    );
    if (confirmHumanEntry) {
      await tester.tap(
        find.byKey(const ValueKey('authority-outcome-human-confirmation')),
      );
      await tester.pump();
    }
    if (confirmNeutrality) {
      await tester.tap(
        find.byKey(const ValueKey('authority-outcome-neutrality-confirmation')),
      );
      await tester.pump();
    }
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

    final pdfButton = find.byKey(const ValueKey('download-package-pdf'));
    final manifestButton = find.byKey(
      const ValueKey('download-package-manifest'),
    );
    await tester.ensureVisible(pdfButton);
    await tester.pumpAndSettle();
    await tester.tap(pdfButton);
    await tester.pumpAndSettle();
    await tester.ensureVisible(manifestButton);
    await tester.pumpAndSettle();
    await tester.tap(manifestButton);
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
      await tapVisible(
        tester,
        find.byKey(const ValueKey('retry-materialize-package')),
      );
      await tapVisible(
        tester,
        find.byKey(const ValueKey('confirm-materialize-package')),
      );
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

  testWidgets(
    'approved submission generates one immutable package and reloads detail',
    (tester) async {
      final repository = FakeCustomsAuthoritySubmissionRepository()
        ..detail = sampleAuthoritySubmissionDetail(
          status: 'approved_for_package',
          includeScope: true,
          humanReviewReference: 'review-reference-1',
          rightsHolderApprovalReference: 'approval-reference-1',
          dataMinimizationConfirmed: true,
          nonAccusatoryLanguageConfirmed: true,
        );
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await pumpArtifactDetail(tester, repository);

      final generate = find.byKey(
        const ValueKey('generate-customs-submission-package'),
      );
      await tester.ensureVisible(generate);
      expect(tester.widget<FilledButton>(generate).onPressed, isNotNull);
      await tester.tap(generate);
      await tester.pumpAndSettle();

      expect(find.text('Başvuru paketi hazırlama'), findsOneWidget);
      await addRequiredPackageManifestItem(tester);
      expect(
        find.byKey(const ValueKey('customs-package-manifest-item-0')),
        findsOneWidget,
      );
      await addPackageRedactionItem(tester);
      expect(
        find.byKey(const ValueKey('customs-package-redaction-item-0')),
        findsOneWidget,
      );

      final review = find.byKey(const ValueKey('review-customs-package'));
      await tester.ensureVisible(review);
      await tester.tap(review);
      await tester.pumpAndSettle();
      expect(
        find.textContaining('değiştirilemez bir başvuru paketine'),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const ValueKey('confirm-generate-customs-package')),
      );
      await tester.pumpAndSettle();

      expect(repository.generatePackageCalls, 1);
      expect(repository.packageGenerationRequestIds, ['stable-request-id']);
      expect(repository.lastPackageTenantId, 'tenant-1');
      expect(repository.lastPackageCanonicalBrandId, 'brand-1');
      expect(repository.lastPackageSubmissionId, 'submission-1');
      expect(
        repository.lastPackageDraft?.packageType,
        CustomsSubmissionPackageType.fsmhApplicationPackage,
      );
      expect(repository.lastPackageDraft?.documentManifest, hasLength(1));
      expect(repository.lastPackageDraft?.evidenceManifest, isEmpty);
      expect(repository.lastPackageDraft?.redactionManifest, hasLength(1));
      expect(
        repository.lastPackageDraft?.redactionManifest.single.action,
        'mask',
      );
      expect(repository.detailCalls, 2);
      expect(
        find.descendant(
          of: find.byType(SnackBar),
          matching: find.text('Başvuru paketi hazırlandı'),
        ),
        findsOneWidget,
      );
      expect(find.text('Resmî Paket ve Güvenli İndirme'), findsOneWidget);
    },
  );

  testWidgets(
    'package generation final confirmation cancellation writes nothing',
    (tester) async {
      final repository = FakeCustomsAuthoritySubmissionRepository()
        ..detail = sampleAuthoritySubmissionDetail(
          status: 'approved_for_package',
          includeScope: true,
          humanReviewReference: 'review-reference-1',
          rightsHolderApprovalReference: 'approval-reference-1',
          dataMinimizationConfirmed: true,
          nonAccusatoryLanguageConfirmed: true,
        );
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await pumpArtifactDetail(tester, repository);

      final generate = find.byKey(
        const ValueKey('generate-customs-submission-package'),
      );
      await tester.ensureVisible(generate);
      await tester.tap(generate);
      await tester.pumpAndSettle();
      await addRequiredPackageManifestItem(tester);

      final review = find.byKey(const ValueKey('review-customs-package'));
      await tester.ensureVisible(review);
      await tester.tap(review);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Vazgeç'));
      await tester.pumpAndSettle();

      expect(repository.generatePackageCalls, 0);
      expect(repository.packageGenerationRequestIds, isEmpty);
    },
  );

  testWidgets(
    'package generation stays fail closed until scope and gates pass',
    (tester) async {
      final repository = FakeCustomsAuthoritySubmissionRepository()
        ..detail = sampleAuthoritySubmissionDetail(
          status: 'approved_for_package',
        );
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await pumpArtifactDetail(tester, repository);

      final generate = find.byKey(
        const ValueKey('generate-customs-submission-package'),
      );
      await tester.ensureVisible(generate);
      expect(tester.widget<FilledButton>(generate).onPressed, isNull);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('customs-package-generation-blockers')),
          matching: find.text('Tenant ve marka kapsamı doğrulanamadı.'),
        ),
        findsOneWidget,
      );
      expect(find.text('İnsan incelemesi referansı eksik.'), findsOneWidget);
      expect(
        find.text('Hak sahibi veya temsilci onayı eksik.'),
        findsOneWidget,
      );
      expect(repository.generatePackageCalls, 0);
    },
  );

  testWidgets(
    'package generated submission records one external delivery without artifact',
    (tester) async {
      final repository = FakeCustomsAuthoritySubmissionRepository()
        ..detail = sampleAuthoritySubmissionDetail(
          status: 'package_generated',
          includePackage: true,
          includeScope: true,
        );
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await pumpExternalSubmissionDetail(tester, repository);

      final record = find.byKey(const ValueKey('record-external-submission'));
      await tester.ensureVisible(record);
      expect(tester.widget<FilledButton>(record).onPressed, isNotNull);
      expect(
        find.textContaining(
          'Güvenli indirme dosyalarının hazır olması bu kayıt için zorunlu değildir.',
        ),
        findsOneWidget,
      );

      await tester.tap(record);
      await tester.pumpAndSettle();
      expect(find.text('Kuruma dış teslim kaydı'), findsWidgets);
      await completeExternalSubmissionForm(tester);

      await tester.tap(
        find.byKey(const ValueKey('confirm-record-external-submission')),
      );
      await tester.pumpAndSettle();

      expect(repository.externalSubmissionCalls, 1);
      expect(repository.externalSubmissionRequestIds, ['stable-request-id']);
      expect(repository.lastExternalSubmissionTenantId, 'tenant-1');
      expect(repository.lastExternalSubmissionCanonicalBrandId, 'brand-1');
      expect(repository.lastExternalSubmissionSubmissionId, 'submission-1');
      expect(repository.lastExternalSubmissionPackageId, 'package-1');
      expect(repository.lastExternalSubmissionPackageVersion, 1);
      expect(
        repository.lastExternalSubmissionPackageHash,
        List<String>.filled(64, 'a').join(),
      );
      expect(
        repository.lastExternalSubmissionDraft?.submissionChannel,
        CustomsSubmissionChannel.fsmhPortal,
      );
      expect(
        repository.lastExternalSubmissionDraft?.externalReferenceType,
        CustomsExternalReferenceType.portalTransactionId,
      );
      expect(
        repository.lastExternalSubmissionDraft?.externalReferenceValue,
        'PORTAL-2026-0001',
      );
      expect(
        repository.lastExternalSubmissionDraft?.externalSubmissionConfirmed,
        isTrue,
      );
      expect(repository.detailCalls, 2);
      expect(find.text('Kuruma dış teslim kaydedildi'), findsOneWidget);
      expect(find.text('Resmî kanaldan iletildi'), findsWidgets);
      expect(
        find.textContaining(
          'customs_submission_recorded_as_submitted_externally',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'external delivery final confirmation cancellation writes nothing',
    (tester) async {
      final repository = FakeCustomsAuthoritySubmissionRepository()
        ..detail = sampleAuthoritySubmissionDetail(
          status: 'package_generated',
          includePackage: true,
          includeScope: true,
        );
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await pumpExternalSubmissionDetail(tester, repository);

      final record = find.byKey(const ValueKey('record-external-submission'));
      await tester.ensureVisible(record);
      await tester.tap(record);
      await tester.pumpAndSettle();
      await completeExternalSubmissionForm(tester);
      await tester.tap(find.text('Vazgeç'));
      await tester.pumpAndSettle();

      expect(repository.externalSubmissionCalls, 0);
      expect(repository.externalSubmissionRequestIds, isEmpty);
    },
  );

  testWidgets(
    'external delivery stays fail closed without tenant and brand scope',
    (tester) async {
      final repository = FakeCustomsAuthoritySubmissionRepository()
        ..detail = sampleAuthoritySubmissionDetail(
          status: 'package_generated',
          includePackage: true,
        );
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await pumpExternalSubmissionDetail(tester, repository);

      final record = find.byKey(const ValueKey('record-external-submission'));
      await tester.ensureVisible(record);
      expect(tester.widget<FilledButton>(record).onPressed, isNull);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('external-submission-blockers')),
          matching: find.text('Tenant ve marka kapsamı doğrulanamadı.'),
        ),
        findsOneWidget,
      );
      expect(repository.externalSubmissionCalls, 0);
    },
  );

  testWidgets(
    'recoverable external delivery retry preserves request id and draft',
    (tester) async {
      final repository = FakeCustomsAuthoritySubmissionRepository()
        ..detail = sampleAuthoritySubmissionDetail(
          status: 'package_generated',
          includePackage: true,
          includeScope: true,
        )
        ..externalSubmissionError = FirebaseFunctionsException(
          code: 'unavailable',
          message: 'technical',
        );
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await pumpExternalSubmissionDetail(tester, repository);

      final record = find.byKey(const ValueKey('record-external-submission'));
      await tester.ensureVisible(record);
      await tester.tap(record);
      await tester.pumpAndSettle();
      await completeExternalSubmissionForm(tester);
      await tester.tap(
        find.byKey(const ValueKey('confirm-record-external-submission')),
      );
      await tester.pumpAndSettle();

      expect(repository.externalSubmissionCalls, 1);
      expect(repository.externalSubmissionRequestIds, ['stable-request-id']);
      expect(
        find.byKey(const ValueKey('retry-external-submission')),
        findsOneWidget,
      );

      repository.externalSubmissionError = null;
      final retry = find.byKey(const ValueKey('retry-external-submission'));
      await tester.ensureVisible(retry);
      await tester.tap(retry);
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('confirm-retry-external-submission')),
      );
      await tester.pumpAndSettle();

      expect(repository.externalSubmissionCalls, 2);
      expect(repository.externalSubmissionRequestIds, [
        'stable-request-id',
        'stable-request-id',
      ]);
      expect(
        repository.lastExternalSubmissionDraft?.externalReferenceValue,
        'PORTAL-2026-0001',
      );
      expect(repository.detailCalls, 2);
      expect(find.text('Resmî kanaldan iletildi'), findsWidgets);
    },
  );

  testWidgets(
    'submitted file records immutable authority receipt and reloads canonical detail',
    (tester) async {
      final repository = FakeCustomsAuthoritySubmissionRepository()
        ..detail = sampleAuthoritySubmissionDetail(
          status: 'submitted_externally',
          includePackage: true,
          includeScope: true,
          submittedAt: '2026-07-25T10:02:00.000Z',
          externalSubmissionStatement:
              'Paket FSMH Portalı üzerinden teslim edildi.',
          externalReferenceType: 'portal_transaction_id',
          externalReferenceValue: 'PORTAL-2026-0001',
        );
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await pumpAuthorityOperationsDetail(tester, repository);

      final record = find.byKey(
        const ValueKey('record-customs-submission-receipt'),
      );
      await tester.ensureVisible(record);
      await tester.tap(record);
      await tester.pumpAndSettle();
      await completeAuthorityReceiptForm(tester);

      final review = find.byKey(const ValueKey('review-authority-receipt'));
      await tester.ensureVisible(review);
      await tester.tap(review);
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('confirm-record-authority-receipt')),
      );
      await tester.pumpAndSettle();

      expect(repository.receiptCalls, 1);
      expect(repository.receiptRequestIds, ['stable-authority-operation-id']);
      expect(repository.lastAuthorityOperationTenantId, 'tenant-1');
      expect(repository.lastAuthorityOperationCanonicalBrandId, 'brand-1');
      expect(repository.lastAuthorityOperationSubmissionId, 'submission-1');
      expect(
        repository.lastReceiptDraft?.officialReferenceNumber,
        'FSMH-2026-ALINDI-1',
      );
      expect(
        repository.lastReceiptDraft?.receiptDocumentHash,
        List<String>.filled(64, 'a').join(),
      );
      expect(repository.detailCalls, 2);
      expect(find.text('Resmî alındı kaydedildi'), findsOneWidget);
      expect(find.text('Teslim kaydı alındı'), findsWidgets);
      expect(find.text('Resmî alındı'), findsWidgets);
      expect(find.text('Resmî alındı kaydı değiştirilemez.'), findsOneWidget);
    },
  );

  testWidgets('authority receipt document and hash pair fails closed', (
    tester,
  ) async {
    final repository = FakeCustomsAuthoritySubmissionRepository()
      ..detail = sampleAuthoritySubmissionDetail(
        status: 'submitted_externally',
        includePackage: true,
        includeScope: true,
        submittedAt: '2026-07-25T10:02:00.000Z',
        externalSubmissionStatement: 'Paket dış kanalda teslim edildi.',
      );
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpAuthorityOperationsDetail(tester, repository);

    await tapVisible(
      tester,
      find.byKey(const ValueKey('record-customs-submission-receipt')),
    );
    await completeAuthorityReceiptForm(tester, includeHash: false);
    await tapVisible(
      tester,
      find.byKey(const ValueKey('review-authority-receipt')),
    );

    expect(
      find.text('Belge SHA-256 değeri referansla birlikte girilmelidir.'),
      findsOneWidget,
    );
    expect(repository.receiptCalls, 0);
    expect(
      find.byKey(const ValueKey('confirm-record-authority-receipt')),
      findsNothing,
    );
  });

  testWidgets(
    'information request records attachments and moves canonical file to requested state',
    (tester) async {
      final repository = FakeCustomsAuthoritySubmissionRepository()
        ..detail = sampleAuthoritySubmissionDetail(
          status: 'submitted_externally',
          includePackage: true,
          includeScope: true,
          submittedAt: '2026-07-25T10:02:00.000Z',
          externalSubmissionStatement: 'Paket dış kanalda teslim edildi.',
        );
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await pumpAuthorityOperationsDetail(tester, repository);

      await tapVisible(
        tester,
        find.byKey(const ValueKey('append-customs-authority-response')),
      );
      await completeAuthorityResponseForm(
        tester,
        informationRequest: true,
        addAttachment: true,
      );
      await tapVisible(
        tester,
        find.byKey(const ValueKey('review-authority-response')),
      );
      await tester.tap(
        find.byKey(const ValueKey('confirm-append-authority-response')),
      );
      await tester.pumpAndSettle();

      expect(repository.authorityResponseCalls, 1);
      expect(repository.authorityResponseRequestIds, [
        'stable-authority-operation-id',
      ]);
      expect(
        repository.lastAuthorityResponseDraft?.responseType,
        CustomsInterimAuthorityResponseType.informationRequest,
      );
      expect(repository.lastAuthorityResponseDraft?.requestedDueAt, isNotNull);
      expect(repository.lastAuthorityResponseDraft?.attachmentReferences, [
        'authority-letter-1',
      ]);
      expect(find.text('Ek bilgi talep edildi'), findsWidgets);
      expect(find.text('Ek bilgi talebi'), findsWidgets);
      expect(repository.detailCalls, 2);
    },
  );

  testWidgets('authority response invalid attachment hash fails closed', (
    tester,
  ) async {
    final repository = FakeCustomsAuthoritySubmissionRepository()
      ..detail = sampleAuthoritySubmissionDetail(
        status: 'receipt_recorded',
        includePackage: true,
        includeScope: true,
        submittedAt: '2026-07-25T10:02:00.000Z',
        externalSubmissionStatement: 'Paket dış kanalda teslim edildi.',
        officialReferenceNumber: 'FSMH-2026-ALINDI',
        receiptRecordedAt: '2026-07-25T10:05:00.000Z',
      );
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpAuthorityOperationsDetail(tester, repository);

    await tapVisible(
      tester,
      find.byKey(const ValueKey('append-customs-authority-response')),
    );
    await completeAuthorityResponseForm(
      tester,
      addAttachment: true,
      validHash: false,
    );
    await tapVisible(
      tester,
      find.byKey(const ValueKey('review-authority-response')),
    );

    expect(
      find.text('Ek SHA-256 değeri 64 haneli hex olmalıdır.'),
      findsOneWidget,
    );
    expect(repository.authorityResponseCalls, 0);
  });

  testWidgets(
    'recoverable authority receipt retry preserves request id and draft',
    (tester) async {
      final repository = FakeCustomsAuthoritySubmissionRepository()
        ..detail = sampleAuthoritySubmissionDetail(
          status: 'submitted_externally',
          includePackage: true,
          includeScope: true,
          submittedAt: '2026-07-25T10:02:00.000Z',
          externalSubmissionStatement: 'Paket dış kanalda teslim edildi.',
        )
        ..receiptError = FirebaseFunctionsException(
          code: 'unavailable',
          message: 'technical',
        );
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await pumpAuthorityOperationsDetail(tester, repository);

      await tapVisible(
        tester,
        find.byKey(const ValueKey('record-customs-submission-receipt')),
      );
      await completeAuthorityReceiptForm(tester);
      await tapVisible(
        tester,
        find.byKey(const ValueKey('review-authority-receipt')),
      );
      await tester.tap(
        find.byKey(const ValueKey('confirm-record-authority-receipt')),
      );
      await tester.pumpAndSettle();

      expect(repository.receiptCalls, 1);
      expect(
        find.byKey(const ValueKey('retry-customs-submission-receipt')),
        findsOneWidget,
      );

      repository.receiptError = null;
      await tapVisible(
        tester,
        find.byKey(const ValueKey('retry-customs-submission-receipt')),
      );
      await tester.tap(
        find.byKey(const ValueKey('confirm-retry-authority-receipt')),
      );
      await tester.pumpAndSettle();

      expect(repository.receiptCalls, 2);
      expect(repository.receiptRequestIds, [
        'stable-authority-operation-id',
        'stable-authority-operation-id',
      ]);
      expect(
        repository.lastReceiptDraft?.officialReferenceNumber,
        'FSMH-2026-ALINDI-1',
      );
      expect(find.text('Teslim kaydı alındı'), findsWidgets);
    },
  );

  testWidgets(
    'terminal outcome matrix and two confirmations conclude the canonical file',
    (tester) async {
      final repository = FakeCustomsAuthoritySubmissionRepository()
        ..detail = sampleAuthoritySubmissionDetail(
          status: 'receipt_recorded',
          includePackage: true,
          includeScope: true,
          submittedAt: '2026-07-25T10:02:00.000Z',
          externalSubmissionStatement: 'Paket dış kanalda teslim edildi.',
          officialReferenceNumber: 'FSMH-2026-ALINDI',
          receiptRecordedAt: '2026-07-25T10:05:00.000Z',
        );
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await pumpAuthorityOperationsDetail(tester, repository);

      await tapVisible(
        tester,
        find.byKey(const ValueKey('record-customs-authority-outcome')),
      );
      await tester.tap(
        find.byKey(const ValueKey('authority-outcome-response-type')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ret bildirimi').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('authority-outcome-code')));
      await tester.pumpAndSettle();
      expect(find.text('Başvuru reddedildi'), findsWidgets);
      expect(find.text('İşlem yapıldı'), findsNothing);
      await tester.tap(find.text('Başvuru reddedildi').last);
      await tester.pumpAndSettle();

      await completeAuthorityOutcomeForm(tester, confirmNeutrality: false);
      await tapVisible(
        tester,
        find.byKey(const ValueKey('review-authority-outcome')),
      );
      expect(
        find.text('İnsan girişi ve hukukî tarafsızlık teyitleri zorunludur.'),
        findsOneWidget,
      );
      expect(repository.authorityOutcomeCalls, 0);

      await tester.tap(
        find.byKey(const ValueKey('authority-outcome-neutrality-confirmation')),
      );
      await tester.pump();
      await tapVisible(
        tester,
        find.byKey(const ValueKey('review-authority-outcome')),
      );
      await tester.tap(
        find.byKey(const ValueKey('confirm-record-authority-outcome')),
      );
      await tester.pumpAndSettle();

      expect(repository.authorityOutcomeCalls, 1);
      expect(repository.authorityOutcomeRequestIds, [
        'stable-authority-operation-id',
      ]);
      expect(
        repository.lastAuthorityOutcomeDraft?.responseType,
        CustomsFinalAuthorityResponseType.rejectionNotice,
      );
      expect(
        repository.lastAuthorityOutcomeDraft?.outcomeCode,
        CustomsAuthorityOutcomeCode.rejected,
      );
      expect(
        repository.lastAuthorityOutcomeDraft?.outcomeFinalityLevel,
        CustomsAuthorityOutcomeFinalityLevel.administrativeFinal,
      );
      expect(repository.lastAuthorityOutcomeDraft?.humanEntryConfirmed, isTrue);
      expect(find.text('Sonuçlandı'), findsWidgets);
      expect(
        find.byKey(const ValueKey('authority-outcome-summary')),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          'MarkaKalkan tarafından verilmiş hukukî karar değildir',
        ),
        findsWidgets,
      );
      expect(repository.detailCalls, 2);
    },
  );

  testWidgets('concluded file locks all authority write operations', (
    tester,
  ) async {
    final finalResponse = <String, dynamic>{
      'responseId': 'final-response-1',
      'submissionId': 'submission-1',
      'responseType': 'decision',
      'authorityReference': 'FSMH-2026-SONUC-1',
      'receivedAt': '2026-07-25T11:00:00.000Z',
      'receivedByUid': 'user-1',
      'summary': 'Kurum nihai kararını bildirdi.',
      'attachmentReferences': const <String>[],
      'attachmentHashes': const <String>[],
      'outcomeCode': 'action_taken',
      'outcomeFinalityLevel': 'administrative_final',
      'officialDocumentDate': '2026-07-25T10:30:00.000Z',
      'authorityNameSnapshot': 'FSMH Programı',
      'attachmentIntegrityStatus': 'metadata_only_unverified',
      'immutable': true,
    };
    final repository = FakeCustomsAuthoritySubmissionRepository()
      ..detail = sampleAuthoritySubmissionDetail(
        status: 'concluded',
        includePackage: true,
        includeScope: true,
        submittedAt: '2026-07-25T10:02:00.000Z',
        externalSubmissionStatement: 'Paket dış kanalda teslim edildi.',
        officialReferenceNumber: 'FSMH-2026-ALINDI',
        receiptRecordedAt: '2026-07-25T10:05:00.000Z',
        outcomeResponseId: 'final-response-1',
        outcomeCode: 'action_taken',
        outcomeFinalityLevel: 'administrative_final',
        authorityReferenceNumber: 'FSMH-2026-SONUC-1',
        officialDocumentDate: '2026-07-25T10:30:00.000Z',
        outcomeReceivedAt: '2026-07-25T11:00:00.000Z',
        outcomeRecordedAt: '2026-07-25T11:01:00.000Z',
        authorityNameSnapshot: 'FSMH Programı',
        outcomeSummary: 'Kurum nihai kararını bildirdi.',
        responses: [finalResponse],
      );
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpAuthorityOperationsDetail(tester, repository);

    expect(
      find.byKey(const ValueKey('record-customs-submission-receipt')),
      findsNothing,
    );
    final responseButton = find.byKey(
      const ValueKey('append-customs-authority-response'),
    );
    final outcomeButton = find.byKey(
      const ValueKey('record-customs-authority-outcome'),
    );
    await tester.ensureVisible(responseButton);
    expect(tester.widget<FilledButton>(responseButton).onPressed, isNull);
    await tester.ensureVisible(outcomeButton);
    expect(tester.widget<FilledButton>(outcomeButton).onPressed, isNull);
    expect(
      find.text('Dosya sonucunu ve kapanış kaydını inceleyin'),
      findsOneWidget,
    );
    expect(find.text('Nihai sonuç ve kapanış özeti'), findsOneWidget);
  });

  testWidgets('authority operations remain scrollable on mobile viewport', (
    tester,
  ) async {
    final repository = FakeCustomsAuthoritySubmissionRepository()
      ..detail = sampleAuthoritySubmissionDetail(
        status: 'submitted_externally',
        includePackage: true,
        includeScope: true,
        submittedAt: '2026-07-25T10:02:00.000Z',
        externalSubmissionStatement: 'Paket dış kanalda teslim edildi.',
      );
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpAuthorityOperationsDetail(
      tester,
      repository,
      size: const Size(390, 700),
    );

    final outcome = find.byKey(
      const ValueKey('record-customs-authority-outcome'),
    );
    await tester.ensureVisible(outcome);
    await tester.pumpAndSettle();
    expect(outcome, findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(outcome);
    await tester.pumpAndSettle();
    final review = find.byKey(const ValueKey('review-authority-outcome'));
    await tester.ensureVisible(review);
    await tester.pumpAndSettle();
    expect(review, findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('hub exposes three canonical official-operation views', (
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
          submissionDetailOpener: (context, submissionId, initialStage) async {
            openedId = submissionId;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final applicationTab = find.byKey(
      const ValueKey('customs-authority-submission-tab'),
    );
    await tester.ensureVisible(applicationTab);
    await tester.tap(applicationTab);
    await tester.pumpAndSettle();
    expect(find.text('Resmî Başvurular ve İhbarlar'), findsWidgets);
    expect(find.text('İnsan incelemesi kaydı bekleniyor'), findsOneWidget);
    expect(find.text('Başvuruyu incele'), findsOneWidget);
    expect(
      find.byKey(
        const ValueKey('customs-authority-submission-submission-1-action'),
      ),
      findsOneWidget,
    );
    expect(find.byType(FloatingActionButton), findsNothing);
    await tapVisible(
      tester,
      find.byKey(const ValueKey('customs-authority-submission-submission-1')),
    );
    expect(openedId, 'submission-1');

    openedId = null;
    final packageTab = find.byKey(
      const ValueKey('customs-package-delivery-tab'),
    );
    await tester.ensureVisible(packageTab);
    await tester.tap(packageTab);
    await tester.pumpAndSettle();
    expect(find.text('Paket ve Resmî Teslim'), findsWidgets);
    expect(find.text('Başvuru paketi henüz oluşturulmadı'), findsOneWidget);
    expect(find.text('Paket hazırlığını aç'), findsOneWidget);
    expect(
      find.text(
        'Paket hazırlığı için önce başvuru ve insan kontrol kapılarını tamamlayın.',
      ),
      findsOneWidget,
    );
    await tapVisible(
      tester,
      find.byKey(const ValueKey('customs-package-delivery-submission-1')),
    );
    expect(openedId, 'submission-1');

    openedId = null;
    final responseTab = find.byKey(
      const ValueKey('customs-authority-response-tab'),
    );
    await tester.ensureVisible(responseTab);
    await tester.tap(responseTab);
    await tester.pumpAndSettle();
    expect(find.text('Kurum Cevapları ve Sonuçlar'), findsWidgets);
    expect(find.text('Kurum cevabı henüz kaydedilmedi'), findsOneWidget);
    await tapVisible(
      tester,
      find.byKey(const ValueKey('customs-authority-response-submission-1')),
    );
    expect(openedId, isNull);
    expect(find.text('Önce kuruma dış teslim kaydedilmelidir.'), findsWidgets);
  });

  testWidgets(
    'operation stage selection opens the canonical submission at artifact target',
    (tester) async {
      final repository = FakeCustomsSecurityRepository();
      final authorityRepository = FakeCustomsAuthoritySubmissionRepository();
      String? openedId;
      CustomsAuthoritySubmissionStage? openedStage;

      await tester.binding.setSurfaceSize(const Size(1100, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: CustomsSecurityHubPage(
            repository: repository,
            authorityRepository: authorityRepository,
            submissionDetailOpener:
                (context, submissionId, initialStage) async {
                  openedId = submissionId;
                  openedStage = initialStage;
                },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tapVisible(
        tester,
        find.byKey(
          const ValueKey(
            'customs-operation-stage-action-downloadableOfficialFile',
          ),
        ),
      );
      expect(find.text('Resmî dosya durumunu aç'), findsOneWidget);
      expect(
        find.text('Önce başvuru paketi oluşturulmalıdır.'),
        findsOneWidget,
      );
      await tapVisible(
        tester,
        find.byKey(const ValueKey('customs-package-delivery-submission-1')),
      );

      expect(openedId, 'submission-1');
      expect(
        openedStage,
        CustomsAuthoritySubmissionStage.downloadableOfficialFile,
      );
    },
  );

  testWidgets(
    'workspace swipe keeps the operation stage aligned with the visible tab',
    (tester) async {
      final repository = FakeCustomsSecurityRepository();
      final authorityRepository = FakeCustomsAuthoritySubmissionRepository()
        ..submissions = [
          sampleAuthoritySubmissionDetail(
            status: 'submitted_externally',
            includePackage: true,
            includeScope: true,
            submittedAt: '2026-07-28T12:00:00.000Z',
          ).submission,
        ];
      CustomsAuthoritySubmissionStage? openedStage;

      await tester.binding.setSurfaceSize(const Size(1100, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: CustomsSecurityHubPage(
            repository: repository,
            authorityRepository: authorityRepository,
            submissionDetailOpener:
                (context, submissionId, initialStage) async {
                  openedStage = initialStage;
                },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tapVisible(
        tester,
        find.byKey(
          const ValueKey(
            'customs-operation-stage-action-downloadableOfficialFile',
          ),
        ),
      );

      final tabView = find.byType(TabBarView);
      await tester.ensureVisible(tabView);
      await tester.pumpAndSettle();
      await tester.drag(tabView, const Offset(-900, 0));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('customs-authority-response-status-filter')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<Semantics>(
              find.byKey(
                const ValueKey(
                  'customs-operation-stage-semantics-deliveryResponseOutcome',
                ),
              ),
            )
            .properties
            .selected,
        isTrue,
      );

      await tapVisible(
        tester,
        find.byKey(const ValueKey('customs-authority-response-submission-1')),
      );

      expect(
        openedStage,
        CustomsAuthoritySubmissionStage.deliveryResponseOutcome,
      );
    },
  );

  testWidgets(
    'outcome stage stays locked until external delivery is recorded',
    (tester) async {
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
            submissionDetailOpener:
                (context, submissionId, initialStage) async {
                  openedId = submissionId;
                },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tapVisible(
        tester,
        find.byKey(
          const ValueKey(
            'customs-operation-stage-action-deliveryResponseOutcome',
          ),
        ),
      );
      expect(
        find.text('Önce kuruma dış teslim kaydedilmelidir.'),
        findsOneWidget,
      );

      await tapVisible(
        tester,
        find.byKey(const ValueKey('customs-authority-response-submission-1')),
      );

      expect(openedId, isNull);
      expect(
        find.text('Önce kuruma dış teslim kaydedilmelidir.'),
        findsWidgets,
      );
    },
  );

  testWidgets('detail page scrolls to the requested operation stage', (
    tester,
  ) async {
    final repository = FakeCustomsAuthoritySubmissionRepository();
    await tester.binding.setSurfaceSize(const Size(1100, 650));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: CustomsAuthoritySubmissionDetailPage(
          submissionId: 'submission-1',
          repository: repository,
          initialStage: CustomsAuthoritySubmissionStage.deliveryResponseOutcome,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final anchor = find.byKey(
      const ValueKey('authority-stage-anchor-deliveryResponseOutcome'),
    );
    expect(anchor, findsOneWidget);
    final scrollable = tester.state<ScrollableState>(
      find.byType(Scrollable).first,
    );
    expect(scrollable.position.pixels, greaterThan(0));
    expect(tester.getTopLeft(anchor).dy, inInclusiveRange(0, 650));
  });

  testWidgets(
    'authority delivery target remains available before artifact materialization',
    (tester) async {
      final repository = FakeCustomsAuthoritySubmissionRepository()
        ..detail = sampleAuthoritySubmissionDetail(
          status: 'package_generated',
          includePackage: true,
          includeScope: true,
          artifactStatus: 'legacy_not_materialized',
        );
      await tester.binding.setSurfaceSize(const Size(1100, 760));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: CustomsAuthoritySubmissionDetailPage(
            submissionId: 'submission-1',
            repository: repository,
            initialStage: CustomsAuthoritySubmissionStage.authorityDelivery,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('authority-stage-anchor-authorityDelivery')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('record-external-submission')),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          'Güvenli indirme dosyalarının hazır olması bu kayıt için',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('default detail target keeps submission content at the top', (
    tester,
  ) async {
    final repository = FakeCustomsAuthoritySubmissionRepository();
    await tester.binding.setSurfaceSize(const Size(1100, 900));
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

    final scrollable = tester.state<ScrollableState>(
      find.byType(Scrollable).first,
    );
    expect(scrollable.position.pixels, 0);
    expect(
      find.byKey(const ValueKey('authority-stage-anchor-submissionContent')),
      findsOneWidget,
    );
  });

  testWidgets('detail guidance explains the missing human control gates', (
    tester,
  ) async {
    final repository = FakeCustomsAuthoritySubmissionRepository();
    await tester.binding.setSurfaceSize(const Size(1100, 1100));
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

    expect(
      find.byKey(const ValueKey('authority-next-step-guidance')),
      findsOneWidget,
    );
    expect(find.text('Şimdi ne yapmalısınız?'), findsOneWidget);
    expect(find.text('Başvuruyu insan incelemesine gönderin'), findsOneWidget);
    expect(find.textContaining('Dosya taslak durumda'), findsOneWidget);
    expect(find.textContaining('Bu adımın çıktısı:'), findsOneWidget);
  });

  testWidgets(
    'detail guidance keeps artifact preparation and delivery independent',
    (tester) async {
      final repository = FakeCustomsAuthoritySubmissionRepository()
        ..detail = sampleAuthoritySubmissionDetail(
          status: 'package_generated',
          includePackage: true,
          includeScope: true,
          artifactStatus: 'legacy_not_materialized',
          humanReviewReference: 'review-1',
          rightsHolderApprovalReference: 'approval-1',
          dataMinimizationConfirmed: true,
          nonAccusatoryLanguageConfirmed: true,
        );
      await tester.binding.setSurfaceSize(const Size(1100, 1500));
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

      expect(
        find.text('Resmî dosyaları hazırlayın veya dış teslimi kaydedin'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Güvenli indirme dosyalarının hazır olması'),
        findsWidgets,
      );
      expect(
        find.byKey(const ValueKey('record-external-submission')),
        findsOneWidget,
      );
    },
  );

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

  testWidgets('draft submits the same canonical file for human review', (
    tester,
  ) async {
    final repository = FakeCustomsAuthoritySubmissionRepository()
      ..detail = sampleAuthoritySubmissionDetail(
        status: 'draft',
        includeScope: true,
      );
    await pumpReviewApprovalDetail(
      tester,
      repository,
      requestIds: const ['submit-review-request-id'],
    );
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tapVisible(tester, find.byKey(const ValueKey('submit-human-review')));
    await completeSubmitHumanReviewForm(tester);
    await tester.tap(find.byKey(const ValueKey('confirm-submit-human-review')));
    await tester.pumpAndSettle();

    expect(repository.transitionCalls, 1);
    expect(repository.updateCalls, 0);
    expect(repository.lastReviewApprovalTenantId, 'tenant-1');
    expect(repository.lastReviewApprovalCanonicalBrandId, 'brand-1');
    expect(repository.lastReviewApprovalSubmissionId, 'submission-1');
    expect(repository.lastTransitionStatus, 'awaiting_human_review');
    expect(repository.transitionSubmissionRequestIds, [
      'submit-review-request-id',
    ]);
    expect(repository.detail?.submission.status, 'awaiting_human_review');
    expect(find.byKey(const ValueKey('complete-human-review')), findsOneWidget);
  });

  testWidgets(
    'human review records reference before rights holder approval transition',
    (tester) async {
      final repository = FakeCustomsAuthoritySubmissionRepository()
        ..detail = sampleAuthoritySubmissionDetail(
          status: 'awaiting_human_review',
          includeScope: true,
        );
      await pumpReviewApprovalDetail(
        tester,
        repository,
        requestIds: const [
          'human-review-update-id',
          'human-review-transition-id',
        ],
      );
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tapVisible(
        tester,
        find.byKey(const ValueKey('complete-human-review')),
      );
      await completeHumanReviewForm(tester);
      await tester.tap(
        find.byKey(const ValueKey('confirm-complete-human-review')),
      );
      await tester.pumpAndSettle();

      expect(repository.updateCalls, 1);
      expect(repository.transitionCalls, 1);
      expect(
        repository.lastUpdateDraft?.humanReviewReference,
        'HUMAN-REVIEW-2026-0001',
      );
      expect(
        repository.lastTransitionStatus,
        'awaiting_rights_holder_approval',
      );
      expect(repository.updateSubmissionRequestIds, ['human-review-update-id']);
      expect(repository.transitionSubmissionRequestIds, [
        'human-review-transition-id',
      ]);
      expect(
        repository.detail?.submission.humanReviewReference,
        'HUMAN-REVIEW-2026-0001',
      );
      expect(
        repository.detail?.submission.status,
        'awaiting_rights_holder_approval',
      );
      expect(find.byKey(const ValueKey('approve-for-package')), findsOneWidget);
    },
  );

  testWidgets(
    'rights holder approval enables package generation on the same file',
    (tester) async {
      final repository = FakeCustomsAuthoritySubmissionRepository()
        ..detail = sampleAuthoritySubmissionDetail(
          status: 'awaiting_rights_holder_approval',
          includeScope: true,
          humanReviewReference: 'HUMAN-REVIEW-2026-0001',
        );
      await pumpReviewApprovalDetail(
        tester,
        repository,
        requestIds: const [
          'package-approval-update-id',
          'package-approval-transition-id',
        ],
      );
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tapVisible(
        tester,
        find.byKey(const ValueKey('approve-for-package')),
      );
      await completeRightsHolderApprovalForm(tester);
      await tester.tap(
        find.byKey(const ValueKey('confirm-approve-for-package')),
      );
      await tester.pumpAndSettle();

      expect(repository.updateCalls, 1);
      expect(repository.transitionCalls, 1);
      expect(
        repository.lastUpdateDraft?.rightsHolderApprovalReference,
        'RIGHTS-APPROVAL-2026-0001',
      );
      expect(repository.lastUpdateDraft?.dataMinimizationConfirmed, isTrue);
      expect(
        repository.lastUpdateDraft?.nonAccusatoryLanguageConfirmed,
        isTrue,
      );
      expect(repository.lastTransitionStatus, 'approved_for_package');
      expect(repository.updateSubmissionRequestIds, [
        'package-approval-update-id',
      ]);
      expect(repository.transitionSubmissionRequestIds, [
        'package-approval-transition-id',
      ]);
      expect(repository.detail?.submission.status, 'approved_for_package');
      expect(
        repository.detail?.submission.rightsHolderApprovalReference,
        'RIGHTS-APPROVAL-2026-0001',
      );
      final generateButton = tester.widget<FilledButton>(
        find.byKey(const ValueKey('generate-customs-submission-package')),
      );
      expect(generateButton.onPressed, isNotNull);
    },
  );

  testWidgets(
    'rights holder approval fails closed without three confirmations',
    (tester) async {
      final repository = FakeCustomsAuthoritySubmissionRepository()
        ..detail = sampleAuthoritySubmissionDetail(
          status: 'awaiting_rights_holder_approval',
          includeScope: true,
          humanReviewReference: 'HUMAN-REVIEW-2026-0001',
        );
      await pumpReviewApprovalDetail(tester, repository);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tapVisible(
        tester,
        find.byKey(const ValueKey('approve-for-package')),
      );
      await completeRightsHolderApprovalForm(tester, confirmations: false);

      expect(
        find.byKey(const ValueKey('rights-holder-approval-confirmation-error')),
        findsOneWidget,
      );
      expect(repository.updateCalls, 0);
      expect(repository.transitionCalls, 0);
    },
  );

  testWidgets('partial human review retry preserves both secure request ids', (
    tester,
  ) async {
    final repository = FakeCustomsAuthoritySubmissionRepository()
      ..detail = sampleAuthoritySubmissionDetail(
        status: 'awaiting_human_review',
        includeScope: true,
      )
      ..transitionSubmissionError = FirebaseFunctionsException(
        code: 'unavailable',
        message: 'temporary',
      );
    await pumpReviewApprovalDetail(
      tester,
      repository,
      requestIds: const [
        'stable-review-update-id',
        'stable-review-transition-id',
      ],
    );
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tapVisible(
      tester,
      find.byKey(const ValueKey('complete-human-review')),
    );
    await completeHumanReviewForm(tester);
    await tester.tap(
      find.byKey(const ValueKey('confirm-complete-human-review')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('retry-complete-human-review')),
      findsOneWidget,
    );
    repository.transitionSubmissionError = null;
    await tapVisible(
      tester,
      find.byKey(const ValueKey('retry-complete-human-review')),
    );
    await tester.tap(
      find.byKey(const ValueKey('confirm-retry-complete-human-review')),
    );
    await tester.pumpAndSettle();

    expect(repository.updateSubmissionRequestIds, [
      'stable-review-update-id',
      'stable-review-update-id',
    ]);
    expect(repository.transitionSubmissionRequestIds, [
      'stable-review-transition-id',
      'stable-review-transition-id',
    ]);
    expect(
      repository.detail?.submission.status,
      'awaiting_rights_holder_approval',
    );
  });

  testWidgets('downstream files lock review and approval writes', (
    tester,
  ) async {
    final repository = FakeCustomsAuthoritySubmissionRepository()
      ..detail = sampleAuthoritySubmissionDetail(
        status: 'package_generated',
        includePackage: true,
        includeScope: true,
        humanReviewReference: 'review-1',
        rightsHolderApprovalReference: 'approval-1',
        dataMinimizationConfirmed: true,
        nonAccusatoryLanguageConfirmed: true,
      );
    await pumpReviewApprovalDetail(tester, repository);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    expect(find.byKey(const ValueKey('submit-human-review')), findsNothing);
    expect(find.byKey(const ValueKey('complete-human-review')), findsNothing);
    expect(find.byKey(const ValueKey('approve-for-package')), findsNothing);
    expect(find.textContaining('yazma işlemleri kilitlidir'), findsOneWidget);
  });

  testWidgets(
    'review approval workspace remains scrollable on mobile viewport',
    (tester) async {
      final repository = FakeCustomsAuthoritySubmissionRepository()
        ..detail = sampleAuthoritySubmissionDetail(
          status: 'draft',
          includeScope: true,
        );
      await pumpReviewApprovalDetail(
        tester,
        repository,
        size: const Size(390, 700),
      );
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final button = find.byKey(const ValueKey('submit-human-review'));
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      expect(button, findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('human-review-submission-reason')),
        findsOneWidget,
      );
      expect(find.byType(SingleChildScrollView), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );
}

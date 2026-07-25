import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markakalkan/features/customs_security/presentation/customs_authority_submission_detail_page.dart';
import 'package:markakalkan/features/customs_security/presentation/customs_security_detail_page.dart';
import 'package:markakalkan/features/customs_security/presentation/customs_security_hub_page.dart';

import 'customs_authority_submission_test_fakes.dart';
import 'customs_security_test_fakes.dart';

void main() {
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

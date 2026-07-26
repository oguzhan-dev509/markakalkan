import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markakalkan/core/security/app_check_bootstrap.dart';
import 'package:markakalkan/features/customs_security/data/customs_authority_submission_repository.dart';
import 'package:markakalkan/features/customs_security/data/customs_security_repository.dart';
import 'package:markakalkan/features/customs_security/presentation/customs_authority_submission_labels.dart';
import 'package:markakalkan/features/customs_security/presentation/customs_security_labels.dart';

void main() {
  test(
    'atomic profile activation waits for readiness before one invocation',
    () async {
      final readiness = Completer<void>();
      var invocations = 0;
      final repository = CallableCustomsSecurityRepository(
        ensureAppCheckReady: () => readiness.future,
        callable: (name, _) async {
          expect(name, 'createAndActivateCustomsProtectionProfile');
          invocations++;
          return <String, dynamic>{};
        },
      );
      final operation = repository.createAndActivateProfile(
        const CustomsProtectionProfileDraft(
          profileName: 'Profil',
          rightHolderName: 'Hak sahibi',
          authenticationInstructions: 'Doğrulama talimatı yeterince uzundur.',
        ),
        requestId: '123e4567-e89b-42d3-a456-426614174000',
      );
      await Future<void>.delayed(Duration.zero);
      expect(invocations, 0);
      readiness.complete();
      await expectLater(operation, throwsFormatException);
      expect(invocations, 1);
    },
  );

  test(
    'protected transition waits for readiness before one invocation',
    () async {
      final readiness = Completer<void>();
      var invocations = 0;
      final repository = CallableCustomsSecurityRepository(
        ensureAppCheckReady: () => readiness.future,
        requestIdFactory: () => '123e4567-e89b-42d3-a456-426614174000',
        callable: (_, _) async {
          invocations++;
          return <String, dynamic>{};
        },
      );

      final transition = repository.transitionProfile(
        profileId: 'profile-1',
        nextStatus: 'under_review',
        reason: 'İnsan incelemesi başlatıldı.',
      );
      await Future<void>.delayed(Duration.zero);
      expect(invocations, 0);

      readiness.complete();
      await expectLater(transition, throwsFormatException);
      expect(invocations, 1);
    },
  );

  test('customs reads do not wait for App Check readiness', () async {
    var readinessCalls = 0;
    var invocations = 0;
    final repository = CallableCustomsSecurityRepository(
      ensureAppCheckReady: () async => readinessCalls++,
      callable: (name, _) async {
        invocations++;
        expect(name, 'listCustomsProtectionProfiles');
        return {
          'contractVersion': 'customs-protection-profile-list-v1',
          'items': <Object>[],
          'nextPageToken': null,
          'readOnly': true,
          'writesPerformed': 0,
        };
      },
    );

    final result = await repository.listProfiles();
    expect(result.items, isEmpty);
    expect(invocations, 1);
    expect(readinessCalls, 0);
  });

  test('authority submission writes use the common readiness gate', () async {
    var readinessCalls = 0;
    var invocations = 0;
    final repository = CallableCustomsAuthoritySubmissionRepository(
      ensureAppCheckReady: () async => readinessCalls++,
      requestIdFactory: () => '123e4567-e89b-42d3-a456-426614174000',
      callable: (_, _) async {
        invocations++;
        return <String, dynamic>{};
      },
    );
    const draft = CustomsAuthoritySubmissionDraft(
      submissionType: 'fsmh_protection_application',
      targetAuthority: 'fsmh_program',
      protectionProfileId: 'profile-1',
      incidentReference: 'GKP-2026-001',
      title: 'Gümrük koruma başvurusu',
      authoritySummary:
          'Aktif koruma profiline dayanan resmî başvuru özeti hazırlanmıştır.',
    );

    await expectLater(
      repository.createSubmission(draft),
      throwsFormatException,
    );
    expect(readinessCalls, 1);
    expect(invocations, 1);
  });

  test('authority submission reads bypass readiness', () async {
    var readinessCalls = 0;
    final repository = CallableCustomsAuthoritySubmissionRepository(
      ensureAppCheckReady: () async => readinessCalls++,
      callable: (_, _) async => {
        'contractVersion': 'customs-authority-submission-list-v1',
        'items': <Object>[],
        'nextPageToken': null,
        'readOnly': true,
        'writesPerformed': 0,
      },
    );

    final result = await repository.listSubmissions();
    expect(result.items, isEmpty);
    expect(readinessCalls, 0);
  });

  test('Auth and App Check failures have different user messages', () {
    final auth = FirebaseFunctionsException(
      code: 'unauthenticated',
      message: 'technical',
    );
    const appCheck = AppCheckUnavailableException();
    const securityMessage =
        'Uygulama güvenlik doğrulaması tamamlanamadı. '
        'Bağlantınızı kontrol edip yeniden deneyin.';

    expect(
      customsSecurityErrorMessage(auth),
      'Devam etmek için oturum açmanız gerekir.',
    );
    expect(customsSecurityErrorMessage(appCheck), securityMessage);
    expect(
      customsAuthoritySubmissionErrorMessage(auth),
      'Devam etmek için oturum açmanız gerekir.',
    );
    expect(customsAuthoritySubmissionErrorMessage(appCheck), securityMessage);
  });
}

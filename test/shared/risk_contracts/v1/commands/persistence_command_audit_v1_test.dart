import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:markakalkan/shared/risk_contracts/v1/audit/audit_v1.dart';
import 'package:markakalkan/shared/risk_contracts/v1/commands/commands_v1.dart';
import 'package:markakalkan/shared/risk_contracts/v1/idempotency/idempotency_v1.dart';
import 'package:markakalkan/shared/risk_contracts/v1/identity/identity_v1.dart';
import 'package:markakalkan/shared/risk_contracts/v1/persistence/persistence_v1.dart';

import '../persistence/persistence_test_fixtures.dart' as base;
import 'command_test_fixtures.dart';

bool hasCode(PersistenceCommandAuditDecisionV1 result, String code) =>
    result.blockers.any((issue) => issue.code == code) ||
    result.warnings.any((issue) => issue.code == code);

void main() {
  group('authorization', () {
    test('exact permission allows, roles alone and wrong permission deny', () {
      expect(auditSignal(signalCommand()).executable, isTrue);
      for (final permissions in <List<String>>[
        const [],
        const ['other.persist'],
      ]) {
        final result = auditSignal(
          signalCommand(
            auth: authorization(
              roles: const ['admin', 'risk_writer'],
              permissions: permissions,
            ),
          ),
        );
        expect(result.executable, isFalse);
        expect(hasCode(result, 'authorization.permission_missing'), isTrue);
      }
    });

    test('tenant, brand, expired, and future authorization deny', () {
      final contexts = [
        authorization(tenantId: 'tenant-2'),
        authorization(brandId: 'brand-2'),
        authorization(expiresAt: commandAt),
        authorization(authorizedAt: commandAt.add(const Duration(seconds: 1))),
      ];
      for (final auth in contexts) {
        expect(auditSignal(signalCommand(auth: auth)).executable, isFalse);
      }
    });

    test('roles and permissions canonicalize without mutating inputs', () {
      final roles = ['writer', 'admin', 'writer'];
      final permissions = ['risk_signal.persist', 'a', 'risk_signal.persist'];
      final auth = authorization(roles: roles, permissions: permissions);
      expect(auth.roles, ['admin', 'writer']);
      expect(auth.permissions, ['a', 'risk_signal.persist']);
      expect(roles, ['writer', 'admin', 'writer']);
      expect(permissions, ['risk_signal.persist', 'a', 'risk_signal.persist']);
      expect(() => auth.metadata['x'] = true, throwsUnsupportedError);
    });
  });

  group('target and typed subjects', () {
    test('logical namespaces parse strictly', () {
      expect(
        parsePersistenceTargetNamespaceV1('shared_risk_signals'),
        PersistenceTargetNamespaceV1.sharedRiskSignals,
      );
      expect(
        () => parsePersistenceTargetNamespaceV1('unknown'),
        throwsFormatException,
      );
    });

    test('signal, risk, and candidate allow only their exact targets', () {
      expect(auditSignal(signalCommand()).executable, isTrue);
      expect(
        auditSignal(
          signalCommand(
            target: PersistenceTargetNamespaceV1.sharedRiskAssessments,
          ),
        ).executable,
        isFalse,
      );
      expect(
        const RiskAssessmentPersistenceCommandAuditorV1()
            .audit(riskCommand(), auditedAt: auditAt)
            .executable,
        isTrue,
      );
      expect(
        const RiskAssessmentPersistenceCommandAuditorV1()
            .audit(
              riskCommand(
                target: PersistenceTargetNamespaceV1.sharedRiskSignals,
              ),
              auditedAt: auditAt,
            )
            .executable,
        isFalse,
      );
      expect(
        const CaseCandidatePersistenceCommandAuditorV1()
            .audit(candidateCommand(), auditedAt: auditAt)
            .executable,
        isTrue,
      );
      expect(
        const CaseCandidatePersistenceCommandAuditorV1()
            .audit(
              candidateCommand(
                target: PersistenceTargetNamespaceV1.sharedRiskAssessments,
              ),
              auditedAt: auditAt,
            )
            .executable,
        isFalse,
      );
    });
  });

  group('readiness binding', () {
    test(
      'blocker, subject ID/type, policy, time, and identity fail closed',
      () {
        final valid = signalCommand().readinessBinding.decision;
        final blocker = PersistenceReadinessIssueV1(
          code: 'test.blocker',
          severity: PersistenceReadinessIssueSeverityV1.blocker,
          message: 'blocked',
        );
        final variants = [
          decisionCopy(valid, issues: [blocker]),
          decisionCopy(valid, subjectId: 'other'),
          decisionCopy(
            valid,
            subjectType: PersistenceSubjectTypeV1.riskAssessment,
          ),
          decisionCopy(valid, policyVersion: 'future-policy'),
          decisionCopy(
            valid,
            evaluatedAt: commandAt.add(const Duration(seconds: 1)),
          ),
          decisionCopy(
            valid,
            identityStatus: IdentityResolutionResultStatus.partial,
          ),
        ];
        for (final readiness in variants) {
          expect(
            auditSignal(signalCommand(readiness: readiness)).executable,
            isFalse,
          );
        }
      },
    );

    test(
      'readiness warning is preserved as warning and remains executable',
      () {
        final valid = signalCommand().readinessBinding.decision;
        final warning = PersistenceReadinessIssueV1(
          code: 'test.warning',
          severity: PersistenceReadinessIssueSeverityV1.warning,
          message: 'review suggested',
        );
        final result = auditSignal(
          signalCommand(readiness: decisionCopy(valid, issues: [warning])),
        );
        expect(result.executable, isTrue);
        expect(hasCode(result, 'readiness.warnings_present'), isTrue);
      },
    );
  });

  group('fingerprint', () {
    test('same semantic JSON is stable across map and set-like ref order', () {
      const builder = SubjectFingerprintBuilderV1();
      final first = builder.fromJson({
        'b': 2,
        'a': 1,
        'evidenceRefs': [
          {'id': 'b'},
          {'id': 'a'},
        ],
      });
      final second = builder.fromJson({
        'evidenceRefs': [
          {'id': 'a'},
          {'id': 'b'},
        ],
        'a': 1,
        'b': 2,
      });
      expect(first.value, second.value);
      expect(builder.fromJson({'a': 2}).value, isNot(first.value));
    });

    test('changed subject and unsupported algorithm deny', () {
      final original = signalCommand();
      final changed = base.signal(summary: 'Changed payload');
      expect(
        auditSignal(
          signalCommand(
            subject: changed,
            fingerprint: original.readinessBinding.subjectFingerprint,
          ),
        ).executable,
        isFalse,
      );
      expect(
        auditSignal(
          signalCommand(
            fingerprint: SubjectFingerprintV1(
              algorithm: 'unknown',
              value: original.readinessBinding.subjectFingerprint.value,
            ),
          ),
        ).executable,
        isFalse,
      );
    });
  });

  group('idempotency and command ID', () {
    test('exact source accepted and stable recurrence rejected', () {
      expect(
        PersistenceIdempotencyBindingV1.exactSource(
          base.keyFor('traceability'),
        ).purpose,
        PersistenceIdempotencyPurposeV1.exactSourceOccurrence,
      );
      const stable = SourceIngestionKeyBuilderV1();
      expect(
        () => PersistenceIdempotencyBindingV1.exactSource(
          stable.digitalDetectiveStableFinding(
            taskId: 'task',
            findingKey: 'finding',
          ),
        ),
        throwsFormatException,
      );
    });

    test('candidate initial key is distinct and target-bound', () {
      final a = candidateCommand();
      final b = candidateCommand(
        target: PersistenceTargetNamespaceV1.sharedRiskSignals,
      );
      expect(
        a.idempotencyBinding.purpose,
        PersistenceIdempotencyPurposeV1.caseCandidateInitialPersistence,
      );
      expect(
        a.idempotencyBinding.canonicalKey,
        isNot(b.idempotencyBinding.canonicalKey),
      );
      expect(a.commandId, isNot(b.commandId));
    });

    test('readiness missing or different exact key denies', () {
      final valid = signalCommand().readinessBinding.decision;
      for (final readiness in [
        decisionCopy(valid, removeIdempotencyKey: true),
        decisionCopy(valid, evaluatedIdempotencyKey: 'different'),
      ]) {
        expect(
          auditSignal(signalCommand(readiness: readiness)).executable,
          isFalse,
        );
      }
    });

    test(
      'command ID deterministic and changes with all identity components',
      () {
        final sameA = signalCommand();
        final sameB = signalCommand();
        expect(sameA.commandId, sameB.commandId);
        expect(
          signalCommand(auth: authorization(tenantId: 'tenant-2')).commandId,
          isNot(sameA.commandId),
        );
        expect(
          signalCommand(
            target: PersistenceTargetNamespaceV1.sharedRiskAssessments,
          ).commandId,
          isNot(sameA.commandId),
        );
        final otherKey = SourceIngestionKeyV1(
          sourceModule: 'traceability',
          sourceType: 'verification_scan',
          kind: SourceIngestionKeyKind.exactOccurrence,
          stableSourceParts: const ['other'],
        );
        expect(
          signalCommand(
            idempotency: PersistenceIdempotencyBindingV1.exactSource(otherKey),
          ).commandId,
          isNot(sameA.commandId),
        );
        expect(
          buildPersistenceCommandIdV1(
            subjectType: PersistenceSubjectTypeV1.riskSignal,
            subjectId: 'ab',
            targetNamespace: PersistenceTargetNamespaceV1.sharedRiskSignals,
            idempotencyKey: 'c',
            tenantId: 'd',
          ),
          isNot(
            buildPersistenceCommandIdV1(
              subjectType: PersistenceSubjectTypeV1.riskSignal,
              subjectId: 'a',
              targetNamespace: PersistenceTargetNamespaceV1.sharedRiskSignals,
              idempotencyKey: 'bc',
              tenantId: 'd',
            ),
          ),
        );
        expect(
          auditSignal(signalCommand(commandId: 'tampered')).executable,
          isFalse,
        );
      },
    );
  });

  group('chronology, requester, and determinism', () {
    test('chronology violations deny while active boundary accepts', () {
      expect(
        auditSignal(
          signalCommand(),
          at: commandAt.subtract(const Duration(seconds: 1)),
        ).executable,
        isFalse,
      );
      expect(
        auditSignal(
          signalCommand(
            provenanceAt: commandAt.subtract(const Duration(seconds: 1)),
          ),
        ).executable,
        isFalse,
      );
      expect(
        auditSignal(
          signalCommand(auth: authorization(authorizedAt: commandAt)),
        ).executable,
        isTrue,
      );
    });

    test('allowlisted producers pass and unknown producer denies', () {
      for (final module in const [
        'risk_orchestration',
        'traceability',
        'monitoring',
        'digital_market_monitoring',
        'digital_detective',
      ]) {
        expect(auditSignal(signalCommand(module: module)).executable, isTrue);
      }
      expect(
        auditSignal(signalCommand(module: 'public_ui')).executable,
        isFalse,
      );
    });

    test('same command and auditedAt produce byte-identical audit JSON', () {
      final command = signalCommand();
      final first = jsonEncode(auditSignal(command).toJson());
      final second = jsonEncode(auditSignal(command).toJson());
      expect(first, second);
      expect(jsonDecode(first)['targetNamespace'], 'shared_risk_signals');
      expect(jsonDecode(first)['dryRun'], isTrue);
    });
  });
}

// ignore_for_file: curly_braces_in_flow_control_structures

library;

import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../idempotency/idempotency_v1.dart';
import '../persistence/persistence_v1.dart';
import '../shared_risk_contracts_v1.dart';

part 'persistence_target_authorization_v1.dart';
part 'subject_fingerprint_v1.dart';
part 'persistence_command_bindings_v1.dart';
part 'persistence_command_contracts_v1.dart';

const String persistenceCommandContractVersionV1 = 'persistence-command-v1';
const String subjectFingerprintAlgorithmV1 = 'sha256-canonical-json-v1';

enum PersistenceTargetNamespaceV1 {
  sharedRiskSignals,
  sharedRiskAssessments,
  sharedCaseCandidates,
}

enum PersistenceActorTypeV1 { user, serviceAccount, system }

enum PersistenceIdempotencyPurposeV1 {
  exactSourceOccurrence,
  caseCandidateInitialPersistence,
}

String _targetValue(PersistenceTargetNamespaceV1 value) => switch (value) {
  PersistenceTargetNamespaceV1.sharedRiskSignals => 'shared_risk_signals',
  PersistenceTargetNamespaceV1.sharedRiskAssessments =>
    'shared_risk_assessments',
  PersistenceTargetNamespaceV1.sharedCaseCandidates => 'shared_case_candidates',
};

String persistenceTargetNamespaceValueV1(PersistenceTargetNamespaceV1 value) =>
    _targetValue(value);

String _commandSubjectValue(PersistenceSubjectTypeV1 value) => switch (value) {
  PersistenceSubjectTypeV1.riskSignal => 'risk_signal',
  PersistenceSubjectTypeV1.riskAssessment => 'risk_assessment',
  PersistenceSubjectTypeV1.caseCandidate => 'case_candidate',
};

String _required(Object? value, String field) {
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('$field is required');
  }
  return value.trim();
}

String? _optional(String? value, String field) =>
    value == null ? null : _required(value, field);

String _encode(Iterable<String> values) =>
    values.map((value) => '${value.length}:$value').join('|');

Object? _freeze(Object? value, String field) {
  if (value == null || value is String || value is bool || value is num)
    return value;
  if (value is List)
    return List<Object?>.unmodifiable(
      value.map((item) => _freeze(item, field)),
    );
  if (value is Map) {
    final output = <String, Object?>{};
    for (final entry in value.entries) {
      if (entry.key is! String) throw FormatException('$field key is invalid');
      output[entry.key as String] = _freeze(entry.value, field);
    }
    return Map<String, Object?>.unmodifiable(output);
  }
  throw FormatException('$field contains non-JSON data');
}

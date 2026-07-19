// ignore_for_file: curly_braces_in_flow_control_structures

library;

import '../commands/commands_v1.dart';
import '../identity/identity_v1.dart';
import '../persistence/persistence_v1.dart';

part 'persistence_command_audit_contracts_v1.dart';
part 'persistence_command_auditor_v1.dart';

const String persistenceCommandAuditContractVersionV1 =
    'persistence-command-audit-v1';

enum PersistenceCommandAuditSeverityV1 { blocker, warning }

String _required(Object? value, String field) {
  if (value is! String || value.trim().isEmpty)
    throw FormatException('$field is required');
  return value.trim();
}

String _subjectValue(PersistenceSubjectTypeV1 value) => switch (value) {
  PersistenceSubjectTypeV1.riskSignal => 'risk_signal',
  PersistenceSubjectTypeV1.riskAssessment => 'risk_assessment',
  PersistenceSubjectTypeV1.caseCandidate => 'case_candidate',
};

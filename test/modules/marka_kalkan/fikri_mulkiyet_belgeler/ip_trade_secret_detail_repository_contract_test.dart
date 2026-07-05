import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const repositoryRoot =
      'lib/modules/marka_kalkan/fikri_mulkiyet_belgeler/repositories';

  const repositoryFiles = <String>[
    'ip_trade_secret_component_repository.dart',
    'ip_trade_secret_access_grant_repository.dart',
    'ip_trade_secret_disclosure_repository.dart',
    'ip_trade_secret_incident_repository.dart',
    'ip_trade_secret_protection_control_repository.dart',
    'ip_trade_secret_risk_assessment_repository.dart',
    'ip_trade_secret_resilience_profile_repository.dart',
    'ip_trade_secret_defensibility_record_repository.dart',
    'ip_trade_secret_lifecycle_transition_repository.dart',
    'ip_trade_secret_remediation_action_repository.dart',
    'ip_trade_secret_alert_rule_repository.dart',
    'ip_trade_secret_management_decision_repository.dart',
  ];

  test('ortak CRUD çekirdeği zorunlu operasyonları sağlar', () {
    final source = File(
      '$repositoryRoot/ip_trade_secret_detail_repository.dart',
    ).readAsStringSync();

    for (final marker in <String>[
      'Future<String> create(T model)',
      'Future<void> update(T model)',
      'Future<T?> getById(String id)',
      'Future<T?> findByCode',
      'Future<List<T>> list',
      'Stream<List<T>> watch',
      'Future<void> delete(String id)',
      ".where('tenantId', isEqualTo: _tenantId)",
      ".where('brandId', isEqualTo: cleanedBrandId)",
      ".where('tradeSecretId',",
      ".orderBy('createdAt', descending: true)",
    ]) {
      expect(source, contains(marker), reason: marker);
    }
  });

  test('12 repository aynı port ve CRUD sözleşmesini uygular', () {
    for (final fileName in repositoryFiles) {
      final source = File('$repositoryRoot/$fileName').readAsStringSync();

      expect(
        RegExp(
          r'implements\s+IpTradeSecretDetailRepositoryPort<',
          multiLine: true,
        ).hasMatch(source),
        isTrue,
        reason: fileName,
      );
      expect(source, contains('Future<String> create('), reason: fileName);
      expect(source, contains('Future<void> update('), reason: fileName);
      expect(source, contains('getById(String id)'), reason: fileName);
      expect(source, contains('findByCode({'), reason: fileName);
      expect(source, contains('Future<List<'), reason: fileName);
      expect(source, contains('Stream<List<'), reason: fileName);
      expect(
        source,
        contains('Future<void> delete(String id)'),
        reason: fileName,
      );
      expect(source, contains('model.toCreateMap()'), reason: fileName);
      expect(
        source,
        contains('model.toUpdateMap(actorId: actorId)'),
        reason: fileName,
      );
      expect(source, contains('model.toMap();'), reason: fileName);
    }
  });

  test(
    'IpFirestoreRefs 12 ayrıntı koleksiyonunu ve belge erişimini içerir',
    () {
      final source = File(
        '$repositoryRoot/ip_firestore_refs.dart',
      ).readAsStringSync();

      for (final marker in <String>[
        'get tradeSecretComponents',
        'get tradeSecretAccessGrants',
        'get tradeSecretDisclosures',
        'get tradeSecretIncidents',
        'get tradeSecretProtectionControls',
        'get tradeSecretRiskAssessments',
        'get tradeSecretResilienceProfiles',
        'get tradeSecretDefensibilityRecords',
        'get tradeSecretLifecycleTransitions',
        'get tradeSecretRemediationActions',
        'get tradeSecretAlertRules',
        'get tradeSecretManagementDecisions',
        'tradeSecretComponentDocument',
        'tradeSecretAccessGrantDocument',
        'tradeSecretDisclosureDocument',
        'tradeSecretIncidentDocument',
        'tradeSecretProtectionControlDocument',
        'tradeSecretRiskAssessmentDocument',
        'tradeSecretResilienceProfileDocument',
        'tradeSecretDefensibilityRecordDocument',
        'tradeSecretLifecycleTransitionDocument',
        'tradeSecretRemediationActionDocument',
        'tradeSecretAlertRuleDocument',
        'tradeSecretManagementDecisionDocument',
      ]) {
        expect(source, contains(marker), reason: marker);
      }
    },
  );

  test('repository dosyaları açık ticari sır alanı tanımlamaz', () {
    for (final fileName in <String>[
      'ip_trade_secret_detail_repository.dart',
      ...repositoryFiles,
    ]) {
      final source = File('$repositoryRoot/$fileName').readAsStringSync();

      for (final prohibited in <String>[
        'formulaContent',
        'recipeContent',
        'secretContent',
        'plaintextSecret',
        'rawFormula',
        'rawRecipe',
      ]) {
        expect(
          source,
          isNot(contains(prohibited)),
          reason: '$fileName $prohibited',
        );
      }
    }
  });
}

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _matchBlock(String rules, String collection) {
  final marker = 'match /$collection/{recordId} {';
  final start = rules.indexOf(marker);
  expect(start, greaterThanOrEqualTo(0), reason: collection);

  final nextMatch = rules.indexOf('match /', start + marker.length);
  return nextMatch < 0
      ? rules.substring(start)
      : rules.substring(start, nextMatch);
}

void main() {
  const collections = <String>[
    'ip_trade_secret_components',
    'ip_trade_secret_access_grants',
    'ip_trade_secret_disclosures',
    'ip_trade_secret_incidents',
    'ip_trade_secret_protection_controls',
    'ip_trade_secret_risk_assessments',
    'ip_trade_secret_resilience_profiles',
    'ip_trade_secret_defensibility_records',
    'ip_trade_secret_lifecycle_transitions',
    'ip_trade_secret_remediation_actions',
    'ip_trade_secret_alert_rules',
    'ip_trade_secret_management_decisions',
  ];

  const serverOnlyCollections = <String>{
    'ip_trade_secret_risk_assessments',
    'ip_trade_secret_resilience_profiles',
    'ip_trade_secret_defensibility_records',
    'ip_trade_secret_lifecycle_transitions',
    'ip_trade_secret_alert_rules',
  };

  const serverOnlyFieldFunctions = <String>[
    'ipTsRiskAssessmentFields',
    'ipTsResilienceProfileFields',
    'ipTsDefensibilityFields',
    'ipTsLifecycleFields',
    'ipTsAlertRuleFields',
  ];

  const clientValidatedCodeFields = <String, String>{
    'ip_trade_secret_components': 'componentCode',
    'ip_trade_secret_access_grants': 'grantCode',
    'ip_trade_secret_disclosures': 'disclosureCode',
    'ip_trade_secret_incidents': 'incidentCode',
    'ip_trade_secret_protection_controls': 'controlCode',
    'ip_trade_secret_remediation_actions': 'actionCode',
    'ip_trade_secret_management_decisions': 'decisionCode',
  };

  test('12 ticari sır ayrıntı koleksiyonunun açık rule sınırı vardır', () {
    final rules = File('firestore.rules').readAsStringSync();

    for (final collection in collections) {
      expect(
        rules,
        contains('match /$collection/{recordId}'),
        reason: collection,
      );
    }

    expect(
      RegExp(
        r'match /ip_trade_secret_[^{]+/\{recordId\}',
      ).allMatches(rules).length,
      greaterThanOrEqualTo(12),
    );
  });

  test('beş boş koleksiyon açık server-only deny sınırına sahiptir', () {
    final rules = File('firestore.rules').readAsStringSync();

    for (final collection in serverOnlyCollections) {
      final block = _matchBlock(rules, collection);
      expect(
        block,
        contains('allow read, write: if false;'),
        reason: collection,
      );
      for (final legacyAllow in <String>[
        'allow get',
        'allow list',
        'allow create',
        'allow update',
        'allow delete',
      ]) {
        expect(
          block,
          isNot(contains(legacyAllow)),
          reason: '$collection $legacyAllow',
        );
      }
    }

    for (final functionName in serverOnlyFieldFunctions) {
      expect(
        rules,
        isNot(contains('function $functionName()')),
        reason: functionName,
      );
    }
  });

  test('yedi canlı koleksiyon client doğrulama sözleşmesini korur', () {
    final rules = File('firestore.rules').readAsStringSync();

    for (final entry in clientValidatedCodeFields.entries) {
      final block = _matchBlock(rules, entry.key);

      expect(
        block,
        contains('request.resource.data.${entry.value} is string'),
        reason: entry.key,
      );
      expect(
        block,
        contains(
          'request.resource.data.${entry.value} == resource.data.${entry.value}',
        ),
        reason: entry.key,
      );
      expect(
        block,
        isNot(contains('allow read, write: if false;')),
        reason: entry.key,
      );
    }
  });

  test('client doğrulanan koleksiyonlarda tenant ve sır koruması sürer', () {
    final rules = File('firestore.rules').readAsStringSync();

    for (final marker in <String>[
      'resource.data.tenantId == request.auth.uid',
      'request.resource.data.tenantId == request.auth.uid',
      'request.resource.data.createdAt == request.time',
      'request.resource.data.updatedAt == request.time',
      '/documents/ip_trade_secrets/',
      "'formulaContent'",
      "'recipeContent'",
      "'secretContent'",
      "'plaintextSecret'",
      "'rawFormula'",
      "'rawRecipe'",
      "'sourceCodeContent'",
      "'algorithmContent'",
    ]) {
      expect(rules, contains(marker), reason: marker);
    }
  });

  test('12 ayrıntı koleksiyonunun composite index sözleşmesi korunur', () {
    final decoded =
        jsonDecode(File('firestore.indexes.json').readAsStringSync())
            as Map<String, dynamic>;

    final indexes = (decoded['indexes'] as List<dynamic>)
        .cast<Map<String, dynamic>>();

    for (final collection in collections) {
      final collectionIndexes = indexes
          .where((index) => index['collectionGroup'] == collection)
          .toList(growable: false);

      expect(collectionIndexes, hasLength(5), reason: collection);
    }
  });

  test('Rules kaynağı pilot sonrası 175000 byte altında kalır', () {
    final rulesBytes = File('firestore.rules').readAsBytesSync().length;

    expect(
      rulesBytes,
      lessThan(175000),
      reason: 'FRC-1H pilotu ölçülebilir Rules payı oluşturmalıdır.',
    );
  });

  test('firestore index json geçerlidir ve fieldOverrides korunur', () {
    final decoded =
        jsonDecode(File('firestore.indexes.json').readAsStringSync())
            as Map<String, dynamic>;

    expect(decoded['indexes'], isA<List<dynamic>>());
    expect(decoded['fieldOverrides'], isA<List<dynamic>>());
  });
}

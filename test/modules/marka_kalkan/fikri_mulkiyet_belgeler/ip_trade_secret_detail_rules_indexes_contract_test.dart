import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

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

  const codeFields = <String, String>{
    'ip_trade_secret_components': 'componentCode',
    'ip_trade_secret_access_grants': 'grantCode',
    'ip_trade_secret_disclosures': 'disclosureCode',
    'ip_trade_secret_incidents': 'incidentCode',
    'ip_trade_secret_protection_controls': 'controlCode',
    'ip_trade_secret_risk_assessments': 'assessmentCode',
    'ip_trade_secret_resilience_profiles': 'profileCode',
    'ip_trade_secret_defensibility_records': 'recordCode',
    'ip_trade_secret_lifecycle_transitions': 'transitionCode',
    'ip_trade_secret_remediation_actions': 'actionCode',
    'ip_trade_secret_alert_rules': 'ruleCode',
    'ip_trade_secret_management_decisions': 'decisionCode',
  };

  test('12 ticari sır ayrıntı koleksiyonunun rule bloğu vardır', () {
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

  test('rules tenant, timestamp, parent bağ ve açık sır koruması içerir', () {
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

  test('her koleksiyonun kod alanı create ve update kurallarında korunur', () {
    final rules = File('firestore.rules').readAsStringSync();

    for (final entry in codeFields.entries) {
      final start = rules.indexOf('match /${entry.key}/{recordId}');
      expect(start, greaterThanOrEqualTo(0), reason: entry.key);

      final nextMatch = rules.indexOf('    match /', start + 10);
      final block = nextMatch < 0
          ? rules.substring(start)
          : rules.substring(start, nextMatch);

      expect(block, contains('request.resource.data.${entry.value} is string'));
      expect(
        block,
        contains(
          'request.resource.data.${entry.value} == resource.data.${entry.value}',
        ),
      );
    }
  });

  test('her ayrıntı koleksiyonunda beş gerekli composite index vardır', () {
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

  test('firestore index json geçerlidir ve fieldOverrides korunur', () {
    final decoded =
        jsonDecode(File('firestore.indexes.json').readAsStringSync())
            as Map<String, dynamic>;

    expect(decoded['indexes'], isA<List<dynamic>>());
    expect(decoded['fieldOverrides'], isA<List<dynamic>>());
  });
}

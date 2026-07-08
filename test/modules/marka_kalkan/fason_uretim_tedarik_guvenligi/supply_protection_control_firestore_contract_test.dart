import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const rulesPath = 'firestore.rules';
  const indexesPath = 'firestore.indexes.json';
  const collectionName = 'supply_security_protection_controls';

  late String rules;
  late List<dynamic> indexes;

  setUpAll(() {
    rules = File(rulesPath).readAsStringSync();

    final json =
        jsonDecode(File(indexesPath).readAsStringSync())
            as Map<String, dynamic>;

    indexes = json['indexes'] as List<dynamic>;
  });

  test('rules expose protection control collection', () {
    expect(
      rules,
      contains(
        'match /supply_security_protection_controls/'
        '{controlId}',
      ),
    );

    expect(rules, contains('function ssProtectionControlIsValid()'));
  });

  test('rules allow protection control creation only through server', () {
    final collectionStart = rules.indexOf(
      'match /supply_security_protection_controls/'
      '{controlId}',
    );

    expect(collectionStart, greaterThanOrEqualTo(0));

    final followingSection = rules.substring(collectionStart);
    final collectionEnd = followingSection.indexOf('\n    match /');

    final collectionRules = collectionEnd < 0
        ? followingSection
        : followingSection.substring(0, collectionEnd);

    expect(collectionRules, contains('allow create: if false;'));
  });

  test('rules enforce tenant ownership', () {
    expect(
      rules,
      contains(
        'request.resource.data.tenantId '
        '== request.auth.uid',
      ),
    );

    expect(rules, contains('resource.data.tenantId == request.auth.uid'));
  });

  test('rules protect immutable identity fields', () {
    expect(
      rules,
      contains(
        'request.resource.data.brandId '
        '== resource.data.brandId',
      ),
    );

    expect(rules, contains('request.resource.data.controlCode'));

    expect(rules, contains('request.resource.data.controlCodeNormalized'));

    expect(rules, contains('request.resource.data.createdAt'));

    expect(rules, contains('request.resource.data.createdBy'));
  });

  test('rules reject physical deletion', () {
    final collectionStart = rules.indexOf(
      'match /supply_security_protection_controls/'
      '{controlId}',
    );

    expect(collectionStart, greaterThanOrEqualTo(0));

    final followingSection = rules.substring(collectionStart);

    expect(followingSection, contains('allow delete: if false;'));
  });

  test('rules require failure findings and corrective action', () {
    expect(rules, contains('failed|critical_failure'));
    expect(rules, contains('request.resource.data.findings.size() > 0'));

    expect(
      rules,
      contains('request.resource.data.correctiveAction.size() > 0'),
    );
  });

  test('rules require archive reason and timestamp', () {
    expect(rules, contains("request.resource.data.status != 'archived'"));

    expect(rules, contains('request.resource.data.archiveReason.size() > 0'));

    expect(rules, contains('request.resource.data.archivedAt is timestamp'));
  });

  test('exactly eight protection control indexes exist', () {
    final controlIndexes = indexes.where(
      (item) =>
          (item as Map<String, dynamic>)['collectionGroup'] == collectionName,
    );

    expect(controlIndexes.length, 8);
  });

  test('control code lookup index exists', () {
    final exists = indexes.any((item) {
      final index = item as Map<String, dynamic>;

      if (index['collectionGroup'] != collectionName) {
        return false;
      }

      final fields = index['fields'] as List<dynamic>;

      return fields.length == 3 &&
          (fields[0] as Map<String, dynamic>)['fieldPath'] == 'tenantId' &&
          (fields[1] as Map<String, dynamic>)['fieldPath'] == 'brandId' &&
          (fields[2] as Map<String, dynamic>)['fieldPath'] ==
              'controlCodeNormalized';
    });

    expect(exists, isTrue);
  });

  test('ordered registry indexes end with createdAt descending', () {
    final orderedIndexes = indexes.where((item) {
      final index = item as Map<String, dynamic>;

      if (index['collectionGroup'] != collectionName) {
        return false;
      }

      final fields = index['fields'] as List<dynamic>;
      final lastField = fields.last as Map<String, dynamic>;

      return lastField['fieldPath'] == 'createdAt';
    });

    expect(orderedIndexes.length, 7);

    for (final item in orderedIndexes) {
      final index = item as Map<String, dynamic>;
      final fields = index['fields'] as List<dynamic>;
      final lastField = fields.last as Map<String, dynamic>;

      expect(lastField['order'], 'DESCENDING');
    }
  });
}

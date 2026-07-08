import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const rulesPath = 'firestore.rules';
  const indexesPath = 'firestore.indexes.json';
  const collectionName = 'supply_security_protection_controls';
  const collectionMatch =
      'match /supply_security_protection_controls/{controlId}';

  late String rules;
  late List<dynamic> indexes;
  late String collectionRules;

  setUpAll(() {
    rules = File(rulesPath).readAsStringSync();

    final collectionStart = rules.indexOf(collectionMatch);
    expect(collectionStart, greaterThanOrEqualTo(0));

    final followingSection = rules.substring(collectionStart);
    final collectionEnd = followingSection.indexOf('\n    match /');

    collectionRules = collectionEnd < 0
        ? followingSection
        : followingSection.substring(0, collectionEnd);

    final json =
        jsonDecode(File(indexesPath).readAsStringSync())
            as Map<String, dynamic>;

    indexes = json['indexes'] as List<dynamic>;
  });

  test('rules expose protection control collection', () {
    expect(rules, contains(collectionMatch));
  });

  test('rules keep reads tenant safe', () {
    expect(collectionRules, contains('request.auth != null'));

    expect(
      collectionRules,
      contains('resource.data.tenantId == request.auth.uid'),
    );
  });

  test('rules reject all direct client writes', () {
    final combinedWriteRule = collectionRules.contains(
      'allow create, update, delete: if false;',
    );

    final splitWriteRules =
        collectionRules.contains('allow create: if false;') &&
        collectionRules.contains('allow update: if false;') &&
        collectionRules.contains('allow delete: if false;');

    expect(
      combinedWriteRule || splitWriteRules,
      isTrue,
      reason:
          'Koruma kontrolleri yalnız güvenilir callable/Admin SDK katmanından '
          'yazılmalıdır.',
    );
  });

  test('rules do not reintroduce business validation helpers', () {
    expect(collectionRules, isNot(contains('ssProtectionControlIsValid()')));

    expect(collectionRules, isNot(contains('controlCodeNormalized')));

    expect(collectionRules, isNot(contains('failed|critical_failure')));

    expect(collectionRules, isNot(contains('correctiveAction.size()')));
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

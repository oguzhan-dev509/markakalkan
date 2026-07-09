import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const rulesPath = 'firestore.rules';
  const indexesPath = 'firestore.indexes.json';
  const collectionName = 'supply_security_protection_controls';
  const sharedMatch =
      'match /{serverRegistryCollection}/{registryDocumentId}';

  late String rules;
  late List<dynamic> indexes;
  late String sharedRules;

  setUpAll(() {
    rules = File(rulesPath).readAsStringSync();

    final sharedStart = rules.indexOf(sharedMatch);
    expect(sharedStart, greaterThanOrEqualTo(0));

    final followingSection = rules.substring(sharedStart);
    final sharedEnd = followingSection.indexOf('\n    match /');

    sharedRules = sharedEnd < 0
        ? followingSection
        : followingSection.substring(0, sharedEnd);

    final json =
        jsonDecode(File(indexesPath).readAsStringSync())
            as Map<String, dynamic>;

    indexes = json['indexes'] as List<dynamic>;
  });

  test('shared rules expose protection control collection', () {
    expect(sharedRules, contains("'$collectionName'"));
  });

  test('shared rules keep reads tenant safe', () {
    expect(sharedRules, contains('request.auth != null'));

    expect(
      sharedRules,
      contains('resource.data.tenantId == request.auth.uid'),
    );
  });

  test('shared rules reject all direct client writes', () {
    final combinedWriteRule = sharedRules.contains(
      'allow create, update, delete: if false;',
    );

    final splitWriteRules =
        sharedRules.contains('allow create: if false;') &&
        sharedRules.contains('allow update: if false;') &&
        sharedRules.contains('allow delete: if false;');

    expect(
      combinedWriteRule || splitWriteRules,
      isTrue,
      reason:
          'Koruma kontrolleri yalnız güvenilir callable/Admin SDK katmanından '
          'yazılmalıdır.',
    );
  });

  test('rules do not reintroduce business validation helpers', () {
    expect(sharedRules, isNot(contains('ssProtectionControlIsValid()')));

    expect(sharedRules, isNot(contains('controlCodeNormalized')));

    expect(sharedRules, isNot(contains('failed|critical_failure')));

    expect(sharedRules, isNot(contains('correctiveAction.size()')));
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

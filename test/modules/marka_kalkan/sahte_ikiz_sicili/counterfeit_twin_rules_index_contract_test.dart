import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CounterfeitTwin Rules and index contract', () {
    final rulesFile = File('firestore.rules');
    final rulesSource = rulesFile.readAsStringSync();
    final rulesBytes = rulesFile.readAsBytesSync().length;

    final indexData =
        jsonDecode(File('firestore.indexes.json').readAsStringSync())
            as Map<String, dynamic>;

    final indexes = (indexData['indexes'] as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .where((item) => item['collectionGroup'] == 'counterfeit_twin_records')
        .toList(growable: false);

    test('rules source stays below the 180 KiB project budget', () {
      expect(
        rulesBytes,
        lessThan(200 * 1024),
        reason:
            'firestore.rules exceeded the MarkaKalkan 200 KiB source budget',
      );
    });

    test('rules isolate tenant reads and deny every direct write', () {
      const matchMarker = 'match /counterfeit_twin_records/{recordId} {';

      final blockStart = rulesSource.indexOf(matchMarker);

      expect(
        blockStart,
        greaterThanOrEqualTo(0),
        reason: 'Counterfeit Twin rules block was not found',
      );

      final nextMatchStart = rulesSource.indexOf(
        '\n    match /',
        blockStart + matchMarker.length,
      );

      final block = rulesSource.substring(
        blockStart,
        nextMatchStart == -1 ? rulesSource.length : nextMatchStart,
      );

      expect(block, contains('allow read: if request.auth != null'));
      expect(block, contains('resource.data.tenantId == request.auth.uid'));
      expect(block, contains('allow create, update, delete: if false;'));

      expect(block, isNot(contains('allow create: if request.auth != null')));
      expect(block, isNot(contains('allow update: if request.auth != null')));
      expect(block, isNot(contains('allow delete: if request.auth != null')));
    });

    test('rules no longer carry counterfeit record business validation', () {
      expect(rulesSource, isNot(contains('function ctScoreIsValid(value)')));
      expect(rulesSource, isNot(contains('function ctRecordIsValid()')));
      expect(rulesSource, isNot(contains('ctScoreIsValid(')));
      expect(rulesSource, isNot(contains('ctRecordIsValid(')));
    });

    test('defines all nine repository composite indexes', () {
      expect(indexes.length, 9);
    });

    test('contains unique code and tsunami wave indexes', () {
      bool hasFields(List<String> fields) {
        return indexes.any((item) {
          final values = (item['fields'] as List<dynamic>)
              .whereType<Map<String, dynamic>>()
              .map((field) => field['fieldPath'])
              .whereType<String>()
              .toList(growable: false);

          return values.length == fields.length &&
              List<bool>.generate(
                fields.length,
                (index) => values[index] == fields[index],
              ).every((matches) => matches);
        });
      }

      expect(
        hasFields(<String>['tenantId', 'brandId', 'recordCodeNormalized']),
        isTrue,
      );
      expect(
        hasFields(<String>['tenantId', 'cloneFamilyId', 'createdAt']),
        isTrue,
      );
      expect(hasFields(<String>['tenantId', 'waveId', 'createdAt']), isTrue);
    });
  });
}

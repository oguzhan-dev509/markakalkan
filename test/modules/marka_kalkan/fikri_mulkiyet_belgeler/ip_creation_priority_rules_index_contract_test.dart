import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('IpCreationPriority Rules and index contract', () {
    final rulesSource = File('firestore.rules').readAsStringSync();

    final indexData =
        jsonDecode(File('firestore.indexes.json').readAsStringSync())
            as Map<String, dynamic>;

    final indexes = (indexData['indexes'] as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);

    test('shared server-only rule protects priority collections', () {
      expect(
        rulesSource,
        contains('match /{serverRegistryCollection}/{registryDocumentId}'),
      );
      expect(
        rulesSource,
        contains("'ip_creation_priority_records'"),
      );
      expect(
        rulesSource,
        contains("'ip_creation_priority_versions'"),
      );
      expect(
        rulesSource,
        contains('resource.data.tenantId == request.auth.uid'),
      );
      expect(
        rulesSource,
        contains('allow create, update, delete: if false;'),
      );
      expect(
        rulesSource,
        isNot(contains('match /ip_creation_priority_records/{recordId}')),
      );
      expect(
        rulesSource,
        isNot(contains('match /ip_creation_priority_versions/{versionId}')),
      );
    });

    test('defines required record and version composite indexes', () {
      bool hasFields(String collectionGroup, List<String> fields) {
        return indexes.any((item) {
          if (item['collectionGroup'] != collectionGroup) {
            return false;
          }

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
        hasFields('ip_creation_priority_records', <String>[
          'tenantId',
          'createdAt',
        ]),
        isTrue,
      );

      expect(
        hasFields('ip_creation_priority_records', <String>[
          'tenantId',
          'brandId',
          'recordCodeNormalized',
        ]),
        isTrue,
      );

      expect(
        hasFields('ip_creation_priority_versions', <String>[
          'tenantId',
          'recordId',
          'versionNumber',
        ]),
        isTrue,
      );
    });

    test('defines single-filter registry indexes used by repository', () {
      bool hasFields(List<String> fields) {
        return indexes.any((item) {
          if (item['collectionGroup'] != 'ip_creation_priority_records') {
            return false;
          }

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

      expect(hasFields(<String>['tenantId', 'brandId', 'createdAt']), isTrue);
      expect(
        hasFields(<String>['tenantId', 'creationType', 'createdAt']),
        isTrue,
      );
      expect(hasFields(<String>['tenantId', 'status', 'createdAt']), isTrue);
      expect(
        hasFields(<String>['tenantId', 'confidentialityLevel', 'createdAt']),
        isTrue,
      );
      expect(
        hasFields(<String>['tenantId', 'sealStatus', 'createdAt']),
        isTrue,
      );
    });
  });
}

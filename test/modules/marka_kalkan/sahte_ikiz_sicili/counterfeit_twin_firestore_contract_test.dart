import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CounterfeitTwin Firestore contract', () {
    final refsSource = File(
      'lib/modules/marka_kalkan/sahte_ikiz_sicili/'
      'repositories/counterfeit_twin_firestore_refs.dart',
    ).readAsStringSync();

    final repositorySource = File(
      'lib/modules/marka_kalkan/sahte_ikiz_sicili/'
      'repositories/counterfeit_twin_repository.dart',
    ).readAsStringSync();

    test('uses the dedicated collection and tenant query', () {
      expect(refsSource, contains('CounterfeitTwinCollections.records'));
      expect(refsSource, contains(".where('tenantId', isEqualTo: tenantId)"));
      expect(refsSource, contains('recordDocument'));
    });

    test('enforces unique code within tenant and brand', () {
      expect(repositorySource, contains('findByCode'));
      expect(
        repositorySource,
        contains(".where('brandId', isEqualTo: cleanedBrandId)"),
      );
      expect(
        repositorySource,
        contains(".where('recordCodeNormalized', isEqualTo: normalizedCode)"),
      );
    });

    test('routes update through callable without direct identity writes', () {
      expect(repositorySource, contains('_commandService.update(record)'));
      expect(
        repositorySource,
        isNot(contains('record.toUpdateMap(actorId: actorId)')),
      );
      expect(repositorySource, isNot(contains('document.update(')));
      expect(repositorySource, isNot(contains("'recordCode':")));
      expect(repositorySource, isNot(contains("'brandId':")));
    });

    test('supports tsunami family and wave filters', () {
      expect(repositorySource, contains(".where('cloneFamilyId'"));
      expect(
        repositorySource,
        contains(".where('waveId', isEqualTo: cleanedWaveId)"),
      );
    });

    test('orders registry by newest creation timestamp', () {
      expect(
        repositorySource,
        contains(".orderBy('createdAt', descending: true)"),
      );
    });
  });
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CounterfeitTwin callable contract', () {
    final functionSource = File(
      'functions/counterfeit_twin/counterfeit_twin_records.js',
    ).readAsStringSync();

    final indexSource = File('functions/index.js').readAsStringSync();

    final commandSource = File(
      'lib/modules/marka_kalkan/sahte_ikiz_sicili/'
      'repositories/counterfeit_twin_command_service.dart',
    ).readAsStringSync();

    final repositorySource = File(
      'lib/modules/marka_kalkan/sahte_ikiz_sicili/'
      'repositories/counterfeit_twin_repository.dart',
    ).readAsStringSync();

    test('exports create and update callable builders', () {
      expect(functionSource, contains('buildCreateCounterfeitTwinRecord'));
      expect(functionSource, contains('buildUpdateCounterfeitTwinRecord'));
      expect(indexSource, contains('exports.createCounterfeitTwinRecord'));
      expect(indexSource, contains('exports.updateCounterfeitTwinRecord'));
    });

    test('server enforces tenant and brand from authenticated uid', () {
      expect(functionSource, contains('tenantId: uid'));
      expect(functionSource, contains('brandId: uid'));
      expect(
        functionSource,
        contains('existing.tenantId !== uid || existing.brandId !== uid'),
      );
    });

    test('server validates unique code, scores and wave recurrence', () {
      expect(functionSource, contains('recordCodeNormalized'));
      expect(functionSource, contains('"already-exists"'));
      expect(functionSource, contains('function score(value, fieldName)'));
      expect(functionSource, contains('recurrenceCount'));
      expect(functionSource, contains('cloneFamilyId'));
      expect(functionSource, contains('waveId'));
    });

    test('Flutter command service calls both callable functions', () {
      expect(commandSource, contains("'createCounterfeitTwinRecord'"));
      expect(commandSource, contains("'updateCounterfeitTwinRecord'"));
      expect(commandSource, contains("'evidencePackageIds'"));
      expect(commandSource, contains("'relatedTwinRecordIds'"));
    });

    test('repository no longer writes records directly', () {
      expect(repositorySource, contains('_commandService.create(record)'));
      expect(repositorySource, contains('_commandService.update(record)'));
      expect(repositorySource, isNot(contains('document.set(')));
      expect(repositorySource, isNot(contains('document.update(')));
    });
  });
}

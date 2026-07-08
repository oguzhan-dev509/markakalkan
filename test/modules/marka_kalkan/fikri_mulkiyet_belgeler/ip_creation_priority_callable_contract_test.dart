import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('IpCreationPriority callable contract', () {
    final functionSource = File(
      'functions/ip_creation_priority/ip_creation_priority_records.js',
    ).readAsStringSync();

    final indexSource = File('functions/index.js').readAsStringSync();

    final commandSource = File(
      'lib/modules/marka_kalkan/fikri_mulkiyet_belgeler/'
      'repositories/ip_creation_priority_command_service.dart',
    ).readAsStringSync();

    final repositorySource = File(
      'lib/modules/marka_kalkan/fikri_mulkiyet_belgeler/'
      'repositories/ip_creation_priority_repository.dart',
    ).readAsStringSync();

    test('exports create and update draft callable builders', () {
      expect(functionSource, contains('buildCreateIpCreationPriorityDraft'));
      expect(functionSource, contains('buildUpdateIpCreationPriorityDraft'));
      expect(indexSource, contains('exports.createIpCreationPriorityDraft'));
      expect(indexSource, contains('exports.updateIpCreationPriorityDraft'));
    });

    test('server derives tenant and brand identity from authenticated uid', () {
      expect(functionSource, contains('tenantId: uid'));
      expect(functionSource, contains('brandId: uid'));
      expect(
        functionSource,
        contains('record.tenantId !== uid || record.brandId !== uid'),
      );
      expect(
        functionSource,
        contains('version.tenantId !== uid || version.brandId !== uid'),
      );
    });

    test('create draft atomically creates record and first version', () {
      expect(functionSource, contains('db.runTransaction'));
      expect(functionSource, contains('transaction.create(recordRef'));
      expect(functionSource, contains('transaction.create(versionRef'));
      expect(functionSource, contains('activeVersionId: versionRef.id'));
      expect(functionSource, contains('versionNumber: 1'));
      expect(functionSource, contains('sealStatus: "unsealed"'));
    });

    test('update only permits matching unsealed draft and active version', () {
      expect(functionSource, contains('record.status !== "draft"'));
      expect(functionSource, contains('record.sealStatus !== "unsealed"'));
      expect(functionSource, contains('record.activeVersionId !== versionId'));
      expect(functionSource, contains('version.recordId !== recordId'));
    });

    test('Flutter command service calls both draft functions', () {
      expect(commandSource, contains("'createIpCreationPriorityDraft'"));
      expect(commandSource, contains("'updateIpCreationPriorityDraft'"));
      expect(commandSource, contains("'developmentStage'"));
      expect(commandSource, contains("'fileManifest'"));
    });

    test('exports sealing and immutable version callables', () {
      expect(functionSource, contains('buildSealIpCreationPriorityRecord'));
      expect(functionSource, contains('buildCreateIpCreationPriorityVersion'));
      expect(indexSource, contains('exports.sealIpCreationPriorityRecord'));
      expect(indexSource, contains('exports.createIpCreationPriorityVersion'));
    });

    test('server hashes canonical version content with SHA-256', () {
      expect(functionSource, contains('createHash("sha256")'));
      expect(functionSource, contains('function canonicalize(value)'));
      expect(functionSource, contains('function versionHashPayload'));
      expect(functionSource, contains('hashAlgorithm: "SHA-256"'));
      expect(functionSource, contains('contentHash'));
    });

    test('sealing atomically locks first version and parent record', () {
      expect(functionSource, contains('buildSealIpCreationPriorityRecord'));
      expect(functionSource, contains('record.currentVersion !== 1'));
      expect(functionSource, contains('version.versionNumber !== 1'));
      expect(functionSource, contains('transaction.update(versionRef'));
      expect(functionSource, contains('transaction.update(recordRef'));
    });

    test('new versions chain previous id and hash on server', () {
      expect(functionSource, contains('const previousVersionId = requiredId'));
      expect(functionSource, contains('previousVersionHash'));
      expect(
        functionSource,
        contains('versionNumber = record.currentVersion + 1'),
      );
      expect(functionSource, contains('activeVersionId: newVersionRef.id'));
    });

    test('Flutter routes seal and version creation through callables', () {
      expect(commandSource, contains("'sealIpCreationPriorityRecord'"));
      expect(commandSource, contains("'createIpCreationPriorityVersion'"));
      expect(repositorySource, contains('_commandService.sealRecord('));
      expect(repositorySource, contains('_commandService.createVersion('));
    });

    test('repository routes draft writes through command service', () {
      expect(repositorySource, contains('_commandService.createDraft('));
      expect(repositorySource, contains('_commandService.updateDraft('));
      expect(repositorySource, isNot(contains('transaction.create(')));
      expect(repositorySource, isNot(contains('document.set(')));
    });
  });
}

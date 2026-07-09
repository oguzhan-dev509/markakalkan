import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('IP creation registry owner identity contract', () {
    final functionSource = File(
      'functions/ip_creation_priority/'
      'ip_creation_registry_owner_identity.js',
    ).readAsStringSync();

    final indexSource = File('functions/index.js').readAsStringSync();
    final rulesSource = File('firestore.rules').readAsStringSync();

    final commandSource = File(
      'lib/modules/marka_kalkan/fikri_mulkiyet_belgeler/'
      'repositories/ip_creation_priority_command_service.dart',
    ).readAsStringSync();

    final repositorySource = File(
      'lib/modules/marka_kalkan/fikri_mulkiyet_belgeler/'
      'repositories/ip_creation_priority_repository.dart',
    ).readAsStringSync();

    final pageSource = File(
      'lib/modules/marka_kalkan/fikri_mulkiyet_belgeler/'
      'presentation/ip_creation_priority_registry_page.dart',
    ).readAsStringSync();

    test('callable is authenticated, idempotent and transactional', () {
      expect(
        functionSource,
        contains('buildEnsureIpCreationRegistryOwnerIdentity'),
      );
      expect(functionSource, contains('request.auth?.uid'));
      expect(functionSource, contains('db.runTransaction'));
      expect(functionSource, contains('ownerSnapshot.exists'));
      expect(functionSource, contains('transaction.create(ownerRef'));
      expect(functionSource, contains('transaction.create(numberRef'));
    });

    test('number format is branded and collision-safe', () {
      expect(
        functionSource,
        contains(r'MK-SH-${randomGroup()}-${randomGroup()}'),
      );
      expect(functionSource, contains('OWNER_NUMBER_COLLISION'));
      expect(functionSource, contains('MAX_GENERATION_ATTEMPTS'));
      expect(commandSource, contains(r'^MK-SH-[A-Z0-9]{4}-[A-Z0-9]{4}$'));
    });

    test('index exports callable in europe-west3 project', () {
      expect(
        indexSource,
        contains('exports.ensureIpCreationRegistryOwnerIdentity'),
      );
      expect(indexSource, contains('region: "europe-west3"'));
    });

    test('rules permit owner self-read and deny client writes', () {
      expect(rulesSource, contains("'ip_creation_registry_owners'"));
      expect(
        rulesSource,
        contains('resource.data.tenantId == request.auth.uid'),
      );
      expect(rulesSource, contains('allow create, update, delete: if false;'));
      expect(
        rulesSource,
        isNot(contains("'ip_creation_registry_owner_numbers'")),
      );
    });

    test('Flutter obtains and displays immutable owner number', () {
      expect(
        commandSource,
        contains("'ensureIpCreationRegistryOwnerIdentity'"),
      );
      expect(repositorySource, contains('ensureOwnerIdentity()'));
      expect(pageSource, contains('FutureBuilder<String>'));
      expect(pageSource, contains(r'Sicil Sahibi No: ${snapshot.data}'));
      expect(pageSource, contains('Sicil Sahibi No için yeniden dene'));
    });
  });
}

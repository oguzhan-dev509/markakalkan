import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('IpCreationPriority detail contract', () {
    final detailSource = File(
      'lib/modules/marka_kalkan/fikri_mulkiyet_belgeler/'
      'presentation/ip_creation_priority_detail_page.dart',
    ).readAsStringSync();

    final registrySource = File(
      'lib/modules/marka_kalkan/fikri_mulkiyet_belgeler/'
      'presentation/ip_creation_priority_registry_page.dart',
    ).readAsStringSync();

    test('registry card opens detail page', () {
      expect(registrySource, contains('IpCreationPriorityDetailPage('));
      expect(registrySource, contains('recordId: record.id'));
      expect(registrySource, contains('repository: repository'));
      expect(registrySource, contains('ip_creation_priority_detail_page.dart'));
    });

    test('detail loads record, active version and version history', () {
      expect(detailSource, contains('getRecordById(widget.recordId)'));
      expect(detailSource, contains('listVersions(recordId: record.id)'));
      expect(detailSource, contains('getActiveVersion(record)'));
      expect(detailSource, contains('Aktif Sürüm'));
      expect(detailSource, contains('Sürüm Geçmişi'));
    });

    test('detail exposes SHA-256 status and full selectable hash', () {
      expect(detailSource, contains("RegExp(r'^[a-f0-9]{64}\$')"));
      expect(detailSource, contains('version.hashAlgorithm'));
      expect(detailSource, contains('SelectableText('));
      expect(detailSource, contains('SHA-256 bütünlük özeti'));
    });

    test('only matching unsealed draft exposes seal action', () {
      expect(
        detailSource,
        contains('record.status == IpCreationPriorityStatus.draft'),
      );
      expect(
        detailSource,
        contains('record.sealStatus == IpCreationSealStatus.unsealed'),
      );
      expect(
        detailSource,
        contains('activeVersion.sealStatus == IpCreationSealStatus.unsealed'),
      );
      expect(detailSource, contains('Kaydı Mühürle'));
    });

    test('seal action uses repository callable path and reloads detail', () {
      expect(
        detailSource,
        contains('widget.repository.sealRecord(record: record)'),
      );
      expect(detailSource, contains('_reload();'));
      expect(detailSource, contains('contentHash'));
    });

    test('version history exposes chain state', () {
      expect(detailSource, contains('version.hasValidChainLink'));
      expect(detailSource, contains('Önceki sürüm zinciri bağlı'));
      expect(detailSource, contains('version.versionNumber > 1'));
    });
  });
}

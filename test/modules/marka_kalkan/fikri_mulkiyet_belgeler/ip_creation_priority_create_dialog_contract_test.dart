import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('IpCreationPriority create dialog contract', () {
    final dialogSource = File(
      'lib/modules/marka_kalkan/fikri_mulkiyet_belgeler/'
      'presentation/ip_creation_priority_create_dialog.dart',
    ).readAsStringSync();

    final registrySource = File(
      'lib/modules/marka_kalkan/fikri_mulkiyet_belgeler/'
      'presentation/ip_creation_priority_registry_page.dart',
    ).readAsStringSync();

    test('dialog creates paired draft record and first version', () {
      expect(dialogSource, contains('IpCreationPriorityRecordModel('));
      expect(dialogSource, contains('IpCreationPriorityVersionModel('));
      expect(dialogSource, contains('widget.repository.createDraft('));
      expect(dialogSource, contains('status: IpCreationPriorityStatus.draft'));
      expect(
        dialogSource,
        contains('sealStatus: IpCreationSealStatus.unsealed'),
      );
      expect(dialogSource, contains('versionNumber: 1'));
    });

    test('dialog defaults to private confidentiality', () {
      expect(dialogSource, contains('IpCreationConfidentialityLevel.private'));
    });

    test('dialog contains patent public disclosure warning', () {
      expect(dialogSource, contains('_showPatentDisclosureWarning'));
      expect(dialogSource, contains('yenilik değerlendirmesini'));
    });

    test('registry new record button opens dialog', () {
      expect(registrySource, contains('showIpCreationPriorityCreateDialog('));
      expect(
        registrySource,
        contains('ip_creation_priority_create_dialog.dart'),
      );
    });
  });
}

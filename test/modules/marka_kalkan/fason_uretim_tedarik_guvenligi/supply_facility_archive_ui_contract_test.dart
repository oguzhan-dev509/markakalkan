import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String registry;
  late String dialog;
  late String repository;

  setUpAll(() {
    registry = File(
      'lib/modules/marka_kalkan/fason_uretim_tedarik_guvenligi/'
      'presentation/supply_facility_registry_page.dart',
    ).readAsStringSync();

    dialog = File(
      'lib/modules/marka_kalkan/fason_uretim_tedarik_guvenligi/'
      'presentation/supply_facility_detail_edit_dialog.dart',
    ).readAsStringSync();

    repository = File(
      'lib/modules/marka_kalkan/fason_uretim_tedarik_guvenligi/'
      'repositories/supply_facility_repository.dart',
    ).readAsStringSync();
  });

  group('Supply facility archive UI contract', () {
    test('aktif sicil arşiv kayıtlarını ayırır', () {
      expect(registry, contains('final activeFacilities = facilities'));

      expect(registry, contains('.where((item) => !item.isArchived)'));

      expect(registry, contains("label: 'Arşivlenen'"));

      expect(registry, contains('activeFacilities.length'));

      expect(registry, contains('...activeFacilities.map('));
    });

    test('arşiv gerekçesi zorunludur', () {
      expect(dialog, contains("'Arşiv gerekçesi *'"));
      expect(dialog, contains('archiveReason.trim().isEmpty'));
      expect(dialog, contains('archiveReason: archiveReason'));
    });

    test('repository archive kullanıcı kimliğiyle çağrılır', () {
      expect(dialog, contains('widget.repository.archive('));

      expect(dialog, contains('facilityId: widget.facility.id'));

      expect(dialog, contains('updatedBy: widget.user.uid'));
    });

    test('repository sunucu zaman damgası yazar', () {
      expect(
        repository,
        contains("'status': SupplyFacilityStatus.archived.value"),
      );

      expect(
        repository,
        contains("'archivedAt': FieldValue.serverTimestamp()"),
      );

      expect(repository, contains("'updatedAt': FieldValue.serverTimestamp()"));
    });

    test('fiziksel silme bağlanmaz', () {
      expect(dialog, isNot(contains('repository.delete(')));
    });
  });
}

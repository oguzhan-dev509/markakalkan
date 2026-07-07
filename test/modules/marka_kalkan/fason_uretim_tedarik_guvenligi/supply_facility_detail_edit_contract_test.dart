import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String registry;
  late String dialog;

  setUpAll(() {
    registry = File(
      'lib/modules/marka_kalkan/fason_uretim_tedarik_guvenligi/'
      'presentation/supply_facility_registry_page.dart',
    ).readAsStringSync();

    dialog = File(
      'lib/modules/marka_kalkan/fason_uretim_tedarik_guvenligi/'
      'presentation/supply_facility_detail_edit_dialog.dart',
    ).readAsStringSync();
  });

  group('Supply facility detail edit contract', () {
    test('tesis kartı detay dialoguna bağlanır', () {
      expect(
        registry,
        contains("import 'supply_facility_detail_edit_dialog.dart';"),
      );
      expect(registry, contains('showSupplyFacilityDetailEditDialog('));
      expect(registry, contains('facility: facility'));
      expect(registry, contains('facilityRepository: facilityRepository'));
      expect(registry, contains('partnerRepository: partnerRepository'));
    });

    test('değişmez tesis kimlik alanları korunur', () {
      expect(dialog, contains('id: source.id'));
      expect(dialog, contains('tenantId: source.tenantId'));
      expect(dialog, contains('brandId: source.brandId'));
      expect(dialog, contains('partnerId: source.partnerId'));
      expect(dialog, contains('facilityCode: source.facilityCode'));
      expect(dialog, contains('createdAt: source.createdAt'));
      expect(dialog, contains('createdBy: source.createdBy'));
    });

    test('repository update kullanıcı kimliğiyle çağrılır', () {
      expect(dialog, contains('updatedBy: widget.user.uid'));
      expect(dialog, contains('widget.repository.update(updated)'));
    });

    test('arşiv normal düzenleme listesinden çıkarılır', () {
      expect(dialog, contains('item != SupplyFacilityStatus.archived'));
    });

    test('kritik risk ve yetkilendirme kuralları korunur', () {
      expect(dialog, contains('SupplyFacilityRiskLevel.critical'));
      expect(dialog, contains('SupplyFacilityAuthorizationStatus.authorized'));
      expect(dialog, contains('SupplyFacilityType.suspectedUnauthorizedSite'));
    });
  });
}

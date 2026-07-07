import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String registry;
  late String dialog;
  late String repository;

  setUpAll(() {
    registry = File(
      'lib/modules/marka_kalkan/fason_uretim_tedarik_guvenligi/'
      'presentation/supply_partner_registry_page.dart',
    ).readAsStringSync();

    dialog = File(
      'lib/modules/marka_kalkan/fason_uretim_tedarik_guvenligi/'
      'presentation/supply_partner_detail_edit_dialog.dart',
    ).readAsStringSync();

    repository = File(
      'lib/modules/marka_kalkan/fason_uretim_tedarik_guvenligi/'
      'repositories/supply_partner_repository.dart',
    ).readAsStringSync();
  });

  group('Supply partner archive UI contract', () {
    test('aktif sicil arşiv partnerleri ayırır', () {
      expect(registry, contains('final activePartners = partners'));

      expect(registry, contains('.where((item) => !item.isArchived)'));

      expect(registry, contains("label: 'Arşivlenen'"));

      expect(registry, contains('activePartners.length'));

      expect(registry, contains('...activePartners.map('));
    });

    test('arşiv gerekçesi zorunludur', () {
      expect(dialog, contains("'Arşiv gerekçesi *'"));
      expect(dialog, contains('archiveReason.trim().isEmpty'));
      expect(dialog, contains('archiveReason: archiveReason'));
    });

    test('repository archive kullanıcı kimliğiyle çağrılır', () {
      expect(dialog, contains('widget.repository.archive('));

      expect(dialog, contains('partnerId: widget.partner.id'));

      expect(dialog, contains('updatedBy: widget.user.uid'));
    });

    test('repository aktif tesis bulunan partneri engeller', () {
      expect(repository, contains('final facilitiesSnapshot = await'));

      expect(repository, contains("_refs.tenantQuery(_refs.facilities)"));

      expect(repository, contains("data['partnerId'] == partnerId"));

      expect(
        repository,
        contains("data['status'] != SupplyFacilityStatus.archived.value"),
      );

      expect(
        repository,
        contains('Bağlı aktif tesisi bulunan partner arşivlenemez.'),
      );
    });

    test('repository arşiv zaman damgasını sunucudan yazar', () {
      expect(
        repository,
        contains("'status': SupplyPartnerStatus.archived.value"),
      );

      expect(
        repository,
        contains("'archivedAt': FieldValue.serverTimestamp()"),
      );

      expect(repository, contains("'updatedAt': FieldValue.serverTimestamp()"));
    });

    test('fiziksel silme arşiv eylemine bağlanmaz', () {
      expect(dialog, isNot(contains('repository.delete(')));
    });
  });
}

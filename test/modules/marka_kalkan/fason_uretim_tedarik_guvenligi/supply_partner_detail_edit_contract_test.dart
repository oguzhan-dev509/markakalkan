import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String registry;
  late String dialog;

  setUpAll(() {
    registry = File(
      'lib/modules/marka_kalkan/fason_uretim_tedarik_guvenligi/'
      'presentation/supply_partner_registry_page.dart',
    ).readAsStringSync();

    dialog = File(
      'lib/modules/marka_kalkan/fason_uretim_tedarik_guvenligi/'
      'presentation/supply_partner_detail_edit_dialog.dart',
    ).readAsStringSync();
  });

  group('Supply partner detail edit contract', () {
    test('partner kartı dialoga bağlanır', () {
      expect(
        registry,
        contains("import 'supply_partner_detail_edit_dialog.dart';"),
      );
      expect(registry, contains('showSupplyPartnerDetailEditDialog('));
      expect(registry, contains('partner: partner'));
      expect(registry, contains('repository: repository'));
    });

    test('değişmez kimlik alanları korunur', () {
      expect(dialog, contains('id: source.id'));
      expect(dialog, contains('tenantId: source.tenantId'));
      expect(dialog, contains('brandId: source.brandId'));
      expect(dialog, contains('partnerCode: source.partnerCode'));
      expect(dialog, contains('createdAt: source.createdAt'));
      expect(dialog, contains('createdBy: source.createdBy'));
    });

    test('repository update kullanıcı kimliğiyle çağrılır', () {
      expect(dialog, contains('updatedBy: widget.user.uid'));
      expect(dialog, contains('widget.repository.update(updated)'));
    });

    test('arşiv durumu normal düzenleme listesinden çıkarılır', () {
      expect(dialog, contains('item != SupplyPartnerStatus.archived'));
    });
  });
}

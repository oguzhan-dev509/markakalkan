import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const dialogPath =
      'lib/modules/marka_kalkan/'
      'fason_uretim_tedarik_guvenligi/'
      'presentation/'
      'supply_protection_control_create_dialog.dart';

  const registryPath =
      'lib/modules/marka_kalkan/'
      'fason_uretim_tedarik_guvenligi/'
      'presentation/'
      'supply_protection_control_registry_page.dart';

  late String dialog;
  late String registry;

  setUpAll(() {
    dialog = File(dialogPath).readAsStringSync();
    registry = File(registryPath).readAsStringSync();
  });

  test('dialog loads partner and facility inventories', () {
    expect(dialog, contains('partnerRepository.listAll(limit: 500)'));

    expect(dialog, contains('facilityRepository.listAll(limit: 500)'));

    expect(dialog, contains('.where((item) => !item.isArchived)'));
  });

  test('dialog supports all control scopes', () {
    expect(dialog, contains('SupplyProtectionControlScope.partner'));

    expect(dialog, contains('SupplyProtectionControlScope.facility'));

    expect(dialog, contains('SupplyProtectionControlScope.partnerAndFacility'));
  });

  test('facility list follows selected partner', () {
    expect(dialog, contains('facility.partnerId == _selectedPartnerId'));

    expect(dialog, contains('_availableFacilities'));
  });

  test('dialog requires a planned date', () {
    expect(dialog, contains('Planlanan kontrol tarihini seçin.'));

    expect(dialog, contains('showDatePicker('));
    expect(dialog, contains('plannedAt: _plannedAt'));
  });

  test('dialog creates a planned unevaluated control', () {
    expect(dialog, contains('status: SupplyProtectionControlStatus.planned'));

    expect(dialog, contains('SupplyProtectionControlResult.notEvaluated'));

    expect(dialog, contains('await widget.controlRepository.create(control)'));
  });

  test('dialog uses authenticated tenant and brand', () {
    expect(dialog, contains('tenantId: widget.user.uid'));
    expect(dialog, contains('brandId: widget.user.uid'));
    expect(dialog, contains('createdBy: widget.user.uid'));
  });

  test('dialog uses current dropdown form API', () {
    expect(dialog, contains('initialValue: _controlType'));
    expect(dialog, contains('initialValue: _scope'));
    expect(dialog, contains('initialValue: _riskLevel'));
  });

  test('registry opens real create dialog', () {
    expect(
      registry,
      contains("import 'supply_protection_control_create_dialog.dart';"),
    );

    expect(registry, contains('showSupplyProtectionControlCreateDialog('));

    expect(registry, contains('SupplyPartnerRepository.instance'));

    expect(registry, contains('SupplyFacilityRepository.instance'));

    expect(registry, isNot(contains('Faz 2B kapsamında açılacak.')));
  });
}

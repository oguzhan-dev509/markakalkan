import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const registryPath =
      'lib/modules/marka_kalkan/'
      'fason_uretim_tedarik_guvenligi/'
      'presentation/'
      'supply_protection_control_registry_page.dart';

  const hubPath =
      'lib/modules/marka_kalkan/'
      'fason_uretim_tedarik_guvenligi/'
      'presentation/'
      'supply_security_hub_page.dart';

  late String registry;
  late String hub;

  setUpAll(() {
    registry = File(registryPath).readAsStringSync();
    hub = File(hubPath).readAsStringSync();
  });

  test('registry uses authenticated tenant repository', () {
    expect(registry, contains('FirebaseAuth.instance.currentUser'));

    expect(registry, contains('SupplyProtectionControlRepository.instance'));

    expect(registry, contains('tenantId: user.uid'));
  });

  test('registry watches protection controls', () {
    expect(registry, contains('SupplyProtectionControlModel'));

    expect(registry, contains('stream: repository.watchAll()'));
  });

  test('registry exposes summary metrics', () {
    expect(registry, contains("'Aktif kontrol'"));
    expect(registry, contains("'Açık kontrol'"));
    expect(registry, contains("'Gecikmiş'"));
    expect(registry, contains("'Yüksek / kritik risk'"));
    expect(registry, contains("'Uygunsuz sonuç'"));
    expect(registry, contains("'Arşivlenen'"));
  });

  test('registry filters status result and risk', () {
    expect(registry, contains('SupplyProtectionControlStatus? _statusFilter'));

    expect(registry, contains('SupplyProtectionControlResult? _resultFilter'));

    expect(registry, contains('SupplyProtectionControlRiskLevel? _riskFilter'));

    expect(registry, contains('bool _matchesFilters('));
  });

  test('registry uses current form field API', () {
    expect(registry, contains('initialValue: status'));

    expect(registry, contains('initialValue: result'));

    expect(registry, contains('initialValue: riskLevel'));

    expect(registry, isNot(contains('value: status')));
  });

  test('registry shows dates and corrective action', () {
    expect(registry, contains('control.plannedAt'));

    expect(registry, contains('control.completedAt'));

    expect(registry, contains('control.nextControlAt'));

    expect(registry, contains('control.hasOpenCorrectiveAction'));
  });

  test('hub exposes control registry card', () {
    expect(
      hub,
      contains("import 'supply_protection_control_registry_page.dart';"),
    );

    expect(hub, contains("'Koruma Kontrolleri Sicili'"));

    expect(hub, contains('const SupplyProtectionControlRegistryPage()'));
  });

  test('new control action is visible', () {
    expect(registry, contains("'Yeni Kontrol'"));

    expect(registry, contains('FloatingActionButton.extended'));
  });
}

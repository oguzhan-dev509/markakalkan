import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const repositoryPath =
      'lib/modules/marka_kalkan/'
      'fason_uretim_tedarik_guvenligi/'
      'repositories/'
      'supply_protection_control_repository.dart';

  const commandServicePath =
      'lib/modules/marka_kalkan/'
      'fason_uretim_tedarik_guvenligi/'
      'repositories/'
      'supply_protection_control_command_service.dart';

  const functionPath = 'functions/supply_security/protection_controls.js';

  late String repositorySource;
  late String commandServiceSource;
  late String functionSource;

  setUpAll(() {
    repositorySource = File(repositoryPath).readAsStringSync();
    commandServiceSource = File(commandServicePath).readAsStringSync();
    functionSource = File(functionPath).readAsStringSync();
  });

  test('repository exposes required lifecycle operations', () {
    expect(repositorySource, contains('Future<String> create('));
    expect(repositorySource, contains('Future<void> update('));
    expect(repositorySource, contains('Future<void> complete({'));
    expect(
      repositorySource,
      contains('Future<void> markCorrectiveActionCompleted({'),
    );
    expect(repositorySource, contains('Future<void> archive({'));
  });

  test('general update delegates to callable command service', () {
    expect(repositorySource, contains('await commandService.update(control);'));

    expect(
      repositorySource,
      isNot(contains('document.update(control.toUpdateMap')),
    );

    expect(
      commandServiceSource,
      contains("httpsCallable('updateSupplyProtectionControl')"),
    );
  });

  test('server validates partner and facility targets', () {
    expect(
      functionSource,
      contains('validateTargetShape(scope, partnerId, facilityId);'),
    );

    expect(functionSource, contains('.collection("supply_security_partners")'));

    expect(
      functionSource,
      contains('.collection("supply_security_facilities")'),
    );

    expect(
      functionSource,
      contains('Secilen tesis belirtilen partnere bagli degil.'),
    );

    expect(
      functionSource,
      contains('Arsivlenmis partner koruma kontrolune baglanamaz.'),
    );

    expect(
      functionSource,
      contains('Arsivlenmis tesis koruma kontrolune baglanamaz.'),
    );
  });

  test('repository and server protect tenant and brand ownership', () {
    expect(repositorySource, contains('_validateTenant'));

    expect(
      functionSource,
      contains('current.tenantId !== uid || current.brandId !== uid'),
    );

    expect(
      functionSource,
      contains('partner.tenantId !== uid || partner.brandId !== uid'),
    );

    expect(
      functionSource,
      contains('facility.tenantId !== uid || facility.brandId !== uid'),
    );
  });

  test('failed result requires findings and corrective action', () {
    expect(repositorySource, contains('Uygunsuz kontrolde bulgu zorunludur.'));

    expect(
      repositorySource,
      contains('Uygunsuz kontrolde düzeltici faaliyet zorunludur.'),
    );

    expect(
      functionSource,
      contains('Uygunsuz kontrolde duzeltici faaliyet zorunludur.'),
    );
  });

  test('repository does not expose physical deletion', () {
    expect(repositorySource, isNot(contains('Future<void> delete(')));

    expect(repositorySource, isNot(contains('.delete()')));
  });

  test('repository requires archive reason', () {
    expect(repositorySource, contains("fieldName: 'archiveReason'"));

    expect(repositorySource, contains("'archiveReason': reason"));

    expect(
      repositorySource,
      contains('SupplyProtectionControlStatus.archived.value'),
    );
  });
}

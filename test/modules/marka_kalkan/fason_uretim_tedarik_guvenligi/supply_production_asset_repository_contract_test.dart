import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const repositoryPath =
      'lib/modules/marka_kalkan/fason_uretim_tedarik_guvenligi/'
      'repositories/supply_production_asset_repository.dart';
  const commandPath =
      'lib/modules/marka_kalkan/fason_uretim_tedarik_guvenligi/'
      'repositories/supply_production_asset_command_service.dart';
  const functionPath = 'functions/supply_security/production_assets.js';

  test('all writes use callable services and no delete is exposed', () {
    final repository = File(repositoryPath).readAsStringSync();
    final command = File(commandPath).readAsStringSync();
    final function = File(functionPath).readAsStringSync();

    expect(repository, contains('return _commandService.create(asset);'));
    expect(repository, contains('await _commandService.update(asset);'));
    expect(repository, isNot(contains('.add(')));
    expect(repository, isNot(contains('.set(')));
    expect(repository, isNot(contains('.delete(')));
    expect(command, contains("httpsCallable('createSupplyProductionAsset')"));
    expect(command, contains("httpsCallable('updateSupplyProductionAsset')"));
    expect(function, contains('current.status === "archived"'));
    expect(function, contains('current.status === "destroyed"'));
  });

  test('general update does not accept lifecycle fields', () {
    final command = File(commandPath).readAsStringSync();
    final function = File(functionPath).readAsStringSync();

    for (final forbidden in <String>[
      "'status':",
      "'destroyedAt':",
      "'archivedAt':",
      "'createdAt':",
      "'createdBy':",
      "'tenantId':",
      "'brandId':",
    ]) {
      expect(command, isNot(contains(forbidden)), reason: forbidden);
    }

    final operationalStart = function.indexOf(
      'function operationalFields(data)',
    );
    final operationalEnd = function.indexOf(
      'async function validateTargets',
      operationalStart,
    );

    expect(operationalStart, greaterThanOrEqualTo(0));
    expect(operationalEnd, greaterThan(operationalStart));

    final operationalFields = function.substring(
      operationalStart,
      operationalEnd,
    );

    expect(operationalFields, isNot(contains('data.status')));
    expect(operationalFields, isNot(contains('data.destroyedAt')));
    expect(operationalFields, isNot(contains('data.archivedAt')));
  });
}

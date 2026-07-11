import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const dialogPath =
      'lib/modules/marka_kalkan/sahte_ikiz_sicili/presentation/'
      'counterfeit_twin_report_dialog.dart';
  const registryPath =
      'lib/modules/marka_kalkan/sahte_ikiz_sicili/presentation/'
      'counterfeit_twin_registry_page.dart';

  late String dialog;
  late String registry;

  setUpAll(() {
    dialog = File(dialogPath).readAsStringSync();
    registry = File(registryPath).readAsStringSync();
  });

  test('registry exposes a distinct radar report action', () {
    expect(registry, contains("import 'counterfeit_twin_report_dialog.dart';"));
    expect(registry, contains('showCounterfeitTwinReportDialog'));
    expect(registry, contains("'Sahte ikiz bildir'"));
    expect(registry, contains('showCounterfeitTwinCreateDialog'));
  });

  test('report form supports dynamic target categories', () {
    expect(dialog, contains('CounterfeitTwinTargetType'));
    expect(dialog, contains("'Taklit edilen varlık türü *'"));
    expect(dialog, contains('_changeTarget'));
    expect(dialog, contains('_availableIncidentTypes'));
  });

  test('robot and autonomous agent fields are conditional', () {
    expect(dialog, contains('CounterfeitTwinTargetType.roboticSystem'));
    expect(dialog, contains('CounterfeitTwinTargetType.autonomousAiAgent'));
    expect(dialog, contains('CounterfeitTwinRobotType'));
    expect(dialog, contains("'Robot / ajan alt türü *'"));
  });

  test('incident types are selected with filter chips', () {
    expect(dialog, contains('FilterChip'));
    expect(dialog, contains('_incidentTypes'));
    expect(dialog, contains('En az bir olay türü seçilmelidir.'));
  });

  test('financial loss and dispute workflow is available', () {
    expect(dialog, contains('_hasMonetaryLoss'));
    expect(dialog, contains('_disputeSubmitted'));
    expect(dialog, contains('CounterfeitTwinFinancialImpact'));
    expect(dialog, contains("'Banka / ödeme kuruluşu'"));
    expect(dialog, contains("'İtiraz / dilekçe referansı'"));
  });

  test('sensitive payment data warning is visible', () {
    expect(dialog, contains('Tam kart numarası'));
    expect(dialog, contains('açık IBAN'));
    expect(dialog, contains('CVV'));
  });

  test('report is submitted through the radar callable service', () {
    expect(dialog, contains('CounterfeitTwinRadarService'));
    expect(dialog, contains('CounterfeitTwinRadarReport'));
    expect(dialog, contains('await _service.submit(report)'));
  });

  test('product and platform identity fields remain supported', () {
    expect(dialog, contains('_originalBrandName'));
    expect(dialog, contains('_suspectedBrandName'));
    expect(dialog, contains('_originalEntityName'));
    expect(dialog, contains('_suspectedEntityName'));
    expect(dialog, contains('_platformName'));
  });
}

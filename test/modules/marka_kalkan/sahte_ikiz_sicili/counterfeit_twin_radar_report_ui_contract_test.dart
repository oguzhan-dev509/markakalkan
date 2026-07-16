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
    expect(dialog, contains("'Ana kategori *'"));
    expect(dialog, contains("'Alt kategori *'"));
    expect(dialog, contains('_changePublicSection'));
    expect(dialog, contains('_changePublicSubcategory'));
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

  test('sections four and five are simple and clear', () {
    expect(dialog, contains("'4. Olay ve kanıt açıklaması'"));
    expect(dialog, contains("'5. Zarar veya ek bilgi'"));
    expect(dialog, contains('CounterfeitTwinSimpleEvidenceEditor'));
    expect(dialog, contains('maxLength: 1500'));
    expect(dialog, contains('maxLength: 750'));
  });

  test('financial and comparison workflows are removed from public form', () {
    expect(dialog, isNot(contains('_hasMonetaryLoss')));
    expect(dialog, isNot(contains('_disputeSubmitted')));
    expect(dialog, isNot(contains("'Banka / ödeme kuruluşu'")));
    expect(dialog, isNot(contains("'İtiraz / dilekçe referansı'")));
    expect(dialog, isNot(contains('CounterfeitTwinComparisonCodec.encode')));
    expect(dialog, isNot(contains('CounterfeitTwinEvidenceEditor(')));
  });

  test('evidence and sensitive data warnings are visible', () {
    expect(dialog, contains('en az bir kanıt görseli'));
    expect(dialog, contains('kaynak bağlantısı'));
    expect(dialog, contains('Tam kart numarası'));
    expect(dialog, contains('açık IBAN'));
    expect(dialog, contains('parola'));
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

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final radarContract = File(
    'lib/modules/marka_kalkan/sahte_ikiz_sicili/models/'
    'counterfeit_twin_radar_contract.dart',
  ).readAsStringSync();
  final publicContract = File(
    'lib/modules/marka_kalkan/sahte_ikiz_sicili/models/'
    'counterfeit_twin_public_contract.dart',
  ).readAsStringSync();
  final reportDialog = File(
    'lib/modules/marka_kalkan/sahte_ikiz_sicili/presentation/'
    'counterfeit_twin_report_dialog.dart',
  ).readAsStringSync();
  final publicRadar = File(
    'lib/modules/marka_kalkan/sahte_ikiz_sicili/presentation/'
    'counterfeit_twin_public_radar_page.dart',
  ).readAsStringSync();
  final backend = File(
    'functions/counterfeit_twin/counterfeit_twin_radar.js',
  ).readAsStringSync();

  test('three public sections own distinct subcategory taxonomies', () {
    expect(radarContract, contains("food_beverage"));
    expect(radarContract, contains("website_domain"));
    expect(radarContract, contains("autonomous_ai_agent"));
    expect(radarContract, contains("production_tool_mold_component"));
    expect(radarContract, contains("digital_document_certificate"));
    expect(radarContract, contains("robot_fleet_device_identity"));
  });

  test('report form selects section and subcategory separately', () {
    expect(reportDialog, contains('CounterfeitTwinPublicSection'));
    expect(reportDialog, contains('CounterfeitTwinPublicSubcategory'));
    expect(reportDialog, contains('Ana kategori *'));
    expect(reportDialog, contains('Alt kategori *'));
    expect(reportDialog, contains('_changePublicSection'));
    expect(reportDialog, contains('_changePublicSubcategory'));
  });

  test('report payload carries public taxonomy', () {
    expect(radarContract, contains("'publicCategory'"));
    expect(radarContract, contains("'publicSubcategory'"));
  });

  test('backend validates category subcategory consistency', () {
    expect(backend, contains('PUBLIC_SUBCATEGORY_RULES'));
    expect(backend, contains('normalizePublicTaxonomy'));
    expect(backend, contains('publicSubcategory secilen publicCategory'));
    expect(backend, contains('publicSubcategory secilen targetType'));
  });

  test('public contract exposes the stable subcategory', () {
    expect(publicContract, contains('publicSubcategory'));
  });

  test('public radar uses fixed section-specific subcategories', () {
    expect(publicRadar, contains('_subcategoryFilters'));
    expect(publicRadar, contains('Alt kategoriler'));
    expect(publicRadar, contains('publicSubcategory'));
    expect(
      publicRadar,
      contains('CounterfeitTwinPublicSubcategory.forSection'),
    );
  });
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final backend = File(
    'functions/counterfeit_twin/counterfeit_twin_radar.js',
  ).readAsStringSync();
  final reportContract = File(
    'lib/modules/marka_kalkan/sahte_ikiz_sicili/models/'
    'counterfeit_twin_radar_contract.dart',
  ).readAsStringSync();
  final dialog = File(
    'lib/modules/marka_kalkan/sahte_ikiz_sicili/presentation/'
    'counterfeit_twin_report_dialog.dart',
  ).readAsStringSync();
  final adminModel = File(
    'lib/features/admin/models/counterfeit_twin_admin_report.dart',
  ).readAsStringSync();
  final adminPage = File(
    'lib/features/admin/presentation/'
    'counterfeit_twin_review_queue_page.dart',
  ).readAsStringSync();
  final publicContract = File(
    'lib/modules/marka_kalkan/sahte_ikiz_sicili/models/'
    'counterfeit_twin_public_contract.dart',
  ).readAsStringSync();
  final publicPage = File(
    'lib/modules/marka_kalkan/sahte_ikiz_sicili/presentation/'
    'counterfeit_twin_public_detail_page.dart',
  ).readAsStringSync();

  test('report contract carries all three core information fields', () {
    for (final field in <String>[
      'usagePurpose',
      'technicalIdentity',
      'counterfeitRisk',
    ]) {
      expect(reportContract, contains('final String $field'));
      expect(reportContract, contains("'$field': $field"));
    }
  });

  test('public form keeps core context short and optional', () {
    expect(dialog, contains("'Ne için kullanılır?'"));
    expect(dialog, contains("'Ayırt edici teknik bilgi / ürün kimliği'"));
    expect(dialog, contains("'5. Zarar veya ek bilgi'"));
    expect(dialog, contains("'Zarar veya ek bilgi'"));
    expect(dialog, contains("_optional(value, 'Ne için kullanılır?', 300)"));
    expect(dialog, contains("_optional(value, 'Zarar veya ek bilgi', 750)"));
    expect(dialog, contains('maxLength: 300'));
    expect(dialog, contains('maxLength: 500'));
    expect(dialog, contains('maxLength: 750'));
  });

  test('callable accepts optional fields with bounded lengths', () {
    expect(
      backend,
      contains('usagePurpose: text(data.usagePurpose, "usagePurpose", 300)'),
    );
    expect(
      backend,
      contains(
        'counterfeitRisk: text(data.counterfeitRisk, "counterfeitRisk", 750)',
      ),
    );
    expect(backend, isNot(contains('CRITICAL_RISK_SUBCATEGORIES')));
    expect(backend, contains('usagePurpose: report.usagePurpose || ""'));
    expect(
      backend,
      contains('technicalIdentity: report.technicalIdentity || ""'),
    );
    expect(backend, contains('counterfeitRisk: report.counterfeitRisk || ""'));
  });

  test('admin review exposes all three optional fields', () {
    expect(adminModel, contains("text('usagePurpose')"));
    expect(adminModel, contains("text('technicalIdentity')"));
    expect(adminModel, contains("text('counterfeitRisk')"));
    expect(adminPage, contains("'Ne için kullanılır?'"));
    expect(adminPage, contains("'Ayırt edici teknik bilgi / ürün kimliği'"));
    expect(adminPage, contains("'Sahte olduğunda doğabilecek risk'"));
  });

  test('public detail remains legacy-compatible and hides empty section', () {
    expect(publicContract, contains("_string(map['usagePurpose'])"));
    expect(publicContract, contains("_string(map['technicalIdentity'])"));
    expect(publicContract, contains("_string(map['counterfeitRisk'])"));
    expect(publicContract, contains("this.usagePurpose = ''"));
    expect(publicContract, contains("this.technicalIdentity = ''"));
    expect(publicContract, contains("this.counterfeitRisk = ''"));
    expect(publicPage, contains('_hasCoreProductInformation'));
    expect(publicPage, contains('_CoreProductInformationSection'));
    expect(publicPage, contains("'Ürün amacı, teknik kimlik ve risk'"));
  });
}

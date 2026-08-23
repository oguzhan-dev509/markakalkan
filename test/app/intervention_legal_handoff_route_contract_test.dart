import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('MHL-3C-3 router preserves generic entry and explicit case handoff', () {
    final source = File('lib/app/router.dart').readAsStringSync();

    expect(source, contains('static Future<void> openInterventionLegalHub('));
    expect(source, contains('String? tenantId'));
    expect(source, contains('String? canonicalBrandId'));
    expect(source, contains('String? caseId'));
    expect(source, contains('hasAnyCreateMatterContext'));
    expect(source, contains('hasCompleteCreateMatterContext'));
    expect(source, contains('InterventionLegalCreateMatterHandoff('));
    expect(source, contains('createMatterHandoff: createMatterHandoff'));
    expect(source, contains("RouteSettings(name: '/intervention-legal')"));
    expect(source, isNot(contains('createInterventionLegalMatter')));
  });

  test('MHL-3C-3 case detail uses the router as navigation-only boundary', () {
    final source = File(
      'lib/features/case_evidence_center/presentation/case_evidence_detail_page.dart',
    ).readAsStringSync();

    expect(source, contains('AppRouter.openInterventionLegalHub('));
    expect(source, contains('tenantId: detail.tenantId'));
    expect(source, contains('canonicalBrandId: detail.canonicalBrandId'));
    expect(source, contains('caseId: detail.caseId'));
    expect(source, isNot(contains('createInterventionLegalMatter')));
  });
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final router = File('lib/app/router.dart').readAsStringSync();
  final dashboard = File(
    'lib/features/dashboard/presentation/brand_dashboard_page.dart',
  ).readAsStringSync();
  final scansPage = File(
    'lib/features/traceability/presentation/suspicious_verification_scans_page.dart',
  ).readAsStringSync();
  final casesPage = File(
    'lib/features/traceability/presentation/traceability_cases_page.dart',
  ).readAsStringSync();

  test('router exposes traceability operation pages', () {
    expect(router, contains('openSuspiciousVerificationScans'));
    expect(router, contains('const SuspiciousVerificationScansPage()'));
    expect(router, contains('openTraceabilityCases'));
    expect(router, contains('const TraceabilityCasesPage()'));
  });

  test('traceability hub cards open their real pages', () {
    expect(dashboard, contains("if (module.title == 'Şüpheli Taramalar')"));
    expect(
      dashboard,
      contains('AppRouter.openSuspiciousVerificationScans(context)'),
    );
    expect(dashboard, contains("if (module.title == 'Vaka Dosyaları')"));
    expect(dashboard, contains('AppRouter.openTraceabilityCases(context)'));
  });

  test('suspicious scans page owns review and case actions', () {
    expect(scansPage, contains('class SuspiciousVerificationScansPage'));
    expect(scansPage, contains('listSuspiciousScans'));
    expect(scansPage, contains('reviewScan'));
    expect(scansPage, contains('createCaseFromScan'));
    expect(scansPage, contains('Vaka Dosyası Aç'));
  });

  test('cases page lists traceability case files', () {
    expect(casesPage, contains('class TraceabilityCasesPage'));
    expect(casesPage, contains('listCases'));
    expect(casesPage, contains('Vaka Dosyaları'));
    expect(casesPage, contains('Şüpheli Taramalar ekranından'));
  });
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final scansPage = File(
    'lib/features/traceability/presentation/'
    'suspicious_verification_scans_page.dart',
  ).readAsStringSync();
  final casesPage = File(
    'lib/features/traceability/presentation/'
    'traceability_cases_page.dart',
  ).readAsStringSync();

  test('suspicious scan actions remain visible from the left edge', () {
    expect(scansPage, contains('alignment: WrapAlignment.start'));
    expect(scansPage, contains('Vaka Dosyası Aç'));
    expect(scansPage, contains('İncele'));
  });

  test('empty case center links back to suspicious scans', () {
    expect(casesPage, contains('Şüpheli Taramalara Git'));
    expect(
      casesPage,
      contains('AppRouter.openSuspiciousVerificationScans(context)'),
    );
  });
}

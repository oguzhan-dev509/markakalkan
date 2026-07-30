import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AppRouter exposes only a programmatic Public Lite preview route', () {
    final source = File('lib/app/router.dart').readAsStringSync();

    expect(
      source,
      contains(
        "import 'package:markakalkan/features/risk_scan/presentation/"
        "public_lite_risk_scan_preview_page.dart';",
      ),
    );
    expect(source, contains('openPublicLiteRiskScanPreview('));
    expect(source, contains("name: '/risk-scan/public-lite-preview'"));
    expect(
      source,
      contains('builder: (_) => const PublicLiteRiskScanPreviewPage()'),
    );

    expect(
      RegExp(r"'/risk-scan/public-lite-preview'").allMatches(source).length,
      1,
    );
  });
}

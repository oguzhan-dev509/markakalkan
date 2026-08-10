import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Public Lite page includes the approved sponsor/footer section once',
    () {
      final source = File(
        'lib/features/risk_scan/presentation/'
        'public_lite_risk_scan_preview_page.dart',
      ).readAsStringSync();

      expect(
        source,
        contains(
          "import 'package:markakalkan/features/risk_scan/presentation/"
          "public_lite_sponsor_footer_section.dart';",
        ),
      );
      expect(
        RegExp(
          r'const PublicLiteSponsorFooterSection\(\)',
        ).allMatches(source).length,
        1,
      );
      expect(source, contains('Marka ve resmî kaynak'));
      expect(source, contains('_buildProjection(context, projection)'));
      expect(RegExp(r"'Hızlı Risk Taraması'").allMatches(source).length, 1);
    },
  );
}

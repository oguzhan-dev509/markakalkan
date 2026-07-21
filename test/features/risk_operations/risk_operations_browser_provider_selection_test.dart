import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markakalkan/features/risk_operations/data/risk_operations_browser_context.dart';

void main() {
  test('conditional export selects the platform-safe provider', () {
    expect(
      riskOperationsBrowserProviderKind,
      kIsWeb ? 'web_interop_v1' : 'stub_v1',
    );
    final context = createRiskOperationsBrowserContext();
    expect(context.providerKind, riskOperationsBrowserProviderKind);
    if (kIsWeb) {
      expect(context.sessionStorage, isNotNull);
    } else {
      expect(context.sessionStorage, isNull);
      expect(context.browserAccessDegraded, true);
    }
  });
}

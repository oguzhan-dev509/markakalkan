// ignore_for_file: avoid_print

import 'package:markakalkan/features/risk_operations/data/risk_operations_browser_context.dart';

void main() {
  if (riskOperationsBrowserProviderKind != 'web_interop_v1') {
    throw StateError('Wasm selected a non-web risk lifecycle provider.');
  }
  print(riskOperationsBrowserProviderKind);
}

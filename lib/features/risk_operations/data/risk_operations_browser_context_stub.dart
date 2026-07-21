import 'risk_operations_lifecycle.dart';

const riskOperationsBrowserProviderKind = 'stub_v1';

RiskOperationsBrowserContext createRiskOperationsBrowserContext() =>
    const RiskOperationsBrowserContext(
      providerKind: riskOperationsBrowserProviderKind,
      browserAccessDegraded: true,
    );

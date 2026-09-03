import 'package:markakalkan/features/intervention_legal/data/intervention_legal_workspace_repository.dart';
import 'package:markakalkan/shared/risk_contracts/v1/shared_risk_contracts_v1.dart';

const String interventionLegalTransitionOperationCode =
    'transition_legal_matter';
const String interventionLegalCreateApprovalRequestOperationCode =
    'create_approval_request';

final class InterventionLegalCapabilityAccessAdapterV1 {
  const InterventionLegalCapabilityAccessAdapterV1();

  CapabilityAccessDecisionV1 evaluate({
    required InterventionLegalMatterSummary matter,
    required String operationCode,
  }) {
    final normalized = operationCode.trim();
    final projection = matter.capabilityAccess.legalAction(normalized);
    final scoped =
        projection != null &&
        projection.operationCode == normalized &&
        projection.canonicalBrandId == matter.canonicalBrandId;
    final authority = scoped && projection.operationAuthorityGranted;

    return evaluateCapabilityAccessV1(
      policy: CapabilityAccessPolicyV1.defaultFor(
        RiskCapabilityCodeV1.legalAction,
      ),
      context: CapabilityAccessContextV1(
        loggedIn: true,
        verifiedBrand: false,
        subscriptionActive: false,
        operationAuthorityGranted: authority,
      ),
    );
  }

  bool isGranted({
    required InterventionLegalMatterSummary matter,
    required String operationCode,
  }) => evaluate(matter: matter, operationCode: operationCode).granted;
}

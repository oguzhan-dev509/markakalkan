import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants/ip_collections.dart';
import '../models/ip_trade_secret_access_grant_model.dart';
import '../models/ip_trade_secret_alert_rule_model.dart';
import '../models/ip_trade_secret_component_model.dart';
import '../models/ip_trade_secret_defensibility_record_model.dart';
import '../models/ip_trade_secret_disclosure_model.dart';
import '../models/ip_trade_secret_incident_model.dart';
import '../models/ip_trade_secret_lifecycle_transition_model.dart';
import '../models/ip_trade_secret_management_decision_model.dart';
import '../models/ip_trade_secret_model.dart';
import '../models/ip_trade_secret_protection_control_model.dart';
import '../models/ip_trade_secret_remediation_action_model.dart';
import '../models/ip_trade_secret_resilience_profile_model.dart';
import '../models/ip_trade_secret_risk_assessment_model.dart';

class IpTradeSecretPortfolioDataSet {
  const IpTradeSecretPortfolioDataSet({
    this.tradeSecrets = const <IpTradeSecretModel>[],
    this.components = const <IpTradeSecretComponentModel>[],
    this.accessGrants = const <IpTradeSecretAccessGrantModel>[],
    this.disclosures = const <IpTradeSecretDisclosureModel>[],
    this.incidents = const <IpTradeSecretIncidentModel>[],
    this.protectionControls = const <IpTradeSecretProtectionControlModel>[],
    this.riskAssessments = const <IpTradeSecretRiskAssessmentModel>[],
    this.resilienceProfiles = const <IpTradeSecretResilienceProfileModel>[],
    this.defensibilityRecords = const <IpTradeSecretDefensibilityRecordModel>[],
    this.lifecycleTransitions = const <IpTradeSecretLifecycleTransitionModel>[],
    this.remediationActions = const <IpTradeSecretRemediationActionModel>[],
    this.alertRules = const <IpTradeSecretAlertRuleModel>[],
    this.managementDecisions = const <IpTradeSecretManagementDecisionModel>[],
  });

  final List<IpTradeSecretModel> tradeSecrets;
  final List<IpTradeSecretComponentModel> components;
  final List<IpTradeSecretAccessGrantModel> accessGrants;
  final List<IpTradeSecretDisclosureModel> disclosures;
  final List<IpTradeSecretIncidentModel> incidents;
  final List<IpTradeSecretProtectionControlModel> protectionControls;
  final List<IpTradeSecretRiskAssessmentModel> riskAssessments;
  final List<IpTradeSecretResilienceProfileModel> resilienceProfiles;
  final List<IpTradeSecretDefensibilityRecordModel> defensibilityRecords;
  final List<IpTradeSecretLifecycleTransitionModel> lifecycleTransitions;
  final List<IpTradeSecretRemediationActionModel> remediationActions;
  final List<IpTradeSecretAlertRuleModel> alertRules;
  final List<IpTradeSecretManagementDecisionModel> managementDecisions;

  Map<String, int> get sourceRecordCounts => <String, int>{
    'tradeSecrets': tradeSecrets.length,
    'components': components.length,
    'accessGrants': accessGrants.length,
    'disclosures': disclosures.length,
    'incidents': incidents.length,
    'protectionControls': protectionControls.length,
    'riskAssessments': riskAssessments.length,
    'resilienceProfiles': resilienceProfiles.length,
    'defensibilityRecords': defensibilityRecords.length,
    'lifecycleTransitions': lifecycleTransitions.length,
    'remediationActions': remediationActions.length,
    'alertRules': alertRules.length,
    'managementDecisions': managementDecisions.length,
  };

  int get totalSourceRecordCount {
    return sourceRecordCounts.values.fold<int>(
      0,
      (total, recordCount) => total + recordCount,
    );
  }
}

abstract interface class IpTradeSecretPortfolioDataSourcePort {
  Future<IpTradeSecretPortfolioDataSet> loadPortfolioData({
    required String tenantId,
    String? brandId,
  });
}

class FirestoreIpTradeSecretPortfolioDataSource
    implements IpTradeSecretPortfolioDataSourcePort {
  FirestoreIpTradeSecretPortfolioDataSource({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  @override
  Future<IpTradeSecretPortfolioDataSet> loadPortfolioData({
    required String tenantId,
    String? brandId,
  }) async {
    final cleanedTenantId = tenantId.trim();
    final cleanedBrandId = brandId?.trim();

    if (cleanedTenantId.isEmpty) {
      throw ArgumentError.value(
        tenantId,
        'tenantId',
        'Tenant kimliği boş olamaz.',
      );
    }

    Query<Map<String, dynamic>> queryFor(String collectionName) {
      Query<Map<String, dynamic>> query = _firestore
          .collection(collectionName)
          .where('tenantId', isEqualTo: cleanedTenantId);

      if (cleanedBrandId != null && cleanedBrandId.isNotEmpty) {
        query = query.where('brandId', isEqualTo: cleanedBrandId);
      }

      return query;
    }

    final results = await Future.wait<QuerySnapshot<Map<String, dynamic>>>([
      queryFor(IpCollections.tradeSecrets).get(),
      queryFor(IpCollections.tradeSecretComponents).get(),
      queryFor(IpCollections.tradeSecretAccessGrants).get(),
      queryFor(IpCollections.tradeSecretDisclosures).get(),
      queryFor(IpCollections.tradeSecretIncidents).get(),
      queryFor(IpCollections.tradeSecretProtectionControls).get(),
      queryFor(IpCollections.tradeSecretRiskAssessments).get(),
      queryFor(IpCollections.tradeSecretResilienceProfiles).get(),
      queryFor(IpCollections.tradeSecretDefensibilityRecords).get(),
      queryFor(IpCollections.tradeSecretLifecycleTransitions).get(),
      queryFor(IpCollections.tradeSecretRemediationActions).get(),
      queryFor(IpCollections.tradeSecretAlertRules).get(),
      queryFor(IpCollections.tradeSecretManagementDecisions).get(),
    ]);

    return IpTradeSecretPortfolioDataSet(
      tradeSecrets: results[0].docs
          .map(IpTradeSecretModel.fromDocument)
          .toList(),
      components: results[1].docs
          .map(IpTradeSecretComponentModel.fromDocument)
          .toList(),
      accessGrants: results[2].docs
          .map(IpTradeSecretAccessGrantModel.fromDocument)
          .toList(),
      disclosures: results[3].docs
          .map(IpTradeSecretDisclosureModel.fromDocument)
          .toList(),
      incidents: results[4].docs
          .map(IpTradeSecretIncidentModel.fromDocument)
          .toList(),
      protectionControls: results[5].docs
          .map(IpTradeSecretProtectionControlModel.fromDocument)
          .toList(),
      riskAssessments: results[6].docs
          .map(IpTradeSecretRiskAssessmentModel.fromDocument)
          .toList(),
      resilienceProfiles: results[7].docs
          .map(IpTradeSecretResilienceProfileModel.fromDocument)
          .toList(),
      defensibilityRecords: results[8].docs
          .map(IpTradeSecretDefensibilityRecordModel.fromDocument)
          .toList(),
      lifecycleTransitions: results[9].docs
          .map(IpTradeSecretLifecycleTransitionModel.fromDocument)
          .toList(),
      remediationActions: results[10].docs
          .map(IpTradeSecretRemediationActionModel.fromDocument)
          .toList(),
      alertRules: results[11].docs
          .map(IpTradeSecretAlertRuleModel.fromDocument)
          .toList(),
      managementDecisions: results[12].docs
          .map(IpTradeSecretManagementDecisionModel.fromDocument)
          .toList(),
    );
  }
}

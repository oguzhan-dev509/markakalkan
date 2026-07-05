import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants/ip_collections.dart';

class IpFirestoreRefs {
  IpFirestoreRefs({
    required FirebaseFirestore firestore,
    required String tenantId,
  }) : _firestore = firestore,
       tenantId = _validateRequiredId(tenantId, fieldName: 'tenantId');

  factory IpFirestoreRefs.instance({required String tenantId}) {
    return IpFirestoreRefs(
      firestore: FirebaseFirestore.instance,
      tenantId: tenantId,
    );
  }

  final FirebaseFirestore _firestore;
  final String tenantId;

  FirebaseFirestore get firestore => _firestore;

  CollectionReference<Map<String, dynamic>> get assets {
    return _firestore.collection(IpCollections.assets);
  }

  CollectionReference<Map<String, dynamic>> get rights {
    return _firestore.collection(IpCollections.rights);
  }

  CollectionReference<Map<String, dynamic>> get documents {
    return _firestore.collection(IpCollections.documents);
  }

  CollectionReference<Map<String, dynamic>> get tradeSecrets {
    return _firestore.collection(IpCollections.tradeSecrets);
  }

  CollectionReference<Map<String, dynamic>> get tradeSecretComponents {
    return _firestore.collection(IpCollections.tradeSecretComponents);
  }

  CollectionReference<Map<String, dynamic>> get tradeSecretAccessGrants {
    return _firestore.collection(IpCollections.tradeSecretAccessGrants);
  }

  CollectionReference<Map<String, dynamic>> get tradeSecretDisclosures {
    return _firestore.collection(IpCollections.tradeSecretDisclosures);
  }

  CollectionReference<Map<String, dynamic>> get tradeSecretIncidents {
    return _firestore.collection(IpCollections.tradeSecretIncidents);
  }

  CollectionReference<Map<String, dynamic>> get tradeSecretProtectionControls {
    return _firestore.collection(IpCollections.tradeSecretProtectionControls);
  }

  CollectionReference<Map<String, dynamic>> get tradeSecretRiskAssessments {
    return _firestore.collection(IpCollections.tradeSecretRiskAssessments);
  }

  CollectionReference<Map<String, dynamic>> get tradeSecretResilienceProfiles {
    return _firestore.collection(IpCollections.tradeSecretResilienceProfiles);
  }

  CollectionReference<Map<String, dynamic>>
  get tradeSecretDefensibilityRecords {
    return _firestore.collection(IpCollections.tradeSecretDefensibilityRecords);
  }

  CollectionReference<Map<String, dynamic>>
  get tradeSecretLifecycleTransitions {
    return _firestore.collection(IpCollections.tradeSecretLifecycleTransitions);
  }

  CollectionReference<Map<String, dynamic>> get tradeSecretRemediationActions {
    return _firestore.collection(IpCollections.tradeSecretRemediationActions);
  }

  CollectionReference<Map<String, dynamic>> get tradeSecretAlertRules {
    return _firestore.collection(IpCollections.tradeSecretAlertRules);
  }

  CollectionReference<Map<String, dynamic>> get tradeSecretManagementDecisions {
    return _firestore.collection(IpCollections.tradeSecretManagementDecisions);
  }

  CollectionReference<Map<String, dynamic>> get relationships {
    return _firestore.collection(IpCollections.relationships);
  }

  CollectionReference<Map<String, dynamic>> get ownershipRecords {
    return _firestore.collection(IpCollections.ownershipRecords);
  }

  CollectionReference<Map<String, dynamic>> get registrations {
    return _firestore.collection(IpCollections.registrations);
  }

  CollectionReference<Map<String, dynamic>> get licenses {
    return _firestore.collection(IpCollections.licenses);
  }

  CollectionReference<Map<String, dynamic>> get assignments {
    return _firestore.collection(IpCollections.assignments);
  }

  CollectionReference<Map<String, dynamic>> get deadlines {
    return _firestore.collection(IpCollections.deadlines);
  }

  CollectionReference<Map<String, dynamic>> get evidenceRecords {
    return _firestore.collection(IpCollections.evidenceRecords);
  }

  CollectionReference<Map<String, dynamic>> get accessEvents {
    return _firestore.collection(IpCollections.accessEvents);
  }

  CollectionReference<Map<String, dynamic>> get enforcementCases {
    return _firestore.collection(IpCollections.enforcementCases);
  }

  CollectionReference<Map<String, dynamic>> get customsProtections {
    return _firestore.collection(IpCollections.customsProtections);
  }

  CollectionReference<Map<String, dynamic>> get watchRules {
    return _firestore.collection(IpCollections.watchRules);
  }

  Query<Map<String, dynamic>> tenantQuery(
    CollectionReference<Map<String, dynamic>> collection,
  ) {
    return collection.where('tenantId', isEqualTo: tenantId);
  }

  DocumentReference<Map<String, dynamic>> assetDocument(String assetId) {
    return assets.doc(_validateRequiredId(assetId, fieldName: 'assetId'));
  }

  DocumentReference<Map<String, dynamic>> rightDocument(String rightId) {
    return rights.doc(_validateRequiredId(rightId, fieldName: 'rightId'));
  }

  DocumentReference<Map<String, dynamic>> documentDocument(String documentId) {
    return documents.doc(
      _validateRequiredId(documentId, fieldName: 'documentId'),
    );
  }

  DocumentReference<Map<String, dynamic>> tradeSecretDocument(
    String tradeSecretId,
  ) {
    return tradeSecrets.doc(
      _validateRequiredId(tradeSecretId, fieldName: 'tradeSecretId'),
    );
  }

  DocumentReference<Map<String, dynamic>> tradeSecretComponentDocument(
    String id,
  ) {
    return tradeSecretComponents.doc(
      _validateRequiredId(id, fieldName: 'componentId'),
    );
  }

  DocumentReference<Map<String, dynamic>> tradeSecretAccessGrantDocument(
    String id,
  ) {
    return tradeSecretAccessGrants.doc(
      _validateRequiredId(id, fieldName: 'accessGrantId'),
    );
  }

  DocumentReference<Map<String, dynamic>> tradeSecretDisclosureDocument(
    String id,
  ) {
    return tradeSecretDisclosures.doc(
      _validateRequiredId(id, fieldName: 'disclosureId'),
    );
  }

  DocumentReference<Map<String, dynamic>> tradeSecretIncidentDocument(
    String id,
  ) {
    return tradeSecretIncidents.doc(
      _validateRequiredId(id, fieldName: 'incidentId'),
    );
  }

  DocumentReference<Map<String, dynamic>> tradeSecretProtectionControlDocument(
    String id,
  ) {
    return tradeSecretProtectionControls.doc(
      _validateRequiredId(id, fieldName: 'protectionControlId'),
    );
  }

  DocumentReference<Map<String, dynamic>> tradeSecretRiskAssessmentDocument(
    String id,
  ) {
    return tradeSecretRiskAssessments.doc(
      _validateRequiredId(id, fieldName: 'riskAssessmentId'),
    );
  }

  DocumentReference<Map<String, dynamic>> tradeSecretResilienceProfileDocument(
    String id,
  ) {
    return tradeSecretResilienceProfiles.doc(
      _validateRequiredId(id, fieldName: 'resilienceProfileId'),
    );
  }

  DocumentReference<Map<String, dynamic>>
  tradeSecretDefensibilityRecordDocument(String id) {
    return tradeSecretDefensibilityRecords.doc(
      _validateRequiredId(id, fieldName: 'defensibilityRecordId'),
    );
  }

  DocumentReference<Map<String, dynamic>>
  tradeSecretLifecycleTransitionDocument(String id) {
    return tradeSecretLifecycleTransitions.doc(
      _validateRequiredId(id, fieldName: 'lifecycleTransitionId'),
    );
  }

  DocumentReference<Map<String, dynamic>> tradeSecretRemediationActionDocument(
    String id,
  ) {
    return tradeSecretRemediationActions.doc(
      _validateRequiredId(id, fieldName: 'remediationActionId'),
    );
  }

  DocumentReference<Map<String, dynamic>> tradeSecretAlertRuleDocument(
    String id,
  ) {
    return tradeSecretAlertRules.doc(
      _validateRequiredId(id, fieldName: 'alertRuleId'),
    );
  }

  DocumentReference<Map<String, dynamic>> tradeSecretManagementDecisionDocument(
    String id,
  ) {
    return tradeSecretManagementDecisions.doc(
      _validateRequiredId(id, fieldName: 'managementDecisionId'),
    );
  }

  DocumentReference<Map<String, dynamic>> relationshipDocument(
    String relationshipId,
  ) {
    return relationships.doc(
      _validateRequiredId(relationshipId, fieldName: 'relationshipId'),
    );
  }

  DocumentReference<Map<String, dynamic>> ownershipRecordDocument(
    String ownershipRecordId,
  ) {
    return ownershipRecords.doc(
      _validateRequiredId(ownershipRecordId, fieldName: 'ownershipRecordId'),
    );
  }

  DocumentReference<Map<String, dynamic>> registrationDocument(
    String registrationId,
  ) {
    return registrations.doc(
      _validateRequiredId(registrationId, fieldName: 'registrationId'),
    );
  }

  DocumentReference<Map<String, dynamic>> licenseDocument(String licenseId) {
    return licenses.doc(_validateRequiredId(licenseId, fieldName: 'licenseId'));
  }

  DocumentReference<Map<String, dynamic>> assignmentDocument(
    String assignmentId,
  ) {
    return assignments.doc(
      _validateRequiredId(assignmentId, fieldName: 'assignmentId'),
    );
  }

  DocumentReference<Map<String, dynamic>> deadlineDocument(String deadlineId) {
    return deadlines.doc(
      _validateRequiredId(deadlineId, fieldName: 'deadlineId'),
    );
  }

  DocumentReference<Map<String, dynamic>> evidenceRecordDocument(
    String evidenceRecordId,
  ) {
    return evidenceRecords.doc(
      _validateRequiredId(evidenceRecordId, fieldName: 'evidenceRecordId'),
    );
  }

  DocumentReference<Map<String, dynamic>> accessEventDocument(
    String accessEventId,
  ) {
    return accessEvents.doc(
      _validateRequiredId(accessEventId, fieldName: 'accessEventId'),
    );
  }

  DocumentReference<Map<String, dynamic>> enforcementCaseDocument(
    String caseId,
  ) {
    return enforcementCases.doc(
      _validateRequiredId(caseId, fieldName: 'caseId'),
    );
  }

  DocumentReference<Map<String, dynamic>> customsProtectionDocument(
    String customsProtectionId,
  ) {
    return customsProtections.doc(
      _validateRequiredId(
        customsProtectionId,
        fieldName: 'customsProtectionId',
      ),
    );
  }

  DocumentReference<Map<String, dynamic>> watchRuleDocument(
    String watchRuleId,
  ) {
    return watchRules.doc(
      _validateRequiredId(watchRuleId, fieldName: 'watchRuleId'),
    );
  }

  static String _validateRequiredId(String value, {required String fieldName}) {
    final cleaned = value.trim();

    if (cleaned.isEmpty) {
      throw ArgumentError.value(value, fieldName, '$fieldName boş olamaz.');
    }

    if (cleaned.contains('/')) {
      throw ArgumentError.value(
        value,
        fieldName,
        '$fieldName "/" karakteri içeremez.',
      );
    }

    return cleaned;
  }
}

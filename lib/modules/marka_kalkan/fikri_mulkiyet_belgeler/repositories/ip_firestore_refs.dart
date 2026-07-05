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

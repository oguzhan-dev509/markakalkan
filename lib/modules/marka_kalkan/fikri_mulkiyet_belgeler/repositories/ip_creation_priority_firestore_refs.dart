import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants/ip_creation_priority_collections.dart';

class IpCreationPriorityFirestoreRefs {
  IpCreationPriorityFirestoreRefs({
    required FirebaseFirestore firestore,
    required String tenantId,
  }) : _firestore = firestore,
       tenantId = _validateRequiredId(tenantId, fieldName: 'tenantId');

  factory IpCreationPriorityFirestoreRefs.instance({required String tenantId}) {
    return IpCreationPriorityFirestoreRefs(
      firestore: FirebaseFirestore.instance,
      tenantId: tenantId,
    );
  }

  final FirebaseFirestore _firestore;
  final String tenantId;

  FirebaseFirestore get firestore => _firestore;

  CollectionReference<Map<String, dynamic>> get records {
    return _firestore.collection(IpCreationPriorityCollections.records);
  }

  CollectionReference<Map<String, dynamic>> get versions {
    return _firestore.collection(IpCreationPriorityCollections.versions);
  }

  Query<Map<String, dynamic>> get tenantRecords {
    return records.where('tenantId', isEqualTo: tenantId);
  }

  Query<Map<String, dynamic>> get tenantVersions {
    return versions.where('tenantId', isEqualTo: tenantId);
  }

  DocumentReference<Map<String, dynamic>> recordDocument(String recordId) {
    return records.doc(_validateRequiredId(recordId, fieldName: 'recordId'));
  }

  DocumentReference<Map<String, dynamic>> versionDocument(String versionId) {
    return versions.doc(_validateRequiredId(versionId, fieldName: 'versionId'));
  }

  Query<Map<String, dynamic>> versionsForRecord(String recordId) {
    return tenantVersions.where(
      'recordId',
      isEqualTo: _validateRequiredId(recordId, fieldName: 'recordId'),
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

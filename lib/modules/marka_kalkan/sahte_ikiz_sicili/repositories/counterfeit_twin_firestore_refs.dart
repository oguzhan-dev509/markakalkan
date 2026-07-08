import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants/counterfeit_twin_collections.dart';

class CounterfeitTwinFirestoreRefs {
  CounterfeitTwinFirestoreRefs({
    required FirebaseFirestore firestore,
    required String tenantId,
  }) : _firestore = firestore,
       tenantId = _validateRequiredId(tenantId, fieldName: 'tenantId');

  factory CounterfeitTwinFirestoreRefs.instance({required String tenantId}) {
    return CounterfeitTwinFirestoreRefs(
      firestore: FirebaseFirestore.instance,
      tenantId: tenantId,
    );
  }

  final FirebaseFirestore _firestore;
  final String tenantId;

  CollectionReference<Map<String, dynamic>> get records {
    return _firestore.collection(CounterfeitTwinCollections.records);
  }

  Query<Map<String, dynamic>> get tenantRecords {
    return records.where('tenantId', isEqualTo: tenantId);
  }

  DocumentReference<Map<String, dynamic>> recordDocument(String recordId) {
    return records.doc(_validateRequiredId(recordId, fieldName: 'recordId'));
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

import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants/supply_security_collections.dart';

class SupplySecurityFirestoreRefs {
  SupplySecurityFirestoreRefs({
    required FirebaseFirestore firestore,
    required String tenantId,
  }) : _firestore = firestore,
       tenantId = _validateRequiredId(tenantId, fieldName: 'tenantId');

  factory SupplySecurityFirestoreRefs.instance({required String tenantId}) {
    return SupplySecurityFirestoreRefs(
      firestore: FirebaseFirestore.instance,
      tenantId: tenantId,
    );
  }

  final FirebaseFirestore _firestore;
  final String tenantId;

  FirebaseFirestore get firestore => _firestore;

  CollectionReference<Map<String, dynamic>> get partners {
    return _firestore.collection(SupplySecurityCollections.partners);
  }

  CollectionReference<Map<String, dynamic>> get facilities {
    return _firestore.collection(SupplySecurityCollections.facilities);
  }

  Query<Map<String, dynamic>> tenantQuery(
    CollectionReference<Map<String, dynamic>> collection,
  ) {
    return collection.where('tenantId', isEqualTo: tenantId);
  }

  DocumentReference<Map<String, dynamic>> partnerDocument(String partnerId) {
    return partners.doc(_validateRequiredId(partnerId, fieldName: 'partnerId'));
  }

  DocumentReference<Map<String, dynamic>> facilityDocument(String facilityId) {
    return facilities.doc(
      _validateRequiredId(facilityId, fieldName: 'facilityId'),
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

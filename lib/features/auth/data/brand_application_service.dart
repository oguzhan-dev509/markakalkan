import 'package:cloud_firestore/cloud_firestore.dart';

class BrandApplicationService {
  BrandApplicationService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<void> submitApplication({
    required String companyName,
    required String brandName,
    required String businessType,
    required String sector,
    required String authorizedPerson,
    required String email,
    required String phone,
    required String taxNumber,
    required String website,
    required String problemDescription,
  }) async {
    await _firestore.collection('brandApplications').add({
      'companyName': companyName.trim(),
      'brandName': brandName.trim(),
      'businessType': businessType.trim(),
      'sector': sector.trim(),
      'authorizedPerson': authorizedPerson.trim(),
      'email': email.trim().toLowerCase(),
      'phone': phone.trim(),
      'taxNumber': taxNumber.trim(),
      'website': website.trim(),
      'problemDescription': problemDescription.trim(),
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}

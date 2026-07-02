import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BrandApplicationService {
  BrandApplicationService({
    FirebaseFirestore? firestore,
    FirebaseAuth? firebaseAuth,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _firebaseAuth;

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
    final user = _firebaseAuth.currentUser;
    final accountEmail = user?.email?.trim().toLowerCase();

    if (user == null || accountEmail == null || accountEmail.isEmpty) {
      throw StateError(
        'Marka başvurusu için önce hesabınızla giriş yapmalısınız.',
      );
    }

    if (email.trim().toLowerCase() != accountEmail) {
      throw StateError(
        'Başvuru e-postası, oturum açılan hesapla aynı olmalıdır.',
      );
    }

    await _firestore.collection('brandApplications').add({
      'applicantUid': user.uid,
      'applicantEmail': accountEmail,
      'companyName': companyName.trim(),
      'brandName': brandName.trim(),
      'businessType': businessType.trim(),
      'sector': sector.trim(),
      'authorizedPerson': authorizedPerson.trim(),
      'email': accountEmail,
      'phone': phone.trim(),
      'taxNumber': taxNumber.trim(),
      'website': website.trim(),
      'problemDescription': problemDescription.trim(),
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}

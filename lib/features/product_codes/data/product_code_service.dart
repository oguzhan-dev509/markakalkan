import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProductCodeService {
  ProductCodeService({
    FirebaseFirestore? firestore,
    FirebaseAuth? firebaseAuth,
    Random? secureRandom,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
       _secureRandom = secureRandom ?? Random.secure();

  static const String _alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  final FirebaseFirestore _firestore;
  final FirebaseAuth _firebaseAuth;
  final Random _secureRandom;

  User get _currentUser {
    final user = _firebaseAuth.currentUser;

    if (user == null) {
      throw StateError(
        'Tekil kod işlemi için marka hesabıyla giriş yapılmalıdır.',
      );
    }

    return user;
  }

  CollectionReference<Map<String, dynamic>> get _codesCollection {
    return _firestore.collection('productCodes');
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchOwnCodes() {
    final user = _currentUser;

    return _codesCollection.where('ownerUid', isEqualTo: user.uid).snapshots();
  }

  Future<String> createCode({
    required String brandName,
    required String productId,
    required String productName,
    required String batchId,
    required String batchNumber,
  }) async {
    final user = _currentUser;

    for (var attempt = 0; attempt < 5; attempt++) {
      final publicCode = _generatePublicCode();
      final document = _codesCollection.doc(publicCode);
      final existing = await document.get();

      if (existing.exists) {
        continue;
      }

      await document.set({
        'publicCode': publicCode,
        'ownerUid': user.uid,
        'brandName': brandName.trim(),
        'productId': productId,
        'productName': productName.trim(),
        'batchId': batchId,
        'batchNumber': batchNumber.trim(),
        'status': 'active',
        'scanCount': 0,
        'firstVerifiedAt': null,
        'lastVerifiedAt': null,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return publicCode;
    }

    throw StateError(
      'Benzersiz ürün kodu oluşturulamadı. Lütfen yeniden deneyin.',
    );
  }

  String _generatePublicCode() {
    String createGroup() {
      return List.generate(
        4,
        (_) => _alphabet[_secureRandom.nextInt(_alphabet.length)],
      ).join();
    }

    return 'MK-${createGroup()}-${createGroup()}-${createGroup()}';
  }
}

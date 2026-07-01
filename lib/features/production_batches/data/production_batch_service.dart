import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProductionBatchService {
  ProductionBatchService({
    FirebaseFirestore? firestore,
    FirebaseAuth? firebaseAuth,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _firebaseAuth;

  User get _currentUser {
    final user = _firebaseAuth.currentUser;

    if (user == null) {
      throw StateError(
        'Üretim partisi işlemi için marka hesabıyla giriş yapılmalıdır.',
      );
    }

    return user;
  }

  CollectionReference<Map<String, dynamic>> get _batchesCollection {
    final user = _currentUser;

    return _firestore
        .collection('brands')
        .doc(user.uid)
        .collection('productionBatches');
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchBatches() {
    return _batchesCollection
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<String> createBatch({
    required String productId,
    required String productName,
    required String batchNumber,
    required String productionType,
    required int authorizedQuantity,
    required int defectQuantity,
    required int shippedQuantity,
    required DateTime productionDate,
    required String notes,
    required String status,
  }) async {
    final user = _currentUser;
    final document = _batchesCollection.doc();

    await document.set({
      'productId': productId,
      'productName': productName.trim(),
      'batchNumber': batchNumber.trim(),
      'productionType': productionType,
      'authorizedQuantity': authorizedQuantity,
      'defectQuantity': defectQuantity,
      'shippedQuantity': shippedQuantity,
      'productionDate': Timestamp.fromDate(productionDate),
      'notes': notes.trim(),
      'status': status,
      'ownerUid': user.uid,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return document.id;
  }
}

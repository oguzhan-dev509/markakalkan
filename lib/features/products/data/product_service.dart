import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProductService {
  ProductService({FirebaseFirestore? firestore, FirebaseAuth? firebaseAuth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _firebaseAuth;

  User get _currentUser {
    final user = _firebaseAuth.currentUser;

    if (user == null) {
      throw StateError('Ürün işlemi için marka hesabıyla giriş yapılmalıdır.');
    }

    return user;
  }

  CollectionReference<Map<String, dynamic>> get _productsCollection {
    final user = _currentUser;

    return _firestore.collection('brands').doc(user.uid).collection('products');
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchProducts() {
    return _productsCollection
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<String> createProduct({
    required String name,
    required String brandName,
    required String sku,
    required String category,
    required String description,
    required bool isActive,
  }) async {
    final user = _currentUser;
    final document = _productsCollection.doc();

    await document.set({
      'name': name.trim(),
      'brandName': brandName.trim(),
      'sku': sku.trim(),
      'category': category.trim(),
      'description': description.trim(),
      'isActive': isActive,
      'ownerUid': user.uid,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return document.id;
  }
}

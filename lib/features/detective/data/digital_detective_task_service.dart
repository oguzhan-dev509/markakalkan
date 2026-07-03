import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DigitalDetectiveTaskService {
  DigitalDetectiveTaskService({
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
        'Dijital Dedektif görevi oluşturmak için marka hesabıyla giriş yapılmalıdır.',
      );
    }

    return user;
  }

  CollectionReference<Map<String, dynamic>> get _tasksCollection {
    final user = _currentUser;

    return _firestore
        .collection('brands')
        .doc(user.uid)
        .collection('digitalDetectiveTasks');
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchTasks() {
    return _tasksCollection.orderBy('createdAt', descending: true).snapshots();
  }

  Future<void> deleteQueuedTask(String taskId) async {
    final user = _currentUser;
    final document = _tasksCollection.doc(taskId);
    final snapshot = await document.get();

    if (!snapshot.exists) {
      throw StateError('Görev bulunamadı.');
    }

    final data = snapshot.data();
    final ownerUid = data?['ownerUid'];
    final status = data?['status'];

    if (ownerUid != user.uid) {
      throw StateError('Bu görevi silme yetkiniz bulunmuyor.');
    }

    if (status != 'queued') {
      throw StateError('Yalnızca henüz başlamamış görevler silinebilir.');
    }

    await document.delete();
  }

  Future<String> createTask({
    required String taskName,
    required String brandName,
    required String productName,
    required String categoryId,
    required String? subcategory,
    required List<String> violationIds,
    required List<String> sources,
    required List<String> searchTerms,
    required List<String> excludedTerms,
    required List<String> countries,
    required List<String> cities,
    required double? minimumPrice,
    required double? maximumPrice,
    required String currency,
    required String frequency,
    required String riskLevel,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final user = _currentUser;
    final document = _tasksCollection.doc();

    await document.set({
      'taskName': taskName.trim(),
      'brandName': brandName.trim(),
      'productName': productName.trim(),
      'categoryId': categoryId,
      'subcategory': subcategory?.trim(),
      'violationIds': violationIds,
      'sources': sources,
      'searchTerms': searchTerms,
      'excludedTerms': excludedTerms,
      'countries': countries,
      'cities': cities,
      'minimumPrice': minimumPrice,
      'maximumPrice': maximumPrice,
      'currency': currency,
      'frequency': frequency,
      'riskLevel': riskLevel,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'status': 'queued',
      'ownerUid': user.uid,
      'ownerEmail': user.email?.trim().toLowerCase(),
      'resultCount': 0,
      'processedCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return document.id;
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';

class DigitalDetectiveTaskService {
  DigitalDetectiveTaskService({
    FirebaseFirestore? firestore,
    FirebaseAuth? firebaseAuth,
    FirebaseFunctions? functions,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
       _functions =
           functions ?? FirebaseFunctions.instanceFor(region: 'europe-west3');

  final FirebaseFirestore _firestore;
  final FirebaseAuth _firebaseAuth;
  final FirebaseFunctions _functions;

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
    final submissionId =
        '${DateTime.now().toUtc().microsecondsSinceEpoch}-'
        '${user.uid.hashCode}-${identityHashCode(Object())}';

    final result = await _functions
        .httpsCallable('createDigitalDetectiveTask')
        .call<dynamic>(<String, dynamic>{
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
          'startDate': startDate.toUtc().toIso8601String(),
          'endDate': endDate.toUtc().toIso8601String(),
          'submissionId': submissionId,
        });

    final data = result.data;
    if (data is! Map) {
      throw StateError('Dijital Dedektif görevi yanıtı geçersiz.');
    }

    final taskId = data['taskId']?.toString().trim() ?? '';
    if (taskId.isEmpty) {
      throw StateError('Dijital Dedektif görev numarası alınamadı.');
    }

    return taskId;
  }
}

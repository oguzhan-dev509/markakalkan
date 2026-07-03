import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:markakalkan/features/detective/data/ai_field_operation_models.dart';

class AiFieldOperationService {
  AiFieldOperationService({
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
        'Yapay Zekâ Saha Dedektifi işlemi için oturum açılmalıdır.',
      );
    }

    return user;
  }

  CollectionReference<Map<String, dynamic>> get _operationsCollection {
    final user = _currentUser;

    return _firestore
        .collection('brands')
        .doc(user.uid)
        .collection('aiFieldOperations');
  }

  Stream<List<AiFieldOperation>> watchOperations() {
    return _operationsCollection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(AiFieldOperation.fromDocument)
              .toList(growable: false),
        );
  }

  Stream<AiFieldOperation?> watchOperation(String operationId) {
    return _operationsCollection.doc(operationId).snapshots().map((document) {
      if (!document.exists) {
        return null;
      }

      return AiFieldOperation.fromDocument(document);
    });
  }

  Stream<List<AiFieldAgentTask>> watchAgentTasks(String operationId) {
    return _operationsCollection
        .doc(operationId)
        .collection('agentTasks')
        .orderBy('agentOrder')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(AiFieldAgentTask.fromDocument)
              .toList(growable: false),
        );
  }

  Future<String> createOperation({
    required String title,
    required String objective,
    AiFieldOperationPriority priority = AiFieldOperationPriority.normal,
    Map<String, dynamic> initialInput = const <String, dynamic>{},
  }) async {
    final normalizedTitle = title.trim();
    final normalizedObjective = objective.trim();

    if (normalizedTitle.isEmpty) {
      throw ArgumentError('Operasyon başlığı boş bırakılamaz.');
    }

    if (normalizedObjective.isEmpty) {
      throw ArgumentError('Operasyon amacı boş bırakılamaz.');
    }

    final operationDocument = _operationsCollection.doc();
    final batch = _firestore.batch();
    final agents = AiFieldAgentCatalog.agents;

    batch.set(operationDocument, {
      'title': normalizedTitle,
      'objective': normalizedObjective,
      'status': AiFieldOperationStatus.queued.value,
      'priority': priority.value,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'currentAgentId': agents.first.id,
      'requiresHumanApproval': true,
    });

    for (var index = 0; index < agents.length; index++) {
      final agent = agents[index];
      final isFirstAgent = index == 0;
      final nextAgentId = index + 1 < agents.length ? agents[index + 1].id : '';

      final taskDocument = operationDocument
          .collection('agentTasks')
          .doc(agent.id);

      batch.set(taskDocument, {
        'agentId': agent.id,
        'agentName': agent.name,
        'agentOrder': agent.order,
        'status': isFirstAgent
            ? AiFieldAgentTaskStatus.queued.value
            : AiFieldAgentTaskStatus.pending.value,
        'input': isFirstAgent
            ? <String, dynamic>{
                'operationTitle': normalizedTitle,
                'operationObjective': normalizedObjective,
                ...initialInput,
              }
            : <String, dynamic>{},
        'output': <String, dynamic>{},
        'startedAt': null,
        'completedAt': null,
        'errorMessage': '',
        'handoffToAgentId': nextAgentId,
      });
    }

    await batch.commit();

    return operationDocument.id;
  }

  Future<void> updateOperationStatus({
    required String operationId,
    required AiFieldOperationStatus status,
    String? currentAgentId,
  }) async {
    final updates = <String, dynamic>{
      'status': status.value,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (currentAgentId != null) {
      updates['currentAgentId'] = currentAgentId.trim();
    }

    await _operationsCollection.doc(operationId).update(updates);
  }

  Future<void> updateAgentTaskStatus({
    required String operationId,
    required String agentId,
    required AiFieldAgentTaskStatus status,
    Map<String, dynamic>? output,
    String? errorMessage,
    String? handoffToAgentId,
  }) async {
    final updates = <String, dynamic>{'status': status.value};

    if (status == AiFieldAgentTaskStatus.running) {
      updates['startedAt'] = FieldValue.serverTimestamp();
      updates['completedAt'] = null;
      updates['errorMessage'] = '';
    }

    if (status == AiFieldAgentTaskStatus.completed ||
        status == AiFieldAgentTaskStatus.failed ||
        status == AiFieldAgentTaskStatus.skipped) {
      updates['completedAt'] = FieldValue.serverTimestamp();
    }

    if (output != null) {
      updates['output'] = output;
    }

    if (errorMessage != null) {
      updates['errorMessage'] = errorMessage.trim();
    }

    if (handoffToAgentId != null) {
      updates['handoffToAgentId'] = handoffToAgentId.trim();
    }

    final operationDocument = _operationsCollection.doc(operationId);

    final batch = _firestore.batch();

    batch.update(
      operationDocument.collection('agentTasks').doc(agentId),
      updates,
    );

    batch.update(operationDocument, {
      'currentAgentId': agentId,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }
}

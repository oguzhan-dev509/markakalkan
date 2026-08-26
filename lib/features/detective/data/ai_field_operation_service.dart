import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:markakalkan/core/security/app_check_bootstrap.dart';
import 'package:markakalkan/features/detective/data/ai_field_operation_models.dart';

typedef AiFieldOperationCallable =
    Future<Object?> Function(String callableName, Map<String, Object?> payload);

final class AiFieldOperationFailure implements Exception {
  const AiFieldOperationFailure(
    this.code,
    this.message, {
    this.retryable = false,
  });

  final String code;
  final String message;
  final bool retryable;

  @override
  String toString() => 'AiFieldOperationFailure($code)';
}

final class AiFieldOperationReadiness {
  const AiFieldOperationReadiness({
    required this.verifiedBrand,
    required this.serviceAccess,
    required this.operationAuthority,
    required this.ready,
    required this.brandName,
    required this.companyName,
    required this.reasons,
  });

  final bool verifiedBrand;
  final bool serviceAccess;
  final bool operationAuthority;
  final bool ready;
  final String brandName;
  final String companyName;
  final List<String> reasons;

  factory AiFieldOperationReadiness.fromValue(Object? value) {
    final root = _map(value);
    if (root['contractVersion'] != AiFieldOperationService.contractVersion) {
      throw const FormatException('Yetki yanıtı sözleşme sürümü geçersiz.');
    }
    final gates = _map(root['gates']);
    final brand = root['brand'] == null
        ? const <String, dynamic>{}
        : _map(root['brand']);
    final reasons = root['gates'] is Map ? gates['reasons'] : null;
    return AiFieldOperationReadiness(
      verifiedBrand: gates['verifiedBrand'] == true,
      serviceAccess: gates['serviceAccess'] == true,
      operationAuthority: gates['operationAuthority'] == true,
      ready: gates['ready'] == true,
      brandName: brand['brandName']?.toString().trim() ?? '',
      companyName: brand['companyName']?.toString().trim() ?? '',
      reasons: reasons is List
          ? reasons.map((item) => item.toString()).toList(growable: false)
          : const <String>[],
    );
  }
}

class AiFieldOperationService {
  AiFieldOperationService({
    FirebaseFirestore? firestore,
    FirebaseAuth? firebaseAuth,
    FirebaseFunctions? functions,
    Future<void> Function()? ensureAppCheckReady,
    AiFieldOperationCallable? callable,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
       _functions = callable == null
           ? functions ?? FirebaseFunctions.instanceFor(region: 'europe-west3')
           : null,
       _ensureAppCheckReady =
           ensureAppCheckReady ?? AppCheckBootstrap.instance.ensureReady,
       _callable = callable;

  static const String contractVersion = 'ai-field-operation-authority-v1';
  static const String readinessCallableName = 'getAiFieldOperationReadiness';
  static const String createCallableName = 'createAiFieldOperation';

  final FirebaseFirestore _firestore;
  final FirebaseAuth _firebaseAuth;
  final FirebaseFunctions? _functions;
  final Future<void> Function() _ensureAppCheckReady;
  final AiFieldOperationCallable? _callable;

  User get _currentUser {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw const AiFieldOperationFailure(
        'unauthenticated',
        'Yapay Zekâ Saha Dedektifi işlemi için oturum açılmalıdır.',
      );
    }
    return user;
  }

  CollectionReference<Map<String, dynamic>> get _operationsCollection {
    return _firestore
        .collection('brands')
        .doc(_currentUser.uid)
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

  Future<AiFieldOperationReadiness> getReadiness() async {
    final value = await _invoke(
      readinessCallableName,
      const <String, Object?>{},
    );
    return AiFieldOperationReadiness.fromValue(value);
  }

  Future<String> createOperation({
    required String title,
    required String objective,
    AiFieldOperationPriority priority = AiFieldOperationPriority.normal,
    Map<String, dynamic> initialInput = const <String, dynamic>{},
  }) async {
    final requestId = _uuidV4();
    final value = await _invoke(createCallableName, <String, Object?>{
      'contractVersion': contractVersion,
      'requestId': requestId,
      'idempotencyKey': 'ai-field-operation:$requestId',
      'title': title.trim(),
      'objective': objective.trim(),
      'priority': priority.value,
      'initialInput': Map<String, Object?>.from(initialInput),
    });
    final result = _map(value);
    if (result['contractVersion'] != contractVersion ||
        result['resultType'] != 'ai_field_operation') {
      throw const AiFieldOperationFailure(
        'invalid-response',
        'Operasyon hizmetinden geçersiz yanıt alındı.',
      );
    }
    final operationId = result['operationId']?.toString().trim() ?? '';
    if (operationId.isEmpty) {
      throw const AiFieldOperationFailure(
        'invalid-response',
        'Operasyon numarası alınamadı.',
      );
    }
    return operationId;
  }

  Future<Object?> _invoke(
    String callableName,
    Map<String, Object?> payload,
  ) async {
    try {
      if (_currentUser.uid.isEmpty) {
        throw const AiFieldOperationFailure(
          'unauthenticated',
          'Operasyon için oturum açmanız gerekir.',
        );
      }
      await _ensureAppCheckReady();
      final injected = _callable;
      if (injected != null) {
        return await injected(callableName, payload);
      }
      return (await _functions!
              .httpsCallable(callableName)
              .call<Object?>(payload))
          .data;
    } on AiFieldOperationFailure {
      rethrow;
    } on FirebaseFunctionsException catch (error) {
      throw AiFieldOperationFailure(
        error.code,
        _message(error),
        retryable: const {
          'aborted',
          'deadline-exceeded',
          'resource-exhausted',
          'unavailable',
        }.contains(error.code),
      );
    } on AppCheckUnavailableException {
      throw const AiFieldOperationFailure(
        'app-check-unavailable',
        'Güvenlik doğrulaması hazırlanamadı. Sayfayı yenileyip tekrar deneyin.',
        retryable: true,
      );
    } on FormatException catch (error) {
      throw AiFieldOperationFailure('invalid-response', error.message);
    }
  }

  static String _message(FirebaseFunctionsException error) {
    final safe = error.message?.trim();
    if (safe != null && safe.isNotEmpty && error.code != 'internal') {
      return safe;
    }
    return switch (error.code) {
      'unauthenticated' => 'Operasyon için oturum açmanız gerekir.',
      'failed-precondition' => 'Uygulama güvenlik doğrulaması tamamlanamadı.',
      'permission-denied' =>
        'Marka, hizmet veya operasyon yetkisi henüz hazır değil.',
      'invalid-argument' => 'Operasyon bilgilerini kontrol edin.',
      'already-exists' =>
        'Bu istek kimliği daha önce farklı içerikle kullanılmış.',
      'unavailable' => 'Operasyon hizmeti geçici olarak kullanılamıyor.',
      _ => 'Operasyon güvenli biçimde oluşturulamadı.',
    };
  }
}

String _uuidV4() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final value = bytes
      .map((part) => part.toRadixString(16).padLeft(2, '0'))
      .join();
  return '${value.substring(0, 8)}-${value.substring(8, 12)}-'
      '${value.substring(12, 16)}-${value.substring(16, 20)}-'
      '${value.substring(20)}';
}

Map<String, dynamic> _map(Object? value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  throw const FormatException('Nesne bekleniyordu.');
}

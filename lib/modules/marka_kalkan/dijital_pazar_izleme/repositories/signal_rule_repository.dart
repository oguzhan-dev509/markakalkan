import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants/monitoring_enums.dart';
import '../models/signal_rule_model.dart';
import 'monitoring_repository_ports.dart';
import 'monitoring_firestore_refs.dart';

class SignalRuleRepository implements SignalRuleRepositoryPort {
  const SignalRuleRepository({required MonitoringFirestoreRefs refs})
    : _refs = refs;

  factory SignalRuleRepository.instance({required String tenantId}) {
    return SignalRuleRepository(
      refs: MonitoringFirestoreRefs.instance(tenantId: tenantId),
    );
  }

  final MonitoringFirestoreRefs _refs;

  Future<String> create(SignalRuleModel rule) async {
    _validateTenant(rule.tenantId);

    if (rule.id.trim().isNotEmpty) {
      final document = _refs.signalRuleDocument(rule.id);

      await document.set(rule.toCreateMap());

      return document.id;
    }

    final document = _refs.signalRules.doc();

    await document.set(rule.toCreateMap());

    return document.id;
  }

  Future<void> update(SignalRuleModel rule) async {
    _validateTenant(rule.tenantId);

    final ruleId = _validateRequiredId(rule.id, fieldName: 'ruleId');

    final document = _refs.signalRuleDocument(ruleId);

    final snapshot = await document.get();

    if (!snapshot.exists || snapshot.data() == null) {
      throw StateError('Güncellenecek sinyal kuralı bulunamadı: $ruleId');
    }

    final existingRule = SignalRuleModel.fromDocument(snapshot);

    _validateTenant(existingRule.tenantId);

    await document.update(rule.toUpdateMap());
  }

  Future<SignalRuleModel?> getById(String ruleId) async {
    final document = await _refs.signalRuleDocument(ruleId).get();

    if (!document.exists || document.data() == null) {
      return null;
    }

    final rule = SignalRuleModel.fromDocument(document);

    _validateTenant(rule.tenantId);

    return rule;
  }

  Future<List<SignalRuleModel>> listAll({int limit = 200}) async {
    final safeLimit = _validateLimit(limit);

    final query = await _refs
        .tenantQuery(_refs.signalRules)
        .orderBy('priority', descending: false)
        .limit(safeLimit)
        .get();

    return query.docs.map(SignalRuleModel.fromDocument).toList(growable: false);
  }

  @override
  Future<List<SignalRuleModel>> listActive({
    String? brandId,
    String? sourceId,
    int limit = 200,
  }) async {
    final safeLimit = _validateLimit(limit);

    final cleanedBrandId = _cleanNullableId(brandId, fieldName: 'brandId');

    final cleanedSourceId = _cleanNullableId(sourceId, fieldName: 'sourceId');

    final snapshot = await _refs
        .tenantQuery(_refs.signalRules)
        .where('status', isEqualTo: MonitoringSignalRuleStatus.active.value)
        .limit(safeLimit)
        .get();

    final rules =
        snapshot.docs
            .map(SignalRuleModel.fromDocument)
            .where(
              (rule) =>
                  (cleanedBrandId == null ||
                      rule.brandId == null ||
                      rule.brandId == cleanedBrandId) &&
                  (cleanedSourceId == null ||
                      rule.appliesToSource(cleanedSourceId)),
            )
            .toList(growable: false)
          ..sort(
            (first, second) => _priorityRank(
              first.priority,
            ).compareTo(_priorityRank(second.priority)),
          );

    return List<SignalRuleModel>.unmodifiable(rules);
  }

  Future<List<SignalRuleModel>> listByStatus({
    required MonitoringSignalRuleStatus status,
    int limit = 200,
  }) async {
    final safeLimit = _validateLimit(limit);

    final query = await _refs
        .tenantQuery(_refs.signalRules)
        .where('status', isEqualTo: status.value)
        .orderBy('priority', descending: false)
        .limit(safeLimit)
        .get();

    return query.docs.map(SignalRuleModel.fromDocument).toList(growable: false);
  }

  Stream<List<SignalRuleModel>> watchActive({int limit = 200}) {
    final safeLimit = _validateLimit(limit);

    return _refs
        .tenantQuery(_refs.signalRules)
        .where('status', isEqualTo: MonitoringSignalRuleStatus.active.value)
        .orderBy('priority', descending: false)
        .limit(safeLimit)
        .snapshots()
        .map(
          (query) => query.docs
              .map(SignalRuleModel.fromDocument)
              .toList(growable: false),
        );
  }

  Future<void> updateStatus({
    required String ruleId,
    required MonitoringSignalRuleStatus status,
    required String updatedBy,
  }) async {
    final document = _refs.signalRuleDocument(ruleId);

    final snapshot = await document.get();

    if (!snapshot.exists || snapshot.data() == null) {
      throw StateError(
        'Durumu güncellenecek sinyal kuralı bulunamadı: $ruleId',
      );
    }

    final rule = SignalRuleModel.fromDocument(snapshot);

    _validateTenant(rule.tenantId);

    final cleanedUpdatedBy = _validateRequiredId(
      updatedBy,
      fieldName: 'updatedBy',
    );

    await document.update(<String, dynamic>{
      'status': status.value,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': cleanedUpdatedBy,
    });
  }

  void _validateTenant(String modelTenantId) {
    if (modelTenantId.trim() != _refs.tenantId) {
      throw StateError(
        'Signal rule tenantId ile repository tenantId eşleşmiyor.',
      );
    }
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

  static String? _cleanNullableId(String? value, {required String fieldName}) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }

    return _validateRequiredId(value, fieldName: fieldName);
  }

  static int _priorityRank(MonitoringPriority priority) {
    switch (priority) {
      case MonitoringPriority.critical:
        return 0;
      case MonitoringPriority.high:
        return 1;
      case MonitoringPriority.normal:
        return 2;
      case MonitoringPriority.low:
        return 3;
    }
  }

  static int _validateLimit(int value) {
    if (value < 1 || value > 500) {
      throw ArgumentError.value(
        value,
        'limit',
        'limit 1 ile 500 arasında olmalıdır.',
      );
    }

    return value;
  }
}

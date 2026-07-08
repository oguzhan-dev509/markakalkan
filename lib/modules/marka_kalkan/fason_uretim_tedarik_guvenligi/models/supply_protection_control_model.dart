import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants/supply_protection_control_enums.dart';

class SupplyProtectionControlModel {
  const SupplyProtectionControlModel({
    required this.id,
    required this.tenantId,
    required this.brandId,
    required this.controlCode,
    required this.title,
    required this.controlType,
    required this.scope,
    required this.status,
    required this.result,
    required this.riskLevel,
    required this.createdAt,
    required this.createdBy,
    this.partnerId,
    this.facilityId,
    this.description,
    this.assignedToId,
    this.assignedToName,
    this.plannedAt,
    this.startedAt,
    this.completedAt,
    this.nextControlAt,
    this.findings,
    this.evidenceDocumentIds = const <String>[],
    this.relatedProductIds = const <String>[],
    this.correctiveAction,
    this.correctiveActionOwnerId,
    this.correctiveActionOwnerName,
    this.correctiveActionDueAt,
    this.correctiveActionCompletedAt,
    this.notes,
    this.archiveReason,
    this.archivedAt,
    this.metadata = const <String, dynamic>{},
    this.updatedAt,
    this.updatedBy,
  });

  final String id;
  final String tenantId;
  final String brandId;
  final String controlCode;
  final String title;

  final SupplyProtectionControlType controlType;
  final SupplyProtectionControlScope scope;
  final SupplyProtectionControlStatus status;
  final SupplyProtectionControlResult result;
  final SupplyProtectionControlRiskLevel riskLevel;

  final String? partnerId;
  final String? facilityId;
  final String? description;

  final String? assignedToId;
  final String? assignedToName;

  final DateTime? plannedAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime? nextControlAt;

  final String? findings;
  final List<String> evidenceDocumentIds;
  final List<String> relatedProductIds;

  final String? correctiveAction;
  final String? correctiveActionOwnerId;
  final String? correctiveActionOwnerName;
  final DateTime? correctiveActionDueAt;
  final DateTime? correctiveActionCompletedAt;

  final String? notes;
  final String? archiveReason;
  final DateTime? archivedAt;
  final Map<String, dynamic> metadata;

  final DateTime createdAt;
  final String createdBy;
  final DateTime? updatedAt;
  final String? updatedBy;

  factory SupplyProtectionControlModel.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();

    if (data == null) {
      throw StateError(
        'Koruma kontrolü belgesi veri içermiyor: ${document.id}',
      );
    }

    return SupplyProtectionControlModel.fromMap(id: document.id, data: data);
  }

  factory SupplyProtectionControlModel.fromMap({
    required String id,
    required Map<String, dynamic> data,
  }) {
    final createdAt = _dateTime(data['createdAt']);

    if (createdAt == null) {
      throw StateError('Koruma kontrolü oluşturma tarihi eksik: $id');
    }

    return SupplyProtectionControlModel(
      id: id.trim(),
      tenantId: _requiredString(data['tenantId']),
      brandId: _requiredString(data['brandId']),
      controlCode: _requiredString(data['controlCode']),
      title: _requiredString(data['title']),
      controlType: SupplyProtectionControlType.fromValue(
        data['controlType']?.toString(),
      ),
      scope: SupplyProtectionControlScope.fromValue(data['scope']?.toString()),
      status: SupplyProtectionControlStatus.fromValue(
        data['status']?.toString(),
      ),
      result: SupplyProtectionControlResult.fromValue(
        data['result']?.toString(),
      ),
      riskLevel: SupplyProtectionControlRiskLevel.fromValue(
        data['riskLevel']?.toString(),
      ),
      partnerId: _nullableString(data['partnerId']),
      facilityId: _nullableString(data['facilityId']),
      description: _nullableString(data['description']),
      assignedToId: _nullableString(data['assignedToId']),
      assignedToName: _nullableString(data['assignedToName']),
      plannedAt: _dateTime(data['plannedAt']),
      startedAt: _dateTime(data['startedAt']),
      completedAt: _dateTime(data['completedAt']),
      nextControlAt: _dateTime(data['nextControlAt']),
      findings: _nullableString(data['findings']),
      evidenceDocumentIds: _stringList(data['evidenceDocumentIds']),
      relatedProductIds: _stringList(data['relatedProductIds']),
      correctiveAction: _nullableString(data['correctiveAction']),
      correctiveActionOwnerId: _nullableString(data['correctiveActionOwnerId']),
      correctiveActionOwnerName: _nullableString(
        data['correctiveActionOwnerName'],
      ),
      correctiveActionDueAt: _dateTime(data['correctiveActionDueAt']),
      correctiveActionCompletedAt: _dateTime(
        data['correctiveActionCompletedAt'],
      ),
      notes: _nullableString(data['notes']),
      archiveReason: _nullableString(data['archiveReason']),
      archivedAt: _dateTime(data['archivedAt']),
      metadata: _map(data['metadata']),
      createdAt: createdAt,
      createdBy: _requiredString(data['createdBy']),
      updatedAt: _dateTime(data['updatedAt']),
      updatedBy: _nullableString(data['updatedBy']),
    );
  }

  String get normalizedControlCode => controlCode.trim().toUpperCase();

  bool get hasPartnerTarget =>
      partnerId != null && partnerId!.trim().isNotEmpty;

  bool get hasFacilityTarget =>
      facilityId != null && facilityId!.trim().isNotEmpty;

  bool get hasValidScopeTarget {
    switch (scope) {
      case SupplyProtectionControlScope.partner:
        return hasPartnerTarget && !hasFacilityTarget;
      case SupplyProtectionControlScope.facility:
        return hasFacilityTarget && !hasPartnerTarget;
      case SupplyProtectionControlScope.partnerAndFacility:
        return hasPartnerTarget && hasFacilityTarget;
    }
  }

  bool get isArchived =>
      status == SupplyProtectionControlStatus.archived || archivedAt != null;

  bool get isCompleted =>
      status == SupplyProtectionControlStatus.completed && completedAt != null;

  bool get isOverdue {
    if (isArchived || isCompleted || plannedAt == null) {
      return false;
    }

    return plannedAt!.isBefore(DateTime.now());
  }

  bool get hasFailure =>
      result == SupplyProtectionControlResult.failed ||
      result == SupplyProtectionControlResult.criticalFailure;

  bool get isHighRisk =>
      riskLevel == SupplyProtectionControlRiskLevel.high ||
      riskLevel == SupplyProtectionControlRiskLevel.critical ||
      result == SupplyProtectionControlResult.criticalFailure;

  bool get correctiveActionRequired => hasFailure;

  bool get hasOpenCorrectiveAction =>
      correctiveActionRequired &&
      correctiveAction != null &&
      correctiveAction!.trim().isNotEmpty &&
      correctiveActionCompletedAt == null;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'tenantId': tenantId.trim(),
      'brandId': brandId.trim(),
      'controlCode': controlCode.trim(),
      'controlCodeNormalized': normalizedControlCode,
      'title': title.trim(),
      'controlType': controlType.value,
      'scope': scope.value,
      'status': status.value,
      'result': result.value,
      'riskLevel': riskLevel.value,
      'partnerId': _cleanNullable(partnerId),
      'facilityId': _cleanNullable(facilityId),
      'description': _cleanNullable(description),
      'assignedToId': _cleanNullable(assignedToId),
      'assignedToName': _cleanNullable(assignedToName),
      'plannedAt': _timestamp(plannedAt),
      'startedAt': _timestamp(startedAt),
      'completedAt': _timestamp(completedAt),
      'nextControlAt': _timestamp(nextControlAt),
      'findings': _cleanNullable(findings),
      'evidenceDocumentIds': _cleanStringList(evidenceDocumentIds),
      'relatedProductIds': _cleanStringList(relatedProductIds),
      'correctiveAction': _cleanNullable(correctiveAction),
      'correctiveActionOwnerId': _cleanNullable(correctiveActionOwnerId),
      'correctiveActionOwnerName': _cleanNullable(correctiveActionOwnerName),
      'correctiveActionDueAt': _timestamp(correctiveActionDueAt),
      'correctiveActionCompletedAt': _timestamp(correctiveActionCompletedAt),
      'notes': _cleanNullable(notes),
      'archiveReason': _cleanNullable(archiveReason),
      'archivedAt': _timestamp(archivedAt),
      'metadata': Map<String, dynamic>.from(metadata),
      'createdAt': Timestamp.fromDate(createdAt),
      'createdBy': createdBy.trim(),
      'updatedAt': _timestamp(updatedAt),
      'updatedBy': _cleanNullable(updatedBy),
    };
  }

  Map<String, dynamic> toCreateMap() {
    final map = toMap();
    map['createdAt'] = FieldValue.serverTimestamp();
    map['updatedAt'] = FieldValue.serverTimestamp();
    return map;
  }

  Map<String, dynamic> toUpdateMap({required String actorId}) {
    final cleanedActorId = actorId.trim();

    if (cleanedActorId.isEmpty) {
      throw ArgumentError.value(actorId, 'actorId', 'actorId boş olamaz.');
    }

    final map = toMap()
      ..remove('tenantId')
      ..remove('brandId')
      ..remove('controlCode')
      ..remove('controlCodeNormalized')
      ..remove('createdAt')
      ..remove('createdBy');

    map['updatedAt'] = FieldValue.serverTimestamp();
    map['updatedBy'] = cleanedActorId;

    return map;
  }

  static String _requiredString(Object? value) {
    final cleaned = value?.toString().trim() ?? '';

    if (cleaned.isEmpty) {
      throw const FormatException('Zorunlu metin alanı boş olamaz.');
    }

    return cleaned;
  }

  static String? _nullableString(Object? value) {
    final cleaned = value?.toString().trim();

    return cleaned == null || cleaned.isEmpty ? null : cleaned;
  }

  static DateTime? _dateTime(Object? value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    return null;
  }

  static Timestamp? _timestamp(DateTime? value) {
    return value == null ? null : Timestamp.fromDate(value);
  }

  static List<String> _stringList(Object? value) {
    if (value is! Iterable) {
      return const <String>[];
    }

    return _cleanStringList(value.map((item) => item?.toString() ?? ''));
  }

  static List<String> _cleanStringList(Iterable<String> values) {
    return values
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList(growable: false);
  }

  static Map<String, dynamic> _map(Object? value) {
    if (value is Map<String, dynamic>) {
      return Map<String, dynamic>.from(value);
    }

    if (value is Map) {
      return value.map((key, item) => MapEntry(key.toString(), item));
    }

    return const <String, dynamic>{};
  }

  static String? _cleanNullable(String? value) {
    final cleaned = value?.trim();

    return cleaned == null || cleaned.isEmpty ? null : cleaned;
  }
}

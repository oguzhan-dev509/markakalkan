import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants/monitoring_enums.dart';
import '../utils/monitoring_model_utils.dart';

class SignalRuleConditionModel {
  const SignalRuleConditionModel({
    required this.field,
    required this.operator,
    this.value,
  });

  final String field;
  final MonitoringSignalRuleOperator operator;
  final dynamic value;

  factory SignalRuleConditionModel.fromMap(Map<String, dynamic> data) {
    return SignalRuleConditionModel(
      field: (data['field'] ?? '').toString().trim(),
      operator: MonitoringSignalRuleOperatorX.fromValue(
        data['operator']?.toString(),
      ),
      value: data['value'],
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'field': field.trim(),
      'operator': operator.value,
      'value': value,
    };
  }
}

class SignalRuleModel {
  const SignalRuleModel({
    required this.id,
    required this.tenantId,
    required this.name,
    required this.eventTypes,
    required this.conditions,
    required this.signalLevel,
    required this.status,
    required this.priority,
    required this.createdAt,
    required this.createdBy,
    this.brandId,
    this.sourceIds = const <String>[],
    this.description,
    this.signalTitleTemplate,
    this.signalSummaryTemplate,
    this.stopOnMatch = false,
    this.updatedAt,
    this.updatedBy,
  });

  final String id;
  final String tenantId;
  final String? brandId;
  final String name;
  final String? description;
  final List<MonitoringEventType> eventTypes;
  final List<String> sourceIds;
  final List<SignalRuleConditionModel> conditions;
  final MonitoringSignalLevel signalLevel;
  final MonitoringSignalRuleStatus status;
  final MonitoringPriority priority;
  final String? signalTitleTemplate;
  final String? signalSummaryTemplate;
  final bool stopOnMatch;
  final DateTime createdAt;
  final String createdBy;
  final DateTime? updatedAt;
  final String? updatedBy;

  factory SignalRuleModel.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();

    if (data == null) {
      throw StateError('Signal rule document has no data: ${document.id}');
    }

    return SignalRuleModel.fromMap(id: document.id, data: data);
  }

  factory SignalRuleModel.fromMap({
    required String id,
    required Map<String, dynamic> data,
  }) {
    final createdAt = MonitoringModelUtils.dateTimeFromValue(data['createdAt']);

    if (createdAt == null) {
      throw StateError('Signal rule createdAt is missing: $id');
    }

    return SignalRuleModel(
      id: id,
      tenantId: _requiredString(data['tenantId']),
      brandId: _nullableString(data['brandId']),
      name: _requiredString(data['name']),
      description: _nullableString(data['description']),
      eventTypes: _eventTypesFromValue(data['eventTypes']),
      sourceIds: MonitoringModelUtils.stringListFromValue(data['sourceIds']),
      conditions: _conditionsFromValue(data['conditions']),
      signalLevel: MonitoringSignalLevelX.fromValue(
        data['signalLevel']?.toString(),
      ),
      status: MonitoringSignalRuleStatusX.fromValue(data['status']?.toString()),
      priority: MonitoringPriorityX.fromValue(data['priority']?.toString()),
      signalTitleTemplate: _nullableString(data['signalTitleTemplate']),
      signalSummaryTemplate: _nullableString(data['signalSummaryTemplate']),
      stopOnMatch: MonitoringModelUtils.boolFromValue(data['stopOnMatch']),
      createdAt: createdAt,
      createdBy: _requiredString(data['createdBy']),
      updatedAt: MonitoringModelUtils.dateTimeFromValue(data['updatedAt']),
      updatedBy: _nullableString(data['updatedBy']),
    );
  }

  Map<String, dynamic> toCreateMap() {
    return <String, dynamic>{
      'tenantId': tenantId,
      'brandId': _cleanNullable(brandId),
      'name': name.trim(),
      'description': _cleanNullable(description),
      'eventTypes': eventTypes
          .map((item) => item.value)
          .toList(growable: false),
      'sourceIds': sourceIds,
      'conditions': conditions
          .map((item) => item.toMap())
          .toList(growable: false),
      'signalLevel': signalLevel.value,
      'status': status.value,
      'priority': priority.value,
      'signalTitleTemplate': _cleanNullable(signalTitleTemplate),
      'signalSummaryTemplate': _cleanNullable(signalSummaryTemplate),
      'stopOnMatch': stopOnMatch,
      'createdAt': Timestamp.fromDate(createdAt),
      'createdBy': createdBy,
      'updatedAt': updatedAt == null ? null : Timestamp.fromDate(updatedAt!),
      'updatedBy': updatedBy,
    };
  }

  Map<String, dynamic> toUpdateMap() {
    return <String, dynamic>{
      'brandId': _cleanNullable(brandId),
      'name': name.trim(),
      'description': _cleanNullable(description),
      'eventTypes': eventTypes
          .map((item) => item.value)
          .toList(growable: false),
      'sourceIds': sourceIds,
      'conditions': conditions
          .map((item) => item.toMap())
          .toList(growable: false),
      'signalLevel': signalLevel.value,
      'status': status.value,
      'priority': priority.value,
      'signalTitleTemplate': _cleanNullable(signalTitleTemplate),
      'signalSummaryTemplate': _cleanNullable(signalSummaryTemplate),
      'stopOnMatch': stopOnMatch,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': updatedBy,
    };
  }

  bool get isActive {
    return status == MonitoringSignalRuleStatus.active;
  }

  bool appliesToSource(String sourceId) {
    return sourceIds.isEmpty || sourceIds.contains(sourceId);
  }

  bool appliesToEventType(MonitoringEventType eventType) {
    return eventTypes.isEmpty || eventTypes.contains(eventType);
  }

  static List<MonitoringEventType> _eventTypesFromValue(dynamic value) {
    if (value is! Iterable) {
      return const <MonitoringEventType>[];
    }

    return value
        .map((item) => MonitoringEventTypeX.fromValue(item?.toString()))
        .toList(growable: false);
  }

  static List<SignalRuleConditionModel> _conditionsFromValue(dynamic value) {
    if (value is! Iterable) {
      return const <SignalRuleConditionModel>[];
    }

    return value
        .whereType<Map>()
        .map(
          (item) =>
              SignalRuleConditionModel.fromMap(Map<String, dynamic>.from(item)),
        )
        .toList(growable: false);
  }

  static String _requiredString(dynamic value) {
    return (value ?? '').toString().trim();
  }

  static String? _nullableString(dynamic value) {
    final text = value?.toString().trim();

    return text == null || text.isEmpty ? null : text;
  }

  static String? _cleanNullable(String? value) {
    final cleaned = value?.trim();

    return cleaned == null || cleaned.isEmpty ? null : cleaned;
  }
}

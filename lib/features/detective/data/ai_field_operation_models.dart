import 'package:cloud_firestore/cloud_firestore.dart';

enum AiFieldOperationStatus {
  draft,
  queued,
  running,
  waitingHumanApproval,
  completed,
  failed,
  cancelled,
}

extension AiFieldOperationStatusValue on AiFieldOperationStatus {
  String get value => switch (this) {
    AiFieldOperationStatus.draft => 'draft',
    AiFieldOperationStatus.queued => 'queued',
    AiFieldOperationStatus.running => 'running',
    AiFieldOperationStatus.waitingHumanApproval => 'waiting_human_approval',
    AiFieldOperationStatus.completed => 'completed',
    AiFieldOperationStatus.failed => 'failed',
    AiFieldOperationStatus.cancelled => 'cancelled',
  };

  static AiFieldOperationStatus fromValue(String? value) {
    return switch (value) {
      'queued' => AiFieldOperationStatus.queued,
      'running' => AiFieldOperationStatus.running,
      'waiting_human_approval' => AiFieldOperationStatus.waitingHumanApproval,
      'completed' => AiFieldOperationStatus.completed,
      'failed' => AiFieldOperationStatus.failed,
      'cancelled' => AiFieldOperationStatus.cancelled,
      _ => AiFieldOperationStatus.draft,
    };
  }
}

enum AiFieldOperationPriority { low, normal, high, critical }

extension AiFieldOperationPriorityValue on AiFieldOperationPriority {
  String get value => switch (this) {
    AiFieldOperationPriority.low => 'low',
    AiFieldOperationPriority.normal => 'normal',
    AiFieldOperationPriority.high => 'high',
    AiFieldOperationPriority.critical => 'critical',
  };

  static AiFieldOperationPriority fromValue(String? value) {
    return switch (value) {
      'low' => AiFieldOperationPriority.low,
      'high' => AiFieldOperationPriority.high,
      'critical' => AiFieldOperationPriority.critical,
      _ => AiFieldOperationPriority.normal,
    };
  }
}

enum AiFieldAgentTaskStatus {
  pending,
  queued,
  running,
  completed,
  failed,
  skipped,
  waitingHandoff,
  waitingHumanApproval,
}

extension AiFieldAgentTaskStatusValue on AiFieldAgentTaskStatus {
  String get value => switch (this) {
    AiFieldAgentTaskStatus.pending => 'pending',
    AiFieldAgentTaskStatus.queued => 'queued',
    AiFieldAgentTaskStatus.running => 'running',
    AiFieldAgentTaskStatus.completed => 'completed',
    AiFieldAgentTaskStatus.failed => 'failed',
    AiFieldAgentTaskStatus.skipped => 'skipped',
    AiFieldAgentTaskStatus.waitingHandoff => 'waiting_handoff',
    AiFieldAgentTaskStatus.waitingHumanApproval => 'waiting_human_approval',
  };

  static AiFieldAgentTaskStatus fromValue(String? value) {
    return switch (value) {
      'queued' => AiFieldAgentTaskStatus.queued,
      'running' => AiFieldAgentTaskStatus.running,
      'completed' => AiFieldAgentTaskStatus.completed,
      'failed' => AiFieldAgentTaskStatus.failed,
      'skipped' => AiFieldAgentTaskStatus.skipped,
      'waiting_handoff' => AiFieldAgentTaskStatus.waitingHandoff,
      'waiting_human_approval' => AiFieldAgentTaskStatus.waitingHumanApproval,
      _ => AiFieldAgentTaskStatus.pending,
    };
  }
}

class AiFieldAgentDefinition {
  const AiFieldAgentDefinition({
    required this.id,
    required this.name,
    required this.order,
    required this.requiresHumanApproval,
  });

  final String id;
  final String name;
  final int order;
  final bool requiresHumanApproval;
}

abstract final class AiFieldAgentCatalog {
  static const List<AiFieldAgentDefinition> agents = [
    AiFieldAgentDefinition(
      id: 'task_planner',
      name: 'Görev Planlama Ajanı',
      order: 1,
      requiresHumanApproval: false,
    ),
    AiFieldAgentDefinition(
      id: 'digital_field_scanner',
      name: 'Dijital Saha Tarama Ajanı',
      order: 2,
      requiresHumanApproval: false,
    ),
    AiFieldAgentDefinition(
      id: 'page_change_monitor',
      name: 'Sayfa Değişim İzleme Ajanı',
      order: 3,
      requiresHumanApproval: false,
    ),
    AiFieldAgentDefinition(
      id: 'visual_matcher',
      name: 'Görsel Eşleştirme Ajanı',
      order: 4,
      requiresHumanApproval: false,
    ),
    AiFieldAgentDefinition(
      id: 'text_language_analyst',
      name: 'Metin ve Dil Analizi Ajanı',
      order: 5,
      requiresHumanApproval: false,
    ),
    AiFieldAgentDefinition(
      id: 'seller_entity_resolver',
      name: 'Satıcı ve Varlık Eşleştirme Ajanı',
      order: 6,
      requiresHumanApproval: false,
    ),
    AiFieldAgentDefinition(
      id: 'network_analyst',
      name: 'Ağ Analizi Ajanı',
      order: 7,
      requiresHumanApproval: false,
    ),
    AiFieldAgentDefinition(
      id: 'price_anomaly_analyst',
      name: 'Fiyat ve Anomali Ajanı',
      order: 8,
      requiresHumanApproval: false,
    ),
    AiFieldAgentDefinition(
      id: 'evidence_custodian',
      name: 'Delil Muhafaza Ajanı',
      order: 9,
      requiresHumanApproval: false,
    ),
    AiFieldAgentDefinition(
      id: 'risk_intervention_analyst',
      name: 'Risk ve Müdahale Ajanı',
      order: 10,
      requiresHumanApproval: false,
    ),
    AiFieldAgentDefinition(
      id: 'reporting_agent',
      name: 'Raporlama Ajanı',
      order: 11,
      requiresHumanApproval: false,
    ),
    AiFieldAgentDefinition(
      id: 'human_expert_gate',
      name: 'İnsan Uzman Onay Kapısı',
      order: 12,
      requiresHumanApproval: true,
    ),
  ];

  static AiFieldAgentDefinition? findById(String id) {
    for (final agent in agents) {
      if (agent.id == id) {
        return agent;
      }
    }

    return null;
  }
}

class AiFieldOperation {
  const AiFieldOperation({
    required this.id,
    required this.title,
    required this.objective,
    required this.status,
    required this.priority,
    required this.currentAgentId,
    required this.requiresHumanApproval,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final String objective;
  final AiFieldOperationStatus status;
  final AiFieldOperationPriority priority;
  final String currentAgentId;
  final bool requiresHumanApproval;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory AiFieldOperation.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? const <String, dynamic>{};

    return AiFieldOperation(
      id: document.id,
      title: data['title']?.toString().trim() ?? '',
      objective: data['objective']?.toString().trim() ?? '',
      status: AiFieldOperationStatusValue.fromValue(data['status']?.toString()),
      priority: AiFieldOperationPriorityValue.fromValue(
        data['priority']?.toString(),
      ),
      currentAgentId: data['currentAgentId']?.toString().trim() ?? '',
      requiresHumanApproval: data['requiresHumanApproval'] == true,
      createdAt: _dateTimeFromValue(data['createdAt']),
      updatedAt: _dateTimeFromValue(data['updatedAt']),
    );
  }
}

class AiFieldAgentTask {
  const AiFieldAgentTask({
    required this.id,
    required this.agentId,
    required this.agentName,
    required this.status,
    required this.input,
    required this.output,
    required this.startedAt,
    required this.completedAt,
    required this.errorMessage,
    required this.handoffToAgentId,
  });

  final String id;
  final String agentId;
  final String agentName;
  final AiFieldAgentTaskStatus status;
  final Map<String, dynamic> input;
  final Map<String, dynamic> output;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final String errorMessage;
  final String handoffToAgentId;

  factory AiFieldAgentTask.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? const <String, dynamic>{};

    return AiFieldAgentTask(
      id: document.id,
      agentId: data['agentId']?.toString().trim() ?? '',
      agentName: data['agentName']?.toString().trim() ?? '',
      status: AiFieldAgentTaskStatusValue.fromValue(data['status']?.toString()),
      input: _mapFromValue(data['input']),
      output: _mapFromValue(data['output']),
      startedAt: _dateTimeFromValue(data['startedAt']),
      completedAt: _dateTimeFromValue(data['completedAt']),
      errorMessage: data['errorMessage']?.toString().trim() ?? '',
      handoffToAgentId: data['handoffToAgentId']?.toString().trim() ?? '',
    );
  }
}

Map<String, dynamic> _mapFromValue(dynamic value) {
  if (value is Map<String, dynamic>) {
    return Map<String, dynamic>.from(value);
  }

  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }

  return <String, dynamic>{};
}

DateTime? _dateTimeFromValue(dynamic value) {
  if (value is Timestamp) {
    return value.toDate();
  }

  if (value is DateTime) {
    return value;
  }

  return null;
}

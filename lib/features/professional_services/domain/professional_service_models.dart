import 'dart:collection';

const Set<String> professionalServicesServerActorFields = <String>{
  'actorUid',
  'requestedByUid',
  'createdByUid',
  'updatedByUid',
  'statusChangedByUid',
  'assignedByUid',
  'initiatedByUid',
  'reviewedByUid',
  'publishedByUid',
  'authorizedByUid',
  'preparedByUid',
  'decidedByUid',
};

enum ProfessionalServiceOperation {
  createServiceRequest(
    callableName: 'createProfessionalServiceRequest',
    wireValue: 'create_service_request',
  ),
  transitionServiceRequest(
    callableName: 'transitionProfessionalServiceRequest',
    wireValue: 'transition_service_request',
  ),
  createServiceEngagement(
    callableName: 'createProfessionalServiceEngagement',
    wireValue: 'create_service_engagement',
  ),
  createServiceAssignment(
    callableName: 'createProfessionalServiceAssignment',
    wireValue: 'create_service_assignment',
  ),
  startAgentRun(
    callableName: 'startProfessionalAgentRun',
    wireValue: 'start_agent_run',
  ),
  recordAgentOutput(
    callableName: 'recordProfessionalAgentOutput',
    wireValue: 'record_agent_output',
  ),
  recordAgentReview(
    callableName: 'recordProfessionalAgentReview',
    wireValue: 'record_agent_review',
  ),
  publishAgentOutput(
    callableName: 'publishProfessionalAgentOutput',
    wireValue: 'publish_agent_output',
  );

  const ProfessionalServiceOperation({
    required this.callableName,
    required this.wireValue,
  });

  final String callableName;
  final String wireValue;
}

abstract final class ProfessionalServicesCallableContract {
  static const String region = 'europe-west3';

  static const List<String> callableNames = <String>[
    'createProfessionalServiceRequest',
    'transitionProfessionalServiceRequest',
    'createProfessionalServiceEngagement',
    'createProfessionalServiceAssignment',
    'startProfessionalAgentRun',
    'recordProfessionalAgentOutput',
    'recordProfessionalAgentReview',
    'publishProfessionalAgentOutput',
  ];
}

class ProfessionalServiceCommand {
  ProfessionalServiceCommand({
    required this.operation,
    required Map<String, Object?> payload,
  }) : payload = _freezeMap(payload) {
    final actorPaths = collectProfessionalServiceActorPaths(this.payload);
    if (actorPaths.isNotEmpty) {
      throw ArgumentError.value(
        actorPaths,
        'payload',
        'Aktör kimliği istemci tarafından gönderilemez.',
      );
    }
  }

  final ProfessionalServiceOperation operation;
  final Map<String, Object?> payload;

  Map<String, Object?> toMap() => payload;
}

class ProfessionalServiceResult {
  const ProfessionalServiceResult._({
    required this.resultType,
    required this.resultId,
    required this.idempotentReplay,
    required this.payload,
  });

  factory ProfessionalServiceResult.fromValue(Object? value) {
    final normalized = normalizeProfessionalServicesValue(value);
    if (normalized is! Map<String, Object?>) {
      throw const FormatException(
        'Professional Services callable sonucu nesne olmalıdır.',
      );
    }

    final resultType = normalized['resultType'];
    final resultId = normalized['resultId'];
    final idempotentReplay = normalized['idempotentReplay'];

    if (resultType is! String || resultType.trim().isEmpty) {
      throw const FormatException('resultType zorunludur.');
    }
    if (resultId is! String || resultId.trim().isEmpty) {
      throw const FormatException('resultId zorunludur.');
    }
    if (idempotentReplay != null && idempotentReplay is! bool) {
      throw const FormatException('idempotentReplay boolean olmalıdır.');
    }

    return ProfessionalServiceResult._(
      resultType: resultType.trim(),
      resultId: resultId.trim(),
      idempotentReplay: idempotentReplay == true,
      payload: _freezeMap(normalized),
    );
  }

  final String resultType;
  final String resultId;
  final bool idempotentReplay;
  final Map<String, Object?> payload;
}

class ProfessionalServicesClientFailure implements Exception {
  const ProfessionalServicesClientFailure({
    required this.code,
    required this.message,
    this.details,
    this.retryable = false,
  });

  final String code;
  final String message;
  final Object? details;
  final bool retryable;

  @override
  String toString() => 'ProfessionalServicesClientFailure($code, $message)';
}

List<String> collectProfessionalServiceActorPaths(
  Object? value, {
  String path = r'$',
}) {
  final found = <String>[];
  final visited = HashSet<Object>.identity();

  void visit(Object? current, String currentPath) {
    if (current == null ||
        current is String ||
        current is num ||
        current is bool) {
      return;
    }
    if (current is List) {
      if (!visited.add(current)) return;
      for (var index = 0; index < current.length; index += 1) {
        visit(current[index], '$currentPath[$index]');
      }
      return;
    }
    if (current is Map) {
      if (!visited.add(current)) return;
      for (final entry in current.entries) {
        final key = entry.key;
        if (key is! String) {
          continue;
        }
        final itemPath = '$currentPath.$key';
        if (professionalServicesServerActorFields.contains(key)) {
          found.add(itemPath);
        }
        visit(entry.value, itemPath);
      }
    }
  }

  visit(value, path);
  found.sort();
  return List<String>.unmodifiable(found);
}

Object? normalizeProfessionalServicesValue(Object? value) {
  if (value == null || value is String || value is num || value is bool) {
    return value;
  }
  if (value is List) {
    return List<Object?>.unmodifiable(
      value.map<Object?>(normalizeProfessionalServicesValue),
    );
  }
  if (value is Map) {
    final normalized = <String, Object?>{};
    for (final entry in value.entries) {
      if (entry.key is! String) {
        throw FormatException(
          'Callable yanıtında String olmayan map anahtarı bulundu: '
          '${entry.key.runtimeType}.',
        );
      }
      normalized[entry.key as String] = normalizeProfessionalServicesValue(
        entry.value,
      );
    }
    return Map<String, Object?>.unmodifiable(normalized);
  }
  throw FormatException(
    'Desteklenmeyen callable değer türü: ${value.runtimeType}.',
  );
}

Map<String, Object?> _freezeMap(Map<String, Object?> source) {
  final result = <String, Object?>{};
  for (final entry in source.entries) {
    result[entry.key] = _freezeValue(entry.value);
  }
  return Map<String, Object?>.unmodifiable(result);
}

Object? _freezeValue(Object? value) {
  if (value is Map<String, Object?>) {
    return _freezeMap(value);
  }
  if (value is Map) {
    final normalized = <String, Object?>{};
    for (final entry in value.entries) {
      if (entry.key is! String) {
        throw ArgumentError.value(
          entry.key,
          'payload',
          'Map anahtarları String olmalıdır.',
        );
      }
      normalized[entry.key as String] = _freezeValue(entry.value);
    }
    return Map<String, Object?>.unmodifiable(normalized);
  }
  if (value is List) {
    return List<Object?>.unmodifiable(value.map<Object?>(_freezeValue));
  }
  return value;
}

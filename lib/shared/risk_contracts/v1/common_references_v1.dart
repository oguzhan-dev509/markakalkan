// ignore_for_file: prefer_initializing_formals

part of 'shared_risk_contracts_v1.dart';

final class CanonicalEntityRef {
  CanonicalEntityRef({
    required String module,
    required String entityType,
    required String entityId,
    String? displayCode,
    String? sourceCollection,
  }) : module = _requiredString(module, 'module'),
       entityType = _requiredString(entityType, 'entityType'),
       entityId = _requiredString(entityId, 'entityId'),
       displayCode = _optionalString(displayCode, 'displayCode'),
       sourceCollection = _optionalString(sourceCollection, 'sourceCollection');

  final String module;
  final String entityType;
  final String entityId;
  final String? displayCode;
  final String? sourceCollection;

  factory CanonicalEntityRef.fromJson(Map<String, dynamic> json) =>
      CanonicalEntityRef(
        module: _requiredString(json['module'], 'module'),
        entityType: _requiredString(json['entityType'], 'entityType'),
        entityId: _requiredString(json['entityId'], 'entityId'),
        displayCode: _optionalString(json['displayCode'], 'displayCode'),
        sourceCollection: _optionalString(
          json['sourceCollection'],
          'sourceCollection',
        ),
      );

  Map<String, Object?> toJson() => {
    'module': module,
    'entityType': entityType,
    'entityId': entityId,
    if (displayCode != null) 'displayCode': displayCode,
    if (sourceCollection != null) 'sourceCollection': sourceCollection,
  };
}

final class CanonicalAssetRef {
  CanonicalAssetRef({
    required String assetType,
    required String assetId,
    required String module,
    String? brandId,
    String? productId,
    String? versionRef,
  }) : assetType = _requiredString(assetType, 'assetType'),
       assetId = _requiredString(assetId, 'assetId'),
       module = _requiredString(module, 'module'),
       brandId = _optionalString(brandId, 'brandId'),
       productId = _optionalString(productId, 'productId'),
       versionRef = _optionalString(versionRef, 'versionRef');

  final String assetType;
  final String assetId;
  final String module;
  final String? brandId;
  final String? productId;
  final String? versionRef;

  factory CanonicalAssetRef.fromJson(Map<String, dynamic> json) =>
      CanonicalAssetRef(
        assetType: _requiredString(json['assetType'], 'assetType'),
        assetId: _requiredString(json['assetId'], 'assetId'),
        module: _requiredString(json['module'], 'module'),
        brandId: _optionalString(json['brandId'], 'brandId'),
        productId: _optionalString(json['productId'], 'productId'),
        versionRef: _optionalString(json['versionRef'], 'versionRef'),
      );

  Map<String, Object?> toJson() => {
    'assetType': assetType,
    'assetId': assetId,
    'module': module,
    if (brandId != null) 'brandId': brandId,
    if (productId != null) 'productId': productId,
    if (versionRef != null) 'versionRef': versionRef,
  };
}

final class EvidenceRef {
  EvidenceRef({
    required String evidenceType,
    required String referenceType,
    required String referenceId,
    required String sourceModule,
    String? hashAlgorithm,
    String? hashValue,
    DateTime? capturedAt,
    Map<String, Object?> metadata = const {},
  }) : evidenceType = _requiredString(evidenceType, 'evidenceType'),
       referenceType = _requiredString(referenceType, 'referenceType'),
       referenceId = _requiredString(referenceId, 'referenceId'),
       sourceModule = _requiredString(sourceModule, 'sourceModule'),
       hashAlgorithm = _optionalString(hashAlgorithm, 'hashAlgorithm'),
       hashValue = _optionalString(hashValue, 'hashValue'),
       capturedAt = capturedAt,
       metadata = _metadata(metadata, 'metadata') {
    if ((this.hashAlgorithm == null) != (this.hashValue == null)) {
      throw FormatException('hashAlgorithm and hashValue must be paired');
    }
  }

  final String evidenceType;
  final String referenceType;
  final String referenceId;
  final String sourceModule;
  final String? hashAlgorithm;
  final String? hashValue;
  final DateTime? capturedAt;
  final Map<String, Object?> metadata;

  factory EvidenceRef.fromJson(Map<String, dynamic> json) => EvidenceRef(
    evidenceType: _requiredString(json['evidenceType'], 'evidenceType'),
    referenceType: _requiredString(json['referenceType'], 'referenceType'),
    referenceId: _requiredString(json['referenceId'], 'referenceId'),
    sourceModule: _requiredString(json['sourceModule'], 'sourceModule'),
    hashAlgorithm: _optionalString(json['hashAlgorithm'], 'hashAlgorithm'),
    hashValue: _optionalString(json['hashValue'], 'hashValue'),
    capturedAt: _optionalDate(json['capturedAt'], 'capturedAt'),
    metadata: _metadata(json['metadata'], 'metadata'),
  );

  Map<String, Object?> toJson() => {
    'evidenceType': evidenceType,
    'referenceType': referenceType,
    'referenceId': referenceId,
    'sourceModule': sourceModule,
    if (hashAlgorithm != null) 'hashAlgorithm': hashAlgorithm,
    if (hashValue != null) 'hashValue': hashValue,
    if (capturedAt != null) 'capturedAt': capturedAt!.toIso8601String(),
    if (metadata.isNotEmpty) 'metadata': metadata,
  };
}

final class ConfidenceValue {
  ConfidenceValue({
    double? normalizedScore,
    Object? originalValue,
    String? originalScale,
    String? sourceNamespace,
  }) : normalizedScore = normalizedScore,
       originalValue = _freezeJson(originalValue, 'originalValue'),
       originalScale = _optionalString(originalScale, 'originalScale'),
       sourceNamespace = _optionalString(sourceNamespace, 'sourceNamespace') {
    if (normalizedScore != null &&
        (!normalizedScore.isFinite ||
            normalizedScore < 0 ||
            normalizedScore > 1)) {
      throw RangeError.range(normalizedScore, 0, 1, 'normalizedScore');
    }
    if (normalizedScore == null && this.originalValue == null) {
      throw FormatException(
        'confidence requires normalizedScore or originalValue',
      );
    }
  }

  final double? normalizedScore;
  final Object? originalValue;
  final String? originalScale;
  final String? sourceNamespace;

  factory ConfidenceValue.fromJson(Map<String, dynamic> json) =>
      ConfidenceValue(
        normalizedScore: json['normalizedScore'] == null
            ? null
            : _requiredNumber(
                json['normalizedScore'],
                'normalizedScore',
              ).toDouble(),
        originalValue: json['originalValue'],
        originalScale: _optionalString(json['originalScale'], 'originalScale'),
        sourceNamespace: _optionalString(
          json['sourceNamespace'],
          'sourceNamespace',
        ),
      );

  Map<String, Object?> toJson() => {
    if (normalizedScore != null) 'normalizedScore': normalizedScore,
    if (originalValue != null) 'originalValue': originalValue,
    if (originalScale != null) 'originalScale': originalScale,
    if (sourceNamespace != null) 'sourceNamespace': sourceNamespace,
  };
}

final class ScoreValue {
  ScoreValue({
    required num value,
    required num minimum,
    required num maximum,
    String? modelVersion,
    Object? originalValue,
    String? originalScale,
  }) : value = _requiredNumber(value, 'value'),
       minimum = _requiredNumber(minimum, 'minimum'),
       maximum = _requiredNumber(maximum, 'maximum'),
       modelVersion = _optionalString(modelVersion, 'modelVersion'),
       originalValue = _freezeJson(originalValue, 'originalValue'),
       originalScale = _optionalString(originalScale, 'originalScale') {
    if (this.minimum >= this.maximum ||
        this.value < this.minimum ||
        this.value > this.maximum) {
      throw RangeError('score value must be within a valid scale');
    }
  }

  final num value;
  final num minimum;
  final num maximum;
  final String? modelVersion;
  final Object? originalValue;
  final String? originalScale;

  factory ScoreValue.fromJson(Map<String, dynamic> json) => ScoreValue(
    value: _requiredNumber(json['value'], 'value'),
    minimum: _requiredNumber(json['minimum'], 'minimum'),
    maximum: _requiredNumber(json['maximum'], 'maximum'),
    modelVersion: _optionalString(json['modelVersion'], 'modelVersion'),
    originalValue: json['originalValue'],
    originalScale: _optionalString(json['originalScale'], 'originalScale'),
  );

  Map<String, Object?> toJson() => {
    'value': value,
    'minimum': minimum,
    'maximum': maximum,
    if (modelVersion != null) 'modelVersion': modelVersion,
    if (originalValue != null) 'originalValue': originalValue,
    if (originalScale != null) 'originalScale': originalScale,
  };
}

final class IdentityScope {
  IdentityScope({
    String? tenantId,
    String? brandId,
    String? brandUid,
    String? ownerUid,
    required IdentityResolutionStatus resolutionStatus,
    String? resolutionSource,
    List<String> unresolvedReasons = const [],
  }) : tenantId = _optionalString(tenantId, 'tenantId'),
       brandId = _optionalString(brandId, 'brandId'),
       brandUid = _optionalString(brandUid, 'brandUid'),
       ownerUid = _optionalString(ownerUid, 'ownerUid'),
       resolutionStatus = resolutionStatus,
       resolutionSource = _optionalString(resolutionSource, 'resolutionSource'),
       unresolvedReasons = List<String>.unmodifiable(
         unresolvedReasons.map(
           (item) => _requiredString(item, 'unresolvedReasons'),
         ),
       ) {
    if (resolutionStatus == IdentityResolutionStatus.resolved &&
        this.tenantId == null) {
      throw FormatException('resolved identity requires tenantId');
    }
  }

  final String? tenantId;
  final String? brandId;
  final String? brandUid;
  final String? ownerUid;
  final IdentityResolutionStatus resolutionStatus;
  final String? resolutionSource;
  final List<String> unresolvedReasons;

  bool get isPersistenceReady =>
      resolutionStatus == IdentityResolutionStatus.resolved && tenantId != null;

  factory IdentityScope.fromJson(Map<String, dynamic> json) => IdentityScope(
    tenantId: _optionalString(json['tenantId'], 'tenantId'),
    brandId: _optionalString(json['brandId'], 'brandId'),
    brandUid: _optionalString(json['brandUid'], 'brandUid'),
    ownerUid: _optionalString(json['ownerUid'], 'ownerUid'),
    resolutionStatus: _enumValue(json['resolutionStatus'], {
      for (final item in IdentityResolutionStatus.values) item.name: item,
    }, 'resolutionStatus'),
    resolutionSource: _optionalString(
      json['resolutionSource'],
      'resolutionSource',
    ),
    unresolvedReasons: _stringList(
      json['unresolvedReasons'] ?? const [],
      'unresolvedReasons',
    ),
  );

  Map<String, Object?> toJson() => {
    if (tenantId != null) 'tenantId': tenantId,
    if (brandId != null) 'brandId': brandId,
    if (brandUid != null) 'brandUid': brandUid,
    if (ownerUid != null) 'ownerUid': ownerUid,
    'resolutionStatus': resolutionStatus.name,
    if (resolutionSource != null) 'resolutionSource': resolutionSource,
    'unresolvedReasons': unresolvedReasons,
  };
}

final class ProvenanceEnvelope {
  ProvenanceEnvelope({
    required String producerModule,
    required DateTime adaptedAt,
    String? producerVersion,
    String? sourceRecordId,
    String? executionId,
    String? workflowRef,
    String? taskId,
    String? sourceId,
    String? snapshotId,
    String? findingKey,
    String? contentHash,
    DateTime? sourceCreatedAt,
  }) : producerModule = _requiredString(producerModule, 'producerModule'),
       producerVersion = _optionalString(producerVersion, 'producerVersion'),
       sourceRecordId = _optionalString(sourceRecordId, 'sourceRecordId'),
       executionId = _optionalString(executionId, 'executionId'),
       workflowRef = _optionalString(workflowRef, 'workflowRef'),
       taskId = _optionalString(taskId, 'taskId'),
       sourceId = _optionalString(sourceId, 'sourceId'),
       snapshotId = _optionalString(snapshotId, 'snapshotId'),
       findingKey = _optionalString(findingKey, 'findingKey'),
       contentHash = _optionalString(contentHash, 'contentHash'),
       sourceCreatedAt = sourceCreatedAt,
       adaptedAt = adaptedAt;

  final String producerModule;
  final String? producerVersion;
  final String? sourceRecordId;
  final String? executionId;
  final String? workflowRef;
  final String? taskId;
  final String? sourceId;
  final String? snapshotId;
  final String? findingKey;
  final String? contentHash;
  final DateTime? sourceCreatedAt;
  final DateTime adaptedAt;

  factory ProvenanceEnvelope.fromJson(
    Map<String, dynamic> json,
  ) => ProvenanceEnvelope(
    producerModule: _requiredString(json['producerModule'], 'producerModule'),
    producerVersion: _optionalString(
      json['producerVersion'],
      'producerVersion',
    ),
    sourceRecordId: _optionalString(json['sourceRecordId'], 'sourceRecordId'),
    executionId: _optionalString(json['executionId'], 'executionId'),
    workflowRef: _optionalString(json['workflowRef'], 'workflowRef'),
    taskId: _optionalString(json['taskId'], 'taskId'),
    sourceId: _optionalString(json['sourceId'], 'sourceId'),
    snapshotId: _optionalString(json['snapshotId'], 'snapshotId'),
    findingKey: _optionalString(json['findingKey'], 'findingKey'),
    contentHash: _optionalString(json['contentHash'], 'contentHash'),
    sourceCreatedAt: _optionalDate(json['sourceCreatedAt'], 'sourceCreatedAt'),
    adaptedAt: _requiredDate(json['adaptedAt'], 'adaptedAt'),
  );

  Map<String, Object?> toJson() => {
    'producerModule': producerModule,
    if (producerVersion != null) 'producerVersion': producerVersion,
    if (sourceRecordId != null) 'sourceRecordId': sourceRecordId,
    if (executionId != null) 'executionId': executionId,
    if (workflowRef != null) 'workflowRef': workflowRef,
    if (taskId != null) 'taskId': taskId,
    if (sourceId != null) 'sourceId': sourceId,
    if (snapshotId != null) 'snapshotId': snapshotId,
    if (findingKey != null) 'findingKey': findingKey,
    if (contentHash != null) 'contentHash': contentHash,
    if (sourceCreatedAt != null)
      'sourceCreatedAt': sourceCreatedAt!.toIso8601String(),
    'adaptedAt': adaptedAt.toIso8601String(),
  };
}

final class NamespacedValue {
  NamespacedValue({required String namespace, required String value})
    : namespace = _requiredString(namespace, 'namespace'),
      value = _requiredString(value, 'value');

  final String namespace;
  final String value;

  factory NamespacedValue.fromJson(Map<String, dynamic> json) =>
      NamespacedValue(
        namespace: _requiredString(json['namespace'], 'namespace'),
        value: _requiredString(json['value'], 'value'),
      );

  Map<String, Object?> toJson() => {'namespace': namespace, 'value': value};
}

final class SignalSource {
  SignalSource({
    required String module,
    required String sourceType,
    String? sourceId,
  }) : module = _requiredString(module, 'module'),
       sourceType = _requiredString(sourceType, 'sourceType'),
       sourceId = _optionalString(sourceId, 'sourceId');

  final String module;
  final String sourceType;
  final String? sourceId;

  factory SignalSource.fromJson(Map<String, dynamic> json) => SignalSource(
    module: _requiredString(json['module'], 'module'),
    sourceType: _requiredString(json['sourceType'], 'sourceType'),
    sourceId: _optionalString(json['sourceId'], 'sourceId'),
  );

  Map<String, Object?> toJson() => {
    'module': module,
    'sourceType': sourceType,
    if (sourceId != null) 'sourceId': sourceId,
  };
}

part of 'idempotency_v1.dart';

enum SourceIngestionKeyKind { exactOccurrence, stableFinding }

final class SourceIngestionKeyV1 {
  SourceIngestionKeyV1({
    required String sourceModule,
    required String sourceType,
    required this.kind,
    required List<String> stableSourceParts,
  }) : sourceModule = _requiredPart(sourceModule, 'sourceModule'),
       sourceType = _requiredPart(sourceType, 'sourceType'),
       stableSourceParts = List.unmodifiable(
         stableSourceParts.map(
           (part) => _requiredPart(part, 'stableSourceParts[]'),
         ),
       ) {
    if (this.stableSourceParts.isEmpty) {
      throw const FormatException('stableSourceParts must not be empty');
    }
    canonicalKey = _canonicalEncoding([
      contractVersion,
      this.sourceModule,
      this.sourceType,
      kind.name,
      ...this.stableSourceParts,
    ]);
  }

  final String contractVersion = sourceIngestionKeyContractVersionV1;
  final String sourceModule;
  final String sourceType;
  final SourceIngestionKeyKind kind;
  final List<String> stableSourceParts;
  late final String canonicalKey;

  Map<String, Object?> toJson() => {
    'contractVersion': contractVersion,
    'sourceModule': sourceModule,
    'sourceType': sourceType,
    'kind': kind.name,
    'stableSourceParts': stableSourceParts,
    'canonicalKey': canonicalKey,
  };
}

final class SourceIngestionKeyBuilderV1 {
  const SourceIngestionKeyBuilderV1();

  SourceIngestionKeyV1 traceabilityScan({required String scanId}) =>
      SourceIngestionKeyV1(
        sourceModule: 'traceability',
        sourceType: 'verification_scan',
        kind: SourceIngestionKeyKind.exactOccurrence,
        stableSourceParts: [_requiredPart(scanId, 'scanId')],
      );

  SourceIngestionKeyV1 monitoringSignal({required String signalId}) =>
      SourceIngestionKeyV1(
        sourceModule: 'digital_market_monitoring',
        sourceType: 'monitoring_signal',
        kind: SourceIngestionKeyKind.exactOccurrence,
        stableSourceParts: [_requiredPart(signalId, 'signalId')],
      );

  SourceIngestionKeyV1 digitalDetectiveExactOccurrence({
    required String taskId,
    required String executionId,
    required String findingKey,
  }) => SourceIngestionKeyV1(
    sourceModule: 'digital_detective',
    sourceType: 'digital_field_scanner_finding',
    kind: SourceIngestionKeyKind.exactOccurrence,
    stableSourceParts: [
      _requiredPart(taskId, 'taskId'),
      _requiredPart(executionId, 'executionId'),
      _requiredPart(findingKey, 'findingKey'),
    ],
  );

  SourceIngestionKeyV1 digitalDetectiveStableFinding({
    required String taskId,
    required String findingKey,
  }) => SourceIngestionKeyV1(
    sourceModule: 'digital_detective',
    sourceType: 'digital_field_scanner_finding',
    kind: SourceIngestionKeyKind.stableFinding,
    stableSourceParts: [
      _requiredPart(taskId, 'taskId'),
      _requiredPart(findingKey, 'findingKey'),
    ],
  );
}

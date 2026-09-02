part of 'shared_risk_contracts_v1.dart';

const String timelineEventRefContractVersionV1 = 'timeline-event-ref-v1';

final class TimelineEventRefV1 {
  TimelineEventRefV1({
    required String eventId,
    required this.eventType,
    required this.occurredAt,
    this.actorRef,
    this.subjectRef,
    String? sourceSystemCode,
    String? sourceRecordId,
  }) : eventId = _requiredString(eventId, 'eventId'),
       sourceSystemCode = _optionalString(sourceSystemCode, 'sourceSystemCode'),
       sourceRecordId = _optionalString(sourceRecordId, 'sourceRecordId');

  final String contractVersion = timelineEventRefContractVersionV1;
  final String eventId;
  final NamespacedValue eventType;
  final DateTime occurredAt;
  final CanonicalEntityRef? actorRef;
  final CanonicalEntityRef? subjectRef;
  final String? sourceSystemCode;
  final String? sourceRecordId;

  factory TimelineEventRefV1.fromJson(Map<String, dynamic> json) {
    final version = _requiredString(json['contractVersion'], 'contractVersion');
    if (version != timelineEventRefContractVersionV1) {
      throw FormatException('Unsupported contractVersion: $version');
    }

    return TimelineEventRefV1(
      eventId: _requiredString(json['eventId'], 'eventId'),
      eventType: NamespacedValue.fromJson(
        _requiredMap(json['eventType'], 'eventType'),
      ),
      occurredAt: _requiredDate(json['occurredAt'], 'occurredAt'),
      actorRef: json['actorRef'] == null
          ? null
          : CanonicalEntityRef.fromJson(
              _requiredMap(json['actorRef'], 'actorRef'),
            ),
      subjectRef: json['subjectRef'] == null
          ? null
          : CanonicalEntityRef.fromJson(
              _requiredMap(json['subjectRef'], 'subjectRef'),
            ),
      sourceSystemCode: _optionalString(
        json['sourceSystemCode'],
        'sourceSystemCode',
      ),
      sourceRecordId: _optionalString(json['sourceRecordId'], 'sourceRecordId'),
    );
  }

  Map<String, Object?> toJson() => {
    'contractVersion': contractVersion,
    'eventId': eventId,
    'eventType': eventType.toJson(),
    'occurredAt': occurredAt.toIso8601String(),
    if (actorRef != null) 'actorRef': actorRef!.toJson(),
    if (subjectRef != null) 'subjectRef': subjectRef!.toJson(),
    if (sourceSystemCode != null) 'sourceSystemCode': sourceSystemCode,
    if (sourceRecordId != null) 'sourceRecordId': sourceRecordId,
  };
}

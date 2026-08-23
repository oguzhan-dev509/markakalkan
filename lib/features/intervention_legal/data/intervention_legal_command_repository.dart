import 'dart:math';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:markakalkan/core/security/app_check_bootstrap.dart';

const String interventionLegalCoreContractVersion =
    'intervention-legal-core-v1';

typedef InterventionLegalCommandCallable =
    Future<Map<String, dynamic>> Function(
      String name,
      Map<String, dynamic> request,
    );

abstract final class InterventionLegalCommandCallables {
  static const String createMatter = 'createInterventionLegalMatter';
  static const String transitionMatter = 'transitionInterventionLegalMatter';
  static const String createApprovalRequest =
      'createInterventionLegalApprovalRequest';
  static const String recordApprovalDecision =
      'recordInterventionLegalApprovalDecision';
}

final class InterventionLegalCommandResponse {
  const InterventionLegalCommandResponse({
    required this.resultType,
    required this.idempotentReplay,
    required this.data,
  });

  factory InterventionLegalCommandResponse.fromMap(Map<String, dynamic> data) {
    return InterventionLegalCommandResponse(
      resultType: _string(data['resultType']),
      idempotentReplay: data['idempotentReplay'] == true,
      data: Map<String, dynamic>.unmodifiable(data),
    );
  }

  final String resultType;
  final bool idempotentReplay;
  final Map<String, dynamic> data;
}

final class InterventionLegalCreateMatterContext {
  const InterventionLegalCreateMatterContext({
    required this.tenantId,
    required this.canonicalBrandId,
    required this.caseId,
  });

  final String tenantId;
  final String canonicalBrandId;
  final String caseId;
}

final class InterventionLegalCreateMatterInput {
  const InterventionLegalCreateMatterInput({
    required this.jurisdictionCode,
    required this.matterScopeCode,
    required this.countryCode,
    this.priorityCode,
    this.title,
    this.sourceSystemCode,
    this.sourceRecordId,
  });

  final String jurisdictionCode;
  final String matterScopeCode;
  final String countryCode;
  final String? priorityCode;
  final String? title;
  final String? sourceSystemCode;
  final String? sourceRecordId;
}

final class InterventionLegalMatterVersionContext {
  const InterventionLegalMatterVersionContext({
    required this.legalMatterId,
    required this.expectedVersion,
  });

  final String legalMatterId;
  final int expectedVersion;
}

final class InterventionLegalTransitionInput {
  const InterventionLegalTransitionInput({
    required this.nextStatus,
    required this.reasonCode,
    this.note,
  });

  final String nextStatus;
  final String reasonCode;
  final String? note;
}

final class InterventionLegalApprovalRequestContext {
  const InterventionLegalApprovalRequestContext({
    required this.legalMatterId,
    required this.expectedLegalMatterVersion,
  });

  final String legalMatterId;
  final int expectedLegalMatterVersion;
}

final class InterventionLegalApprovalRequestInput {
  const InterventionLegalApprovalRequestInput({
    required this.approvalType,
    required this.requestReasonCode,
    this.requestNote,
  });

  final String approvalType;
  final String requestReasonCode;
  final String? requestNote;
}

final class InterventionLegalApprovalDecisionContext {
  const InterventionLegalApprovalDecisionContext({
    required this.approvalRequestId,
    required this.legalMatterId,
    required this.approvalType,
    required this.expectedApprovalRequestVersion,
  });

  final String approvalRequestId;
  final String legalMatterId;
  final String approvalType;
  final int expectedApprovalRequestVersion;
}

final class InterventionLegalApprovalDecisionInput {
  const InterventionLegalApprovalDecisionInput({
    required this.decision,
    required this.decisionReasonCode,
    this.decisionNote,
  });

  final String decision;
  final String decisionReasonCode;
  final String? decisionNote;
}

abstract interface class InterventionLegalCommandRepository {
  Future<InterventionLegalCommandResponse> createLegalMatter({
    required InterventionLegalCreateMatterContext context,
    required InterventionLegalCreateMatterInput input,
  });

  Future<InterventionLegalCommandResponse> transitionLegalMatter({
    required InterventionLegalMatterVersionContext context,
    required InterventionLegalTransitionInput input,
  });

  Future<InterventionLegalCommandResponse> createApprovalRequest({
    required InterventionLegalApprovalRequestContext context,
    required InterventionLegalApprovalRequestInput input,
  });

  Future<InterventionLegalCommandResponse> recordApprovalDecision({
    required InterventionLegalApprovalDecisionContext context,
    required InterventionLegalApprovalDecisionInput input,
  });
}

final class CallableInterventionLegalCommandRepository
    implements InterventionLegalCommandRepository {
  CallableInterventionLegalCommandRepository({
    FirebaseFunctions? functions,
    Future<void> Function()? ensureAppCheckReady,
    InterventionLegalCommandCallable? callable,
    String Function()? requestIdFactory,
    String Function()? idempotencyKeyFactory,
  }) : _functions = callable == null
           ? functions ?? FirebaseFunctions.instanceFor(region: 'europe-west3')
           : null,
       _ensureAppCheckReady =
           ensureAppCheckReady ?? AppCheckBootstrap.instance.ensureReady,
       _callable = callable,
       _requestIdFactory =
           requestIdFactory ?? generateInterventionLegalRequestId,
       _idempotencyKeyFactory =
           idempotencyKeyFactory ?? generateInterventionLegalIdempotencyKey;

  final FirebaseFunctions? _functions;
  final Future<void> Function() _ensureAppCheckReady;
  final InterventionLegalCommandCallable? _callable;
  final String Function() _requestIdFactory;
  final String Function() _idempotencyKeyFactory;

  @override
  Future<InterventionLegalCommandResponse> createLegalMatter({
    required InterventionLegalCreateMatterContext context,
    required InterventionLegalCreateMatterInput input,
  }) {
    final request = _baseEnvelope()
      ..addAll(<String, dynamic>{
        'tenantId': _required(context.tenantId, 'tenantId'),
        'canonicalBrandId': _required(
          context.canonicalBrandId,
          'canonicalBrandId',
        ),
        'caseId': _required(context.caseId, 'caseId'),
        'jurisdictionCode': _required(
          input.jurisdictionCode,
          'jurisdictionCode',
        ),
        'matterScopeCode': _required(input.matterScopeCode, 'matterScopeCode'),
        'countryCode': _required(input.countryCode, 'countryCode'),
      });
    _putOptional(request, 'priorityCode', input.priorityCode);
    _putOptional(request, 'title', input.title);
    _putOptional(request, 'sourceSystemCode', input.sourceSystemCode);
    _putOptional(request, 'sourceRecordId', input.sourceRecordId);
    return _invoke(InterventionLegalCommandCallables.createMatter, request);
  }

  @override
  Future<InterventionLegalCommandResponse> transitionLegalMatter({
    required InterventionLegalMatterVersionContext context,
    required InterventionLegalTransitionInput input,
  }) {
    final request = _baseEnvelope()
      ..addAll(<String, dynamic>{
        'expectedVersion': _positiveVersion(
          context.expectedVersion,
          'expectedVersion',
        ),
        'legalMatterId': _required(context.legalMatterId, 'legalMatterId'),
        'nextStatus': _required(input.nextStatus, 'nextStatus'),
        'reasonCode': _required(input.reasonCode, 'reasonCode'),
      });
    _putOptional(request, 'note', input.note);
    return _invoke(InterventionLegalCommandCallables.transitionMatter, request);
  }

  @override
  Future<InterventionLegalCommandResponse> createApprovalRequest({
    required InterventionLegalApprovalRequestContext context,
    required InterventionLegalApprovalRequestInput input,
  }) {
    final request = _baseEnvelope()
      ..addAll(<String, dynamic>{
        'expectedLegalMatterVersion': _positiveVersion(
          context.expectedLegalMatterVersion,
          'expectedLegalMatterVersion',
        ),
        'legalMatterId': _required(context.legalMatterId, 'legalMatterId'),
        'approvalType': _required(input.approvalType, 'approvalType'),
        'requestReasonCode': _required(
          input.requestReasonCode,
          'requestReasonCode',
        ),
      });
    _putOptional(request, 'requestNote', input.requestNote);
    return _invoke(
      InterventionLegalCommandCallables.createApprovalRequest,
      request,
    );
  }

  @override
  Future<InterventionLegalCommandResponse> recordApprovalDecision({
    required InterventionLegalApprovalDecisionContext context,
    required InterventionLegalApprovalDecisionInput input,
  }) {
    final request = _baseEnvelope()
      ..addAll(<String, dynamic>{
        'expectedApprovalRequestVersion': _positiveVersion(
          context.expectedApprovalRequestVersion,
          'expectedApprovalRequestVersion',
        ),
        'approvalRequestId': _required(
          context.approvalRequestId,
          'approvalRequestId',
        ),
        'legalMatterId': _required(context.legalMatterId, 'legalMatterId'),
        'approvalType': _required(context.approvalType, 'approvalType'),
        'decision': _required(input.decision, 'decision'),
        'decisionReasonCode': _required(
          input.decisionReasonCode,
          'decisionReasonCode',
        ),
      });
    _putOptional(request, 'decisionNote', input.decisionNote);
    return _invoke(
      InterventionLegalCommandCallables.recordApprovalDecision,
      request,
    );
  }

  Map<String, dynamic> _baseEnvelope() {
    return <String, dynamic>{
      'contractVersion': interventionLegalCoreContractVersion,
      'requestId': _required(_requestIdFactory(), 'requestId'),
      'idempotencyKey': _required(_idempotencyKeyFactory(), 'idempotencyKey'),
    };
  }

  Future<InterventionLegalCommandResponse> _invoke(
    String name,
    Map<String, dynamic> request,
  ) async {
    await _ensureAppCheckReady();
    final response = await _call(name, request);
    return InterventionLegalCommandResponse.fromMap(response);
  }

  Future<Map<String, dynamic>> _call(
    String name,
    Map<String, dynamic> request,
  ) async {
    final injected = _callable;
    if (injected != null) {
      return injected(name, Map<String, dynamic>.unmodifiable(request));
    }

    final result = await _functions!.httpsCallable(name).call<dynamic>(request);
    return _map(result.data);
  }
}

String generateInterventionLegalRequestId() => _opaqueId('mhl-req');

String generateInterventionLegalIdempotencyKey() => _opaqueId('mhl-idem');

String _opaqueId(String prefix) {
  final micros = DateTime.now().toUtc().microsecondsSinceEpoch;
  final random = Random.secure().nextInt(1 << 30).toRadixString(16);
  return '$prefix-$micros-$random';
}

String _required(String value, String field) {
  final normalized = value.trim();
  if (normalized.isEmpty) {
    throw ArgumentError.value(value, field, '$field must not be blank');
  }
  return normalized;
}

int _positiveVersion(int value, String field) {
  if (value <= 0) {
    throw ArgumentError.value(value, field, '$field must be positive');
  }
  return value;
}

void _putOptional(Map<String, dynamic> request, String field, String? value) {
  final normalized = value?.trim();
  if (normalized != null && normalized.isNotEmpty) {
    request[field] = normalized;
  }
}

Map<String, dynamic> _map(Object? value) {
  if (value is! Map) {
    return <String, dynamic>{};
  }
  return value.map<String, dynamic>(
    (key, item) => MapEntry<String, dynamic>(key.toString(), item),
  );
}

String _string(Object? value) => value?.toString().trim() ?? '';

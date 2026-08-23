import 'dart:math';

import 'package:flutter/material.dart';

import '../domain/professional_service_models.dart';
import 'professional_services_controller.dart';
import 'professional_services_operation_form_strings.dart';
import 'professional_services_strings.dart';

enum _FormValueKind {
  text,
  positiveInteger,
  nonNegativeInteger,
  sha256,
  isoInstant,
  sourceReferenceField,
}

class _FieldSpec {
  const _FieldSpec(
    this.key, {
    this.required = true,
    this.multiline = false,
    this.kind = _FormValueKind.text,
  });

  final String key;
  final bool required;
  final bool multiline;
  final _FormValueKind kind;
}

class ProfessionalServicesOperationForm extends StatefulWidget {
  const ProfessionalServicesOperationForm({
    super.key,
    required this.operation,
    required this.controller,
    this.locale,
  });

  final ProfessionalServiceOperation operation;
  final ProfessionalServicesController controller;
  final Locale? locale;

  @override
  State<ProfessionalServicesOperationForm> createState() =>
      _ProfessionalServicesOperationFormState();
}

class _ProfessionalServicesOperationFormState
    extends State<ProfessionalServicesOperationForm> {
  static const Set<String> _sourceReferenceFields = <String>{
    'riskSignalId',
    'riskOperationId',
    'caseId',
    'evidenceRefId',
    'evidenceObjectId',
    'legalMatterId',
    'authorityActionId',
    'customsSubmissionId',
    'customsInterventionId',
  };

  static final RegExp _sha256 = RegExp(r'^[0-9a-fA-F]{64}$');

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _controllers =
      <String, TextEditingController>{};

  late final String _requestId;
  late final String _idempotencyKey;
  late final String _initialInstant;

  @override
  void initState() {
    super.initState();
    _requestId = _uuidV4();
    _idempotencyKey = 'pho-ui-${widget.operation.wireValue}-$_requestId';
    _initialInstant = DateTime.now().toUtc().toIso8601String();
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  TextEditingController _controller(String key) {
    return _controllers.putIfAbsent(
      key,
      () => TextEditingController(text: _initialValue(key)),
    );
  }

  String _initialValue(String key) {
    if (<String>{
      'requestedAt',
      'createdAt',
      'assignedAt',
      'startedAt',
      'generatedAt',
      'reviewedAt',
      'publishedAt',
    }.contains(key)) {
      return _initialInstant;
    }

    return switch (key) {
      'serviceCode' => 'legal_preliminary_assessment',
      'priority' => 'high',
      'jurisdictionCode' => 'tr',
      'sourceReferenceField' => 'caseId',
      'expectedVersion' => '1',
      'expectedServiceRequestVersion' => '1',
      'engagementMode' => 'matter_based',
      'assignmentSequence' => '1',
      'assignmentMode' => 'human_only',
      'billingModel' => 'quotation_required',
      'expectedAgentTaskVersion' =>
        widget.operation == ProfessionalServiceOperation.startAgentRun
            ? ''
            : '1',
      'runSequence' => '1',
      'agentCode' => 'legal_intake_triage',
      'agentVersion' => 'v1',
      'modelProvider' => 'openai',
      'promptTemplateVersion' => 'v1',
      'confidentialityClass' => 'client_confidential',
      'privilegeClaimStatus' => 'none',
      'decision' => 'approved',
      _ => '',
    };
  }

  @override
  Widget build(BuildContext context) {
    final operation = widget.operation;
    final pageStrings = ProfessionalServicesStrings.of(locale: widget.locale);
    final strings = ProfessionalServicesOperationFormStrings.of(widget.locale);
    final specs = _fieldsFor(operation);

    return Card(
      key: ValueKey('professional-service-command-form-${operation.wireValue}'),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                child: Text(
                  strings.formTitle,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                pageStrings.operationTitle(operation),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(strings.formDescription),
              const SizedBox(height: 12),
              _SecurityNotice(text: strings.securityNote),
              const SizedBox(height: 16),
              for (final spec in specs) ...[
                _buildField(context, strings, spec),
                const SizedBox(height: 12),
              ],
              _CommandIdentity(
                title: strings.generatedCommandIdentity,
                requestId: _requestId,
                idempotencyKey: _idempotencyKey,
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  key: ValueKey(
                    'professional-service-submit-${operation.wireValue}',
                  ),
                  onPressed: widget.controller.isRunning ? null : _submit,
                  icon: widget.controller.isRunning
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.play_arrow_rounded),
                  label: Text(
                    widget.controller.isRunning
                        ? strings.submitting
                        : strings.submit,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField(
    BuildContext context,
    ProfessionalServicesOperationFormStrings strings,
    _FieldSpec spec,
  ) {
    return TextFormField(
      key: ValueKey(
        'professional-service-field-${widget.operation.wireValue}-${spec.key}',
      ),
      controller: _controller(spec.key),
      minLines: spec.multiline ? 3 : 1,
      maxLines: spec.multiline ? 6 : 1,
      keyboardType:
          spec.kind == _FormValueKind.positiveInteger ||
              spec.kind == _FormValueKind.nonNegativeInteger
          ? TextInputType.number
          : TextInputType.text,
      decoration: InputDecoration(
        labelText: strings.field(spec.key),
        helperText: strings.helper(spec.key),
        border: const OutlineInputBorder(),
        alignLabelWithHint: spec.multiline,
      ),
      validator: (value) => _validate(strings, spec, value ?? ''),
    );
  }

  String? _validate(
    ProfessionalServicesOperationFormStrings strings,
    _FieldSpec spec,
    String raw,
  ) {
    final value = raw.trim();

    if (value.isEmpty) {
      return spec.required ? strings.requiredField : null;
    }

    switch (spec.kind) {
      case _FormValueKind.text:
        return null;
      case _FormValueKind.positiveInteger:
        final parsed = int.tryParse(value);
        if (parsed == null) return strings.invalidInteger;
        if (parsed <= 0) return strings.invalidPositiveInteger;
        return null;
      case _FormValueKind.nonNegativeInteger:
        final parsed = int.tryParse(value);
        if (parsed == null) return strings.invalidInteger;
        if (parsed < 0) return strings.invalidNonNegativeInteger;
        return null;
      case _FormValueKind.sha256:
        return _sha256.hasMatch(value) ? null : strings.invalidSha256;
      case _FormValueKind.isoInstant:
        return DateTime.tryParse(value) == null
            ? strings.invalidIsoInstant
            : null;
      case _FormValueKind.sourceReferenceField:
        return _sourceReferenceFields.contains(value)
            ? null
            : strings.invalidSourceReference;
    }
  }

  Future<void> _submit() async {
    if (widget.controller.isRunning) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final payload = _buildPayload(widget.operation);

    await widget.controller.execute(
      ProfessionalServiceCommand(operation: widget.operation, payload: payload),
    );
  }

  Map<String, Object?> _buildPayload(ProfessionalServiceOperation operation) {
    return switch (operation) {
      ProfessionalServiceOperation.createServiceRequest =>
        _createServiceRequestPayload(),
      ProfessionalServiceOperation.transitionServiceRequest =>
        _transitionServiceRequestPayload(),
      ProfessionalServiceOperation.createServiceEngagement =>
        _createServiceEngagementPayload(),
      ProfessionalServiceOperation.createServiceAssignment =>
        _createServiceAssignmentPayload(),
      ProfessionalServiceOperation.startAgentRun => _startAgentRunPayload(),
      ProfessionalServiceOperation.recordAgentOutput =>
        _recordAgentOutputPayload(),
      ProfessionalServiceOperation.recordAgentReview =>
        _recordAgentReviewPayload(),
      ProfessionalServiceOperation.publishAgentOutput =>
        _publishAgentOutputPayload(),
    };
  }

  Map<String, Object?> _envelope(String contractVersion) {
    return <String, Object?>{
      'contractVersion': contractVersion,
      'requestId': _requestId,
      'idempotencyKey': _idempotencyKey,
    };
  }

  Map<String, Object?> _createServiceRequestPayload() {
    return <String, Object?>{
      ..._envelope('professional-service-request-create-command-v1'),
      'serviceRequest': <String, Object?>{
        'contractVersion': 'professional-service-request-v1',
        'requestId': _requestId,
        'tenantId': _value('tenantId'),
        'canonicalBrandId': _value('canonicalBrandId'),
        'serviceCode': _value('serviceCode'),
        'priority': _value('priority'),
        'jurisdictionCode': _value('jurisdictionCode'),
        'sourceReferences': _sourceReferences(),
        'title': _value('title'),
        'objective': _value('objective'),
        'scope': _scope(),
        'requestedAt': _iso('requestedAt'),
      },
    };
  }

  Map<String, Object?> _transitionServiceRequestPayload() {
    final payload = <String, Object?>{
      ..._envelope('professional-service-request-transition-command-v1'),
      'serviceRequestId': _value('serviceRequestId'),
      'expectedVersion': _positiveInt('expectedVersion'),
      'nextStatus': _value('nextStatus'),
      'reasonCode': _value('reasonCode'),
    };
    _putOptional(payload, 'note', _value('note'));
    return payload;
  }

  Map<String, Object?> _createServiceEngagementPayload() {
    final engagement = <String, Object?>{
      'contractVersion': 'professional-service-engagement-v1',
      'serviceRequestId': _value('serviceRequestId'),
      'engagementMode': _value('engagementMode'),
      'scopeFingerprintSha256': _value('scopeFingerprintSha256').toLowerCase(),
      'clientAuthorizationId': _value('clientAuthorizationId'),
      'createdAt': _iso('createdAt'),
    };
    _putOptional(
      engagement,
      'budgetAuthorizationId',
      _value('budgetAuthorizationId'),
    );

    return <String, Object?>{
      ..._envelope('professional-service-engagement-create-command-v1'),
      'expectedServiceRequestVersion': _positiveInt(
        'expectedServiceRequestVersion',
      ),
      'serviceEngagement': engagement,
    };
  }

  Map<String, Object?> _createServiceAssignmentPayload() {
    final assignment = <String, Object?>{
      'contractVersion': 'professional-service-assignment-v1',
      'serviceRequestId': _value('serviceRequestId'),
      'serviceEngagementId': _value('serviceEngagementId'),
      'providerId': _value('providerId'),
      'assignmentMode': _value('assignmentMode'),
      'jurisdictionCode': _value('jurisdictionCode'),
      'scope': _scope(),
      'billingModel': _value('billingModel'),
      'assignedAt': _iso('assignedAt'),
    };
    _putOptional(assignment, 'supervisingUid', _value('supervisingUid'));
    _putOptional(assignment, 'currencyCode', _value('currencyCode'));
    _putOptionalInt(
      assignment,
      'estimatedAmountMinorUnits',
      _value('estimatedAmountMinorUnits'),
    );
    _putOptionalInt(
      assignment,
      'slaFirstResponseMinutes',
      _value('slaFirstResponseMinutes'),
    );
    _putOptionalInt(
      assignment,
      'slaCompletionMinutes',
      _value('slaCompletionMinutes'),
    );
    _putOptional(assignment, 'dueAt', _normalizedOptionalIso('dueAt'));

    return <String, Object?>{
      ..._envelope('professional-service-assignment-create-command-v1'),
      'expectedServiceRequestVersion': _positiveInt(
        'expectedServiceRequestVersion',
      ),
      'assignmentSequence': _positiveInt('assignmentSequence'),
      'serviceAssignment': assignment,
    };
  }

  Map<String, Object?> _startAgentRunPayload() {
    final payload = <String, Object?>{
      ..._envelope('professional-agent-run-start-command-v1'),
      'runSequence': _positiveInt('runSequence'),
      'agentRunRequest': <String, Object?>{
        'contractVersion': 'professional-agent-run-request-v1',
        'requestId': _requestId,
        'serviceRequestId': _value('serviceRequestId'),
        'agentCode': _value('agentCode'),
        'agentVersion': _value('agentVersion'),
        'modelProvider': _value('modelProvider'),
        'modelName': _value('modelName'),
        'modelVersion': _value('modelVersion'),
        'promptTemplateVersion': _value('promptTemplateVersion'),
        'supervisingUid': _value('supervisingUid'),
        'sourceReferences': _sourceReferences(),
        'inputManifestHashSha256': _value(
          'inputManifestHashSha256',
        ).toLowerCase(),
        'confidentialityClass': _value('confidentialityClass'),
        'privilegeClaimStatus': _value('privilegeClaimStatus'),
        'startedAt': _iso('startedAt'),
      },
    };

    _putOptionalInt(
      payload,
      'expectedAgentTaskVersion',
      _value('expectedAgentTaskVersion'),
    );
    final runRequest = payload['agentRunRequest']! as Map<String, Object?>;
    _putOptional(
      runRequest,
      'serviceAssignmentId',
      _value('serviceAssignmentId'),
    );
    return payload;
  }

  Map<String, Object?> _recordAgentOutputPayload() {
    return <String, Object?>{
      ..._envelope('professional-agent-output-record-command-v1'),
      'agentTaskId': _value('agentTaskId'),
      'expectedAgentTaskVersion': _positiveInt('expectedAgentTaskVersion'),
      'agentOutputDraft': <String, Object?>{
        'contractVersion': 'professional-agent-output-draft-v1',
        'agentRunId': _value('agentRunId'),
        'outputType': _value('outputType'),
        'outputHashSha256': _value('outputHashSha256').toLowerCase(),
        'outputBytes': _nonNegativeInt('outputBytes'),
        'sourceReferenceCount': _nonNegativeInt('sourceReferenceCount'),
        'confidenceLevel': _value('confidenceLevel'),
        'warningCodes': _list('warningCodes'),
        'generatedAt': _iso('generatedAt'),
      },
    };
  }

  Map<String, Object?> _recordAgentReviewPayload() {
    return <String, Object?>{
      ..._envelope('professional-agent-review-record-command-v1'),
      'agentTaskId': _value('agentTaskId'),
      'expectedAgentTaskVersion': _positiveInt('expectedAgentTaskVersion'),
      'agentHumanReview': <String, Object?>{
        'contractVersion': 'professional-agent-human-review-v1',
        'agentRunId': _value('agentRunId'),
        'outputDraftId': _value('outputDraftId'),
        'expectedDraftHashSha256': _value(
          'expectedDraftHashSha256',
        ).toLowerCase(),
        'decision': _value('decision'),
        'reviewNote': _value('reviewNote'),
        'reviewedAt': _iso('reviewedAt'),
      },
    };
  }

  Map<String, Object?> _publishAgentOutputPayload() {
    return <String, Object?>{
      ..._envelope('professional-agent-output-publish-command-v1'),
      'agentTaskId': _value('agentTaskId'),
      'expectedAgentTaskVersion': _positiveInt('expectedAgentTaskVersion'),
      'outputDraftId': _value('outputDraftId'),
      'humanReviewId': _value('humanReviewId'),
      'publishedArtifactId': _value('publishedArtifactId'),
      'publishedArtifactHashSha256': _value(
        'publishedArtifactHashSha256',
      ).toLowerCase(),
      'publishedAt': _iso('publishedAt'),
    };
  }

  Map<String, Object?> _sourceReferences() {
    return <String, Object?>{
      _value('sourceReferenceField'): _value('sourceReferenceId'),
    };
  }

  Map<String, Object?> _scope() {
    return <String, Object?>{
      'summary': _value('scopeSummary'),
      'inclusions': _list('scopeInclusions'),
      'exclusions': _list('scopeExclusions'),
    };
  }

  String _value(String key) => _controller(key).text.trim();

  int _positiveInt(String key) => int.parse(_value(key));

  int _nonNegativeInt(String key) => int.parse(_value(key));

  String _iso(String key) =>
      DateTime.parse(_value(key)).toUtc().toIso8601String();

  String? _normalizedOptionalIso(String key) {
    final value = _value(key);
    if (value.isEmpty) return null;
    return DateTime.parse(value).toUtc().toIso8601String();
  }

  List<String> _list(String key) {
    final value = _value(key);
    if (value.isEmpty) return const <String>[];
    return value
        .split(RegExp(r'[\n,]'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  void _putOptional(Map<String, Object?> target, String key, String? value) {
    if (value != null && value.trim().isNotEmpty) {
      target[key] = value.trim();
    }
  }

  void _putOptionalInt(Map<String, Object?> target, String key, String raw) {
    if (raw.trim().isNotEmpty) {
      target[key] = int.parse(raw.trim());
    }
  }

  List<_FieldSpec> _fieldsFor(ProfessionalServiceOperation operation) {
    return switch (operation) {
      ProfessionalServiceOperation.createServiceRequest => const <_FieldSpec>[
        _FieldSpec('tenantId'),
        _FieldSpec('canonicalBrandId'),
        _FieldSpec('serviceCode'),
        _FieldSpec('priority'),
        _FieldSpec('jurisdictionCode'),
        _FieldSpec(
          'sourceReferenceField',
          kind: _FormValueKind.sourceReferenceField,
        ),
        _FieldSpec('sourceReferenceId'),
        _FieldSpec('title'),
        _FieldSpec('objective', multiline: true),
        _FieldSpec('scopeSummary', multiline: true),
        _FieldSpec('scopeInclusions', required: false, multiline: true),
        _FieldSpec('scopeExclusions', required: false, multiline: true),
        _FieldSpec('requestedAt', kind: _FormValueKind.isoInstant),
      ],
      ProfessionalServiceOperation.transitionServiceRequest =>
        const <_FieldSpec>[
          _FieldSpec('serviceRequestId'),
          _FieldSpec('expectedVersion', kind: _FormValueKind.positiveInteger),
          _FieldSpec('nextStatus'),
          _FieldSpec('reasonCode'),
          _FieldSpec('note', required: false, multiline: true),
        ],
      ProfessionalServiceOperation.createServiceEngagement =>
        const <_FieldSpec>[
          _FieldSpec(
            'expectedServiceRequestVersion',
            kind: _FormValueKind.positiveInteger,
          ),
          _FieldSpec('serviceRequestId'),
          _FieldSpec('engagementMode'),
          _FieldSpec('scopeFingerprintSha256', kind: _FormValueKind.sha256),
          _FieldSpec('clientAuthorizationId'),
          _FieldSpec('budgetAuthorizationId', required: false),
          _FieldSpec('createdAt', kind: _FormValueKind.isoInstant),
        ],
      ProfessionalServiceOperation.createServiceAssignment =>
        const <_FieldSpec>[
          _FieldSpec(
            'expectedServiceRequestVersion',
            kind: _FormValueKind.positiveInteger,
          ),
          _FieldSpec(
            'assignmentSequence',
            kind: _FormValueKind.positiveInteger,
          ),
          _FieldSpec('serviceRequestId'),
          _FieldSpec('serviceEngagementId'),
          _FieldSpec('providerId'),
          _FieldSpec('assignmentMode'),
          _FieldSpec('supervisingUid', required: false),
          _FieldSpec('jurisdictionCode'),
          _FieldSpec('scopeSummary', multiline: true),
          _FieldSpec('scopeInclusions', required: false, multiline: true),
          _FieldSpec('scopeExclusions', required: false, multiline: true),
          _FieldSpec('billingModel'),
          _FieldSpec('currencyCode', required: false),
          _FieldSpec(
            'estimatedAmountMinorUnits',
            required: false,
            kind: _FormValueKind.nonNegativeInteger,
          ),
          _FieldSpec(
            'slaFirstResponseMinutes',
            required: false,
            kind: _FormValueKind.positiveInteger,
          ),
          _FieldSpec(
            'slaCompletionMinutes',
            required: false,
            kind: _FormValueKind.positiveInteger,
          ),
          _FieldSpec('dueAt', required: false, kind: _FormValueKind.isoInstant),
          _FieldSpec('assignedAt', kind: _FormValueKind.isoInstant),
        ],
      ProfessionalServiceOperation.startAgentRun => const <_FieldSpec>[
        _FieldSpec(
          'expectedAgentTaskVersion',
          required: false,
          kind: _FormValueKind.nonNegativeInteger,
        ),
        _FieldSpec('runSequence', kind: _FormValueKind.positiveInteger),
        _FieldSpec('serviceRequestId'),
        _FieldSpec('serviceAssignmentId', required: false),
        _FieldSpec('agentCode'),
        _FieldSpec('agentVersion'),
        _FieldSpec('modelProvider'),
        _FieldSpec('modelName'),
        _FieldSpec('modelVersion'),
        _FieldSpec('promptTemplateVersion'),
        _FieldSpec('supervisingUid'),
        _FieldSpec(
          'sourceReferenceField',
          kind: _FormValueKind.sourceReferenceField,
        ),
        _FieldSpec('sourceReferenceId'),
        _FieldSpec('inputManifestHashSha256', kind: _FormValueKind.sha256),
        _FieldSpec('confidentialityClass'),
        _FieldSpec('privilegeClaimStatus'),
        _FieldSpec('startedAt', kind: _FormValueKind.isoInstant),
      ],
      ProfessionalServiceOperation.recordAgentOutput => const <_FieldSpec>[
        _FieldSpec('agentTaskId'),
        _FieldSpec(
          'expectedAgentTaskVersion',
          kind: _FormValueKind.positiveInteger,
        ),
        _FieldSpec('agentRunId'),
        _FieldSpec('outputType'),
        _FieldSpec('outputHashSha256', kind: _FormValueKind.sha256),
        _FieldSpec('outputBytes', kind: _FormValueKind.nonNegativeInteger),
        _FieldSpec(
          'sourceReferenceCount',
          kind: _FormValueKind.nonNegativeInteger,
        ),
        _FieldSpec('confidenceLevel'),
        _FieldSpec('warningCodes', required: false, multiline: true),
        _FieldSpec('generatedAt', kind: _FormValueKind.isoInstant),
      ],
      ProfessionalServiceOperation.recordAgentReview => const <_FieldSpec>[
        _FieldSpec('agentTaskId'),
        _FieldSpec(
          'expectedAgentTaskVersion',
          kind: _FormValueKind.positiveInteger,
        ),
        _FieldSpec('agentRunId'),
        _FieldSpec('outputDraftId'),
        _FieldSpec('expectedDraftHashSha256', kind: _FormValueKind.sha256),
        _FieldSpec('decision'),
        _FieldSpec('reviewNote', multiline: true),
        _FieldSpec('reviewedAt', kind: _FormValueKind.isoInstant),
      ],
      ProfessionalServiceOperation.publishAgentOutput => const <_FieldSpec>[
        _FieldSpec('agentTaskId'),
        _FieldSpec(
          'expectedAgentTaskVersion',
          kind: _FormValueKind.positiveInteger,
        ),
        _FieldSpec('outputDraftId'),
        _FieldSpec('humanReviewId'),
        _FieldSpec('publishedArtifactId'),
        _FieldSpec('publishedArtifactHashSha256', kind: _FormValueKind.sha256),
        _FieldSpec('publishedAt', kind: _FormValueKind.isoInstant),
      ],
    };
  }

  static String _uuidV4() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;

    String two(int value) => value.toRadixString(16).padLeft(2, '0');
    final hex = bytes.map(two).join();
    return '${hex.substring(0, 8)}-'
        '${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-'
        '${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
  }
}

class _SecurityNotice extends StatelessWidget {
  const _SecurityNotice({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      key: const ValueKey('professional-services-form-security-note'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.verified_user_outlined,
            color: scheme.onSecondaryContainer,
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _CommandIdentity extends StatelessWidget {
  const _CommandIdentity({
    required this.title,
    required this.requestId,
    required this.idempotencyKey,
  });

  final String title;
  final String requestId;
  final String idempotencyKey;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall;
    return Container(
      key: const ValueKey('professional-services-generated-command-identity'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 6),
          SelectableText('requestId: $requestId', style: style),
          SelectableText('idempotencyKey: $idempotencyKey', style: style),
        ],
      ),
    );
  }
}

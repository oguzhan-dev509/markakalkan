import 'package:flutter/widgets.dart';

class ProfessionalServicesOperationFormStrings {
  const ProfessionalServicesOperationFormStrings._(this._english);

  final bool _english;

  static ProfessionalServicesOperationFormStrings of(Locale? locale) {
    final resolved =
        locale ?? WidgetsBinding.instance.platformDispatcher.locale;
    return ProfessionalServicesOperationFormStrings._(
      resolved.languageCode.toLowerCase() == 'en',
    );
  }

  String get formTitle =>
      _english ? 'Operational command form' : 'Operasyon komut formu';

  String get formDescription => _english
      ? 'Complete the fields required by the protected backend contract. '
            'Nothing is sent until you explicitly submit this form.'
      : 'Korumalı backend sözleşmesinin istediği alanları doldurun. '
            'Bu formu açıkça göndermeden hiçbir işlem çalıştırılmaz.';

  String get securityNote => _english
      ? 'User identity and immutable actor attribution are derived on the '
            'server from the authenticated session; they are never entered '
            'or sent by this form.'
      : 'Kullanıcı kimliği ve değiştirilemez işlem-atıf bilgileri sunucuda '
            'oturumdan türetilir; bu formda girilmez ve istemciden gönderilmez.';

  String get generatedCommandIdentity =>
      _english ? 'Generated command identity' : 'Üretilen komut kimliği';

  String get submit =>
      _english ? 'Submit protected command' : 'Korumalı komutu gönder';

  String get submitting => _english ? 'Submitting…' : 'Gönderiliyor…';

  String get requiredField =>
      _english ? 'This field is required.' : 'Bu alan zorunludur.';

  String get invalidInteger =>
      _english ? 'Enter a valid integer.' : 'Geçerli bir tam sayı girin.';

  String get invalidPositiveInteger => _english
      ? 'Enter an integer greater than zero.'
      : 'Sıfırdan büyük bir tam sayı girin.';

  String get invalidNonNegativeInteger => _english
      ? 'Enter zero or a positive integer.'
      : 'Sıfır veya pozitif bir tam sayı girin.';

  String get invalidSha256 => _english
      ? 'Enter a 64-character hexadecimal SHA-256 value.'
      : '64 karakterlik onaltılık SHA-256 değeri girin.';

  String get invalidIsoInstant => _english
      ? 'Enter a valid ISO-8601 date/time.'
      : 'Geçerli bir ISO-8601 tarih/saat değeri girin.';

  String get invalidSourceReference => _english
      ? 'Use one of the supported canonical source-reference fields.'
      : 'Desteklenen kanonik kaynak referansı alanlarından birini kullanın.';

  String field(String key) {
    final labels = _english ? _englishFields : _turkishFields;
    return labels[key] ?? key;
  }

  String? helper(String key) {
    final helpers = _english ? _englishHelpers : _turkishHelpers;
    return helpers[key];
  }

  static const Map<String, String> _turkishFields = <String, String>{
    'tenantId': 'Tenant kimliği',
    'canonicalBrandId': 'Kanonik marka kimliği',
    'serviceCode': 'Hizmet kodu',
    'priority': 'Öncelik kodu',
    'jurisdictionCode': 'Yetki alanı / ülke kodu',
    'sourceReferenceField': 'Kaynak referansı türü',
    'sourceReferenceId': 'Kaynak referansı kimliği',
    'title': 'Talep başlığı',
    'objective': 'Hizmet amacı',
    'scopeSummary': 'Kapsam özeti',
    'scopeInclusions': 'Kapsama dahil işler',
    'scopeExclusions': 'Kapsam dışı işler',
    'requestedAt': 'Talep zamanı (ISO-8601)',
    'serviceRequestId': 'Hizmet talebi kimliği',
    'expectedVersion': 'Beklenen talep sürümü',
    'nextStatus': 'Yeni durum kodu',
    'reasonCode': 'Geçiş gerekçe kodu',
    'note': 'Not',
    'expectedServiceRequestVersion': 'Beklenen hizmet talebi sürümü',
    'engagementMode': 'Angajman modu',
    'scopeFingerprintSha256': 'Kapsam SHA-256 parmak izi',
    'clientAuthorizationId': 'Müşteri kapsam yetki kaydı kimliği',
    'budgetAuthorizationId': 'Bütçe yetki kaydı kimliği',
    'createdAt': 'Angajman oluşturma zamanı (ISO-8601)',
    'assignmentSequence': 'Görevlendirme sıra numarası',
    'serviceEngagementId': 'Hizmet angajmanı kimliği',
    'providerId': 'Profesyonel / sağlayıcı kimliği',
    'assignmentMode': 'Görevlendirme modu',
    'supervisingUid': 'İnsan gözetmen UID',
    'billingModel': 'Ücretlendirme modeli',
    'currencyCode': 'Para birimi kodu',
    'estimatedAmountMinorUnits': 'Tahmini tutar (alt birim)',
    'slaFirstResponseMinutes': 'İlk yanıt SLA (dakika)',
    'slaCompletionMinutes': 'Tamamlama SLA (dakika)',
    'dueAt': 'Son tarih (ISO-8601)',
    'assignedAt': 'Görevlendirme zamanı (ISO-8601)',
    'expectedAgentTaskVersion': 'Beklenen ajan görevi sürümü',
    'runSequence': 'Ajan çalışma sıra numarası',
    'serviceAssignmentId': 'Hizmet görevlendirmesi kimliği',
    'agentCode': 'Ajan kodu',
    'agentVersion': 'Ajan sürümü',
    'modelProvider': 'Model sağlayıcısı kodu',
    'modelName': 'Model adı',
    'modelVersion': 'Model sürümü',
    'promptTemplateVersion': 'Prompt şablonu sürümü',
    'inputManifestHashSha256': 'Girdi manifesti SHA-256',
    'confidentialityClass': 'Gizlilik sınıfı',
    'privilegeClaimStatus': 'Hukuki imtiyaz / gizlilik iddiası',
    'startedAt': 'Ajan başlatma zamanı (ISO-8601)',
    'agentTaskId': 'Ajan görevi kimliği',
    'agentRunId': 'Ajan çalışma kimliği',
    'outputType': 'Çıktı türü kodu',
    'outputHashSha256': 'Çıktı SHA-256',
    'outputBytes': 'Çıktı boyutu (byte)',
    'sourceReferenceCount': 'Kaynak referansı sayısı',
    'confidenceLevel': 'Güven seviyesi kodu',
    'warningCodes': 'Uyarı kodları',
    'generatedAt': 'Çıktı üretim zamanı (ISO-8601)',
    'outputDraftId': 'Çıktı taslağı kimliği',
    'expectedDraftHashSha256': 'Beklenen taslak SHA-256',
    'decision': 'İnsan inceleme kararı',
    'reviewNote': 'İnceleme notu',
    'reviewedAt': 'İnceleme zamanı (ISO-8601)',
    'humanReviewId': 'İnsan inceleme kaydı kimliği',
    'publishedArtifactId': 'Yayımlanan artifact kimliği',
    'publishedArtifactHashSha256': 'Yayımlanan artifact SHA-256',
    'publishedAt': 'Yayın zamanı (ISO-8601)',
  };

  static const Map<String, String> _englishFields = <String, String>{
    'tenantId': 'Tenant ID',
    'canonicalBrandId': 'Canonical brand ID',
    'serviceCode': 'Service code',
    'priority': 'Priority code',
    'jurisdictionCode': 'Jurisdiction / country code',
    'sourceReferenceField': 'Source-reference type',
    'sourceReferenceId': 'Source-reference ID',
    'title': 'Request title',
    'objective': 'Service objective',
    'scopeSummary': 'Scope summary',
    'scopeInclusions': 'Scope inclusions',
    'scopeExclusions': 'Scope exclusions',
    'requestedAt': 'Requested at (ISO-8601)',
    'serviceRequestId': 'Service request ID',
    'expectedVersion': 'Expected request version',
    'nextStatus': 'Next status code',
    'reasonCode': 'Transition reason code',
    'note': 'Note',
    'expectedServiceRequestVersion': 'Expected service-request version',
    'engagementMode': 'Engagement mode',
    'scopeFingerprintSha256': 'Scope SHA-256 fingerprint',
    'clientAuthorizationId': 'Client scope authorization ID',
    'budgetAuthorizationId': 'Budget authorization ID',
    'createdAt': 'Engagement created at (ISO-8601)',
    'assignmentSequence': 'Assignment sequence',
    'serviceEngagementId': 'Service engagement ID',
    'providerId': 'Professional / provider ID',
    'assignmentMode': 'Assignment mode',
    'supervisingUid': 'Human supervisor UID',
    'billingModel': 'Billing model',
    'currencyCode': 'Currency code',
    'estimatedAmountMinorUnits': 'Estimated amount (minor units)',
    'slaFirstResponseMinutes': 'First-response SLA (minutes)',
    'slaCompletionMinutes': 'Completion SLA (minutes)',
    'dueAt': 'Due at (ISO-8601)',
    'assignedAt': 'Assigned at (ISO-8601)',
    'expectedAgentTaskVersion': 'Expected agent-task version',
    'runSequence': 'Agent-run sequence',
    'serviceAssignmentId': 'Service assignment ID',
    'agentCode': 'Agent code',
    'agentVersion': 'Agent version',
    'modelProvider': 'Model-provider code',
    'modelName': 'Model name',
    'modelVersion': 'Model version',
    'promptTemplateVersion': 'Prompt-template version',
    'inputManifestHashSha256': 'Input-manifest SHA-256',
    'confidentialityClass': 'Confidentiality class',
    'privilegeClaimStatus': 'Privilege-claim status',
    'startedAt': 'Agent started at (ISO-8601)',
    'agentTaskId': 'Agent task ID',
    'agentRunId': 'Agent run ID',
    'outputType': 'Output-type code',
    'outputHashSha256': 'Output SHA-256',
    'outputBytes': 'Output bytes',
    'sourceReferenceCount': 'Source-reference count',
    'confidenceLevel': 'Confidence-level code',
    'warningCodes': 'Warning codes',
    'generatedAt': 'Generated at (ISO-8601)',
    'outputDraftId': 'Output draft ID',
    'expectedDraftHashSha256': 'Expected draft SHA-256',
    'decision': 'Human-review decision',
    'reviewNote': 'Review note',
    'reviewedAt': 'Reviewed at (ISO-8601)',
    'humanReviewId': 'Human-review ID',
    'publishedArtifactId': 'Published artifact ID',
    'publishedArtifactHashSha256': 'Published artifact SHA-256',
    'publishedAt': 'Published at (ISO-8601)',
  };

  static const Map<String, String> _turkishHelpers = <String, String>{
    'serviceCode': 'Örnek: legal_preliminary_assessment',
    'priority': 'Backend sözleşmesindeki kodu girin. Örnek: high',
    'sourceReferenceField':
        'riskSignalId, riskOperationId, caseId, evidenceRefId, evidenceObjectId, '
        'legalMatterId, authorityActionId, customsSubmissionId veya '
        'customsInterventionId',
    'scopeInclusions': 'Birden çok değeri yeni satır veya virgülle ayırın.',
    'scopeExclusions': 'Birden çok değeri yeni satır veya virgülle ayırın.',
    'nextStatus': 'Talebin geçerli yaşam döngüsü durum kodunu girin.',
    'reasonCode': 'Denetlenebilir gerekçe kodu girin.',
    'engagementMode':
        'single_service, matter_based, ongoing_retainer veya emergency_response',
    'assignmentMode': 'human_only veya agent_assisted_human',
    'billingModel':
        'included_in_plan, fixed_fee, hourly, retainer, per_action, '
        'expense_reimbursement veya quotation_required',
    'warningCodes':
        'Boş bırakılabilir; değerleri yeni satır veya virgülle ayırın.',
    'decision': 'Backend insan inceleme karar kodu. Örnek: approved',
  };

  static const Map<String, String> _englishHelpers = <String, String>{
    'serviceCode': 'Example: legal_preliminary_assessment',
    'priority': 'Enter a backend contract code. Example: high',
    'sourceReferenceField':
        'riskSignalId, riskOperationId, caseId, evidenceRefId, evidenceObjectId, '
        'legalMatterId, authorityActionId, customsSubmissionId, or '
        'customsInterventionId',
    'scopeInclusions': 'Separate multiple values with commas or new lines.',
    'scopeExclusions': 'Separate multiple values with commas or new lines.',
    'nextStatus': 'Enter a valid service-request lifecycle status code.',
    'reasonCode': 'Enter an auditable reason code.',
    'engagementMode':
        'single_service, matter_based, ongoing_retainer, or emergency_response',
    'assignmentMode': 'human_only or agent_assisted_human',
    'billingModel':
        'included_in_plan, fixed_fee, hourly, retainer, per_action, '
        'expense_reimbursement, or quotation_required',
    'warningCodes': 'Optional; separate values with commas or new lines.',
    'decision': 'Backend human-review decision code. Example: approved',
  };
}

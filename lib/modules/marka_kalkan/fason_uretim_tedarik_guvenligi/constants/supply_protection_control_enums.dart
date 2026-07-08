enum SupplyProtectionControlType {
  identityVerification('identity_verification', 'Kimlik ve Kurumsal Doğrulama'),
  authorizationReview('authorization_review', 'Yetki ve Sözleşme Kontrolü'),
  facilityInspection('facility_inspection', 'Tesis Fiziksel Denetimi'),
  productionSecurity('production_security', 'Üretim Güvenliği Kontrolü'),
  capacityConsistency('capacity_consistency', 'Kapasite Tutarlılığı Kontrolü'),
  rawMaterialTraceability(
    'raw_material_traceability',
    'Hammadde İzlenebilirliği',
  ),
  packagingAndLabelSecurity(
    'packaging_and_label_security',
    'Ambalaj ve Etiket Güvenliği',
  ),
  shipmentSecurity('shipment_security', 'Sevkiyat Güvenliği'),
  destructionVerification('destruction_verification', 'İmha Doğrulaması'),
  subcontractorReview('subcontractor_review', 'Alt Yüklenici Kontrolü'),
  documentAndCertificateReview(
    'document_and_certificate_review',
    'Belge ve Sertifika Kontrolü',
  ),
  incidentFollowUp('incident_follow_up', 'Olay ve İhlal Takibi'),
  custom('custom', 'Özel Kontrol');

  const SupplyProtectionControlType(this.value, this.label);

  final String value;
  final String label;

  static SupplyProtectionControlType fromValue(String? value) {
    return SupplyProtectionControlType.values.firstWhere(
      (item) => item.value == value,
      orElse: () => SupplyProtectionControlType.custom,
    );
  }
}

enum SupplyProtectionControlScope {
  partner('partner', 'Partner'),
  facility('facility', 'Tesis'),
  partnerAndFacility('partner_and_facility', 'Partner ve Tesis');

  const SupplyProtectionControlScope(this.value, this.label);

  final String value;
  final String label;

  static SupplyProtectionControlScope fromValue(String? value) {
    return SupplyProtectionControlScope.values.firstWhere(
      (item) => item.value == value,
      orElse: () => SupplyProtectionControlScope.partner,
    );
  }
}

enum SupplyProtectionControlStatus {
  draft('draft', 'Taslak'),
  planned('planned', 'Planlandı'),
  inProgress('in_progress', 'Devam Ediyor'),
  completed('completed', 'Tamamlandı'),
  overdue('overdue', 'Gecikmiş'),
  cancelled('cancelled', 'İptal Edildi'),
  archived('archived', 'Arşivlendi');

  const SupplyProtectionControlStatus(this.value, this.label);

  final String value;
  final String label;

  static SupplyProtectionControlStatus fromValue(String? value) {
    return SupplyProtectionControlStatus.values.firstWhere(
      (item) => item.value == value,
      orElse: () => SupplyProtectionControlStatus.draft,
    );
  }
}

enum SupplyProtectionControlResult {
  notEvaluated('not_evaluated', 'Henüz Değerlendirilmedi'),
  passed('passed', 'Uygun'),
  passedWithObservation('passed_with_observation', 'Gözlemle Uygun'),
  failed('failed', 'Uygunsuz'),
  criticalFailure('critical_failure', 'Kritik Uygunsuzluk'),
  notApplicable('not_applicable', 'Uygulanamaz');

  const SupplyProtectionControlResult(this.value, this.label);

  final String value;
  final String label;

  static SupplyProtectionControlResult fromValue(String? value) {
    return SupplyProtectionControlResult.values.firstWhere(
      (item) => item.value == value,
      orElse: () => SupplyProtectionControlResult.notEvaluated,
    );
  }
}

enum SupplyProtectionControlRiskLevel {
  low('low', 'Düşük'),
  medium('medium', 'Orta'),
  high('high', 'Yüksek'),
  critical('critical', 'Kritik');

  const SupplyProtectionControlRiskLevel(this.value, this.label);

  final String value;
  final String label;

  static SupplyProtectionControlRiskLevel fromValue(String? value) {
    return SupplyProtectionControlRiskLevel.values.firstWhere(
      (item) => item.value == value,
      orElse: () => SupplyProtectionControlRiskLevel.medium,
    );
  }
}

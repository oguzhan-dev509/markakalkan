enum IpTradeSecretComponentType {
  ingredient('ingredient', 'İçerik veya Girdi'),
  proportion('proportion', 'Oran ve Miktar'),
  processStep('process_step', 'Proses Adımı'),
  processParameter('process_parameter', 'Proses Parametresi'),
  temperatureProfile('temperature_profile', 'Sıcaklık Profili'),
  timingProfile('timing_profile', 'Zamanlama Profili'),
  equipmentSetting('equipment_setting', 'Makine veya Ekipman Ayarı'),
  qualityCriterion('quality_criterion', 'Kalite Kriteri'),
  testMethod('test_method', 'Test ve Analiz Yöntemi'),
  softwareModule('software_module', 'Yazılım Modülü'),
  algorithmStage('algorithm_stage', 'Algoritma Aşaması'),
  datasetSegment('dataset_segment', 'Veri Seti Bölümü'),
  supplierInput('supplier_input', 'Tedarikçi Girdisi'),
  commercialParameter('commercial_parameter', 'Ticari Parametre'),
  other('other', 'Diğer Bileşen');

  const IpTradeSecretComponentType(this.value, this.label);

  final String value;
  final String label;

  static IpTradeSecretComponentType fromValue(String? value) {
    return IpTradeSecretComponentType.values.firstWhere(
      (item) => item.value == value,
      orElse: () => IpTradeSecretComponentType.other,
    );
  }
}

enum IpTradeSecretComponentStatus {
  draft('draft', 'Taslak'),
  active('active', 'Aktif'),
  underReview('under_review', 'İncelemede'),
  suspended('suspended', 'Askıda'),
  compromised('compromised', 'Sızıntı veya İhlal Şüphesi'),
  retired('retired', 'Kullanımdan Kaldırıldı');

  const IpTradeSecretComponentStatus(this.value, this.label);

  final String value;
  final String label;

  static IpTradeSecretComponentStatus fromValue(String? value) {
    return IpTradeSecretComponentStatus.values.firstWhere(
      (item) => item.value == value,
      orElse: () => IpTradeSecretComponentStatus.draft,
    );
  }
}

enum IpTradeSecretComponentCriticality {
  low('low', 'Düşük'),
  medium('medium', 'Orta'),
  high('high', 'Yüksek'),
  critical('critical', 'Kritik');

  const IpTradeSecretComponentCriticality(this.value, this.label);

  final String value;
  final String label;

  static IpTradeSecretComponentCriticality fromValue(String? value) {
    return IpTradeSecretComponentCriticality.values.firstWhere(
      (item) => item.value == value,
      orElse: () => IpTradeSecretComponentCriticality.medium,
    );
  }
}

enum IpTradeSecretComponentStorageMode {
  metadataOnly('metadata_only', 'Yalnız Metaveri'),
  encryptedVault('encrypted_vault', 'Şifreli Kasa'),
  externalSecureSystem('external_secure_system', 'Harici Güvenli Sistem'),
  splitKnowledge('split_knowledge', 'Bölünmüş Bilgi'),
  offlineCustody('offline_custody', 'Çevrimdışı Muhafaza');

  const IpTradeSecretComponentStorageMode(this.value, this.label);

  final String value;
  final String label;

  static IpTradeSecretComponentStorageMode fromValue(String? value) {
    return IpTradeSecretComponentStorageMode.values.firstWhere(
      (item) => item.value == value,
      orElse: () => IpTradeSecretComponentStorageMode.metadataOnly,
    );
  }
}

enum IpTradeSecretAccessSubjectType {
  user('user', 'Kullanıcı'),
  employee('employee', 'Çalışan'),
  department('department', 'Departman'),
  role('role', 'Rol'),
  contractor('contractor', 'Yüklenici'),
  consultant('consultant', 'Danışman'),
  supplier('supplier', 'Tedarikçi'),
  distributor('distributor', 'Distribütör'),
  businessPartner('business_partner', 'İş Ortağı'),
  externalOrganization('external_organization', 'Harici Kuruluş'),
  serviceAccount('service_account', 'Servis Hesabı'),
  other('other', 'Diğer');

  const IpTradeSecretAccessSubjectType(this.value, this.label);

  final String value;
  final String label;

  static IpTradeSecretAccessSubjectType fromValue(String? value) {
    return IpTradeSecretAccessSubjectType.values.firstWhere(
      (item) => item.value == value,
      orElse: () => IpTradeSecretAccessSubjectType.other,
    );
  }
}

enum IpTradeSecretAccessGrantStatus {
  draft('draft', 'Taslak'),
  pendingApproval('pending_approval', 'Onay Bekliyor'),
  active('active', 'Aktif'),
  suspended('suspended', 'Askıda'),
  expired('expired', 'Süresi Doldu'),
  revoked('revoked', 'İptal Edildi'),
  rejected('rejected', 'Reddedildi');

  const IpTradeSecretAccessGrantStatus(this.value, this.label);

  final String value;
  final String label;

  static IpTradeSecretAccessGrantStatus fromValue(String? value) {
    return IpTradeSecretAccessGrantStatus.values.firstWhere(
      (item) => item.value == value,
      orElse: () => IpTradeSecretAccessGrantStatus.draft,
    );
  }
}

enum IpTradeSecretAccessGrantBasis {
  ownership('ownership', 'Hak Sahipliği'),
  employment('employment', 'İş İlişkisi'),
  confidentialityAgreement('confidentiality_agreement', 'Gizlilik Sözleşmesi'),
  serviceAgreement('service_agreement', 'Hizmet Sözleşmesi'),
  supplierAgreement('supplier_agreement', 'Tedarikçi Sözleşmesi'),
  partnershipAgreement('partnership_agreement', 'Ortaklık Sözleşmesi'),
  legalObligation('legal_obligation', 'Hukuki Yükümlülük'),
  managementApproval('management_approval', 'Yönetim Onayı'),
  emergencyAccess('emergency_access', 'Acil Durum Erişimi'),
  other('other', 'Diğer Dayanak');

  const IpTradeSecretAccessGrantBasis(this.value, this.label);

  final String value;
  final String label;

  static IpTradeSecretAccessGrantBasis fromValue(String? value) {
    return IpTradeSecretAccessGrantBasis.values.firstWhere(
      (item) => item.value == value,
      orElse: () => IpTradeSecretAccessGrantBasis.other,
    );
  }
}

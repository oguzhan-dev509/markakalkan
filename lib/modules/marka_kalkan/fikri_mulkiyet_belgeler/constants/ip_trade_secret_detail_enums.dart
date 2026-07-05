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

enum IpTradeSecretDisclosureRecipientType {
  employee('employee', 'Çalışan'),
  department('department', 'Departman'),
  contractor('contractor', 'Yüklenici'),
  consultant('consultant', 'Danışman'),
  supplier('supplier', 'Tedarikçi'),
  distributor('distributor', 'Distribütör'),
  businessPartner('business_partner', 'İş Ortağı'),
  customer('customer', 'Müşteri'),
  investor('investor', 'Yatırımcı'),
  auditor('auditor', 'Denetçi'),
  regulator('regulator', 'Düzenleyici Kurum'),
  court('court', 'Mahkeme'),
  lawEnforcement('law_enforcement', 'Kolluk Birimi'),
  externalOrganization('external_organization', 'Harici Kuruluş'),
  publicAudience('public_audience', 'Kamuya Açık Kitle'),
  other('other', 'Diğer');

  const IpTradeSecretDisclosureRecipientType(this.value, this.label);

  final String value;
  final String label;

  static IpTradeSecretDisclosureRecipientType fromValue(String? value) {
    return IpTradeSecretDisclosureRecipientType.values.firstWhere(
      (item) => item.value == value,
      orElse: () => IpTradeSecretDisclosureRecipientType.other,
    );
  }
}

enum IpTradeSecretDisclosureStatus {
  draft('draft', 'Taslak'),
  pendingApproval('pending_approval', 'Onay Bekliyor'),
  approved('approved', 'Onaylandı'),
  completed('completed', 'Tamamlandı'),
  rejected('rejected', 'Reddedildi'),
  cancelled('cancelled', 'İptal Edildi'),
  disputed('disputed', 'İhtilaflı'),
  recalled('recalled', 'Geri Çağrıldı');

  const IpTradeSecretDisclosureStatus(this.value, this.label);

  final String value;
  final String label;

  static IpTradeSecretDisclosureStatus fromValue(String? value) {
    return IpTradeSecretDisclosureStatus.values.firstWhere(
      (item) => item.value == value,
      orElse: () => IpTradeSecretDisclosureStatus.draft,
    );
  }
}

enum IpTradeSecretDisclosureChannel {
  securePortal('secure_portal', 'Güvenli Portal'),
  encryptedEmail('encrypted_email', 'Şifreli E-posta'),
  physicalDocument('physical_document', 'Fiziksel Belge'),
  secureDataRoom('secure_data_room', 'Güvenli Veri Odası'),
  controlledMeeting('controlled_meeting', 'Kontrollü Toplantı'),
  videoConference('video_conference', 'Video Konferans'),
  apiTransfer('api_transfer', 'API Aktarımı'),
  removableMedia('removable_media', 'Taşınabilir Medya'),
  courier('courier', 'Kurye'),
  legalSubmission('legal_submission', 'Hukuki Makama Sunum'),
  regulatorySubmission('regulatory_submission', 'Düzenleyici Kuruma Sunum'),
  publicPublication('public_publication', 'Kamuya Açık Yayın'),
  verbal('verbal', 'Sözlü Açıklama'),
  other('other', 'Diğer Kanal');

  const IpTradeSecretDisclosureChannel(this.value, this.label);

  final String value;
  final String label;

  static IpTradeSecretDisclosureChannel fromValue(String? value) {
    return IpTradeSecretDisclosureChannel.values.firstWhere(
      (item) => item.value == value,
      orElse: () => IpTradeSecretDisclosureChannel.other,
    );
  }
}

enum IpTradeSecretDisclosurePurpose {
  manufacturing('manufacturing', 'Üretim'),
  productDevelopment('product_development', 'Ürün Geliştirme'),
  researchAndDevelopment('research_and_development', 'Araştırma ve Geliştirme'),
  qualityControl('quality_control', 'Kalite Kontrol'),
  procurement('procurement', 'Tedarik'),
  distribution('distribution', 'Dağıtım'),
  licensing('licensing', 'Lisanslama'),
  investmentReview('investment_review', 'Yatırım İncelemesi'),
  dueDiligence('due_diligence', 'Durum Tespiti'),
  audit('audit', 'Denetim'),
  legalProceeding('legal_proceeding', 'Hukuki Süreç'),
  regulatoryCompliance('regulatory_compliance', 'Mevzuata Uyum'),
  incidentResponse('incident_response', 'Olay Müdahalesi'),
  emergency('emergency', 'Acil Durum'),
  other('other', 'Diğer Amaç');

  const IpTradeSecretDisclosurePurpose(this.value, this.label);

  final String value;
  final String label;

  static IpTradeSecretDisclosurePurpose fromValue(String? value) {
    return IpTradeSecretDisclosurePurpose.values.firstWhere(
      (item) => item.value == value,
      orElse: () => IpTradeSecretDisclosurePurpose.other,
    );
  }
}

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

enum IpTradeSecretIncidentType {
  unauthorizedAccess('unauthorized_access', 'Yetkisiz Erişim'),
  suspectedLeak('suspected_leak', 'Sızıntı Şüphesi'),
  confirmedLeak('confirmed_leak', 'Teyitli Sızıntı'),
  wrongRecipient('wrong_recipient', 'Yanlış Alıcıya Gönderim'),
  lostDocument('lost_document', 'Kayıp Belge'),
  lostDevice('lost_device', 'Kayıp Cihaz'),
  stolenDevice('stolen_device', 'Çalınan Cihaz'),
  credentialCompromise('credential_compromise', 'Kimlik Bilgisi İhlali'),
  malware('malware', 'Zararlı Yazılım'),
  phishing('phishing', 'Kimlik Avı'),
  insiderThreat('insider_threat', 'İçeriden Tehdit'),
  contractBreach('contract_breach', 'Sözleşme İhlali'),
  ndaBreach('nda_breach', 'Gizlilik Sözleşmesi İhlali'),
  supplierBreach('supplier_breach', 'Tedarikçi İhlali'),
  unauthorizedCopy('unauthorized_copy', 'Yetkisiz Kopyalama'),
  unauthorizedExport('unauthorized_export', 'Yetkisiz Dışa Aktarım'),
  unauthorizedDisclosure('unauthorized_disclosure', 'Yetkisiz Açıklama'),
  publicExposure('public_exposure', 'Kamuya Açık Maruziyet'),
  physicalSecurityBreach(
    'physical_security_breach',
    'Fiziksel Güvenlik İhlali',
  ),
  processViolation('process_violation', 'Süreç İhlali'),
  other('other', 'Diğer');

  const IpTradeSecretIncidentType(this.value, this.label);

  final String value;
  final String label;

  static IpTradeSecretIncidentType fromValue(String? value) {
    return IpTradeSecretIncidentType.values.firstWhere(
      (item) => item.value == value,
      orElse: () => IpTradeSecretIncidentType.other,
    );
  }
}

enum IpTradeSecretIncidentStatus {
  reported('reported', 'Bildirildi'),
  triage('triage', 'Ön Değerlendirme'),
  investigating('investigating', 'İnceleniyor'),
  contained('contained', 'Kontrol Altına Alındı'),
  remediating('remediating', 'Gideriliyor'),
  monitoring('monitoring', 'İzleniyor'),
  resolved('resolved', 'Çözüldü'),
  closed('closed', 'Kapatıldı'),
  falsePositive('false_positive', 'Yanlış Alarm'),
  escalated('escalated', 'Üst Seviyeye Taşındı'),
  legalAction('legal_action', 'Hukuki Süreçte');

  const IpTradeSecretIncidentStatus(this.value, this.label);

  final String value;
  final String label;

  static IpTradeSecretIncidentStatus fromValue(String? value) {
    return IpTradeSecretIncidentStatus.values.firstWhere(
      (item) => item.value == value,
      orElse: () => IpTradeSecretIncidentStatus.reported,
    );
  }
}

enum IpTradeSecretIncidentSeverity {
  informational('informational', 'Bilgilendirme', 0),
  low('low', 'Düşük', 1),
  medium('medium', 'Orta', 2),
  high('high', 'Yüksek', 3),
  critical('critical', 'Kritik', 4);

  const IpTradeSecretIncidentSeverity(this.value, this.label, this.level);

  final String value;
  final String label;
  final int level;

  static IpTradeSecretIncidentSeverity fromValue(String? value) {
    return IpTradeSecretIncidentSeverity.values.firstWhere(
      (item) => item.value == value,
      orElse: () => IpTradeSecretIncidentSeverity.medium,
    );
  }
}

enum IpTradeSecretIncidentSource {
  employeeReport('employee_report', 'Çalışan Bildirimi'),
  managerReport('manager_report', 'Yönetici Bildirimi'),
  auditFinding('audit_finding', 'Denetim Bulgusu'),
  accessLog('access_log', 'Erişim Kaydı'),
  securityTool('security_tool', 'Güvenlik Aracı'),
  dataLossPrevention('data_loss_prevention', 'Veri Kaybı Önleme Sistemi'),
  customerReport('customer_report', 'Müşteri Bildirimi'),
  supplierReport('supplier_report', 'Tedarikçi Bildirimi'),
  anonymousReport('anonymous_report', 'Anonim Bildirim'),
  legalNotice('legal_notice', 'Hukuki Bildirim'),
  regulatorNotice('regulator_notice', 'Düzenleyici Kurum Bildirimi'),
  mediaMonitoring('media_monitoring', 'Medya İzleme'),
  digitalMarketMonitoring('digital_market_monitoring', 'Dijital Pazar İzleme'),
  fieldInvestigation('field_investigation', 'Saha Araştırması'),
  threatIntelligence('threat_intelligence', 'Tehdit İstihbaratı'),
  other('other', 'Diğer Kaynak');

  const IpTradeSecretIncidentSource(this.value, this.label);

  final String value;
  final String label;

  static IpTradeSecretIncidentSource fromValue(String? value) {
    return IpTradeSecretIncidentSource.values.firstWhere(
      (item) => item.value == value,
      orElse: () => IpTradeSecretIncidentSource.other,
    );
  }
}

enum IpTradeSecretProtectionControlType {
  preventive('preventive', 'Önleyici'),
  detective('detective', 'Tespit Edici'),
  corrective('corrective', 'Düzeltici'),
  deterrent('deterrent', 'Caydırıcı'),
  compensating('compensating', 'Telafi Edici'),
  recovery('recovery', 'Kurtarma'),
  monitoring('monitoring', 'İzleme'),
  governance('governance', 'Yönetişim'),
  other('other', 'Diğer');

  const IpTradeSecretProtectionControlType(this.value, this.label);

  final String value;
  final String label;

  static IpTradeSecretProtectionControlType fromValue(String? value) {
    return IpTradeSecretProtectionControlType.values.firstWhere(
      (item) => item.value == value,
      orElse: () => IpTradeSecretProtectionControlType.other,
    );
  }
}

enum IpTradeSecretProtectionControlStatus {
  planned('planned', 'Planlandı'),
  implementing('implementing', 'Uygulanıyor'),
  active('active', 'Aktif'),
  partiallyEffective('partially_effective', 'Kısmen Etkili'),
  ineffective('ineffective', 'Etkisiz'),
  suspended('suspended', 'Askıda'),
  retired('retired', 'Kullanımdan Kaldırıldı'),
  remediationRequired('remediation_required', 'İyileştirme Gerekli');

  const IpTradeSecretProtectionControlStatus(this.value, this.label);

  final String value;
  final String label;

  static IpTradeSecretProtectionControlStatus fromValue(String? value) {
    return IpTradeSecretProtectionControlStatus.values.firstWhere(
      (item) => item.value == value,
      orElse: () => IpTradeSecretProtectionControlStatus.planned,
    );
  }
}

enum IpTradeSecretProtectionControlCategory {
  accessControl('access_control', 'Erişim Kontrolü'),
  identityManagement('identity_management', 'Kimlik Yönetimi'),
  encryption('encryption', 'Şifreleme'),
  dataLossPrevention('data_loss_prevention', 'Veri Kaybı Önleme'),
  loggingMonitoring('logging_monitoring', 'Kayıt ve İzleme'),
  physicalSecurity('physical_security', 'Fiziksel Güvenlik'),
  personnelSecurity('personnel_security', 'Personel Güvenliği'),
  contractualProtection('contractual_protection', 'Sözleşmesel Koruma'),
  supplierSecurity('supplier_security', 'Tedarikçi Güvenliği'),
  secureDevelopment('secure_development', 'Güvenli Geliştirme'),
  backupRecovery('backup_recovery', 'Yedekleme ve Kurtarma'),
  incidentResponse('incident_response', 'Olay Müdahalesi'),
  classificationHandling(
    'classification_handling',
    'Sınıflandırma ve Kullanım',
  ),
  retentionDestruction('retention_destruction', 'Saklama ve İmha'),
  awarenessTraining('awareness_training', 'Farkındalık Eğitimi'),
  auditCompliance('audit_compliance', 'Denetim ve Uyum'),
  other('other', 'Diğer');

  const IpTradeSecretProtectionControlCategory(this.value, this.label);

  final String value;
  final String label;

  static IpTradeSecretProtectionControlCategory fromValue(String? value) {
    return IpTradeSecretProtectionControlCategory.values.firstWhere(
      (item) => item.value == value,
      orElse: () => IpTradeSecretProtectionControlCategory.other,
    );
  }
}

enum IpTradeSecretProtectionControlFrequency {
  continuous('continuous', 'Sürekli'),
  daily('daily', 'Günlük'),
  weekly('weekly', 'Haftalık'),
  monthly('monthly', 'Aylık'),
  quarterly('quarterly', 'Üç Aylık'),
  semiAnnual('semi_annual', 'Altı Aylık'),
  annual('annual', 'Yıllık'),
  eventDriven('event_driven', 'Olaya Bağlı'),
  onDemand('on_demand', 'İhtiyaç Halinde'),
  oneTime('one_time', 'Tek Seferlik'),
  notApplicable('not_applicable', 'Uygulanamaz');

  const IpTradeSecretProtectionControlFrequency(this.value, this.label);

  final String value;
  final String label;

  static IpTradeSecretProtectionControlFrequency fromValue(String? value) {
    return IpTradeSecretProtectionControlFrequency.values.firstWhere(
      (item) => item.value == value,
      orElse: () => IpTradeSecretProtectionControlFrequency.notApplicable,
    );
  }
}

enum IpTradeSecretRiskAssessmentStatus {
  draft('draft', 'Taslak'),
  inReview('in_review', 'İncelemede'),
  approved('approved', 'Onaylandı'),
  active('active', 'Aktif'),
  mitigating('mitigating', 'İyileştiriliyor'),
  accepted('accepted', 'Risk Kabul Edildi'),
  closed('closed', 'Kapatıldı'),
  archived('archived', 'Arşivlendi');

  const IpTradeSecretRiskAssessmentStatus(this.value, this.label);

  final String value;
  final String label;

  static IpTradeSecretRiskAssessmentStatus fromValue(String? value) {
    return IpTradeSecretRiskAssessmentStatus.values.firstWhere(
      (item) => item.value == value,
      orElse: () => IpTradeSecretRiskAssessmentStatus.draft,
    );
  }
}

enum IpTradeSecretRiskLevel {
  informational('informational', 'Bilgilendirme', 0),
  low('low', 'Düşük', 1),
  medium('medium', 'Orta', 2),
  high('high', 'Yüksek', 3),
  critical('critical', 'Kritik', 4);

  const IpTradeSecretRiskLevel(this.value, this.label, this.level);

  final String value;
  final String label;
  final int level;

  static IpTradeSecretRiskLevel fromValue(String? value) {
    return IpTradeSecretRiskLevel.values.firstWhere(
      (item) => item.value == value,
      orElse: () => IpTradeSecretRiskLevel.medium,
    );
  }
}

enum IpTradeSecretThreatCategory {
  insiderThreat('insider_threat', 'İçeriden Tehdit'),
  externalAttack('external_attack', 'Harici Saldırı'),
  unauthorizedAccess('unauthorized_access', 'Yetkisiz Erişim'),
  accidentalDisclosure('accidental_disclosure', 'Kazara Açıklama'),
  cyberAttack('cyber_attack', 'Siber Saldırı'),
  malwareRansomware(
    'malware_ransomware',
    'Zararlı Yazılım veya Fidye Yazılımı',
  ),
  physicalLossTheft('physical_loss_theft', 'Fiziksel Kayıp veya Hırsızlık'),
  supplierThirdParty('supplier_third_party', 'Tedarikçi veya Üçüncü Taraf'),
  contractualFailure('contractual_failure', 'Sözleşmesel Koruma Eksikliği'),
  processFailure('process_failure', 'Süreç Hatası'),
  humanError('human_error', 'İnsan Hatası'),
  competitiveIntelligence('competitive_intelligence', 'Rakip İstihbaratı'),
  technologyObsolescence('technology_obsolescence', 'Teknoloji Eskimesi'),
  backupRecoveryFailure(
    'backup_recovery_failure',
    'Yedekleme veya Kurtarma Hatası',
  ),
  disasterBusinessInterruption(
    'disaster_business_interruption',
    'Afet veya İş Kesintisi',
  ),
  legalRegulatory('legal_regulatory', 'Hukuki veya Düzenleyici'),
  other('other', 'Diğer');

  const IpTradeSecretThreatCategory(this.value, this.label);

  final String value;
  final String label;

  static IpTradeSecretThreatCategory fromValue(String? value) {
    return IpTradeSecretThreatCategory.values.firstWhere(
      (item) => item.value == value,
      orElse: () => IpTradeSecretThreatCategory.other,
    );
  }
}

enum IpTradeSecretGapStatus {
  none('none', 'Açık Yok'),
  identified('identified', 'Açık Tespit Edildi'),
  planned('planned', 'İyileştirme Planlandı'),
  remediationInProgress('remediation_in_progress', 'İyileştirme Sürüyor'),
  mitigated('mitigated', 'Açık Giderildi'),
  accepted('accepted', 'Açık Kabul Edildi'),
  overdue('overdue', 'Süresi Geçti'),
  closed('closed', 'Kapatıldı');

  const IpTradeSecretGapStatus(this.value, this.label);

  final String value;
  final String label;

  static IpTradeSecretGapStatus fromValue(String? value) {
    return IpTradeSecretGapStatus.values.firstWhere(
      (item) => item.value == value,
      orElse: () => IpTradeSecretGapStatus.none,
    );
  }
}

enum IpTradeSecretResilienceProfileStatus {
  draft('draft', 'Taslak'),
  inReview('in_review', 'İncelemede'),
  approved('approved', 'Onaylandı'),
  active('active', 'Aktif'),
  improvementRequired('improvement_required', 'İyileştirme Gerekli'),
  suspended('suspended', 'Askıya Alındı'),
  superseded('superseded', 'Yeni Sürümle Değiştirildi'),
  archived('archived', 'Arşivlendi');

  const IpTradeSecretResilienceProfileStatus(this.value, this.label);

  final String value;
  final String label;

  static IpTradeSecretResilienceProfileStatus fromValue(String? value) {
    return IpTradeSecretResilienceProfileStatus.values.firstWhere(
      (item) => item.value == value,
      orElse: () => IpTradeSecretResilienceProfileStatus.draft,
    );
  }
}

enum IpTradeSecretResilienceLevel {
  fragile('fragile', 'Kırılgan', 0),
  weak('weak', 'Zayıf', 1),
  developing('developing', 'Gelişiyor', 2),
  resilient('resilient', 'Dayanıklı', 3),
  advanced('advanced', 'İleri', 4);

  const IpTradeSecretResilienceLevel(this.value, this.label, this.level);

  final String value;
  final String label;
  final int level;

  static IpTradeSecretResilienceLevel fromValue(String? value) {
    return IpTradeSecretResilienceLevel.values.firstWhere(
      (item) => item.value == value,
      orElse: () => IpTradeSecretResilienceLevel.developing,
    );
  }
}

enum IpTradeSecretReviewType {
  initial('initial', 'İlk İnceleme'),
  periodic('periodic', 'Periyodik İnceleme'),
  eventDriven('event_driven', 'Olay Tetiklemeli İnceleme'),
  incidentDriven('incident_driven', 'İhlal Sonrası İnceleme'),
  controlChange('control_change', 'Kontrol Değişikliği İncelemesi'),
  ownershipChange('ownership_change', 'Sahiplik Değişikliği İncelemesi'),
  regulatoryChange('regulatory_change', 'Mevzuat Değişikliği İncelemesi'),
  closure('closure', 'Kapanış İncelemesi');

  const IpTradeSecretReviewType(this.value, this.label);

  final String value;
  final String label;

  static IpTradeSecretReviewType fromValue(String? value) {
    return IpTradeSecretReviewType.values.firstWhere(
      (item) => item.value == value,
      orElse: () => IpTradeSecretReviewType.periodic,
    );
  }
}

enum IpTradeSecretMaturityLevel {
  initial('initial', 'Başlangıç', 0),
  repeatable('repeatable', 'Tekrarlanabilir', 1),
  defined('defined', 'Tanımlı', 2),
  managed('managed', 'Yönetilen', 3),
  optimized('optimized', 'Optimize', 4);

  const IpTradeSecretMaturityLevel(this.value, this.label, this.level);

  final String value;
  final String label;
  final int level;

  static IpTradeSecretMaturityLevel fromValue(String? value) {
    return IpTradeSecretMaturityLevel.values.firstWhere(
      (item) => item.value == value,
      orElse: () => IpTradeSecretMaturityLevel.initial,
    );
  }
}

enum IpTradeSecretDefensibilityStatus {
  draft('draft', 'Taslak'),
  evidenceCollection('evidence_collection', 'Kanıt Toplanıyor'),
  inReview('in_review', 'İncelemede'),
  approved('approved', 'Onaylandı'),
  active('active', 'Aktif'),
  remediationRequired('remediation_required', 'Eksik Giderme Gerekli'),
  litigationHold('litigation_hold', 'Hukuki Muhafaza'),
  closed('closed', 'Kapatıldı'),
  archived('archived', 'Arşivlendi');

  const IpTradeSecretDefensibilityStatus(this.value, this.label);

  final String value;
  final String label;

  static IpTradeSecretDefensibilityStatus fromValue(String? value) {
    return IpTradeSecretDefensibilityStatus.values.firstWhere(
      (item) => item.value == value,
      orElse: () => IpTradeSecretDefensibilityStatus.draft,
    );
  }
}

enum IpTradeSecretEvidenceCategory {
  ownership('ownership', 'Hak Sahipliği'),
  confidentialityPolicy('confidentiality_policy', 'Gizlilik Politikası'),
  ndaContract('nda_contract', 'NDA veya Sözleşme'),
  accessControl('access_control', 'Erişim Kontrolü'),
  trainingAcknowledgement('training_acknowledgement', 'Eğitim ve Kabul'),
  technicalControl('technical_control', 'Teknik Kontrol'),
  physicalControl('physical_control', 'Fiziksel Kontrol'),
  disclosureRecord('disclosure_record', 'Paylaşım Kaydı'),
  incidentResponse('incident_response', 'Olay Müdahalesi'),
  auditLog('audit_log', 'Denetim Kaydı'),
  riskAssessment('risk_assessment', 'Risk Değerlendirmesi'),
  resilienceReview('resilience_review', 'Dayanıklılık İncelemesi'),
  retentionRecord('retention_record', 'Saklama Kaydı'),
  other('other', 'Diğer');

  const IpTradeSecretEvidenceCategory(this.value, this.label);

  final String value;
  final String label;

  static IpTradeSecretEvidenceCategory fromValue(String? value) {
    return IpTradeSecretEvidenceCategory.values.firstWhere(
      (item) => item.value == value,
      orElse: () => IpTradeSecretEvidenceCategory.other,
    );
  }
}

enum IpTradeSecretEvidenceStrength {
  none('none', 'Yok', 0),
  weak('weak', 'Zayıf', 1),
  moderate('moderate', 'Orta', 2),
  strong('strong', 'Güçlü', 3),
  conclusive('conclusive', 'Kesin', 4);

  const IpTradeSecretEvidenceStrength(this.value, this.label, this.level);

  final String value;
  final String label;
  final int level;

  static IpTradeSecretEvidenceStrength fromValue(String? value) {
    return IpTradeSecretEvidenceStrength.values.firstWhere(
      (item) => item.value == value,
      orElse: () => IpTradeSecretEvidenceStrength.none,
    );
  }
}

enum IpTradeSecretLegalReadinessLevel {
  unprepared('unprepared', 'Hazırlıksız', 0),
  limited('limited', 'Sınırlı', 1),
  defensible('defensible', 'Savunulabilir', 2),
  strong('strong', 'Güçlü', 3),
  litigationReady('litigation_ready', 'Uyuşmazlığa Hazır', 4);

  const IpTradeSecretLegalReadinessLevel(this.value, this.label, this.level);

  final String value;
  final String label;
  final int level;

  static IpTradeSecretLegalReadinessLevel fromValue(String? value) {
    return IpTradeSecretLegalReadinessLevel.values.firstWhere(
      (item) => item.value == value,
      orElse: () => IpTradeSecretLegalReadinessLevel.unprepared,
    );
  }
}

enum IpTradeSecretLifecycleStatus {
  active('active', 'Aktif'),
  transferPlanned('transfer_planned', 'Devir Planlandı'),
  transferring('transferring', 'Devrediliyor'),
  suspended('suspended', 'Askıya Alındı'),
  restricted('restricted', 'Erişim Kısıtlı'),
  retired('retired', 'Emekliye Ayrıldı'),
  closed('closed', 'Kapatıldı'),
  archived('archived', 'Arşivlendi');

  const IpTradeSecretLifecycleStatus(this.value, this.label);

  final String value;
  final String label;

  static IpTradeSecretLifecycleStatus fromValue(String? value) {
    return IpTradeSecretLifecycleStatus.values.firstWhere(
      (item) => item.value == value,
      orElse: () => IpTradeSecretLifecycleStatus.active,
    );
  }
}

enum IpTradeSecretTransitionType {
  onboarding('onboarding', 'Göreve Başlama'),
  roleChange('role_change', 'Görev Değişikliği'),
  ownershipTransfer('ownership_transfer', 'Sahiplik Devri'),
  responsibilityTransfer('responsibility_transfer', 'Sorumluluk Devri'),
  accessReduction('access_reduction', 'Erişim Daraltma'),
  accessRevocation('access_revocation', 'Erişim İptali'),
  employeeExit('employee_exit', 'Çalışan Çıkışı'),
  consultantExit('consultant_exit', 'Danışman Çıkışı'),
  partnerExit('partner_exit', 'Ortak Çıkışı'),
  supplierExit('supplier_exit', 'Tedarikçi Çıkışı'),
  retirement('retirement', 'Emekliye Ayırma'),
  closure('closure', 'Kapatma');

  const IpTradeSecretTransitionType(this.value, this.label);

  final String value;
  final String label;

  static IpTradeSecretTransitionType fromValue(String? value) {
    return IpTradeSecretTransitionType.values.firstWhere(
      (item) => item.value == value,
      orElse: () => IpTradeSecretTransitionType.roleChange,
    );
  }
}

enum IpTradeSecretExitPartyType {
  employee('employee', 'Çalışan'),
  consultant('consultant', 'Danışman'),
  partner('partner', 'Ortak'),
  supplier('supplier', 'Tedarikçi'),
  distributor('distributor', 'Distribütör'),
  contractor('contractor', 'Yüklenici'),
  boardMember('board_member', 'Yönetim Kurulu Üyesi'),
  other('other', 'Diğer');

  const IpTradeSecretExitPartyType(this.value, this.label);

  final String value;
  final String label;

  static IpTradeSecretExitPartyType fromValue(String? value) {
    return IpTradeSecretExitPartyType.values.firstWhere(
      (item) => item.value == value,
      orElse: () => IpTradeSecretExitPartyType.other,
    );
  }
}

enum IpTradeSecretHandoverStatus {
  notRequired('not_required', 'Gerekli Değil'),
  pending('pending', 'Bekliyor'),
  inProgress('in_progress', 'Sürüyor'),
  completed('completed', 'Tamamlandı'),
  partiallyCompleted('partially_completed', 'Kısmen Tamamlandı'),
  failed('failed', 'Başarısız'),
  waived('waived', 'Muaf Tutuldu');

  const IpTradeSecretHandoverStatus(this.value, this.label);

  final String value;
  final String label;

  static IpTradeSecretHandoverStatus fromValue(String? value) {
    return IpTradeSecretHandoverStatus.values.firstWhere(
      (item) => item.value == value,
      orElse: () => IpTradeSecretHandoverStatus.pending,
    );
  }
}

enum IpTradeSecretRemediationStatus {
  draft('draft', 'Taslak'),
  planned('planned', 'Planlandı'),
  assigned('assigned', 'Atandı'),
  inProgress('in_progress', 'Sürüyor'),
  blocked('blocked', 'Engellendi'),
  pendingVerification('pending_verification', 'Doğrulama Bekliyor'),
  verified('verified', 'Doğrulandı'),
  closed('closed', 'Kapatıldı'),
  reopened('reopened', 'Yeniden Açıldı'),
  cancelled('cancelled', 'İptal Edildi');

  const IpTradeSecretRemediationStatus(this.value, this.label);

  final String value;
  final String label;

  static IpTradeSecretRemediationStatus fromValue(String? value) {
    return IpTradeSecretRemediationStatus.values.firstWhere(
      (item) => item.value == value,
      orElse: () => IpTradeSecretRemediationStatus.draft,
    );
  }
}

enum IpTradeSecretRemediationPriority {
  low('low', 'Düşük', 1),
  medium('medium', 'Orta', 2),
  high('high', 'Yüksek', 3),
  critical('critical', 'Kritik', 4);

  const IpTradeSecretRemediationPriority(this.value, this.label, this.level);

  final String value;
  final String label;
  final int level;

  static IpTradeSecretRemediationPriority fromValue(String? value) {
    return IpTradeSecretRemediationPriority.values.firstWhere(
      (item) => item.value == value,
      orElse: () => IpTradeSecretRemediationPriority.medium,
    );
  }
}

enum IpTradeSecretRemediationSourceType {
  riskAssessment('risk_assessment', 'Risk Değerlendirmesi'),
  incident('incident', 'Olay'),
  protectionControl('protection_control', 'Koruma Kontrolü'),
  resilienceReview('resilience_review', 'Dayanıklılık İncelemesi'),
  defensibilityReview('defensibility_review', 'Hukuki Savunma İncelemesi'),
  lifecycleTransition('lifecycle_transition', 'Yaşam Döngüsü Geçişi'),
  audit('audit', 'Denetim'),
  managementDecision('management_decision', 'Yönetim Kararı'),
  other('other', 'Diğer');

  const IpTradeSecretRemediationSourceType(this.value, this.label);

  final String value;
  final String label;

  static IpTradeSecretRemediationSourceType fromValue(String? value) {
    return IpTradeSecretRemediationSourceType.values.firstWhere(
      (item) => item.value == value,
      orElse: () => IpTradeSecretRemediationSourceType.other,
    );
  }
}

enum IpTradeSecretVerificationOutcome {
  notReviewed('not_reviewed', 'İncelenmedi'),
  effective('effective', 'Etkili'),
  partiallyEffective('partially_effective', 'Kısmen Etkili'),
  ineffective('ineffective', 'Etkisiz'),
  inconclusive('inconclusive', 'Sonuçsuz'),
  rejected('rejected', 'Reddedildi');

  const IpTradeSecretVerificationOutcome(this.value, this.label);

  final String value;
  final String label;

  static IpTradeSecretVerificationOutcome fromValue(String? value) {
    return IpTradeSecretVerificationOutcome.values.firstWhere(
      (item) => item.value == value,
      orElse: () => IpTradeSecretVerificationOutcome.notReviewed,
    );
  }
}

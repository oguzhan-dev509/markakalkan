enum IpAssetType {
  trademark('trademark', 'Marka'),
  product('product', 'Ürün'),
  invention('invention', 'Buluş'),
  utilityModel('utility_model', 'Faydalı Model'),
  industrialDesign('industrial_design', 'Endüstriyel Tasarım'),
  fashionDesign('fashion_design', 'Moda Tasarımı'),
  packagingDesign('packaging_design', 'Ambalaj Tasarımı'),
  formula('formula', 'Formül'),
  recipe('recipe', 'Reçete'),
  manufacturingProcess('manufacturing_process', 'Üretim Prosesi'),
  tradeSecret('trade_secret', 'Ticari Sır'),
  knowHow('know_how', 'Know-how'),
  software('software', 'Yazılım'),
  sourceCode('source_code', 'Kaynak Kod'),
  algorithm('algorithm', 'Algoritma'),
  dataset('dataset', 'Veri Seti'),
  database('database', 'Veri Tabanı'),
  literaryWork('literary_work', 'Yazılı Eser'),
  visualWork('visual_work', 'Görsel Eser'),
  audioVisualWork('audio_visual_work', 'Görsel-İşitsel Eser'),
  musicWork('music_work', 'Müzik Eseri'),
  domainName('domain_name', 'Alan Adı'),
  tradeName('trade_name', 'Ticaret Unvanı'),
  socialMediaIdentity('social_media_identity', 'Sosyal Medya Kimliği'),
  geographicalIndication('geographical_indication', 'Coğrafi İşaret'),
  traditionalProductName('traditional_product_name', 'Geleneksel Ürün Adı'),
  confidentialDocument('confidential_document', 'Gizli Belge'),
  other('other', 'Diğer');

  const IpAssetType(this.value, this.label);

  final String value;
  final String label;

  static IpAssetType fromValue(String? value) {
    return IpAssetType.values.firstWhere(
      (item) => item.value == value,
      orElse: () => IpAssetType.other,
    );
  }
}

enum IpAssetStatus {
  draft('draft', 'Taslak'),
  underReview('under_review', 'İncelemede'),
  active('active', 'Aktif'),
  protected('protected', 'Koruma Altında'),
  exposed('exposed', 'Koruma Açığı Var'),
  disputed('disputed', 'Uyuşmazlık Konusu'),
  archived('archived', 'Arşivlendi'),
  retired('retired', 'Kullanımdan Kaldırıldı');

  const IpAssetStatus(this.value, this.label);

  final String value;
  final String label;

  static IpAssetStatus fromValue(String? value) {
    return IpAssetStatus.values.firstWhere(
      (item) => item.value == value,
      orElse: () => IpAssetStatus.draft,
    );
  }
}

enum IpRightType {
  trademark('trademark', 'Marka Hakkı'),
  patent('patent', 'Patent'),
  utilityModel('utility_model', 'Faydalı Model'),
  industrialDesign('industrial_design', 'Tasarım Hakkı'),
  copyright('copyright', 'Telif Hakkı'),
  databaseRight('database_right', 'Veri Tabanı Hakkı'),
  tradeSecret('trade_secret', 'Ticari Sır'),
  knowHow('know_how', 'Know-how'),
  geographicalIndication('geographical_indication', 'Coğrafi İşaret'),
  traditionalProductName('traditional_product_name', 'Geleneksel Ürün Adı'),
  tradeName('trade_name', 'Ticaret Unvanı'),
  domainName('domain_name', 'Alan Adı Hakkı'),
  contractualRight('contractual_right', 'Sözleşmesel Hak'),
  licenseRight('license_right', 'Lisans Hakkı'),
  other('other', 'Diğer Hak');

  const IpRightType(this.value, this.label);

  final String value;
  final String label;

  static IpRightType fromValue(String? value) {
    return IpRightType.values.firstWhere(
      (item) => item.value == value,
      orElse: () => IpRightType.other,
    );
  }
}

enum IpRightStatus {
  identified('identified', 'Tespit Edildi'),
  preparing('preparing', 'Başvuru Hazırlığında'),
  filed('filed', 'Başvuruldu'),
  underExamination('under_examination', 'İncelemede'),
  published('published', 'Yayımlandı'),
  opposed('opposed', 'İtiraz Edildi'),
  registered('registered', 'Tescilli'),
  granted('granted', 'Hak Verildi'),
  rejected('rejected', 'Reddedildi'),
  suspended('suspended', 'Askıda'),
  expired('expired', 'Süresi Doldu'),
  cancelled('cancelled', 'İptal Edildi'),
  invalidated('invalidated', 'Hükümsüz Kılındı'),
  abandoned('abandoned', 'Terk Edildi'),
  disputed('disputed', 'Uyuşmazlık Konusu');

  const IpRightStatus(this.value, this.label);

  final String value;
  final String label;

  static IpRightStatus fromValue(String? value) {
    return IpRightStatus.values.firstWhere(
      (item) => item.value == value,
      orElse: () => IpRightStatus.identified,
    );
  }
}

enum IpDocumentType {
  application('application', 'Başvuru Belgesi'),
  registrationCertificate('registration_certificate', 'Tescil Belgesi'),
  renewalCertificate('renewal_certificate', 'Yenileme Belgesi'),
  assignmentAgreement('assignment_agreement', 'Devir Sözleşmesi'),
  licenseAgreement('license_agreement', 'Lisans Sözleşmesi'),
  nda('nda', 'Gizlilik Sözleşmesi'),
  employmentAgreement('employment_agreement', 'İş Sözleşmesi'),
  serviceAgreement('service_agreement', 'Hizmet Sözleşmesi'),
  inventorDeclaration('inventor_declaration', 'Buluşçu Beyanı'),
  creatorDeclaration('creator_declaration', 'Eser Sahibi Beyanı'),
  ownershipDeclaration('ownership_declaration', 'Hak Sahipliği Beyanı'),
  powerOfAttorney('power_of_attorney', 'Vekâletname'),
  technicalDrawing('technical_drawing', 'Teknik Çizim'),
  designFile('design_file', 'Tasarım Dosyası'),
  sourceFile('source_file', 'Kaynak Dosya'),
  sourceCodeArchive('source_code_archive', 'Kaynak Kod Arşivi'),
  formulaFingerprint('formula_fingerprint', 'Formül Parmak İzi'),
  laboratoryReport('laboratory_report', 'Laboratuvar Raporu'),
  productionRecord('production_record', 'Üretim Kaydı'),
  sampleRecord('sample_record', 'Numune Kaydı'),
  firstUseEvidence('first_use_evidence', 'İlk Kullanım Kanıtı'),
  firstPublicationEvidence('first_publication_evidence', 'İlk Yayın Kanıtı'),
  invoice('invoice', 'Fatura'),
  catalogue('catalogue', 'Katalog'),
  photograph('photograph', 'Fotoğraf'),
  video('video', 'Video'),
  emailRecord('email_record', 'E-posta Kaydı'),
  meetingRecord('meeting_record', 'Toplantı Tutanağı'),
  timestampCertificate('timestamp_certificate', 'Zaman Damgası Belgesi'),
  electronicSignatureRecord(
    'electronic_signature_record',
    'Elektronik İmza Kaydı',
  ),
  notarizedRecord('notarized_record', 'Noter Belgesi'),
  customsApplication('customs_application', 'Gümrük Başvurusu'),
  officialCorrespondence('official_correspondence', 'Resmî Yazışma'),
  courtDocument('court_document', 'Mahkeme Belgesi'),
  expertReport('expert_report', 'Bilirkişi Raporu'),
  ceaseAndDesist('cease_and_desist', 'İhtarname'),
  platformNotice('platform_notice', 'Platform İhlal Bildirimi'),
  other('other', 'Diğer Belge');

  const IpDocumentType(this.value, this.label);

  final String value;
  final String label;

  static IpDocumentType fromValue(String? value) {
    return IpDocumentType.values.firstWhere(
      (item) => item.value == value,
      orElse: () => IpDocumentType.other,
    );
  }
}

enum IpDocumentStatus {
  draft('draft', 'Taslak'),
  uploaded('uploaded', 'Yüklendi'),
  underReview('under_review', 'İncelemede'),
  verified('verified', 'Doğrulandı'),
  approved('approved', 'Onaylandı'),
  rejected('rejected', 'Reddedildi'),
  expired('expired', 'Süresi Doldu'),
  superseded('superseded', 'Yeni Sürümle Değiştirildi'),
  archived('archived', 'Arşivlendi'),
  quarantined('quarantined', 'Karantinaya Alındı');

  const IpDocumentStatus(this.value, this.label);

  final String value;
  final String label;

  static IpDocumentStatus fromValue(String? value) {
    return IpDocumentStatus.values.firstWhere(
      (item) => item.value == value,
      orElse: () => IpDocumentStatus.draft,
    );
  }
}

enum IpConfidentialityLevel {
  public('public', 'Açık'),
  internal('internal', 'Kurum İçi'),
  confidential('confidential', 'Gizli'),
  highlyConfidential('highly_confidential', 'Çok Gizli'),
  tradeSecret('trade_secret', 'Ticari Sır'),
  restricted('restricted', 'Sınırlı Erişim');

  const IpConfidentialityLevel(this.value, this.label);

  final String value;
  final String label;

  static IpConfidentialityLevel fromValue(String? value) {
    return IpConfidentialityLevel.values.firstWhere(
      (item) => item.value == value,
      orElse: () => IpConfidentialityLevel.internal,
    );
  }
}

enum IpRelationshipType {
  owner('owner', 'Hak Sahibi'),
  previousOwner('previous_owner', 'Önceki Hak Sahibi'),
  creator('creator', 'Eser Sahibi'),
  inventor('inventor', 'Buluşçu'),
  designer('designer', 'Tasarımcı'),
  employee('employee', 'Çalışan'),
  formerEmployee('former_employee', 'Eski Çalışan'),
  contractor('contractor', 'Yüklenici'),
  agency('agency', 'Ajans'),
  laboratory('laboratory', 'Laboratuvar'),
  manufacturer('manufacturer', 'Üretici'),
  contractManufacturer('contract_manufacturer', 'Fason Üretici'),
  supplier('supplier', 'Tedarikçi'),
  distributor('distributor', 'Distribütör'),
  licensee('licensee', 'Lisans Alan'),
  licensor('licensor', 'Lisans Veren'),
  legalRepresentative('legal_representative', 'Hukuki Temsilci'),
  trademarkAttorney('trademark_attorney', 'Marka Vekili'),
  patentAttorney('patent_attorney', 'Patent Vekili'),
  customsRepresentative('customs_representative', 'Gümrük Temsilcisi'),
  academicPartner('academic_partner', 'Akademik Ortak'),
  testingOrganization('testing_organization', 'Test Kuruluşu'),
  publicInstitution('public_institution', 'Kamu Kurumu'),
  other('other', 'Diğer İlişki');

  const IpRelationshipType(this.value, this.label);

  final String value;
  final String label;

  static IpRelationshipType fromValue(String? value) {
    return IpRelationshipType.values.firstWhere(
      (item) => item.value == value,
      orElse: () => IpRelationshipType.other,
    );
  }
}

enum IpRelationshipStatus {
  planned('planned', 'Planlandı'),
  active('active', 'Aktif'),
  suspended('suspended', 'Askıda'),
  ended('ended', 'Sona Erdi'),
  revoked('revoked', 'Yetkisi İptal Edildi'),
  underReview('under_review', 'İncelemede'),
  highRisk('high_risk', 'Yüksek Riskli');

  const IpRelationshipStatus(this.value, this.label);

  final String value;
  final String label;

  static IpRelationshipStatus fromValue(String? value) {
    return IpRelationshipStatus.values.firstWhere(
      (item) => item.value == value,
      orElse: () => IpRelationshipStatus.planned,
    );
  }
}

enum IpAccessLevel {
  none('none', 'Erişim Yok'),
  metadataOnly('metadata_only', 'Yalnız Meta Veri'),
  view('view', 'Görüntüleme'),
  controlledView('controlled_view', 'Kontrollü Görüntüleme'),
  edit('edit', 'Düzenleme'),
  download('download', 'İndirme'),
  export('export', 'Dışa Aktarma'),
  administrator('administrator', 'Yönetici');

  const IpAccessLevel(this.value, this.label);

  final String value;
  final String label;

  static IpAccessLevel fromValue(String? value) {
    return IpAccessLevel.values.firstWhere(
      (item) => item.value == value,
      orElse: () => IpAccessLevel.none,
    );
  }
}

enum IpEvidenceIntegrityStatus {
  notAssessed('not_assessed', 'Değerlendirilmedi'),
  incomplete('incomplete', 'Eksik'),
  fingerprinted('fingerprinted', 'Parmak İzi Oluşturuldu'),
  timestamped('timestamped', 'Zaman Damgalı'),
  signed('signed', 'Elektronik İmzalı'),
  verified('verified', 'Doğrulandı'),
  compromised('compromised', 'Bütünlük Şüphesi Var');

  const IpEvidenceIntegrityStatus(this.value, this.label);

  final String value;
  final String label;

  static IpEvidenceIntegrityStatus fromValue(String? value) {
    return IpEvidenceIntegrityStatus.values.firstWhere(
      (item) => item.value == value,
      orElse: () => IpEvidenceIntegrityStatus.notAssessed,
    );
  }
}

enum IpRiskLevel {
  informational('informational', 'Bilgi'),
  low('low', 'Düşük'),
  medium('medium', 'Orta'),
  high('high', 'Yüksek'),
  critical('critical', 'Kritik');

  const IpRiskLevel(this.value, this.label);

  final String value;
  final String label;

  static IpRiskLevel fromValue(String? value) {
    return IpRiskLevel.values.firstWhere(
      (item) => item.value == value,
      orElse: () => IpRiskLevel.informational,
    );
  }
}

enum IpJurisdictionScope {
  national('national', 'Ulusal'),
  regional('regional', 'Bölgesel'),
  international('international', 'Uluslararası'),
  contractual('contractual', 'Sözleşmesel'),
  unregistered('unregistered', 'Tescilsiz Koruma');

  const IpJurisdictionScope(this.value, this.label);

  final String value;
  final String label;

  static IpJurisdictionScope fromValue(String? value) {
    return IpJurisdictionScope.values.firstWhere(
      (item) => item.value == value,
      orElse: () => IpJurisdictionScope.national,
    );
  }
}

enum SupplyFacilityType {
  factory('factory', 'Fabrika'),
  contractManufacturingPlant(
    'contract_manufacturing_plant',
    'Fason Üretim Tesisi',
  ),
  productionLine('production_line', 'Üretim Hattı'),
  packagingPlant('packaging_plant', 'Paketleme Tesisi'),
  labelPrintingSite('label_printing_site', 'Etiket / Baskı Noktası'),
  rawMaterialWarehouse('raw_material_warehouse', 'Hammadde Deposu'),
  finishedGoodsWarehouse('finished_goods_warehouse', 'Mamul Deposu'),
  distributionCenter('distribution_center', 'Sevkiyat Merkezi'),
  destructionFacility('destruction_facility', 'İmha Tesisi'),
  qualityLaboratory('quality_laboratory', 'Kalite Laboratuvarı'),
  suspectedUnauthorizedSite(
    'suspected_unauthorized_site',
    'Şüpheli Yetkisiz Üretim Noktası',
  );

  const SupplyFacilityType(this.value, this.label);

  final String value;
  final String label;

  static SupplyFacilityType fromValue(String? value) {
    return SupplyFacilityType.values.firstWhere(
      (item) => item.value == value,
      orElse: () => SupplyFacilityType.factory,
    );
  }
}

enum SupplyFacilityStatus {
  draft('draft', 'Taslak'),
  pendingVerification('pending_verification', 'Doğrulama Bekliyor'),
  active('active', 'Aktif'),
  suspended('suspended', 'Askıya Alındı'),
  blocked('blocked', 'Engellendi'),
  closed('closed', 'Kapalı'),
  archived('archived', 'Arşivlendi');

  const SupplyFacilityStatus(this.value, this.label);

  final String value;
  final String label;

  static SupplyFacilityStatus fromValue(String? value) {
    return SupplyFacilityStatus.values.firstWhere(
      (item) => item.value == value,
      orElse: () => SupplyFacilityStatus.draft,
    );
  }
}

enum SupplyFacilityVerificationStatus {
  unverified('unverified', 'Doğrulanmadı'),
  documentsPending('documents_pending', 'Belgeler Bekleniyor'),
  underReview('under_review', 'İncelemede'),
  verified('verified', 'Doğrulandı'),
  rejected('rejected', 'Reddedildi'),
  expired('expired', 'Doğrulama Süresi Doldu');

  const SupplyFacilityVerificationStatus(this.value, this.label);

  final String value;
  final String label;

  static SupplyFacilityVerificationStatus fromValue(String? value) {
    return SupplyFacilityVerificationStatus.values.firstWhere(
      (item) => item.value == value,
      orElse: () => SupplyFacilityVerificationStatus.unverified,
    );
  }
}

enum SupplyFacilityRiskLevel {
  low('low', 'Düşük'),
  medium('medium', 'Orta'),
  high('high', 'Yüksek'),
  critical('critical', 'Kritik');

  const SupplyFacilityRiskLevel(this.value, this.label);

  final String value;
  final String label;

  static SupplyFacilityRiskLevel fromValue(String? value) {
    return SupplyFacilityRiskLevel.values.firstWhere(
      (item) => item.value == value,
      orElse: () => SupplyFacilityRiskLevel.medium,
    );
  }
}

enum SupplyFacilityAuthorizationStatus {
  notApplicable('not_applicable', 'Uygulanamaz'),
  unauthorized('unauthorized', 'Yetkisiz'),
  pending('pending', 'Yetki Bekliyor'),
  authorized('authorized', 'Yetkili'),
  restricted('restricted', 'Kısıtlı Yetkili'),
  revoked('revoked', 'Yetkisi İptal');

  const SupplyFacilityAuthorizationStatus(this.value, this.label);

  final String value;
  final String label;

  static SupplyFacilityAuthorizationStatus fromValue(String? value) {
    return SupplyFacilityAuthorizationStatus.values.firstWhere(
      (item) => item.value == value,
      orElse: () => SupplyFacilityAuthorizationStatus.notApplicable,
    );
  }
}

enum SupplyShiftCode {
  day('day', 'Gündüz'),
  evening('evening', 'Akşam'),
  night('night', 'Gece'),
  weekend('weekend', 'Hafta Sonu'),
  custom('custom', 'Özel Vardiya');

  const SupplyShiftCode(this.value, this.label);

  final String value;
  final String label;

  static SupplyShiftCode fromValue(String? value) {
    return SupplyShiftCode.values.firstWhere(
      (item) => item.value == value,
      orElse: () => SupplyShiftCode.custom,
    );
  }
}

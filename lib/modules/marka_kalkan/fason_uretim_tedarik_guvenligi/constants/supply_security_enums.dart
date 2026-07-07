enum SupplyPartnerRole {
  manufacturer('manufacturer', 'Üretici'),
  contractManufacturer('contract_manufacturer', 'Fason Üretici'),
  rawMaterialSupplier('raw_material_supplier', 'Hammadde Tedarikçisi'),
  packagingSupplier('packaging_supplier', 'Ambalaj Tedarikçisi'),
  labelPrinter('label_printer', 'Etiket / Baskı Tedarikçisi'),
  logisticsProvider('logistics_provider', 'Lojistik Sağlayıcı'),
  warehouseOperator('warehouse_operator', 'Depo İşletmecisi'),
  subcontractor('subcontractor', 'Alt Yüklenici'),
  destructionProvider('destruction_provider', 'İmha Hizmeti Sağlayıcısı'),
  qualityLaboratory('quality_laboratory', 'Kalite Laboratuvarı');

  const SupplyPartnerRole(this.value, this.label);

  final String value;
  final String label;

  static SupplyPartnerRole fromValue(String? value) {
    return SupplyPartnerRole.values.firstWhere(
      (item) => item.value == value,
      orElse: () => SupplyPartnerRole.rawMaterialSupplier,
    );
  }
}

enum SupplyPartnerStatus {
  draft('draft', 'Taslak'),
  pendingVerification('pending_verification', 'Doğrulama Bekliyor'),
  active('active', 'Aktif'),
  suspended('suspended', 'Askıya Alındı'),
  blocked('blocked', 'Engellendi'),
  terminated('terminated', 'Sona Erdi'),
  archived('archived', 'Arşivlendi');

  const SupplyPartnerStatus(this.value, this.label);

  final String value;
  final String label;

  static SupplyPartnerStatus fromValue(String? value) {
    return SupplyPartnerStatus.values.firstWhere(
      (item) => item.value == value,
      orElse: () => SupplyPartnerStatus.draft,
    );
  }
}

enum SupplyPartnerVerificationStatus {
  unverified('unverified', 'Doğrulanmadı'),
  documentsPending('documents_pending', 'Belgeler Bekleniyor'),
  underReview('under_review', 'İncelemede'),
  verified('verified', 'Doğrulandı'),
  rejected('rejected', 'Reddedildi'),
  expired('expired', 'Doğrulama Süresi Doldu');

  const SupplyPartnerVerificationStatus(this.value, this.label);

  final String value;
  final String label;

  static SupplyPartnerVerificationStatus fromValue(String? value) {
    return SupplyPartnerVerificationStatus.values.firstWhere(
      (item) => item.value == value,
      orElse: () => SupplyPartnerVerificationStatus.unverified,
    );
  }
}

enum SupplyPartnerRiskLevel {
  low('low', 'Düşük'),
  medium('medium', 'Orta'),
  high('high', 'Yüksek'),
  critical('critical', 'Kritik');

  const SupplyPartnerRiskLevel(this.value, this.label);

  final String value;
  final String label;

  static SupplyPartnerRiskLevel fromValue(String? value) {
    return SupplyPartnerRiskLevel.values.firstWhere(
      (item) => item.value == value,
      orElse: () => SupplyPartnerRiskLevel.medium,
    );
  }
}

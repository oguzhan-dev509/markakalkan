enum IpTradeSecretType {
  formula('formula', 'Formül'),
  recipe('recipe', 'Reçete'),
  manufacturingProcess('manufacturing_process', 'Üretim Prosesi'),
  knowHow('know_how', 'Know-how'),
  algorithm('algorithm', 'Algoritma'),
  sourceCode('source_code', 'Kaynak Kod'),
  dataset('dataset', 'Veri Seti'),
  testMethod('test_method', 'Test ve Analiz Yöntemi'),
  pricingModel('pricing_model', 'Fiyatlandırma Modeli'),
  customerList('customer_list', 'Müşteri Listesi'),
  supplierNetwork('supplier_network', 'Tedarikçi Ağı'),
  businessMethod('business_method', 'İş Yöntemi'),
  productRoadmap('product_roadmap', 'Ürün Yol Haritası'),
  marketStrategy('market_strategy', 'Pazar Stratejisi'),
  other('other', 'Diğer Ticari Sır');

  const IpTradeSecretType(this.value, this.label);

  final String value;
  final String label;

  static IpTradeSecretType fromValue(String? value) {
    return IpTradeSecretType.values.firstWhere(
      (item) => item.value == value,
      orElse: () => IpTradeSecretType.other,
    );
  }
}

enum IpTradeSecretStatus {
  draft('draft', 'Taslak'),
  active('active', 'Aktif Koruma'),
  underReview('under_review', 'İncelemede'),
  suspended('suspended', 'Koruma Askıda'),
  compromised('compromised', 'İhlal veya Sızıntı Şüphesi'),
  retired('retired', 'Kullanımdan Kaldırıldı');

  const IpTradeSecretStatus(this.value, this.label);

  final String value;
  final String label;

  static IpTradeSecretStatus fromValue(String? value) {
    return IpTradeSecretStatus.values.firstWhere(
      (item) => item.value == value,
      orElse: () => IpTradeSecretStatus.draft,
    );
  }
}

enum IpSecretProtectionMode {
  metadataOnly('metadata_only', 'Yalnız Metaveri Kaydı'),
  encryptedVault('encrypted_vault', 'Şifreli Kasa'),
  externalSecureSystem('external_secure_system', 'Harici Güvenli Sistem'),
  compartmentalized('compartmentalized', 'Bölümlendirilmiş Koruma');

  const IpSecretProtectionMode(this.value, this.label);

  final String value;
  final String label;

  static IpSecretProtectionMode fromValue(String? value) {
    return IpSecretProtectionMode.values.firstWhere(
      (item) => item.value == value,
      orElse: () => IpSecretProtectionMode.metadataOnly,
    );
  }
}

enum IpSecretDisclosureScope {
  noDisclosure('no_disclosure', 'Açıklama Yapılmadı'),
  ownerOnly('owner_only', 'Yalnız Hak Sahibi'),
  needToKnow('need_to_know', 'Bilmesi Gerekenler'),
  internalRestricted('internal_restricted', 'Kısıtlı İç Erişim'),
  selectedPartners('selected_partners', 'Seçilmiş İş Ortakları'),
  restrictedExternal('restricted_external', 'Kısıtlı Harici Açıklama');

  const IpSecretDisclosureScope(this.value, this.label);

  final String value;
  final String label;

  static IpSecretDisclosureScope fromValue(String? value) {
    return IpSecretDisclosureScope.values.firstWhere(
      (item) => item.value == value,
      orElse: () => IpSecretDisclosureScope.noDisclosure,
    );
  }
}

enum IpSecretLegalBasisStatus {
  undocumented('undocumented', 'Hukuki Dayanak Yok'),
  partial('partial', 'Kısmen Belgeli'),
  documented('documented', 'Belgeli'),
  verified('verified', 'Doğrulanmış');

  const IpSecretLegalBasisStatus(this.value, this.label);

  final String value;
  final String label;

  static IpSecretLegalBasisStatus fromValue(String? value) {
    return IpSecretLegalBasisStatus.values.firstWhere(
      (item) => item.value == value,
      orElse: () => IpSecretLegalBasisStatus.undocumented,
    );
  }
}

enum IpSecretCompartmentalizationLevel {
  none('none', 'Bölümlendirme Yok'),
  basic('basic', 'Temel Bölümlendirme'),
  segmented('segmented', 'Bileşen Bazlı Bölümlendirme'),
  strict('strict', 'Katı Bilmesi Gerekenler Modeli');

  const IpSecretCompartmentalizationLevel(this.value, this.label);

  final String value;
  final String label;

  static IpSecretCompartmentalizationLevel fromValue(String? value) {
    return IpSecretCompartmentalizationLevel.values.firstWhere(
      (item) => item.value == value,
      orElse: () => IpSecretCompartmentalizationLevel.none,
    );
  }
}

enum IpSecretEconomicValueLevel {
  low('low', 'Düşük'),
  medium('medium', 'Orta'),
  high('high', 'Yüksek'),
  critical('critical', 'Kritik');

  const IpSecretEconomicValueLevel(this.value, this.label);

  final String value;
  final String label;

  static IpSecretEconomicValueLevel fromValue(String? value) {
    return IpSecretEconomicValueLevel.values.firstWhere(
      (item) => item.value == value,
      orElse: () => IpSecretEconomicValueLevel.medium,
    );
  }
}

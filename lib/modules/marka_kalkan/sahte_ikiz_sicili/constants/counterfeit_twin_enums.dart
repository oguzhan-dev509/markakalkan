enum CounterfeitTwinStatus {
  draft('draft', 'Taslak'),
  suspected('suspected', 'Şüpheli'),
  underReview('under_review', 'İncelemede'),
  probable('probable', 'Kuvvetle Muhtemel'),
  confirmed('confirmed', 'Teyit Edildi'),
  dismissed('dismissed', 'Çürütüldü'),
  contained('contained', 'Kontrol Altına Alındı'),
  archived('archived', 'Arşivlendi');

  const CounterfeitTwinStatus(this.value, this.label);

  final String value;
  final String label;

  static CounterfeitTwinStatus fromValue(String? value) {
    return CounterfeitTwinStatus.values.firstWhere(
      (item) => item.value == value,
      orElse: () => CounterfeitTwinStatus.draft,
    );
  }
}

enum CounterfeitTwinConfidenceLevel {
  low('low', 'Düşük'),
  medium('medium', 'Orta'),
  high('high', 'Yüksek'),
  veryHigh('very_high', 'Çok Yüksek'),
  verified('verified', 'Doğrulandı');

  const CounterfeitTwinConfidenceLevel(this.value, this.label);

  final String value;
  final String label;

  static CounterfeitTwinConfidenceLevel fromValue(String? value) {
    return CounterfeitTwinConfidenceLevel.values.firstWhere(
      (item) => item.value == value,
      orElse: () => CounterfeitTwinConfidenceLevel.low,
    );
  }
}

enum CounterfeitTwinRiskLevel {
  low('low', 'Düşük'),
  medium('medium', 'Orta'),
  high('high', 'Yüksek'),
  critical('critical', 'Kritik');

  const CounterfeitTwinRiskLevel(this.value, this.label);

  final String value;
  final String label;

  static CounterfeitTwinRiskLevel fromValue(String? value) {
    return CounterfeitTwinRiskLevel.values.firstWhere(
      (item) => item.value == value,
      orElse: () => CounterfeitTwinRiskLevel.medium,
    );
  }
}

enum CounterfeitTwinReviewStatus {
  notStarted('not_started', 'Başlatılmadı'),
  inProgress('in_progress', 'Devam Ediyor'),
  awaitingEvidence('awaiting_evidence', 'Kanıt Bekleniyor'),
  awaitingExpertReview('awaiting_expert_review', 'Uzman İncelemesi Bekleniyor'),
  completed('completed', 'Tamamlandı');

  const CounterfeitTwinReviewStatus(this.value, this.label);

  final String value;
  final String label;

  static CounterfeitTwinReviewStatus fromValue(String? value) {
    return CounterfeitTwinReviewStatus.values.firstWhere(
      (item) => item.value == value,
      orElse: () => CounterfeitTwinReviewStatus.notStarted,
    );
  }
}

enum CounterfeitTwinCloneMethod {
  exactReplica('exact_replica', 'Birebir Kopya'),
  packagingImitation('packaging_imitation', 'Ambalaj Taklidi'),
  logoImitation('logo_imitation', 'Logo Benzetme'),
  brandNameVariation('brand_name_variation', 'Marka Adı Varyasyonu'),
  productNameImitation('product_name_imitation', 'Ürün Adı Taklidi'),
  tradeDressImitation('trade_dress_imitation', 'Ticari Görünüm Taklidi'),
  colorSchemeImitation(
    'color_scheme_imitation',
    'Renk ve Tasarım Kodu Taklidi',
  ),
  productImageTheft('product_image_theft', 'Ürün Fotoğrafı Çalma'),
  descriptionCopying('description_copying', 'Açıklama ve Metin Kopyalama'),
  fakeAuthorizedSeller(
    'fake_authorized_seller',
    'Sahte Yetkili Satıcı Görünümü',
  ),
  domainImpersonation('domain_impersonation', 'Alan Adı Taklidi'),
  socialStoreImpersonation(
    'social_store_impersonation',
    'Sosyal Medya Mağaza Taklidi',
  ),
  repackaging('repackaging', 'Yeniden Paketleme'),
  contentOrFormulaImitation(
    'content_or_formula_imitation',
    'İçerik veya Formül Taklidi',
  ),
  labelOrCertificateForgery(
    'label_or_certificate_forgery',
    'Etiket veya Sertifika Sahteciliği',
  ),
  mixed('mixed', 'Karma Klonlama'),
  unknown('unknown', 'Bilinmeyen');

  const CounterfeitTwinCloneMethod(this.value, this.label);

  final String value;
  final String label;

  static CounterfeitTwinCloneMethod fromValue(String? value) {
    return CounterfeitTwinCloneMethod.values.firstWhere(
      (item) => item.value == value,
      orElse: () => CounterfeitTwinCloneMethod.unknown,
    );
  }
}

class DetectiveViolationType {
  const DetectiveViolationType({
    required this.id,
    required this.name,
    required this.description,
    this.categoryIds = const [],
  });

  final String id;
  final String name;
  final String description;

  /// Boş liste, tüm kategorilerde kullanılabileceğini gösterir.
  final List<String> categoryIds;
}

abstract final class DetectiveViolationCatalog {
  static const List<DetectiveViolationType> violations = [
    DetectiveViolationType(
      id: 'counterfeit_product',
      name: 'Sahte veya taklit ürün',
      description:
          'Marka, ürün, ambalaj veya tasarımın izinsiz taklit edildiği şüphesi.',
    ),
    DetectiveViolationType(
      id: 'smuggled_product',
      name: 'Kaçak ürün',
      description:
          'Yasal ithalat, vergi veya gümrük süreçleri dışında piyasaya sürülme şüphesi.',
    ),
    DetectiveViolationType(
      id: 'fake_or_missing_tax_stamp',
      name: 'Bandrolsüz veya sahte bandrollü ürün',
      description:
          'Bandrolün bulunmaması, taklit edilmesi veya başka üründen aktarılması şüphesi.',
      categoryIds: [
        'tobacco_nicotine',
        'alcoholic_beverages',
        'packaging_labels_security',
      ],
    ),
    DetectiveViolationType(
      id: 'unauthorized_import',
      name: 'Yetkisiz ithalat',
      description:
          'Marka sahibinin veya yetkili dağıtım kanalının izni dışında ithalat şüphesi.',
    ),
    DetectiveViolationType(
      id: 'unauthorized_production',
      name: 'Yetkisiz üretim',
      description:
          'Marka sahibinin izni veya üretim kotası dışında üretim şüphesi.',
    ),
    DetectiveViolationType(
      id: 'unauthorized_seller',
      name: 'Yetkisiz satıcı',
      description:
          'Markanın yetkili satış ağı dışında faaliyet gösteren satıcı şüphesi.',
    ),
    DetectiveViolationType(
      id: 'parallel_import_gray_market',
      name: 'Paralel ithalat veya gri pazar',
      description:
          'Orijinal olabilecek ürünün yetkili dağıtım kanalı dışında satılması şüphesi.',
    ),
    DetectiveViolationType(
      id: 'packaging_or_logo_imitation',
      name: 'Ambalaj veya logo taklidi',
      description:
          'Logo, kutu, şişe, kapak, etiket veya görsel kimlik taklidi şüphesi.',
    ),
    DetectiveViolationType(
      id: 'fake_label',
      name: 'Sahte veya yanıltıcı etiket',
      description:
          'İçerik, menşe, üretici, sertifika veya ürün bilgisinin yanıltıcı olması şüphesi.',
    ),
    DetectiveViolationType(
      id: 'qr_or_serial_copy',
      name: 'QR kod, barkod veya seri numarası kopyası',
      description:
          'Tekil kodun kopyalanması, çoğaltılması veya farklı üründe kullanılması şüphesi.',
      categoryIds: ['packaging_labels_security'],
    ),
    DetectiveViolationType(
      id: 'fake_certificate',
      name: 'Sahte sertifika veya uygunluk belgesi',
      description:
          'Garanti, test, analiz, uygunluk veya yetki belgesinin sahte olması şüphesi.',
    ),
    DetectiveViolationType(
      id: 'ingredient_adulteration',
      name: 'İçerik tağşişi',
      description:
          'Ürünün beyan edilen içerikten farklı, eksik veya karıştırılmış olması şüphesi.',
      categoryIds: [
        'food_non_alcoholic_beverages',
        'alcoholic_beverages',
        'cosmetics_personal_care',
        'pharmaceutical_health_medical',
        'fuel_lubricants_energy',
        'agriculture_fertilizer_seed',
      ],
    ),
    DetectiveViolationType(
      id: 'species_misrepresentation',
      name: 'Ürün veya hayvan türü yanıltması',
      description:
          'Beyan edilen ürün, hammadde veya hayvan türü ile gerçek içeriğin uyuşmaması şüphesi.',
      categoryIds: ['food_non_alcoholic_beverages'],
    ),
    DetectiveViolationType(
      id: 'unregistered_or_illicit_food',
      name: 'Kayıt dışı veya uygunsuz gıda üretimi',
      description:
          'Ruhsatsız, kayıt dışı veya mevzuata aykırı üretim ve satış şüphesi.',
      categoryIds: ['food_non_alcoholic_beverages'],
    ),
    DetectiveViolationType(
      id: 'origin_misrepresentation',
      name: 'Menşe veya coğrafi işaret yanıltması',
      description:
          'Üretim yeri, ülke, bölge veya coğrafi işaret bilgisinin yanıltıcı olması şüphesi.',
    ),
    DetectiveViolationType(
      id: 'expiry_date_manipulation',
      name: 'Son kullanma tarihi manipülasyonu',
      description:
          'Tarihin değiştirilmesi, yeniden etiketlenmesi veya gizlenmesi şüphesi.',
      categoryIds: [
        'food_non_alcoholic_beverages',
        'cosmetics_personal_care',
        'pharmaceutical_health_medical',
      ],
    ),
    DetectiveViolationType(
      id: 'cold_chain_or_storage_risk',
      name: 'Soğuk zincir veya uygunsuz saklama',
      description:
          'Ürünün güvenli saklama ve taşıma koşullarına uyulmadan satılması şüphesi.',
      categoryIds: [
        'food_non_alcoholic_beverages',
        'pharmaceutical_health_medical',
      ],
    ),
    DetectiveViolationType(
      id: 'bottle_refill',
      name: 'Şişe yeniden doldurma',
      description:
          'Orijinal şişe veya ambalajın farklı içerikle yeniden doldurulması şüphesi.',
      categoryIds: ['alcoholic_beverages', 'cosmetics_personal_care'],
    ),
    DetectiveViolationType(
      id: 'methanol_or_health_risk',
      name: 'Metanol veya ciddi sağlık riski şüphesi',
      description:
          'İçerikte insan sağlığı açısından ağır risk oluşturabilecek madde şüphesi.',
      categoryIds: ['alcoholic_beverages'],
    ),
    DetectiveViolationType(
      id: 'price_anomaly',
      name: 'Fiyat anomalisi',
      description:
          'Piyasa değerine göre olağan dışı düşük veya şüpheli fiyatlandırma.',
    ),
    DetectiveViolationType(
      id: 'suspicious_advertisement',
      name: 'Şüpheli reklam veya ilan',
      description:
          'Yanıltıcı başlık, açıklama, görsel, kampanya veya satış vaadi şüphesi.',
    ),
    DetectiveViolationType(
      id: 'illegal_online_sale',
      name: 'Yasadışı veya kısıtlı çevrim içi satış',
      description:
          'Mevzuatla kısıtlanan ürünün uygunsuz çevrim içi kanal üzerinden satılması şüphesi.',
      categoryIds: [
        'tobacco_nicotine',
        'alcoholic_beverages',
        'pharmaceutical_health_medical',
      ],
    ),
    DetectiveViolationType(
      id: 'license_or_digital_piracy',
      name: 'Lisans ihlali veya dijital korsanlık',
      description:
          'Yazılım, lisans, dijital içerik veya aktivasyon anahtarının izinsiz kullanımı.',
      categoryIds: ['software_digital_content_licenses'],
    ),
  ];

  static List<DetectiveViolationType> forCategory(String? categoryId) {
    if (categoryId == null || categoryId.isEmpty) {
      return violations
          .where((violation) => violation.categoryIds.isEmpty)
          .toList();
    }

    return violations.where((violation) {
      return violation.categoryIds.isEmpty ||
          violation.categoryIds.contains(categoryId);
    }).toList();
  }

  static DetectiveViolationType? findById(String id) {
    for (final violation in violations) {
      if (violation.id == id) {
        return violation;
      }
    }

    return null;
  }
}

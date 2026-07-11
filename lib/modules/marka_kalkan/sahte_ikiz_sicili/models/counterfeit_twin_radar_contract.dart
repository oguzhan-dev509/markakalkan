import 'package:cloud_functions/cloud_functions.dart';

enum CounterfeitTwinPublicSection {
  physical('physical', 'Fiziksel Sahte İkizler'),
  digital('digital', 'Dijital Sahte İkizler'),
  aiRobot('ai_robot', 'Yapay Zekâ ve Robot Sahte İkizleri');

  const CounterfeitTwinPublicSection(this.value, this.label);

  final String value;
  final String label;
}

enum CounterfeitTwinTargetType {
  physicalProduct('physical_product', 'Fiziksel ürün'),
  digitalProduct('digital_product', 'Dijital ürün'),
  service('service', 'Hizmet'),
  saasPlatform('saas_platform', 'SaaS platformu'),
  ecommercePlatform('ecommerce_platform', 'E-ticaret platformu'),
  marketplaceStore('marketplace_store', 'Pazaryeri mağazası'),
  tourismBookingPlatform(
    'tourism_booking_platform',
    'Turizm ve rezervasyon platformu',
  ),
  financialService('financial_service', 'Finansal hizmet'),
  paymentPage('payment_page', 'Ödeme sayfası'),
  mobileApplication('mobile_application', 'Mobil uygulama'),
  website('website', 'Web sitesi'),
  socialMediaAccount('social_media_account', 'Sosyal medya hesabı'),
  customerSupportChannel('customer_support_channel', 'Müşteri destek kanalı'),
  institution('institution', 'Kurum veya şirket'),
  roboticSystem('robotic_system', 'Robotik sistem'),
  autonomousAiAgent('autonomous_ai_agent', 'Otonom yapay zekâ ajanı'),
  other('other', 'Diğer');

  const CounterfeitTwinTargetType(this.value, this.label);
  final String value;
  final String label;
}

enum CounterfeitTwinIncidentType {
  productImitation('product_imitation'),
  brandImpersonation('brand_impersonation'),
  platformImpersonation('platform_impersonation'),
  websiteClone('website_clone'),
  mobileAppImpersonation('mobile_app_impersonation'),
  interfaceClone('interface_clone'),
  fakeCheckout('fake_checkout'),
  fakePaymentPage('fake_payment_page'),
  fakeSubscription('fake_subscription'),
  fakeReservation('fake_reservation'),
  fakeFinancialService('fake_financial_service'),
  fakeInvestmentService('fake_investment_service'),
  fakeCustomerSupport('fake_customer_support'),
  credentialPhishing('credential_phishing'),
  paymentDiversion('payment_diversion'),
  ibanDiversion('iban_diversion'),
  merchantIdentityDeception('merchant_identity_deception'),
  unauthorizedCardCharge('unauthorized_card_charge'),
  personalDataHarvesting('personal_data_harvesting'),
  counterfeitRobotHardware('counterfeit_robot_hardware'),
  robotIdentityClone('robot_identity_clone'),
  serialNumberClone('serial_number_clone'),
  deviceCertificateClone('device_certificate_clone'),
  controlSoftwareClone('control_software_clone'),
  firmwareClone('firmware_clone'),
  fakeRobotCertification('fake_robot_certification'),
  teleoperationChannelImpersonation('teleoperation_channel_impersonation'),
  robotFleetImpersonation('robot_fleet_impersonation'),
  aiAgentImpersonation('ai_agent_impersonation'),
  voicePersonaClone('voice_persona_clone'),
  fakeRobotServiceNetwork('fake_robot_service_network'),
  other('other');

  const CounterfeitTwinIncidentType(this.value);
  final String value;
}

enum CounterfeitTwinRobotType {
  industrialRobot('industrial_robot', 'Endüstriyel robot'),
  serviceRobot('service_robot', 'Hizmet robotu'),
  humanoidRobot('humanoid_robot', 'İnsansı robot'),
  medicalRobot('medical_robot', 'Tıbbi robot'),
  logisticsRobot('logistics_robot', 'Lojistik robotu'),
  securityRobot('security_robot', 'Güvenlik robotu'),
  domesticRobot('domestic_robot', 'Ev tipi robot'),
  roboticDevice('robotic_device', 'Robotik cihaz'),
  softwareRobot('software_robot', 'Yazılım robotu / ajan'),
  other('other', 'Diğer');

  const CounterfeitTwinRobotType(this.value, this.label);
  final String value;
  final String label;
}

enum CounterfeitTwinPublicSubcategory {
  foodBeverage(
    'food_beverage',
    'Gıda ve alkolsüz içecek',
    CounterfeitTwinPublicSection.physical,
    CounterfeitTwinTargetType.physicalProduct,
  ),
  pharmaMedicalHealth(
    'pharma_medical_health',
    'İlaç, medikal ve sağlık ürünü',
    CounterfeitTwinPublicSection.physical,
    CounterfeitTwinTargetType.physicalProduct,
  ),
  cosmeticsPersonalCare(
    'cosmetics_personal_care',
    'Kozmetik ve kişisel bakım',
    CounterfeitTwinPublicSection.physical,
    CounterfeitTwinTargetType.physicalProduct,
  ),
  textileFashion(
    'textile_fashion',
    'Tekstil, moda, ayakkabı ve aksesuar',
    CounterfeitTwinPublicSection.physical,
    CounterfeitTwinTargetType.physicalProduct,
  ),
  electronicsElectrical(
    'electronics_electrical',
    'Elektronik ve elektrikli cihaz',
    CounterfeitTwinPublicSection.physical,
    CounterfeitTwinTargetType.physicalProduct,
  ),
  automotiveMachinery(
    'automotive_machinery',
    'Otomotiv, yedek parça ve makine',
    CounterfeitTwinPublicSection.physical,
    CounterfeitTwinTargetType.physicalProduct,
  ),
  homeFurnitureConstruction(
    'home_furniture_construction',
    'Ev, mobilya ve yapı ürünü',
    CounterfeitTwinPublicSection.physical,
    CounterfeitTwinTargetType.physicalProduct,
  ),
  packagingLabelSecurity(
    'packaging_label_security',
    'Ambalaj, etiket ve güvenlik unsuru',
    CounterfeitTwinPublicSection.physical,
    CounterfeitTwinTargetType.physicalProduct,
  ),
  documentCertificateIdentity(
    'document_certificate_identity',
    'Belge, sertifika, garanti ve kimlik unsuru',
    CounterfeitTwinPublicSection.physical,
    CounterfeitTwinTargetType.physicalProduct,
  ),
  productionToolMoldComponent(
    'production_tool_mold_component',
    'Üretim aracı, kalıp ve fiziksel bileşen',
    CounterfeitTwinPublicSection.physical,
    CounterfeitTwinTargetType.physicalProduct,
  ),
  luxuryJewelryCollectible(
    'luxury_jewelry_collectible',
    'Lüks ürün, mücevher ve koleksiyon ürünü',
    CounterfeitTwinPublicSection.physical,
    CounterfeitTwinTargetType.physicalProduct,
  ),
  toyChildSports(
    'toy_child_sports',
    'Oyuncak, çocuk ve spor ürünü',
    CounterfeitTwinPublicSection.physical,
    CounterfeitTwinTargetType.physicalProduct,
  ),
  agricultureChemicalIndustrial(
    'agriculture_chemical_industrial',
    'Tarım, kimya ve endüstriyel ürün',
    CounterfeitTwinPublicSection.physical,
    CounterfeitTwinTargetType.physicalProduct,
  ),
  otherPhysical(
    'other_physical',
    'Diğer fiziksel ürün veya varlık',
    CounterfeitTwinPublicSection.physical,
    CounterfeitTwinTargetType.physicalProduct,
  ),

  websiteDomain(
    'website_domain',
    'Web sitesi ve alan adı',
    CounterfeitTwinPublicSection.digital,
    CounterfeitTwinTargetType.website,
  ),
  mobileApp(
    'mobile_application',
    'Mobil uygulama',
    CounterfeitTwinPublicSection.digital,
    CounterfeitTwinTargetType.mobileApplication,
  ),
  ecommercePlatform(
    'ecommerce_platform',
    'E-ticaret platformu',
    CounterfeitTwinPublicSection.digital,
    CounterfeitTwinTargetType.ecommercePlatform,
  ),
  marketplaceStore(
    'marketplace_store',
    'Pazaryeri mağazası',
    CounterfeitTwinPublicSection.digital,
    CounterfeitTwinTargetType.marketplaceStore,
  ),
  saasCloud(
    'saas_cloud',
    'SaaS ve bulut platformu',
    CounterfeitTwinPublicSection.digital,
    CounterfeitTwinTargetType.saasPlatform,
  ),
  socialMedia(
    'social_media',
    'Sosyal medya hesabı',
    CounterfeitTwinPublicSection.digital,
    CounterfeitTwinTargetType.socialMediaAccount,
  ),
  paymentPage(
    'payment_page',
    'Ödeme sayfası ve ödeme yönlendirmesi',
    CounterfeitTwinPublicSection.digital,
    CounterfeitTwinTargetType.paymentPage,
  ),
  financialInvestment(
    'financial_investment',
    'Finansal veya yatırım hizmeti',
    CounterfeitTwinPublicSection.digital,
    CounterfeitTwinTargetType.financialService,
  ),
  tourismBooking(
    'tourism_booking',
    'Turizm ve rezervasyon platformu',
    CounterfeitTwinPublicSection.digital,
    CounterfeitTwinTargetType.tourismBookingPlatform,
  ),
  customerSupport(
    'customer_support',
    'Müşteri destek kanalı',
    CounterfeitTwinPublicSection.digital,
    CounterfeitTwinTargetType.customerSupportChannel,
  ),
  digitalProductSoftware(
    'digital_product_software',
    'Dijital ürün, yazılım ve lisans',
    CounterfeitTwinPublicSection.digital,
    CounterfeitTwinTargetType.digitalProduct,
  ),
  corporateDigitalIdentity(
    'corporate_digital_identity',
    'Kurumsal veya ticari dijital kimlik',
    CounterfeitTwinPublicSection.digital,
    CounterfeitTwinTargetType.institution,
  ),
  emailMessagingIdentity(
    'email_messaging_identity',
    'E-posta, mesajlaşma ve iletişim kimliği',
    CounterfeitTwinPublicSection.digital,
    CounterfeitTwinTargetType.service,
  ),
  digitalDocumentCertificate(
    'digital_document_certificate',
    'Dijital belge, sertifika ve doğrulama kaydı',
    CounterfeitTwinPublicSection.digital,
    CounterfeitTwinTargetType.digitalProduct,
  ),
  subscriptionMembership(
    'subscription_membership',
    'Abonelik veya üyelik hizmeti',
    CounterfeitTwinPublicSection.digital,
    CounterfeitTwinTargetType.service,
  ),
  otherDigital(
    'other_digital',
    'Diğer dijital varlık veya hizmet',
    CounterfeitTwinPublicSection.digital,
    CounterfeitTwinTargetType.other,
  ),

  autonomousAiAgent(
    'autonomous_ai_agent',
    'Otonom yapay zekâ ajanı',
    CounterfeitTwinPublicSection.aiRobot,
    CounterfeitTwinTargetType.autonomousAiAgent,
    CounterfeitTwinRobotType.softwareRobot,
  ),
  chatbotCustomerAgent(
    'chatbot_customer_agent',
    'Sohbet botu ve müşteri hizmetleri ajanı',
    CounterfeitTwinPublicSection.aiRobot,
    CounterfeitTwinTargetType.autonomousAiAgent,
    CounterfeitTwinRobotType.softwareRobot,
  ),
  voicePersonaVirtualIdentity(
    'voice_persona_virtual_identity',
    'Ses, persona ve sanal kimlik klonu',
    CounterfeitTwinPublicSection.aiRobot,
    CounterfeitTwinTargetType.autonomousAiAgent,
    CounterfeitTwinRobotType.softwareRobot,
  ),
  softwareRobotRpa(
    'software_robot_rpa',
    'Yazılım robotu ve RPA ajanı',
    CounterfeitTwinPublicSection.aiRobot,
    CounterfeitTwinTargetType.autonomousAiAgent,
    CounterfeitTwinRobotType.softwareRobot,
  ),
  industrialRobot(
    'industrial_robot',
    'Endüstriyel robot',
    CounterfeitTwinPublicSection.aiRobot,
    CounterfeitTwinTargetType.roboticSystem,
    CounterfeitTwinRobotType.industrialRobot,
  ),
  serviceRobot(
    'service_robot',
    'Hizmet robotu',
    CounterfeitTwinPublicSection.aiRobot,
    CounterfeitTwinTargetType.roboticSystem,
    CounterfeitTwinRobotType.serviceRobot,
  ),
  humanoidRobot(
    'humanoid_robot',
    'İnsansı robot',
    CounterfeitTwinPublicSection.aiRobot,
    CounterfeitTwinTargetType.roboticSystem,
    CounterfeitTwinRobotType.humanoidRobot,
  ),
  medicalRobot(
    'medical_robot',
    'Tıbbi robot',
    CounterfeitTwinPublicSection.aiRobot,
    CounterfeitTwinTargetType.roboticSystem,
    CounterfeitTwinRobotType.medicalRobot,
  ),
  logisticsDeliveryRobot(
    'logistics_delivery_robot',
    'Lojistik ve teslimat robotu',
    CounterfeitTwinPublicSection.aiRobot,
    CounterfeitTwinTargetType.roboticSystem,
    CounterfeitTwinRobotType.logisticsRobot,
  ),
  securitySurveillanceRobot(
    'security_surveillance_robot',
    'Güvenlik ve gözetim robotu',
    CounterfeitTwinPublicSection.aiRobot,
    CounterfeitTwinTargetType.roboticSystem,
    CounterfeitTwinRobotType.securityRobot,
  ),
  domesticRobot(
    'domestic_robot',
    'Ev tipi robot',
    CounterfeitTwinPublicSection.aiRobot,
    CounterfeitTwinTargetType.roboticSystem,
    CounterfeitTwinRobotType.domesticRobot,
  ),
  roboticDeviceSmartMachine(
    'robotic_device_smart_machine',
    'Robotik cihaz ve akıllı makine',
    CounterfeitTwinPublicSection.aiRobot,
    CounterfeitTwinTargetType.roboticSystem,
    CounterfeitTwinRobotType.roboticDevice,
  ),
  controlSoftwareFirmware(
    'control_software_firmware',
    'Kontrol yazılımı ve firmware',
    CounterfeitTwinPublicSection.aiRobot,
    CounterfeitTwinTargetType.roboticSystem,
    CounterfeitTwinRobotType.softwareRobot,
  ),
  robotFleetDeviceIdentity(
    'robot_fleet_device_identity',
    'Robot filosu ve cihaz kimliği',
    CounterfeitTwinPublicSection.aiRobot,
    CounterfeitTwinTargetType.roboticSystem,
    CounterfeitTwinRobotType.other,
  ),
  serialDeviceCertificateClone(
    'serial_device_certificate_clone',
    'Seri numarası ve cihaz sertifikası klonu',
    CounterfeitTwinPublicSection.aiRobot,
    CounterfeitTwinTargetType.roboticSystem,
    CounterfeitTwinRobotType.other,
  ),
  teleoperationChannel(
    'teleoperation_channel',
    'Uzaktan kontrol ve teleoperasyon kanalı',
    CounterfeitTwinPublicSection.aiRobot,
    CounterfeitTwinTargetType.roboticSystem,
    CounterfeitTwinRobotType.other,
  ),
  robotServiceMaintenanceNetwork(
    'robot_service_maintenance_network',
    'Sahte robot servis ve bakım ağı',
    CounterfeitTwinPublicSection.aiRobot,
    CounterfeitTwinTargetType.roboticSystem,
    CounterfeitTwinRobotType.other,
  ),
  otherAiRobot(
    'other_ai_robot',
    'Diğer yapay zekâ veya robot sistemi',
    CounterfeitTwinPublicSection.aiRobot,
    CounterfeitTwinTargetType.roboticSystem,
    CounterfeitTwinRobotType.other,
  );

  const CounterfeitTwinPublicSubcategory(
    this.value,
    this.label,
    this.section,
    this.targetType, [
    this.robotType,
  ]);

  final String value;
  final String label;
  final CounterfeitTwinPublicSection section;
  final CounterfeitTwinTargetType targetType;
  final CounterfeitTwinRobotType? robotType;

  static CounterfeitTwinPublicSubcategory fromValue(String value) {
    return CounterfeitTwinPublicSubcategory.values.firstWhere(
      (item) => item.value == value,
      orElse: () => CounterfeitTwinPublicSubcategory.otherDigital,
    );
  }

  static List<CounterfeitTwinPublicSubcategory> forSection(
    CounterfeitTwinPublicSection section,
  ) {
    return CounterfeitTwinPublicSubcategory.values
        .where((item) => item.section == section)
        .toList(growable: false);
  }
}

class CounterfeitTwinFinancialImpact {
  const CounterfeitTwinFinancialImpact({
    this.hasMonetaryLoss = false,
    this.lossAmount,
    this.currency = 'TRY',
    this.transactionDate,
    this.paymentMethod,
    this.bankOrPaymentProvider,
    this.merchantDescriptor,
    this.transactionReferenceMasked,
    this.recipientNameMasked,
    this.ibanMasked,
    this.disputeSubmitted = false,
    this.disputeSubmittedAt,
    this.disputeReference,
    this.disputeStatus = 'not_submitted',
    this.refundAmount,
    this.recoveryStatus = 'unknown',
  });

  final bool hasMonetaryLoss;
  final double? lossAmount;
  final String currency;
  final DateTime? transactionDate;
  final String? paymentMethod;
  final String? bankOrPaymentProvider;
  final String? merchantDescriptor;
  final String? transactionReferenceMasked;
  final String? recipientNameMasked;
  final String? ibanMasked;
  final bool disputeSubmitted;
  final DateTime? disputeSubmittedAt;
  final String? disputeReference;
  final String disputeStatus;
  final double? refundAmount;
  final String recoveryStatus;

  Map<String, dynamic> toMap() => <String, dynamic>{
    'hasMonetaryLoss': hasMonetaryLoss,
    'lossAmount': lossAmount,
    'currency': currency,
    'transactionDate': transactionDate?.toUtc().toIso8601String(),
    'paymentMethod': paymentMethod,
    'bankOrPaymentProvider': bankOrPaymentProvider,
    'merchantDescriptor': merchantDescriptor,
    'transactionReferenceMasked': transactionReferenceMasked,
    'recipientNameMasked': recipientNameMasked,
    'ibanMasked': ibanMasked,
    'disputeSubmitted': disputeSubmitted,
    'disputeSubmittedAt': disputeSubmittedAt?.toUtc().toIso8601String(),
    'disputeReference': disputeReference,
    'disputeStatus': disputeStatus,
    'refundAmount': refundAmount,
    'recoveryStatus': recoveryStatus,
  };
}

class CounterfeitTwinRadarReport {
  const CounterfeitTwinRadarReport({
    required this.targetType,
    this.publicCategory,
    this.publicSubcategory,
    required this.originalEntityName,
    required this.suspectedEntityName,
    required this.platformName,
    required this.evidenceNotes,
    this.usagePurpose = '',
    this.technicalIdentity = '',
    this.counterfeitRisk = '',
    this.originalBrandName,
    this.originalProductName,
    this.originalCountry,
    this.originalImageUrls = const <String>[],
    this.originalUrls = const <String>[],
    this.suspectedBrandName,
    this.suspectedProductName,
    this.claimedOriginCountry,
    this.allegedSupplyCountry,
    this.suspectedImageUrls = const <String>[],
    this.suspectedUrls = const <String>[],
    this.incidentTypes = const <CounterfeitTwinIncidentType>[],
    this.robotType,
    this.storeDisplayName,
    this.listingUrl,
    this.authorizedPriceMin,
    this.authorizedPriceMax,
    this.suspectedPrice,
    this.currency = 'TRY',
    this.differenceNotes = const <String>[],
    this.financialImpact = const CounterfeitTwinFinancialImpact(),
  });

  final CounterfeitTwinTargetType targetType;
  final CounterfeitTwinPublicSection? publicCategory;
  final CounterfeitTwinPublicSubcategory? publicSubcategory;
  final String originalEntityName;
  final String suspectedEntityName;
  final String platformName;
  final String evidenceNotes;
  final String usagePurpose;
  final String technicalIdentity;
  final String counterfeitRisk;
  final String? originalBrandName;
  final String? originalProductName;
  final String? originalCountry;
  final List<String> originalImageUrls;
  final List<String> originalUrls;
  final String? suspectedBrandName;
  final String? suspectedProductName;
  final String? claimedOriginCountry;
  final String? allegedSupplyCountry;
  final List<String> suspectedImageUrls;
  final List<String> suspectedUrls;
  final List<CounterfeitTwinIncidentType> incidentTypes;
  final CounterfeitTwinRobotType? robotType;
  final String? storeDisplayName;
  final String? listingUrl;
  final double? authorizedPriceMin;
  final double? authorizedPriceMax;
  final double? suspectedPrice;
  final String currency;
  final List<String> differenceNotes;
  final CounterfeitTwinFinancialImpact financialImpact;

  Map<String, dynamic> toMap() => <String, dynamic>{
    'targetType': targetType.value,
    'publicCategory': publicCategory?.value,
    'publicSubcategory': publicSubcategory?.value,
    'originalEntityName': originalEntityName,
    'suspectedEntityName': suspectedEntityName,
    'platformName': platformName,
    'evidenceNotes': evidenceNotes,
    'usagePurpose': usagePurpose,
    'technicalIdentity': technicalIdentity,
    'counterfeitRisk': counterfeitRisk,
    'originalBrandName': originalBrandName,
    'originalProductName': originalProductName,
    'originalCountry': originalCountry,
    'originalImageUrls': originalImageUrls,
    'originalUrls': originalUrls,
    'suspectedBrandName': suspectedBrandName,
    'suspectedProductName': suspectedProductName,
    'claimedOriginCountry': claimedOriginCountry,
    'allegedSupplyCountry': allegedSupplyCountry,
    'suspectedImageUrls': suspectedImageUrls,
    'suspectedUrls': suspectedUrls,
    'incidentTypes': incidentTypes.map((item) => item.value).toList(),
    'robotType': robotType?.value,
    'storeDisplayName': storeDisplayName,
    'listingUrl': listingUrl,
    'authorizedPriceMin': authorizedPriceMin,
    'authorizedPriceMax': authorizedPriceMax,
    'suspectedPrice': suspectedPrice,
    'currency': currency,
    'differenceNotes': differenceNotes,
    'financialImpact': financialImpact.toMap(),
  };
}

class CounterfeitTwinRadarService {
  CounterfeitTwinRadarService({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'europe-west3');

  final FirebaseFunctions _functions;

  Future<String> submit(CounterfeitTwinRadarReport report) async {
    final result = await _functions
        .httpsCallable('submitCounterfeitTwinReport')
        .call<Map<String, dynamic>>(report.toMap());

    final id = result.data['reportId']?.toString().trim() ?? '';
    if (id.isEmpty) {
      throw StateError('Sahte ikiz bildirimi kimliği alınamadı.');
    }
    return id;
  }
}

import 'package:cloud_functions/cloud_functions.dart';

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
  other('other');

  const CounterfeitTwinIncidentType(this.value);
  final String value;
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
    required this.originalEntityName,
    required this.suspectedEntityName,
    required this.platformName,
    required this.evidenceNotes,
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
  final String originalEntityName;
  final String suspectedEntityName;
  final String platformName;
  final String evidenceNotes;
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
    'originalEntityName': originalEntityName,
    'suspectedEntityName': suspectedEntityName,
    'platformName': platformName,
    'evidenceNotes': evidenceNotes,
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

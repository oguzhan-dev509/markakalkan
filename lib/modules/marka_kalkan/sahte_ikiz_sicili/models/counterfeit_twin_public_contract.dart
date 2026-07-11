import 'package:cloud_functions/cloud_functions.dart';
import 'package:markakalkan/modules/marka_kalkan/sahte_ikiz_sicili/presentation/counterfeit_twin_comparison_codec.dart';

enum CounterfeitTwinPublicCategory {
  physical('physical'),
  digital('digital'),
  aiRobot('ai_robot');

  const CounterfeitTwinPublicCategory(this.value);

  final String value;

  static CounterfeitTwinPublicCategory fromValue(Object? value) {
    final normalized = value?.toString().trim() ?? '';
    return CounterfeitTwinPublicCategory.values.firstWhere(
      (item) => item.value == normalized,
      orElse: () => CounterfeitTwinPublicCategory.digital,
    );
  }
}

class CounterfeitTwinPublicFinancialImpact {
  const CounterfeitTwinPublicFinancialImpact({
    required this.hasMonetaryLoss,
    required this.currency,
    required this.disputeSubmitted,
    required this.disputeStatus,
    required this.recoveryStatus,
    this.lossAmount,
    this.bankOrPaymentProvider = '',
    this.refundAmount,
  });

  factory CounterfeitTwinPublicFinancialImpact.fromMap(Object? value) {
    final map = _map(value);
    return CounterfeitTwinPublicFinancialImpact(
      hasMonetaryLoss: map['hasMonetaryLoss'] == true,
      lossAmount: _number(map['lossAmount']),
      currency: _string(map['currency'], fallback: 'TRY'),
      bankOrPaymentProvider: _string(map['bankOrPaymentProvider']),
      disputeSubmitted: map['disputeSubmitted'] == true,
      disputeStatus: _string(map['disputeStatus'], fallback: 'not_submitted'),
      refundAmount: _number(map['refundAmount']),
      recoveryStatus: _string(map['recoveryStatus'], fallback: 'unknown'),
    );
  }

  final bool hasMonetaryLoss;
  final double? lossAmount;
  final String currency;
  final String bankOrPaymentProvider;
  final bool disputeSubmitted;
  final String disputeStatus;
  final double? refundAmount;
  final String recoveryStatus;
}

class CounterfeitTwinPublicDetail {
  const CounterfeitTwinPublicDetail({
    required this.id,
    required this.slug,
    required this.publicRecordCode,
    required this.publicCategory,
    required this.publicSubcategory,
    required this.targetType,
    required this.comparisonLabel,
    required this.title,
    required this.originalEntityName,
    required this.suspectedEntityName,
    required this.originalBrandName,
    required this.originalProductName,
    required this.originalCountry,
    required this.originalImageUrls,
    required this.originalUrls,
    required this.suspectedBrandName,
    required this.suspectedProductName,
    required this.claimedOriginCountry,
    required this.allegedSupplyCountry,
    required this.suspectedImageUrls,
    required this.suspectedUrls,
    required this.platformName,
    required this.storeDisplayName,
    required this.robotType,
    required this.incidentTypes,
    required this.differenceNotes,
    required this.currency,
    required this.publicSummary,
    required this.verificationLabel,
    required this.canonicalPath,
    required this.shareTitle,
    required this.shareDescription,
    required this.publicationState,
    required this.financialImpact,
    this.usagePurpose = '',
    this.technicalIdentity = '',
    this.counterfeitRisk = '',
    this.authorizedPriceMin,
    this.authorizedPriceMax,
    this.suspectedPrice,
    this.publishedAt,
    this.updatedAt,
    this.withdrawnAt,
  });

  factory CounterfeitTwinPublicDetail.fromMap(Object? value) {
    final map = _map(value);
    return CounterfeitTwinPublicDetail(
      id: _string(map['id']),
      slug: _string(map['slug']),
      publicRecordCode: _string(map['publicRecordCode']),
      publicCategory: CounterfeitTwinPublicCategory.fromValue(
        map['publicCategory'],
      ),
      publicSubcategory: _string(
        map['publicSubcategory'],
        fallback: _legacyPublicSubcategory(map['targetType'], map['robotType']),
      ),
      targetType: _string(map['targetType'], fallback: 'other'),
      comparisonLabel: _string(map['comparisonLabel']),
      title: _string(map['title']),
      usagePurpose: _string(map['usagePurpose']),
      technicalIdentity: _string(map['technicalIdentity']),
      counterfeitRisk: _string(map['counterfeitRisk']),
      originalEntityName: _string(map['originalEntityName']),
      suspectedEntityName: _string(map['suspectedEntityName']),
      originalBrandName: _string(map['originalBrandName']),
      originalProductName: _string(map['originalProductName']),
      originalCountry: _string(map['originalCountry']),
      originalImageUrls: _stringList(map['originalImageUrls']),
      originalUrls: _stringList(map['originalUrls']),
      suspectedBrandName: _string(map['suspectedBrandName']),
      suspectedProductName: _string(map['suspectedProductName']),
      claimedOriginCountry: _string(map['claimedOriginCountry']),
      allegedSupplyCountry: _string(map['allegedSupplyCountry']),
      suspectedImageUrls: _stringList(map['suspectedImageUrls']),
      suspectedUrls: _stringList(map['suspectedUrls']),
      platformName: _string(map['platformName']),
      storeDisplayName: _string(map['storeDisplayName']),
      robotType: _string(map['robotType']),
      incidentTypes: _stringList(map['incidentTypes']),
      differenceNotes: _stringList(map['differenceNotes']),
      authorizedPriceMin: _number(map['authorizedPriceMin']),
      authorizedPriceMax: _number(map['authorizedPriceMax']),
      suspectedPrice: _number(map['suspectedPrice']),
      currency: _string(map['currency'], fallback: 'TRY'),
      publicSummary: _string(map['publicSummary']),
      verificationLabel: _string(
        map['verificationLabel'],
        fallback: 'delille_dogrulandi',
      ),
      canonicalPath: _string(map['canonicalPath']),
      shareTitle: _string(map['shareTitle']),
      shareDescription: _string(map['shareDescription']),
      publicationState: _string(map['publicationState'], fallback: 'published'),
      financialImpact: CounterfeitTwinPublicFinancialImpact.fromMap(
        map['financialImpactSummary'],
      ),
      publishedAt: _dateFromMillis(map['publishedAtMillis']),
      updatedAt: _dateFromMillis(map['updatedAtMillis']),
      withdrawnAt: _dateFromMillis(map['withdrawnAtMillis']),
    );
  }

  String get originalDisplayName {
    if (originalEntityName.isNotEmpty) return originalEntityName;
    if (originalProductName.isNotEmpty) return originalProductName;
    return originalBrandName;
  }

  String get suspectedDisplayName {
    if (suspectedEntityName.isNotEmpty) return suspectedEntityName;
    if (suspectedProductName.isNotEmpty) return suspectedProductName;
    return suspectedBrandName;
  }

  CounterfeitTwinDecodedComparison get decodedComparison =>
      CounterfeitTwinComparisonCodec.decode(differenceNotes);

  final String id;
  final String slug;
  final String publicRecordCode;
  final CounterfeitTwinPublicCategory publicCategory;
  final String publicSubcategory;
  final String targetType;
  final String comparisonLabel;
  final String title;
  final String usagePurpose;
  final String technicalIdentity;
  final String counterfeitRisk;
  final String originalEntityName;
  final String suspectedEntityName;
  final String originalBrandName;
  final String originalProductName;
  final String originalCountry;
  final List<String> originalImageUrls;
  final List<String> originalUrls;
  final String suspectedBrandName;
  final String suspectedProductName;
  final String claimedOriginCountry;
  final String allegedSupplyCountry;
  final List<String> suspectedImageUrls;
  final List<String> suspectedUrls;
  final String platformName;
  final String storeDisplayName;
  final String robotType;
  final List<String> incidentTypes;
  final List<String> differenceNotes;
  final double? authorizedPriceMin;
  final double? authorizedPriceMax;
  final double? suspectedPrice;
  final String currency;
  final String publicSummary;
  final String verificationLabel;
  final String canonicalPath;
  final String shareTitle;
  final String shareDescription;
  final String publicationState;
  final CounterfeitTwinPublicFinancialImpact financialImpact;
  final DateTime? publishedAt;
  final DateTime? updatedAt;
  final DateTime? withdrawnAt;
}

class CounterfeitTwinPublicDetailService {
  CounterfeitTwinPublicDetailService({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'europe-west3');

  final FirebaseFunctions _functions;

  Future<CounterfeitTwinPublicDetail> getBySlug(String slug) async {
    final normalized = slug.trim().toLowerCase();
    if (!RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$').hasMatch(normalized)) {
      throw ArgumentError.value(slug, 'slug', 'Geçersiz kamu kayıt yolu.');
    }

    final result = await _functions
        .httpsCallable('getPublicCounterfeitTwinComparison')
        .call<Map<String, dynamic>>(<String, dynamic>{'slug': normalized});

    return CounterfeitTwinPublicDetail.fromMap(result.data['comparison']);
  }
}

Map<String, dynamic> _map(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return const <String, dynamic>{};
}

String _string(Object? value, {String fallback = ''}) {
  final normalized = value?.toString().trim() ?? '';
  return normalized.isEmpty ? fallback : normalized;
}

double? _number(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '');
}

List<String> _stringList(Object? value) {
  if (value is! List) return const <String>[];
  return value
      .map((item) => item?.toString().trim() ?? '')
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}

String _legacyPublicSubcategory(
  Object? targetTypeValue,
  Object? robotTypeValue,
) {
  final targetType = targetTypeValue?.toString().trim() ?? '';
  final robotType = robotTypeValue?.toString().trim() ?? '';

  const digital = <String, String>{
    'website': 'website_domain',
    'mobile_application': 'mobile_application',
    'ecommerce_platform': 'ecommerce_platform',
    'marketplace_store': 'marketplace_store',
    'saas_platform': 'saas_cloud',
    'social_media_account': 'social_media',
    'payment_page': 'payment_page',
    'financial_service': 'financial_investment',
    'tourism_booking_platform': 'tourism_booking',
    'customer_support_channel': 'customer_support',
    'digital_product': 'digital_product_software',
    'institution': 'corporate_digital_identity',
    'service': 'subscription_membership',
    'other': 'other_digital',
  };

  if (targetType == 'physical_product') return 'other_physical';
  if (targetType == 'autonomous_ai_agent') {
    return 'autonomous_ai_agent';
  }
  if (targetType == 'robotic_system') {
    const robot = <String, String>{
      'industrial_robot': 'industrial_robot',
      'service_robot': 'service_robot',
      'humanoid_robot': 'humanoid_robot',
      'medical_robot': 'medical_robot',
      'logistics_robot': 'logistics_delivery_robot',
      'security_robot': 'security_surveillance_robot',
      'domestic_robot': 'domestic_robot',
      'robotic_device': 'robotic_device_smart_machine',
      'software_robot': 'control_software_firmware',
      'other': 'other_ai_robot',
    };
    return robot[robotType] ?? 'other_ai_robot';
  }
  return digital[targetType] ?? 'other_digital';
}

DateTime? _dateFromMillis(Object? value) {
  if (value is! num) return null;
  return DateTime.fromMillisecondsSinceEpoch(value.toInt(), isUtc: true);
}

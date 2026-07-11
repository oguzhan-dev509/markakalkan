import 'package:cloud_functions/cloud_functions.dart';

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
    required this.targetType,
    required this.comparisonLabel,
    required this.title,
    required this.originalEntityName,
    required this.suspectedEntityName,
    required this.originalBrandName,
    required this.suspectedBrandName,
    required this.platformName,
    required this.robotType,
    required this.incidentTypes,
    required this.differenceNotes,
    required this.publicSummary,
    required this.verificationLabel,
    required this.canonicalPath,
    required this.shareTitle,
    required this.shareDescription,
    required this.publicationState,
    required this.financialImpact,
    this.publishedAt,
    this.updatedAt,
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
      targetType: _string(map['targetType'], fallback: 'other'),
      comparisonLabel: _string(map['comparisonLabel']),
      title: _string(map['title']),
      originalEntityName: _string(map['originalEntityName']),
      suspectedEntityName: _string(map['suspectedEntityName']),
      originalBrandName: _string(map['originalBrandName']),
      suspectedBrandName: _string(map['suspectedBrandName']),
      platformName: _string(map['platformName']),
      robotType: _string(map['robotType']),
      incidentTypes: _stringList(map['incidentTypes']),
      differenceNotes: _stringList(map['differenceNotes']),
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
    );
  }

  final String id;
  final String slug;
  final String publicRecordCode;
  final CounterfeitTwinPublicCategory publicCategory;
  final String targetType;
  final String comparisonLabel;
  final String title;
  final String originalEntityName;
  final String suspectedEntityName;
  final String originalBrandName;
  final String suspectedBrandName;
  final String platformName;
  final String robotType;
  final List<String> incidentTypes;
  final List<String> differenceNotes;
  final String publicSummary;
  final String verificationLabel;
  final String canonicalPath;
  final String shareTitle;
  final String shareDescription;
  final String publicationState;
  final CounterfeitTwinPublicFinancialImpact financialImpact;
  final DateTime? publishedAt;
  final DateTime? updatedAt;
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

DateTime? _dateFromMillis(Object? value) {
  if (value is! num) return null;
  return DateTime.fromMillisecondsSinceEpoch(value.toInt(), isUtc: true);
}

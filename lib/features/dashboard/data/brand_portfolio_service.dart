import 'package:cloud_functions/cloud_functions.dart';

class BrandPortfolioItem {
  const BrandPortfolioItem({
    required this.id,
    required this.brandName,
    required this.companyName,
    required this.sector,
    required this.businessType,
    required this.status,
    required this.createdAt,
  });
  final String id, brandName, companyName, sector, businessType, status;
  final DateTime? createdAt;
  factory BrandPortfolioItem.fromMap(Map<String, dynamic> map) {
    final millis = map['createdAtMillis'];
    return BrandPortfolioItem(
      id: (map['id'] ?? '').toString(),
      brandName: (map['brandName'] ?? '').toString().trim(),
      companyName: (map['companyName'] ?? '').toString().trim(),
      sector: (map['sector'] ?? '').toString().trim(),
      businessType: (map['businessType'] ?? '').toString().trim(),
      status: (map['status'] ?? 'pending').toString().trim(),
      createdAt: millis is num
          ? DateTime.fromMillisecondsSinceEpoch(millis.toInt())
          : null,
    );
  }
}

class BrandPortfolioService {
  BrandPortfolioService({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'europe-west3');
  final FirebaseFunctions _functions;
  Future<List<BrandPortfolioItem>> listMyApplications() async {
    final result = await _functions
        .httpsCallable('listMyBrandApplications')
        .call<Map<String, dynamic>>();
    final raw = result.data['applications'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => BrandPortfolioItem.fromMap(Map<String, dynamic>.from(e)))
        .toList(growable: false);
  }
}

import '../constants/ip_enums.dart';
import 'ip_asset_model.dart';

enum IpAssetInventorySort {
  newestFirst,
  oldestFirst,
  titleAscending,
  riskDescending,
  weakestProtectionFirst,
}

class IpAssetInventoryFilter {
  const IpAssetInventoryFilter({
    this.brandId,
    this.query,
    this.assetType,
    this.status,
    this.riskLevel,
    this.containsTradeSecret,
    this.monitoringEnabled,
    this.missingRightsOnly = false,
    this.missingDocumentsOnly = false,
    this.protectionGapOnly = false,
    this.immediateAttentionOnly = false,
    this.sort = IpAssetInventorySort.newestFirst,
    this.limit = 500,
  });

  final String? brandId;
  final String? query;

  final IpAssetType? assetType;
  final IpAssetStatus? status;
  final IpRiskLevel? riskLevel;

  final bool? containsTradeSecret;
  final bool? monitoringEnabled;

  final bool missingRightsOnly;
  final bool missingDocumentsOnly;
  final bool protectionGapOnly;
  final bool immediateAttentionOnly;

  final IpAssetInventorySort sort;
  final int limit;

  bool get hasActiveFilters {
    return _cleanNullable(brandId) != null ||
        _cleanNullable(query) != null ||
        assetType != null ||
        status != null ||
        riskLevel != null ||
        containsTradeSecret != null ||
        monitoringEnabled != null ||
        missingRightsOnly ||
        missingDocumentsOnly ||
        protectionGapOnly ||
        immediateAttentionOnly;
  }

  IpAssetInventoryFilter normalized() {
    return IpAssetInventoryFilter(
      brandId: _cleanNullable(brandId),
      query: _cleanNullable(query),
      assetType: assetType,
      status: status,
      riskLevel: riskLevel,
      containsTradeSecret: containsTradeSecret,
      monitoringEnabled: monitoringEnabled,
      missingRightsOnly: missingRightsOnly,
      missingDocumentsOnly: missingDocumentsOnly,
      protectionGapOnly: protectionGapOnly,
      immediateAttentionOnly: immediateAttentionOnly,
      sort: sort,
      limit: limit.clamp(1, 500),
    );
  }

  List<IpAssetModel> apply(Iterable<IpAssetModel> source) {
    final normalizedFilter = normalized();
    final normalizedQuery = normalizedFilter.query?.toLowerCase();

    final filtered = source
        .where((asset) {
          if (normalizedFilter.brandId != null &&
              asset.brandId != normalizedFilter.brandId) {
            return false;
          }

          if (normalizedFilter.assetType != null &&
              asset.assetType != normalizedFilter.assetType) {
            return false;
          }

          if (normalizedFilter.status != null &&
              asset.status != normalizedFilter.status) {
            return false;
          }

          if (normalizedFilter.riskLevel != null &&
              asset.riskLevel != normalizedFilter.riskLevel) {
            return false;
          }

          if (normalizedFilter.containsTradeSecret != null &&
              asset.containsTradeSecret !=
                  normalizedFilter.containsTradeSecret) {
            return false;
          }

          if (normalizedFilter.monitoringEnabled != null &&
              asset.monitoringEnabled != normalizedFilter.monitoringEnabled) {
            return false;
          }

          if (normalizedFilter.missingRightsOnly && asset.rightIds.isNotEmpty) {
            return false;
          }

          if (normalizedFilter.missingDocumentsOnly &&
              asset.documentIds.isNotEmpty) {
            return false;
          }

          if (normalizedFilter.protectionGapOnly && !asset.hasProtectionGap) {
            return false;
          }

          if (normalizedFilter.immediateAttentionOnly &&
              !asset.requiresImmediateAttention) {
            return false;
          }

          if (normalizedQuery != null &&
              !_searchableText(asset).contains(normalizedQuery)) {
            return false;
          }

          return true;
        })
        .toList(growable: false);

    final sorted = List<IpAssetModel>.from(filtered);

    sorted.sort((first, second) {
      final primaryComparison = switch (normalizedFilter.sort) {
        IpAssetInventorySort.newestFirst => second.createdAt.compareTo(
          first.createdAt,
        ),
        IpAssetInventorySort.oldestFirst => first.createdAt.compareTo(
          second.createdAt,
        ),
        IpAssetInventorySort.titleAscending =>
          first.title.toLowerCase().compareTo(second.title.toLowerCase()),
        IpAssetInventorySort.riskDescending => _riskRank(
          second.riskLevel,
        ).compareTo(_riskRank(first.riskLevel)),
        IpAssetInventorySort.weakestProtectionFirst => _overallProtectionScore(
          first,
        ).compareTo(_overallProtectionScore(second)),
      };

      if (primaryComparison != 0) {
        return primaryComparison;
      }

      return first.title.toLowerCase().compareTo(second.title.toLowerCase());
    });

    return List<IpAssetModel>.unmodifiable(sorted.take(normalizedFilter.limit));
  }

  IpAssetInventoryFilter copyWith({
    String? brandId,
    String? query,
    IpAssetType? assetType,
    IpAssetStatus? status,
    IpRiskLevel? riskLevel,
    bool? containsTradeSecret,
    bool? monitoringEnabled,
    bool? missingRightsOnly,
    bool? missingDocumentsOnly,
    bool? protectionGapOnly,
    bool? immediateAttentionOnly,
    IpAssetInventorySort? sort,
    int? limit,
    bool clearBrandId = false,
    bool clearQuery = false,
    bool clearAssetType = false,
    bool clearStatus = false,
    bool clearRiskLevel = false,
    bool clearTradeSecretFilter = false,
    bool clearMonitoringFilter = false,
  }) {
    return IpAssetInventoryFilter(
      brandId: clearBrandId ? null : brandId ?? this.brandId,
      query: clearQuery ? null : query ?? this.query,
      assetType: clearAssetType ? null : assetType ?? this.assetType,
      status: clearStatus ? null : status ?? this.status,
      riskLevel: clearRiskLevel ? null : riskLevel ?? this.riskLevel,
      containsTradeSecret: clearTradeSecretFilter
          ? null
          : containsTradeSecret ?? this.containsTradeSecret,
      monitoringEnabled: clearMonitoringFilter
          ? null
          : monitoringEnabled ?? this.monitoringEnabled,
      missingRightsOnly: missingRightsOnly ?? this.missingRightsOnly,
      missingDocumentsOnly: missingDocumentsOnly ?? this.missingDocumentsOnly,
      protectionGapOnly: protectionGapOnly ?? this.protectionGapOnly,
      immediateAttentionOnly:
          immediateAttentionOnly ?? this.immediateAttentionOnly,
      sort: sort ?? this.sort,
      limit: limit ?? this.limit,
    );
  }

  IpAssetInventoryFilter clear() {
    return const IpAssetInventoryFilter();
  }

  static String _searchableText(IpAssetModel asset) {
    return <String>[
      asset.assetCode,
      asset.title,
      asset.description ?? '',
      asset.assetType.label,
      asset.status.label,
      asset.riskLevel.label,
      asset.confidentialityLevel.label,
      asset.sector ?? '',
      asset.category ?? '',
      asset.subcategory ?? '',
      asset.primaryOwnerName ?? '',
      asset.originCountryCode ?? '',
      asset.notes ?? '',
      ...asset.tags,
      ...asset.targetCountryCodes,
    ].join(' ').toLowerCase();
  }

  static int _overallProtectionScore(IpAssetModel asset) {
    return (asset.rightStrengthScore +
            asset.secretSecurityScore +
            asset.responseReadinessScore +
            asset.resilienceScore) ~/
        4;
  }

  static int _riskRank(IpRiskLevel level) {
    return switch (level) {
      IpRiskLevel.informational => 0,
      IpRiskLevel.low => 1,
      IpRiskLevel.medium => 2,
      IpRiskLevel.high => 3,
      IpRiskLevel.critical => 4,
    };
  }

  static String? _cleanNullable(String? value) {
    final cleaned = value?.trim();

    return cleaned == null || cleaned.isEmpty ? null : cleaned;
  }
}

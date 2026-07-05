import '../constants/ip_enums.dart';
import 'ip_asset_inventory_filter.dart';
import 'ip_asset_model.dart';

class IpAssetInventorySummary {
  const IpAssetInventorySummary({
    required this.totalAssetCount,
    required this.activeAssetCount,
    required this.protectedAssetCount,
    required this.archivedAssetCount,
    required this.tradeSecretAssetCount,
    required this.monitoredAssetCount,
    required this.criticalRiskCount,
    required this.highRiskCount,
    required this.immediateAttentionCount,
    required this.protectionGapCount,
    required this.missingRightsCount,
    required this.missingDocumentsCount,
    required this.missingRightsAndDocumentsCount,
    required this.averageRightStrengthScore,
    required this.averageSecretSecurityScore,
    required this.averageResponseReadinessScore,
    required this.averageResilienceScore,
    required this.averageOverallProtectionScore,
    required this.statusCounts,
    required this.riskCounts,
    required this.assetTypeCounts,
  });

  factory IpAssetInventorySummary.empty() {
    return IpAssetInventorySummary.fromAssets(const <IpAssetModel>[]);
  }

  factory IpAssetInventorySummary.fromAssets(Iterable<IpAssetModel> source) {
    final assets = source.toList(growable: false);

    final statusCounts = <IpAssetStatus, int>{
      for (final status in IpAssetStatus.values) status: 0,
    };

    final riskCounts = <IpRiskLevel, int>{
      for (final risk in IpRiskLevel.values) risk: 0,
    };

    final assetTypeCounts = <IpAssetType, int>{
      for (final type in IpAssetType.values) type: 0,
    };

    var rightStrengthTotal = 0;
    var secretSecurityTotal = 0;
    var responseReadinessTotal = 0;
    var resilienceTotal = 0;

    for (final asset in assets) {
      statusCounts[asset.status] = (statusCounts[asset.status] ?? 0) + 1;
      riskCounts[asset.riskLevel] = (riskCounts[asset.riskLevel] ?? 0) + 1;
      assetTypeCounts[asset.assetType] =
          (assetTypeCounts[asset.assetType] ?? 0) + 1;

      rightStrengthTotal += asset.rightStrengthScore;
      secretSecurityTotal += asset.secretSecurityScore;
      responseReadinessTotal += asset.responseReadinessScore;
      resilienceTotal += asset.resilienceScore;
    }

    final count = assets.length;

    final averageRightStrength = _average(rightStrengthTotal, count);
    final averageSecretSecurity = _average(secretSecurityTotal, count);
    final averageResponseReadiness = _average(responseReadinessTotal, count);
    final averageResilience = _average(resilienceTotal, count);

    return IpAssetInventorySummary(
      totalAssetCount: count,
      activeAssetCount: assets
          .where(
            (asset) =>
                asset.status == IpAssetStatus.active ||
                asset.status == IpAssetStatus.protected,
          )
          .length,
      protectedAssetCount: assets
          .where((asset) => asset.status == IpAssetStatus.protected)
          .length,
      archivedAssetCount: assets
          .where(
            (asset) =>
                asset.status == IpAssetStatus.archived ||
                asset.status == IpAssetStatus.retired,
          )
          .length,
      tradeSecretAssetCount: assets
          .where((asset) => asset.isSecretAsset)
          .length,
      monitoredAssetCount: assets
          .where((asset) => asset.monitoringEnabled)
          .length,
      criticalRiskCount: assets
          .where((asset) => asset.riskLevel == IpRiskLevel.critical)
          .length,
      highRiskCount: assets
          .where((asset) => asset.riskLevel == IpRiskLevel.high)
          .length,
      immediateAttentionCount: assets
          .where((asset) => asset.requiresImmediateAttention)
          .length,
      protectionGapCount: assets
          .where((asset) => asset.hasProtectionGap)
          .length,
      missingRightsCount: assets
          .where((asset) => asset.rightIds.isEmpty)
          .length,
      missingDocumentsCount: assets
          .where((asset) => asset.documentIds.isEmpty)
          .length,
      missingRightsAndDocumentsCount: assets
          .where((asset) => asset.rightIds.isEmpty && asset.documentIds.isEmpty)
          .length,
      averageRightStrengthScore: averageRightStrength,
      averageSecretSecurityScore: averageSecretSecurity,
      averageResponseReadinessScore: averageResponseReadiness,
      averageResilienceScore: averageResilience,
      averageOverallProtectionScore: count == 0
          ? 0
          : (averageRightStrength +
                    averageSecretSecurity +
                    averageResponseReadiness +
                    averageResilience) /
                4,
      statusCounts: Map<IpAssetStatus, int>.unmodifiable(statusCounts),
      riskCounts: Map<IpRiskLevel, int>.unmodifiable(riskCounts),
      assetTypeCounts: Map<IpAssetType, int>.unmodifiable(assetTypeCounts),
    );
  }

  final int totalAssetCount;
  final int activeAssetCount;
  final int protectedAssetCount;
  final int archivedAssetCount;

  final int tradeSecretAssetCount;
  final int monitoredAssetCount;

  final int criticalRiskCount;
  final int highRiskCount;
  final int immediateAttentionCount;
  final int protectionGapCount;

  final int missingRightsCount;
  final int missingDocumentsCount;
  final int missingRightsAndDocumentsCount;

  final double averageRightStrengthScore;
  final double averageSecretSecurityScore;
  final double averageResponseReadinessScore;
  final double averageResilienceScore;
  final double averageOverallProtectionScore;

  final Map<IpAssetStatus, int> statusCounts;
  final Map<IpRiskLevel, int> riskCounts;
  final Map<IpAssetType, int> assetTypeCounts;

  int statusCount(IpAssetStatus status) {
    return statusCounts[status] ?? 0;
  }

  int riskCount(IpRiskLevel riskLevel) {
    return riskCounts[riskLevel] ?? 0;
  }

  int assetTypeCount(IpAssetType assetType) {
    return assetTypeCounts[assetType] ?? 0;
  }

  bool get isEmpty => totalAssetCount == 0;

  bool get hasCriticalExposure {
    return criticalRiskCount > 0 ||
        immediateAttentionCount > 0 ||
        protectionGapCount > 0;
  }

  double get rightsCoverageRate {
    return _coverageRate(totalAssetCount - missingRightsCount, totalAssetCount);
  }

  double get documentCoverageRate {
    return _coverageRate(
      totalAssetCount - missingDocumentsCount,
      totalAssetCount,
    );
  }

  double get monitoringCoverageRate {
    return _coverageRate(monitoredAssetCount, totalAssetCount);
  }

  static double _average(int total, int count) {
    return count == 0 ? 0 : total / count;
  }

  static double _coverageRate(int covered, int total) {
    return total == 0 ? 0 : covered / total;
  }
}

class IpAssetInventorySnapshot {
  const IpAssetInventorySnapshot({
    required this.assets,
    required this.summary,
    required this.filter,
    required this.generatedAt,
  });

  final List<IpAssetModel> assets;
  final IpAssetInventorySummary summary;
  final IpAssetInventoryFilter filter;
  final DateTime generatedAt;

  int get visibleAssetCount => assets.length;

  bool get hasResults => assets.isNotEmpty;

  bool get isFiltered {
    return filter.hasActiveFilters ||
        visibleAssetCount != summary.totalAssetCount;
  }
}

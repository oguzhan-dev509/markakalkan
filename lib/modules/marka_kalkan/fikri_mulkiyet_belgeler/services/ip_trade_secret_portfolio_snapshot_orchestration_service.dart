import '../constants/ip_trade_secret_detail_enums.dart';
import '../models/ip_trade_secret_portfolio_summary_model.dart';
import '../repositories/ip_trade_secret_portfolio_data_source.dart';
import '../repositories/ip_trade_secret_portfolio_snapshot_repository.dart';
import 'ip_trade_secret_portfolio_aggregation_service.dart';

abstract interface class IpTradeSecretPortfolioSnapshotStorePort {
  Future<bool> snapshotExists(String snapshotId);

  Future<IpTradeSecretPortfolioSummaryModel?> getSnapshot(String snapshotId);

  Future<IpTradeSecretPortfolioSummaryModel?> findPreviousSnapshot({
    required String tenantId,
    required IpTradeSecretPortfolioScope scope,
    required String scopeId,
    String? brandId,
    required DateTime before,
  });

  Future<void> saveSnapshot(
    IpTradeSecretPortfolioSummaryModel summary, {
    bool overwrite,
  });
}

class IpTradeSecretPortfolioSnapshotRepositoryAdapter
    implements IpTradeSecretPortfolioSnapshotStorePort {
  const IpTradeSecretPortfolioSnapshotRepositoryAdapter({
    required IpTradeSecretPortfolioSnapshotRepository repository,
  }) : _repository = repository;

  final IpTradeSecretPortfolioSnapshotRepository _repository;

  @override
  Future<bool> snapshotExists(String snapshotId) {
    return _repository.snapshotExists(snapshotId);
  }

  @override
  Future<IpTradeSecretPortfolioSummaryModel?> getSnapshot(String snapshotId) {
    return _repository.getSnapshot(snapshotId);
  }

  @override
  Future<IpTradeSecretPortfolioSummaryModel?> findPreviousSnapshot({
    required String tenantId,
    required IpTradeSecretPortfolioScope scope,
    required String scopeId,
    String? brandId,
    required DateTime before,
  }) async {
    final snapshots = await _repository.listSnapshots(
      tenantId: tenantId,
      brandId: brandId,
      scope: scope,
      limit: 100,
    );

    for (final snapshot in snapshots) {
      if (snapshot.scopeId == scopeId &&
          snapshot.generatedAt.toUtc().isBefore(before.toUtc())) {
        return snapshot;
      }
    }

    return null;
  }

  @override
  Future<void> saveSnapshot(
    IpTradeSecretPortfolioSummaryModel summary, {
    bool overwrite = false,
  }) {
    return _repository.saveSnapshot(summary, overwrite: overwrite);
  }
}

class IpTradeSecretPortfolioSnapshotRequest {
  const IpTradeSecretPortfolioSnapshotRequest({
    required this.tenantId,
    required this.scope,
    required this.scopeId,
    required this.generatedBy,
    required this.generatedAt,
    this.brandId,
    this.businessUnitId,
    this.departmentId,
    this.countryCode,
    this.categoryCode,
    this.snapshotStartAt,
    this.snapshotEndAt,
    this.persist = true,
    this.overwrite = false,
    this.usePreviousSnapshot = true,
  });

  final String tenantId;
  final IpTradeSecretPortfolioScope scope;
  final String scopeId;
  final String generatedBy;
  final DateTime generatedAt;
  final String? brandId;
  final String? businessUnitId;
  final String? departmentId;
  final String? countryCode;
  final String? categoryCode;
  final DateTime? snapshotStartAt;
  final DateTime? snapshotEndAt;
  final bool persist;
  final bool overwrite;
  final bool usePreviousSnapshot;
}

class IpTradeSecretPortfolioSnapshotResult {
  const IpTradeSecretPortfolioSnapshotResult({
    required this.summary,
    required this.sourceRecordCounts,
    required this.totalSourceRecordCount,
    required this.persisted,
    required this.duplicateFound,
    required this.previewOnly,
  });

  final IpTradeSecretPortfolioSummaryModel summary;
  final Map<String, int> sourceRecordCounts;
  final int totalSourceRecordCount;
  final bool persisted;
  final bool duplicateFound;
  final bool previewOnly;
}

class IpTradeSecretPortfolioSnapshotOrchestrationService {
  const IpTradeSecretPortfolioSnapshotOrchestrationService({
    required IpTradeSecretPortfolioDataSourcePort dataSource,
    required IpTradeSecretPortfolioSnapshotStorePort snapshotStore,
    required IpTradeSecretPortfolioAggregationService aggregationService,
  }) : _dataSource = dataSource,
       _snapshotStore = snapshotStore,
       _aggregationService = aggregationService;

  final IpTradeSecretPortfolioDataSourcePort _dataSource;
  final IpTradeSecretPortfolioSnapshotStorePort _snapshotStore;
  final IpTradeSecretPortfolioAggregationService _aggregationService;

  Future<IpTradeSecretPortfolioSnapshotResult> run(
    IpTradeSecretPortfolioSnapshotRequest request,
  ) async {
    _validateRequest(request);

    final snapshotEndAt = request.snapshotEndAt ?? request.generatedAt;
    final snapshotId = _aggregationService.buildSnapshotId(
      tenantId: request.tenantId,
      scope: request.scope,
      scopeId: request.scopeId,
      snapshotEndAt: snapshotEndAt,
    );

    if (request.persist && !request.overwrite) {
      final exists = await _snapshotStore.snapshotExists(snapshotId);

      if (exists) {
        final existing = await _snapshotStore.getSnapshot(snapshotId);

        if (existing == null) {
          throw StateError(
            'Snapshot mevcut görünüyor ancak okunamadı: $snapshotId',
          );
        }

        return IpTradeSecretPortfolioSnapshotResult(
          summary: existing,
          sourceRecordCounts: const <String, int>{},
          totalSourceRecordCount: 0,
          persisted: false,
          duplicateFound: true,
          previewOnly: false,
        );
      }
    }

    final dataSet = await _dataSource.loadPortfolioData(
      tenantId: request.tenantId,
      brandId: request.brandId,
    );

    final previousSummary = request.usePreviousSnapshot
        ? await _snapshotStore.findPreviousSnapshot(
            tenantId: request.tenantId,
            scope: request.scope,
            scopeId: request.scopeId,
            brandId: request.brandId,
            before: request.generatedAt,
          )
        : null;

    final facts = _buildFacts(
      dataSet,
      generatedAt: request.generatedAt,
      countryCode: request.countryCode,
    );

    final summary = _aggregationService.aggregateFacts(
      tenantId: request.tenantId,
      scope: request.scope,
      scopeId: request.scopeId,
      generatedBy: request.generatedBy,
      generatedAt: request.generatedAt,
      facts: facts,
      brandId: request.brandId,
      businessUnitId: request.businessUnitId,
      departmentId: request.departmentId,
      countryCode: request.countryCode,
      categoryCode: request.categoryCode,
      snapshotStartAt: request.snapshotStartAt,
      snapshotEndAt: request.snapshotEndAt,
      previousSummary: previousSummary,
    );

    summary.toMap();

    if (request.persist) {
      await _snapshotStore.saveSnapshot(summary, overwrite: request.overwrite);
    }

    return IpTradeSecretPortfolioSnapshotResult(
      summary: summary,
      sourceRecordCounts: dataSet.sourceRecordCounts,
      totalSourceRecordCount: dataSet.totalSourceRecordCount,
      persisted: request.persist,
      duplicateFound: false,
      previewOnly: !request.persist,
    );
  }

  IpTradeSecretPortfolioAggregationFacts _buildFacts(
    IpTradeSecretPortfolioDataSet dataSet, {
    required DateTime generatedAt,
    String? countryCode,
  }) {
    final now = generatedAt.toUtc();
    final expiringLimit = now.add(const Duration(days: 30));

    final exposureByCurrency = <String, num>{};
    for (final risk in dataSet.riskAssessments) {
      final amount = risk.financialExposureAmount;
      final currency = risk.financialExposureCurrency?.trim().toUpperCase();

      if (amount != null &&
          amount > 0 &&
          currency != null &&
          currency.length == 3) {
        exposureByCurrency.update(
          currency,
          (value) => value + amount,
          ifAbsent: () => amount,
        );
      }
    }

    final departmentRiskCounts = <String, int>{};
    for (final secret in dataSet.tradeSecrets) {
      final department = secret.ownerDepartment?.trim();
      if (department != null && department.isNotEmpty) {
        departmentRiskCounts.update(
          department,
          (value) => value + 1,
          ifAbsent: () => 1,
        );
      }
    }

    final categoryRiskCounts = <String, int>{};
    for (final secret in dataSet.tradeSecrets) {
      categoryRiskCounts.update(
        secret.secretType.value,
        (value) => value + 1,
        ifAbsent: () => 1,
      );
    }

    final countryRiskCounts = <String, int>{};
    final cleanedCountryCode = countryCode?.trim().toUpperCase();
    if (cleanedCountryCode != null && cleanedCountryCode.length == 2) {
      countryRiskCounts[cleanedCountryCode] = dataSet.tradeSecrets.length;
    }

    return IpTradeSecretPortfolioAggregationFacts(
      tradeSecretIds: dataSet.tradeSecrets.map((item) => item.id).toList(),
      activeTradeSecretIds: dataSet.tradeSecrets
          .where((item) => item.status.value == 'active')
          .map((item) => item.id)
          .toList(),
      retiredTradeSecretIds: dataSet.tradeSecrets
          .where(
            (item) => <String>{
              'retired',
              'archived',
              'closed',
            }.contains(item.status.value),
          )
          .map((item) => item.id)
          .toList(),
      criticalTradeSecretIds: dataSet.tradeSecrets
          .where((item) => item.riskLevel.value == 'critical')
          .map((item) => item.id)
          .toList(),
      highRiskTradeSecretIds: dataSet.tradeSecrets
          .where((item) => item.riskLevel.value == 'high')
          .map((item) => item.id)
          .toList(),
      openIncidentIds: dataSet.incidents
          .where((item) => item.isOpen)
          .map((item) => item.id)
          .toList(),
      highImpactIncidentIds: dataSet.incidents
          .where(
            (item) =>
                item.isCritical ||
                item.businessImpactScore >= 80 ||
                item.legalImpactScore >= 80 ||
                item.reputationImpactScore >= 80,
          )
          .map((item) => item.id)
          .toList(),
      overdueRemediationActionIds: dataSet.remediationActions
          .where((item) => item.isOverdue || item.isVerificationOverdue)
          .map((item) => item.id)
          .toList(),
      blockedRemediationActionIds: dataSet.remediationActions
          .where((item) => item.blocked)
          .map((item) => item.id)
          .toList(),
      criticalAlertRuleIds: dataSet.alertRules
          .where(
            (item) =>
                item.severity.value == 'critical' &&
                item.shouldAppearOnAlertDashboard,
          )
          .map((item) => item.id)
          .toList(),
      unresolvedAlertRuleIds: dataSet.alertRules
          .where(
            (item) =>
                !<String>{'resolved', 'disabled'}.contains(item.status.value),
          )
          .map((item) => item.id)
          .toList(),
      pendingDecisionIds: dataSet.managementDecisions
          .where(
            (item) => <String>{
              'under_review',
              'pending_approval',
              'conditionally_approved',
              'suspended',
            }.contains(item.status.value),
          )
          .map((item) => item.id)
          .toList(),
      riskAcceptanceDecisionIds: dataSet.managementDecisions
          .where((item) => item.isRiskAcceptanceDecision)
          .map((item) => item.id)
          .toList(),
      weakControlIds: dataSet.protectionControls
          .where((item) => !item.isEffective || item.hasOpenFindings)
          .map((item) => item.id)
          .toList(),
      missingEvidenceRecordIds: dataSet.defensibilityRecords
          .where(
            (item) =>
                item.hasCriticalEvidenceGap ||
                item.overallDefensibilityScore < 60,
          )
          .map((item) => item.id)
          .toList(),
      highRiskExitTransitionIds: dataSet.lifecycleTransitions
          .where((item) => item.highRiskExit)
          .map((item) => item.id)
          .toList(),
      expiringAccessGrantIds: dataSet.accessGrants
          .where((item) {
            final expiry = item.validUntil;
            return item.isActive &&
                expiry != null &&
                !expiry.isBefore(now) &&
                !expiry.isAfter(expiringLimit);
          })
          .map((item) => item.id)
          .toList(),
      overdueReviewRecordIds: <String>[
        ...dataSet.tradeSecrets
            .where(
              (item) =>
                  item.nextAccessReviewAt != null &&
                  item.nextAccessReviewAt!.isBefore(now),
            )
            .map((item) => item.id),
        ...dataSet.protectionControls
            .where((item) => item.isOverdueForReview)
            .map((item) => item.id),
        ...dataSet.riskAssessments
            .where(
              (item) =>
                  item.nextReviewAt != null && item.nextReviewAt!.isBefore(now),
            )
            .map((item) => item.id),
        ...dataSet.resilienceProfiles
            .where((item) => item.isReviewOverdue)
            .map((item) => item.id),
        ...dataSet.defensibilityRecords
            .where(
              (item) =>
                  item.nextReviewAt != null && item.nextReviewAt!.isBefore(now),
            )
            .map((item) => item.id),
        ...dataSet.managementDecisions
            .where((item) => item.requiresReassessment)
            .map((item) => item.id),
      ],
      riskScores: dataSet.riskAssessments
          .map((item) => item.residualRiskScore)
          .toList(),
      resilienceScores: dataSet.resilienceProfiles
          .map((item) => item.overallResilienceScore)
          .toList(),
      defensibilityScores: dataSet.defensibilityRecords
          .map((item) => item.overallDefensibilityScore)
          .toList(),
      controlEffectivenessScores: dataSet.protectionControls
          .map((item) => item.operatingEffectivenessScore)
          .toList(),
      financialExposureByCurrency: exposureByCurrency,
      departmentRiskCounts: departmentRiskCounts,
      countryRiskCounts: countryRiskCounts,
      categoryRiskCounts: categoryRiskCounts,
      managementAttentionRequired:
          dataSet.resilienceProfiles.any(
            (item) => item.managementEscalationRequired,
          ) ||
          dataSet.remediationActions.any(
            (item) => item.managementEscalationRequired,
          ) ||
          dataSet.lifecycleTransitions.any(
            (item) => item.managementEscalationRequired,
          ),
      legalAttentionRequired:
          dataSet.incidents.any(
            (item) => item.legalReviewRequired && !item.legalReviewCompleted,
          ) ||
          dataSet.defensibilityRecords.any(
            (item) => item.requiresImmediateEscalation,
          ),
      securityAttentionRequired:
          dataSet.alertRules.any((item) => item.securityEscalationRequired) ||
          dataSet.incidents.any((item) => item.requiresImmediateEscalation),
      dataCompletenessWarning:
          dataSet.tradeSecrets.isNotEmpty && dataSet.riskAssessments.isEmpty,
    );
  }

  void _validateRequest(IpTradeSecretPortfolioSnapshotRequest request) {
    if (request.tenantId.trim().isEmpty) {
      throw ArgumentError.value(
        request.tenantId,
        'tenantId',
        'Tenant kimliği boş olamaz.',
      );
    }

    if (request.scopeId.trim().isEmpty) {
      throw ArgumentError.value(
        request.scopeId,
        'scopeId',
        'Portföy kapsam kimliği boş olamaz.',
      );
    }

    if (request.generatedBy.trim().isEmpty) {
      throw ArgumentError.value(
        request.generatedBy,
        'generatedBy',
        'Snapshot üreticisi boş olamaz.',
      );
    }

    if (request.snapshotStartAt != null &&
        request.snapshotEndAt != null &&
        request.snapshotEndAt!.isBefore(request.snapshotStartAt!)) {
      throw StateError(
        'Snapshot bitiş tarihi başlangıç tarihinden önce olamaz.',
      );
    }

    if (request.scope == IpTradeSecretPortfolioScope.brand &&
        (request.brandId == null || request.brandId!.trim().isEmpty)) {
      throw StateError('Marka kapsamlı snapshot için brandId zorunludur.');
    }

    if (request.scope == IpTradeSecretPortfolioScope.businessUnit &&
        (request.businessUnitId == null ||
            request.businessUnitId!.trim().isEmpty)) {
      throw StateError(
        'İş birimi kapsamlı snapshot için businessUnitId zorunludur.',
      );
    }

    if (request.scope == IpTradeSecretPortfolioScope.department &&
        (request.departmentId == null ||
            request.departmentId!.trim().isEmpty)) {
      throw StateError(
        'Departman kapsamlı snapshot için departmentId zorunludur.',
      );
    }

    if (request.scope == IpTradeSecretPortfolioScope.country &&
        (request.countryCode == null ||
            request.countryCode!.trim().length != 2)) {
      throw StateError(
        'Ülke kapsamlı snapshot için iki harfli countryCode zorunludur.',
      );
    }

    if (request.scope == IpTradeSecretPortfolioScope.category &&
        (request.categoryCode == null ||
            request.categoryCode!.trim().isEmpty)) {
      throw StateError(
        'Kategori kapsamlı snapshot için categoryCode zorunludur.',
      );
    }
  }
}

import 'package:flutter/material.dart';
import 'package:markakalkan/features/admin/presentation/management_center_page.dart';
import 'package:markakalkan/features/admin/presentation/counterfeit_twin_review_queue_page.dart';
import 'package:markakalkan/features/auth/domain/markakalkan_auth_intent.dart';
import 'package:markakalkan/features/auth/presentation/brand_application_page.dart';
import 'package:markakalkan/features/auth/presentation/brand_login_page.dart';
import 'package:markakalkan/features/auth/presentation/corporate_access_page.dart';
import 'package:markakalkan/features/dashboard/presentation/brand_dashboard_page.dart';
import 'package:markakalkan/features/dashboard/presentation/brand_portfolio_page.dart';
import 'package:markakalkan/features/product_codes/presentation/product_codes_page.dart';
import 'package:markakalkan/features/production_batches/presentation/production_batches_page.dart';
import 'package:markakalkan/features/products/presentation/products_page.dart';
import 'package:markakalkan/features/risk_operations/data/risk_operations_repository.dart';
import 'package:markakalkan/features/verification/presentation/product_verification_page.dart';
import 'package:markakalkan/features/verification/presentation/qr_scanner_page.dart';
import 'package:markakalkan/features/traceability/presentation/suspicious_verification_scans_page.dart';
import 'package:markakalkan/features/traceability/presentation/traceability_cases_page.dart';
import 'package:markakalkan/features/risk_operations/presentation/risk_operations_console_page.dart';
import 'package:markakalkan/features/auth/presentation/brand_account_creation_page.dart';
import 'package:markakalkan/features/dashboard/presentation/corporate_hub_page.dart';
import 'package:markakalkan/features/detective/presentation/brand_detective_hub_page.dart';
import 'package:markakalkan/features/detective/presentation/ai_field_detectives_hub_page.dart';
import 'package:markakalkan/features/detective/presentation/ai_field_operation_create_page.dart';
import 'package:markakalkan/features/detective/presentation/digital_detective_task_page.dart';
import 'package:markakalkan/features/detective/presentation/digital_detective_tasks_page.dart';
import 'package:markakalkan/features/detective/presentation/digital_detective_findings_page.dart';
import 'package:markakalkan/features/detective/presentation/digital_brand_intelligence_report_page.dart';
import 'package:markakalkan/modules/marka_kalkan/dijital_pazar_izleme/presentation/dijital_pazar_izleme_sayfasi.dart';
import 'package:markakalkan/modules/marka_kalkan/dijital_pazar_izleme/presentation/marka_izleme_profili_sayfasi.dart';
import 'package:markakalkan/modules/marka_kalkan/dijital_pazar_izleme/presentation/kaynak_yonetimi_sayfasi.dart';
import 'package:markakalkan/modules/marka_kalkan/dijital_pazar_izleme/presentation/izlenen_sayfalar_sayfasi.dart';
import 'package:markakalkan/modules/marka_kalkan/dijital_pazar_izleme/presentation/tarama_gorevleri_sayfasi.dart';
import 'package:markakalkan/modules/marka_kalkan/dijital_pazar_izleme/presentation/izleme_olaylari_sayfasi.dart';
import 'package:markakalkan/modules/marka_kalkan/dijital_pazar_izleme/presentation/risk_sinyalleri_sayfasi.dart';
import 'package:markakalkan/modules/marka_kalkan/dijital_pazar_izleme/presentation/dijital_pazar_ana_paneli_sayfasi.dart';
import 'package:markakalkan/modules/marka_kalkan/dijital_pazar_izleme/presentation/rapor_merkezi_sayfasi.dart';
import 'package:markakalkan/modules/marka_kalkan/dijital_pazar_izleme/presentation/yonetici_ozeti_raporu_sayfasi.dart';
import 'package:markakalkan/modules/marka_kalkan/dijital_pazar_izleme/presentation/marka_risk_raporu_sayfasi.dart';
import 'package:markakalkan/modules/marka_kalkan/dijital_pazar_izleme/presentation/vaka_kanit_raporu_sayfasi.dart';

import 'package:markakalkan/modules/marka_kalkan/fikri_mulkiyet_belgeler/presentation/ip_document_vault_page.dart';
import 'package:markakalkan/modules/marka_kalkan/fikri_mulkiyet_belgeler/presentation/ip_creation_priority_registry_page.dart';
import 'package:markakalkan/modules/marka_kalkan/fikri_mulkiyet_belgeler/presentation/ip_trade_secret_shield_page.dart';
import 'package:markakalkan/modules/marka_kalkan/fikri_mulkiyet_belgeler/presentation/ip_trade_secret_access_disclosure_page.dart';
import 'package:markakalkan/modules/marka_kalkan/fikri_mulkiyet_belgeler/presentation/ip_trade_secret_incident_page.dart';
import 'package:markakalkan/modules/marka_kalkan/fikri_mulkiyet_belgeler/presentation/ip_trade_secret_inventory_page.dart';
import 'package:markakalkan/modules/marka_kalkan/fikri_mulkiyet_belgeler/presentation/ip_trade_secret_management_decision_page.dart';
import 'package:markakalkan/modules/marka_kalkan/fikri_mulkiyet_belgeler/presentation/ip_trade_secret_protection_control_page.dart';
import 'package:markakalkan/modules/marka_kalkan/fikri_mulkiyet_belgeler/presentation/ip_trade_secret_remediation_action_page.dart';

import 'package:markakalkan/modules/marka_kalkan/fason_uretim_tedarik_guvenligi/presentation/supply_security_hub_page.dart';
import 'package:markakalkan/modules/marka_kalkan/sahte_ikiz_sicili/presentation/counterfeit_twin_registry_page.dart';
import 'package:markakalkan/modules/marka_kalkan/sahte_ikiz_sicili/presentation/counterfeit_twin_public_radar_page.dart';
import 'package:markakalkan/modules/marka_kalkan/sahte_ikiz_sicili/presentation/counterfeit_twin_public_detail_page.dart';

abstract final class AppRouter {
  static Future<void> openManagementCenter(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const ManagementCenterPage()),
    );
  }

  static Future<void> openCounterfeitTwinReviewQueue(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const CounterfeitTwinReviewQueuePage(),
      ),
    );
  }

  static Future<void> openIpCreationPriorityRegistry(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const IpCreationPriorityRegistryPage(),
      ),
    );
  }

  static Future<void> openCounterfeitTwinRegistry(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const CounterfeitTwinRegistryPage(),
      ),
    );
  }

  static Future<void> openCounterfeitTwinPublicRadar(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const CounterfeitTwinPublicRadarPage(),
      ),
    );
  }

  static Future<void> openCounterfeitTwinPublicDetail(
    BuildContext context, {
    required String slug,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: RouteSettings(name: '/sahte-ikiz/$slug'),
        builder: (_) => CounterfeitTwinPublicDetailPage(slug: slug),
      ),
    );
  }

  static Future<void> openSupplySecurityHub(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const SupplySecurityHubPage()),
    );
  }

  static Future<void> openIpTradeSecretManagementDecision(
    BuildContext context,
  ) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const IpTradeSecretManagementDecisionPage(),
      ),
    );
  }

  static Future<void> openIpTradeSecretRemediationAction(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const IpTradeSecretRemediationActionPage(),
      ),
    );
  }

  static Future<void> openIpTradeSecretProtectionControl(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const IpTradeSecretProtectionControlPage(),
      ),
    );
  }

  static Future<void> openIpTradeSecretAccessDisclosure(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const IpTradeSecretAccessDisclosurePage(),
      ),
    );
  }

  static Future<void> openIpTradeSecretIncident(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const IpTradeSecretIncidentPage(),
      ),
    );
  }

  static Future<void> openIpTradeSecretInventory(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const IpTradeSecretInventoryPage(),
      ),
    );
  }

  static Future<void> openIpTradeSecretShield(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const IpTradeSecretShieldPage()),
    );
  }

  static Future<void> openIpDocumentVault(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const IpDocumentVaultPage()),
    );
  }

  static Future<void> openVakaKanitRaporu(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const VakaKanitRaporuSayfasi()),
    );
  }

  static Future<void> openMarkaRiskRaporu(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const MarkaRiskRaporuSayfasi()),
    );
  }

  static Future<void> openYoneticiOzetiRaporu(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const YoneticiOzetiRaporuSayfasi(),
      ),
    );
  }

  static Future<void> openRaporMerkezi(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const RaporMerkeziSayfasi()),
    );
  }

  static Future<void> openDijitalPazarAnaPaneli(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const DijitalPazarAnaPaneliSayfasi(),
      ),
    );
  }

  static Future<void> openRiskSinyalleri(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const RiskSinyalleriSayfasi()),
    );
  }

  static Future<void> openIzlemeOlaylari(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const IzlemeOlaylariSayfasi()),
    );
  }

  static Future<void> openTaramaGorevleri(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const TaramaGorevleriSayfasi()),
    );
  }

  static Future<void> openIzlenenSayfalar(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const IzlenenSayfalarSayfasi()),
    );
  }

  static Future<void> openKaynakYonetimi(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const KaynakYonetimiSayfasi()),
    );
  }

  static Future<void> openMarkaIzlemeProfili(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const MarkaIzlemeProfiliSayfasi(),
      ),
    );
  }

  static Future<void> openDijitalPazarIzleme(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const DijitalPazarIzlemeSayfasi(),
      ),
    );
  }

  static Future<bool?> openBrandLogin(
    BuildContext context, {
    MarkaKalkanAuthIntent intent = MarkaKalkanAuthIntent.corporateManagement,
  }) {
    return Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => BrandLoginPage(intent: intent)),
    );
  }

  static Future<void> openDigitalDetectiveTasks(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const DigitalDetectiveTasksPage(),
      ),
    );
  }

  static Future<void> openDigitalDetectiveFindings(
    BuildContext context, {
    required String taskId,
    required String taskName,
    required String brandName,
    required String productName,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DigitalDetectiveFindingsPage(
          taskId: taskId,
          taskName: taskName,
          brandName: brandName,
          productName: productName,
        ),
      ),
    );
  }

  static Future<void> openDigitalBrandIntelligenceReport(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const DigitalBrandIntelligenceReportPage(),
      ),
    );
  }

  static Future<void> openDigitalDetectiveTask(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const DigitalDetectiveTaskPage()),
    );
  }

  static Future<String?> openAiFieldOperationCreate(BuildContext context) {
    return Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (_) => const AiFieldOperationCreatePage(),
      ),
    );
  }

  static Future<void> openAiFieldDetectivesHub(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const AiFieldDetectivesHubPage()),
    );
  }

  static Future<void> openBrandDetectiveHub(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const BrandDetectiveHubPage()),
    );
  }

  static Future<bool?> openBrandAccountCreation(
    BuildContext context, {
    MarkaKalkanAuthIntent intent = MarkaKalkanAuthIntent.corporateManagement,
  }) {
    return Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => BrandAccountCreationPage(intent: intent),
      ),
    );
  }

  static Future<void> openBrandApplication(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const BrandApplicationPage()),
    );
  }

  static Future<void> openProductVerification(
    BuildContext context, {
    String? initialCode,
    bool autoVerify = false,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProductVerificationPage(
          initialCode: initialCode,
          autoVerify: autoVerify,
        ),
      ),
    );
  }

  static Future<String?> openQrScanner(BuildContext context) {
    return Navigator.of(context).push<String>(
      MaterialPageRoute<String>(builder: (_) => const QrScannerPage()),
    );
  }

  static void openCorporateAccess(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const CorporateAccessPage()),
      (route) => route.isFirst,
    );
  }

  static void openCorporateHub(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const CorporateHubPage()),
      (route) => route.isFirst,
    );
  }

  static Future<void> openBrandPortfolio(BuildContext context) {
    return Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const BrandPortfolioPage()));
  }

  static Future<void> openTraceabilityHub(BuildContext context) {
    return Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const BrandDashboardPage()));
  }

  static Future<void> openBrandOperations(BuildContext context) {
    return openTraceabilityHub(context);
  }

  static Future<void> openSuspiciousVerificationScans(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const SuspiciousVerificationScansPage(),
      ),
    );
  }

  static Future<void> openTraceabilityCases(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const TraceabilityCasesPage()),
    );
  }

  static Future<void> openRiskOperationsConsole(BuildContext context) {
    final diagnostics = RiskOperationsDiagnosticIdProvider.instance;
    final navigationId = diagnostics.createNavigationId();
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: '/risk-operations'),
        builder: (_) => RiskOperationsConsolePage(
          navigationId: navigationId,
          diagnosticIdProvider: diagnostics,
        ),
      ),
    );
  }

  static void openProducts(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => ProductsPage()));
  }

  static void openProductionBatches(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => ProductionBatchesPage()));
  }

  static void openProductCodes(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => ProductCodesPage()));
  }
}

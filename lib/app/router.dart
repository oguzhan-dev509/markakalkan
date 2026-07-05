import 'package:flutter/material.dart';
import 'package:markakalkan/features/auth/presentation/brand_application_page.dart';
import 'package:markakalkan/features/auth/presentation/brand_login_page.dart';
import 'package:markakalkan/features/dashboard/presentation/brand_dashboard_page.dart';
import 'package:markakalkan/features/product_codes/presentation/product_codes_page.dart';
import 'package:markakalkan/features/production_batches/presentation/production_batches_page.dart';
import 'package:markakalkan/features/products/presentation/products_page.dart';
import 'package:markakalkan/features/verification/presentation/product_verification_page.dart';
import 'package:markakalkan/features/verification/presentation/qr_scanner_page.dart';
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

abstract final class AppRouter {
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

  static Future<void> openBrandLogin(BuildContext context) {
    return Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const BrandLoginPage()));
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

  static Future<void> openBrandAccountCreation(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const BrandAccountCreationPage()),
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

  static void openCorporateHub(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const CorporateHubPage()),
      (route) => route.isFirst,
    );
  }

  static Future<void> openBrandOperations(BuildContext context) {
    return Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const BrandDashboardPage()));
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

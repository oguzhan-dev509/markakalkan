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

abstract final class AppRouter {
  static Future<void> openBrandLogin(BuildContext context) {
    return Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const BrandLoginPage()));
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

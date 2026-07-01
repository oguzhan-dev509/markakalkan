import 'package:flutter/material.dart';
import 'package:markakalkan/features/auth/presentation/brand_application_page.dart';
import 'package:markakalkan/features/auth/presentation/brand_login_page.dart';
import 'package:markakalkan/features/verification/presentation/product_verification_page.dart';
import 'package:markakalkan/features/dashboard/presentation/brand_dashboard_page.dart';
import 'package:markakalkan/features/products/presentation/products_page.dart';

abstract final class AppRouter {
  static Future<void> openBrandLogin(BuildContext context) {
    return Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const BrandLoginPage()));
  }

  static void openProducts(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => ProductsPage()));
  }

  static void openBrandDashboard(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const BrandDashboardPage()),
      (route) => route.isFirst,
    );
  }

  static Future<void> openBrandApplication(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const BrandApplicationPage()),
    );
  }

  static Future<void> openProductVerification(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const ProductVerificationPage()),
    );
  }
}

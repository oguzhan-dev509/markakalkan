import 'package:flutter/material.dart';
import 'package:markakalkan/features/auth/presentation/brand_application_page.dart';
import 'package:markakalkan/features/auth/presentation/brand_login_page.dart';
import 'package:markakalkan/features/verification/presentation/product_verification_page.dart';

abstract final class AppRouter {
  static Future<void> openBrandLogin(BuildContext context) {
    return Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const BrandLoginPage()));
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

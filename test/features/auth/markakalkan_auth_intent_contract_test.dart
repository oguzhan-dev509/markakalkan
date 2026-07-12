import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MarkaKalkan common account gateway contract', () {
    final intentSource = File(
      'lib/features/auth/domain/markakalkan_auth_intent.dart',
    ).readAsStringSync();
    final routerSource = File('lib/app/router.dart').readAsStringSync();
    final loginSource = File(
      'lib/features/auth/presentation/brand_login_page.dart',
    ).readAsStringSync();
    final accountSource = File(
      'lib/features/auth/presentation/brand_account_creation_page.dart',
    ).readAsStringSync();

    test('one auth intent model covers public and corporate flows', () {
      expect(intentSource, contains('enum MarkaKalkanAuthIntent'));
      expect(intentSource, contains('corporateManagement'));
      expect(intentSource, contains('counterfeitTwinReport'));
      expect(intentSource, contains('creationRegistry'));
      expect(intentSource, contains('subscription'));
      expect(intentSource, contains('generalAccount'));
    });

    test('router passes intent through login and account creation', () {
      expect(routerSource, contains('Future<bool?> openBrandLogin'));
      expect(routerSource, contains('BrandLoginPage(intent: intent)'));
      expect(routerSource, contains('Future<bool?> openBrandAccountCreation'));
      expect(
        routerSource,
        contains('BrandAccountCreationPage(intent: intent)'),
      );
    });

    test('login opens corporate hub for corporate intent', () {
      expect(loginSource, contains('widget.intent.requiresCorporateFlow'));
      expect(loginSource, contains('AppRouter.openCorporateHub(context)'));
      expect(loginSource, contains('Navigator.of(context).pop(true)'));
      expect(loginSource, contains('MarkaKalkan Hesabı Oluştur'));
    });

    test(
      'account creation no longer forces every user into brand application',
      () {
        expect(accountSource, contains('widget.intent.requiresCorporateFlow'));
        expect(
          accountSource,
          contains('AppRouter.openBrandApplication(context)'),
        );
        expect(accountSource, contains('Navigator.of(context).pop(true)'));
        expect(
          accountSource,
          contains('Kurumsal panel erişimi ayrıca başvuru ve'),
        );
      },
    );
  });
}

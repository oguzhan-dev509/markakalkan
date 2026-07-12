import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('corporate access uses active brand root as authority', () {
    final functionSource = File(
      'functions/brand_portfolio/corporate_access.js',
    ).readAsStringSync();
    expect(functionSource, contains('db.collection(BRANDS).doc(uid).get()'));
    expect(functionSource, contains('brandStatus === "active"'));
    expect(functionSource, contains('where("applicantUid", "==", uid)'));
  });

  test('callable is exported', () {
    final indexSource = File('functions/index.js').readAsStringSync();
    expect(indexSource, contains('buildGetMyCorporateAccess'));
    expect(indexSource, contains('exports.getMyCorporateAccess'));
  });

  test('corporate login keeps the direct corporate hub experience', () {
    final loginSource = File(
      'lib/features/auth/presentation/brand_login_page.dart',
    ).readAsStringSync();
    expect(loginSource, contains('AppRouter.openCorporateHub(context)'));
    expect(
      loginSource,
      isNot(contains('AppRouter.openCorporateAccess(context)')),
    );
  });

  test('access page handles application states', () {
    final pageSource = File(
      'lib/features/auth/presentation/corporate_access_page.dart',
    ).readAsStringSync();
    expect(pageSource, contains("'pending'"));
    expect(pageSource, contains("'under_review'"));
    expect(pageSource, contains("'rejected'"));
    expect(pageSource, contains("'approved_pending_activation'"));
    expect(pageSource, contains('Yetki Başvurusu Yap'));
  });
}

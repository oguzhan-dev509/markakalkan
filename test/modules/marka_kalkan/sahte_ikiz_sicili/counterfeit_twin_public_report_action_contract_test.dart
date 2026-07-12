import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String radar;

  setUpAll(() {
    radar = File(
      'lib/modules/marka_kalkan/sahte_ikiz_sicili/presentation/'
      'counterfeit_twin_public_radar_page.dart',
    ).readAsStringSync();
  });

  test('all public report buttons share one handler', () {
    expect(RegExp(r'onPressed: _openReport').allMatches(radar).length, 2);
    expect(radar, contains('onReport: _openReport'));
  });

  test('canonical login route is used', () {
    expect(radar, contains('AppRouter.openBrandLogin('));
    expect(radar, contains('MarkaKalkanAuthIntent.counterfeitTwinReport'));
    expect(radar, isNot(contains('BrandLoginPage()')));
  });

  test('incomplete login gives explicit feedback', () {
    expect(
      radar,
      contains('Bildirim formunu açmak için giriş işlemini tamamlayın.'),
    );
  });

  test('duplicate taps are guarded', () {
    expect(radar, contains('bool _isOpeningReport = false;'));
    expect(radar, contains('if (_isOpeningReport) return;'));
    expect(radar, contains('_isOpeningReport = true;'));
    expect(radar, contains('_isOpeningReport = false;'));
  });

  test('runtime failures are shown to the user', () {
    expect(radar, contains('on FirebaseFunctionsException catch'));
    expect(radar, contains('Bildirim formu şu anda açılamıyor.'));
    expect(radar, contains('Lütfen yeniden deneyin.'));
  });
}

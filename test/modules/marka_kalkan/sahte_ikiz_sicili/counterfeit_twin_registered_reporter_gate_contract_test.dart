import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final dialog = File(
    'lib/modules/marka_kalkan/sahte_ikiz_sicili/presentation/'
    'counterfeit_twin_report_dialog.dart',
  ).readAsStringSync();
  final backend = File(
    'functions/counterfeit_twin/counterfeit_twin_radar.js',
  ).readAsStringSync();
  final publicRadar = File(
    'lib/modules/marka_kalkan/sahte_ikiz_sicili/presentation/'
    'counterfeit_twin_public_radar_page.dart',
  ).readAsStringSync();

  test('report dialog owns a registered-account defense in depth gate', () {
    expect(dialog, contains('FirebaseAuth.instance.currentUser'));
    expect(dialog, contains('!user.isAnonymous'));
    expect(dialog, contains('email.isNotEmpty'));
    expect(dialog, contains('Bildirim için giriş gerekli'));
    expect(dialog, contains('Sahte İkiz Radarı giriş '));
    expect(dialog, contains('yapmadan okunabilir.'));
  });

  test('submit callable rejects anonymous or email-less sessions', () {
    expect(backend, contains('sign_in_provider'));
    expect(backend, contains('signInProvider === "anonymous"'));
    expect(backend, contains('!actor.email'));
    expect(
      backend,
      contains('Bildirim icin kayitli MarkaKalkan hesabi gerekir.'),
    );
  });

  test(
    'public radar remains readable while report action owns auth intent',
    () {
      expect(
        publicRadar,
        contains('MarkaKalkanAuthIntent.counterfeitTwinReport'),
      );
      expect(publicRadar, contains('showCounterfeitTwinReportDialog'));
    },
  );
}

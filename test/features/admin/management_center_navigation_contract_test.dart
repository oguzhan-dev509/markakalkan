import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markakalkan/features/admin/presentation/management_center_page.dart';

void main() {
  group('Management center navigation contract', () {
    final routerSource = File('lib/app/router.dart').readAsStringSync();

    final hubSource = File(
      'lib/features/dashboard/presentation/corporate_hub_page.dart',
    ).readAsStringSync();

    final pageSource = File(
      'lib/features/admin/presentation/management_center_page.dart',
    ).readAsStringSync();

    test('router opens the management center page', () {
      expect(routerSource, contains('ManagementCenterPage'));
      expect(routerSource, contains('openManagementCenter'));
    });

    test('corporate hub opens protected management entry after five taps', () {
      expect(hubSource, contains("'management-entry-five-tap-action'"));
      expect(hubSource, contains("'Yetkili yönetim girişi'"));
      expect(hubSource, contains('_handleManagementEntryTap'));
      expect(hubSource, contains('_managementTapCount < 5'));
      expect(hubSource, contains('Duration(seconds: 8)'));
      expect(hubSource, contains('verifyEntryCode'));
      expect(hubSource, contains('access.isSuperAdmin'));
      expect(hubSource, isNot(contains("id: 'management_center'")));
    });

    test('page gates access and shows both first management modules', () {
      expect(pageSource, contains('getMyAccess()'));
      expect(pageSource, contains('!access.isSuperAdmin'));
      expect(pageSource, contains("'Bu alana erişim yetkiniz bulunmuyor.'"));
      expect(pageSource, contains("'Marka Başvuruları'"));
      expect(pageSource, contains("'Sahte İkiz Radarı'"));
    });

    testWidgets(
      'module card lays out in vertical scroll at desktop and narrow widths',
      (tester) async {
        for (final width in <double>[438.5, 320]) {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: SingleChildScrollView(
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: SizedBox(
                      width: width,
                      child: buildManagementModuleCardForTesting(
                        title: 'Sponsor / İş Ortakları',
                        description:
                            'Sponsorları, logoları, yayın durumunu, sıralamayı '
                            've tarih aralıklarını yönetin.',
                        icon: Icons.handshake_outlined,
                        actionLabel: 'Sponsor yönetimini aç',
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pump();

          expect(
            tester.takeException(),
            isNull,
            reason: 'Management module card must lay out at width=$width',
          );
          expect(find.text('Sponsor / İş Ortakları'), findsOneWidget);
          expect(find.text('Sponsor yönetimini aç'), findsOneWidget);
        }
      },
    );
  });
}

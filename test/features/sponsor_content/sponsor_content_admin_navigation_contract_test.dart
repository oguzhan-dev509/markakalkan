import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Management Center exposes protected sponsor content management route',
    () {
      final management = File(
        'lib/features/admin/presentation/management_center_page.dart',
      ).readAsStringSync();
      final router = File('lib/app/router.dart').readAsStringSync();

      expect(management, contains("'sponsor-content-admin-action'"));
      expect(management, contains("title: 'Sponsor / İş Ortakları'"));
      expect(
        management,
        contains('AppRouter.openSponsorContentAdmin(context)'),
      );

      expect(router, contains('sponsor_content_admin_page.dart'));
      expect(router, contains('openSponsorContentAdmin'));
      expect(router, contains('const SponsorContentAdminPage()'));
    },
  );
}

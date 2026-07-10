import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Platform admin access service contract', () {
    final modelSource = File(
      'lib/features/admin/models/platform_admin_access.dart',
    ).readAsStringSync();

    final serviceSource = File(
      'lib/features/admin/data/platform_admin_access_service.dart',
    ).readAsStringSync();

    test('uses europe-west3 and the admin access callable', () {
      expect(
        serviceSource,
        contains("FirebaseFunctions.instanceFor(region: 'europe-west3')"),
      );
      expect(serviceSource, contains("'getMyPlatformAdminAccess'"));
    });

    test('parses active roles and protects super admin access', () {
      expect(modelSource, contains('final bool active;'));
      expect(modelSource, contains('final List<String> roles;'));
      expect(modelSource, contains("roles.contains('super_admin')"));
      expect(modelSource, contains('PlatformAdminAccess.fromMap'));
    });
  });
}

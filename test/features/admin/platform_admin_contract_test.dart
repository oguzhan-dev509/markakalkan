import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Platform admin callable contract', () {
    final source = File(
      'functions/common/platform_admin.js',
    ).readAsStringSync();

    test('uses private platform admin collection and active role checks', () {
      expect(source, contains('"platform_admins"'));
      expect(source, contains('data.active === true'));
      expect(source, contains('super_admin'));
      expect(source, contains('requirePlatformRole'));
    });

    test('never trusts an admin role sent by the client', () {
      expect(source, contains('request.auth?.uid'));
      expect(source, isNot(contains('request.data?.roles')));
      expect(source, isNot(contains('request.data?.adminRole')));
    });
  });
}

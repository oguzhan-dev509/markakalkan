import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Counterfeit Twin Radar rules contract', () {
    final rulesFile = File('firestore.rules');
    final source = rulesFile.readAsStringSync();
    final bytes = rulesFile.readAsBytesSync().length;

    test('rules stay below the 200 KiB project budget', () {
      expect(bytes, lessThan(200 * 1024));
    });

    test('admin and report collections deny all direct client access', () {
      expect(source, contains('match /platform_admins/{adminUid} {'));
      expect(source, contains('match /counterfeit_twin_reports/{reportId} {'));
      expect(
        source,
        contains('allow read, create, update, delete: if false;'),
      );
    });

    test('public comparisons are read-only for clients', () {
      const marker =
          'match /counterfeit_twin_public_comparisons/{comparisonId} {';
      final start = source.indexOf(marker);
      expect(start, greaterThanOrEqualTo(0));
      final end = source.indexOf('\n    match /', start + marker.length);
      final block = source.substring(
        start,
        end == -1 ? source.length : end,
      );
      expect(block, contains('allow read: if true;'));
      expect(block, contains('allow create, update, delete: if false;'));
    });
  });
}

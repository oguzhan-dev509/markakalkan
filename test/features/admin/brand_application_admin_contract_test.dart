import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Brand application admin callable contract', () {
    final source = File(
      'functions/admin/brand_application_admin.js',
    ).readAsStringSync();
    final index = File('functions/index.js').readAsStringSync();

    test('exports access, list and review callables', () {
      expect(index, contains('exports.getMyPlatformAdminAccess'));
      expect(index, contains('exports.listBrandApplicationsForAdmin'));
      expect(index, contains('exports.reviewBrandApplication'));
    });

    test('approval is transactional and creates brand root record', () {
      expect(source, contains('db.runTransaction'));
      expect(source, contains('db.collection(BRANDS).doc(applicantUid)'));
      expect(source, contains('decision === "approved"'));
      expect(source, contains('approvedByUid'));
    });

    test('rejection requires a review note', () {
      expect(source, contains('decision === "rejected" && !reviewNote'));
    });
  });
}

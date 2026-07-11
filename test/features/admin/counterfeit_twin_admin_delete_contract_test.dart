import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final index = File('functions/index.js').readAsStringSync();
  final backend = File(
    'functions/counterfeit_twin/counterfeit_twin_radar.js',
  ).readAsStringSync();
  final service = File(
    'lib/features/admin/data/counterfeit_twin_admin_service.dart',
  ).readAsStringSync();
  final page = File(
    'lib/features/admin/presentation/'
    'counterfeit_twin_review_queue_page.dart',
  ).readAsStringSync();

  test('delete callable is exported and restricted to super admin', () {
    expect(index, contains('exports.deleteCounterfeitTwinReport'));
    expect(backend, contains('buildDeleteCounterfeitTwinReport'));
    expect(backend, contains('ROLES.superAdmin'));
    expect(backend, contains('transaction.delete(reportRef)'));
  });

  test('published reports cannot be deleted', () {
    expect(backend, contains('report.status === "published"'));
    expect(backend, contains('report.publicComparisonId'));
    expect(backend, contains('"failed-precondition"'));
  });

  test('deletion keeps a minimal internal audit record', () {
    expect(backend, contains('"counterfeit_twin_report_deletions"'));
    expect(backend, contains('deleteReason'));
    expect(backend, contains('deletedByUid'));
    expect(backend, contains('deletedAt'));
  });

  test('admin UI requires a deletion reason and confirmation', () {
    expect(service, contains("'deleteCounterfeitTwinReport'"));
    expect(page, contains("'Kaydı Sil'"));
    expect(page, contains("'Silme nedeni'"));
    expect(page, contains("'Kalıcı Olarak Sil'"));
    expect(page, contains('_deleteReport'));
  });

  test('admin client does not delete Firestore records directly', () {
    expect(service, isNot(contains('FirebaseFirestore')));
    expect(page, isNot(contains('FirebaseFirestore')));
  });
}

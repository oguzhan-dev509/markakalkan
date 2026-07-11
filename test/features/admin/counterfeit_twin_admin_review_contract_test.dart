import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final hub = File(
    'lib/features/dashboard/presentation/corporate_hub_page.dart',
  ).readAsStringSync();
  final management = File(
    'lib/features/admin/presentation/management_center_page.dart',
  ).readAsStringSync();
  final router = File('lib/app/router.dart').readAsStringSync();
  final service = File(
    'lib/features/admin/data/counterfeit_twin_admin_service.dart',
  ).readAsStringSync();
  final page = File(
    'lib/features/admin/presentation/counterfeit_twin_review_queue_page.dart',
  ).readAsStringSync();
  final backend = File(
    'functions/counterfeit_twin/counterfeit_twin_radar.js',
  ).readAsStringSync();

  test('management entry requires five taps and remains protected', () {
    expect(hub, contains("'management-entry-five-tap-action'"));
    expect(hub, contains("'Yetkili yönetim girişi'"));
    expect(hub, contains('_handleManagementEntryTap'));
    expect(hub, contains('_managementTapCount < 5'));
    expect(hub, contains('Duration(seconds: 8)'));
    expect(hub, contains('verifyEntryCode'));
    expect(hub, contains('access.isSuperAdmin'));
    expect(hub, isNot(contains('_handleHiddenMarkPointerDown')));
  });

  test('management center opens the review queue', () {
    expect(router, contains('openCounterfeitTwinReviewQueue'));
    expect(router, contains('CounterfeitTwinReviewQueuePage'));
    expect(
      management,
      contains('AppRouter.openCounterfeitTwinReviewQueue(context)'),
    );
    expect(management, contains("'counterfeit-twin-admin-review-action'"));
  });

  test('admin service uses callable-only report administration', () {
    expect(service, contains("'listCounterfeitTwinReportsForAdmin'"));
    expect(service, contains("'reviewCounterfeitTwinReport'"));
    expect(service, isNot(contains('FirebaseFirestore')));
  });

  test('review workflow supports review reject and publish', () {
    expect(page, contains("'under_review'"));
    expect(page, contains("'rejected'"));
    expect(page, contains("'published'"));
    expect(page, contains('İç inceleme notu / ret gerekçesi'));
    expect(page, contains('Kamuya açık doğrulama özeti'));
    expect(page, contains('Doğrula ve Yayımla'));
  });

  test('backend does not map the public summary from the internal note', () {
    expect(backend, contains('publicSummary'));
    expect(backend, isNot(contains('publicSummary: reviewNote')));
  });
}

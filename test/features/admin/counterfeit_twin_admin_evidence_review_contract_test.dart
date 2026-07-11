import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final backend = File(
    'functions/counterfeit_twin/counterfeit_twin_radar.js',
  ).readAsStringSync();
  final service = File(
    'lib/features/admin/data/counterfeit_twin_admin_service.dart',
  ).readAsStringSync();
  final model = File(
    'lib/features/admin/models/counterfeit_twin_admin_report.dart',
  ).readAsStringSync();
  final page = File(
    'lib/features/admin/presentation/'
    'counterfeit_twin_review_queue_page.dart',
  ).readAsStringSync();

  test('admin review carries explicit image publication selections', () {
    expect(service, contains('approvedOriginalImageUrls'));
    expect(service, contains('approvedSuspectedImageUrls'));
    expect(page, contains('Kamuya yayımla'));
    expect(page, contains('_approvedOriginalImageUrls'));
    expect(page, contains('_approvedSuspectedImageUrls'));
  });

  test('backend restricts approved images to report-owned URLs', () {
    expect(backend, contains('approvedImageSelection'));
    expect(backend, contains('Secilen gorsel bildirime ait degil.'));
    expect(backend, contains('originalImageUrls: approvedOriginalImageUrls'));
    expect(backend, contains('suspectedImageUrls: approvedSuspectedImageUrls'));
  });

  test('admin renders structured comparison and observed prices', () {
    expect(model, contains('decodedComparison'));
    expect(model, contains('double? number(String key)'));
    expect(page, contains('Gerçek–Sahte Karşılaştırma Tablosu'));
    expect(page, contains('Gerçek fiyat'));
    expect(page, contains('Sahte / şüpheli fiyat'));
    expect(page, contains('Fiyat tespit tarihi'));
  });

  test('legacy notes remain visible without encoded metadata', () {
    expect(page, contains('_list(report.decodedComparison.legacyNotes)'));
    expect(page, contains('Gerçek görsel kaynağı / atfı'));
    expect(page, contains('Şüpheli görsel kaynağı / atfı'));
  });
}

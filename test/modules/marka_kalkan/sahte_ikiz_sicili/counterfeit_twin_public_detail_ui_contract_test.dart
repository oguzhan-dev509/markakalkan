import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final appSource = File('lib/app/app.dart').readAsStringSync();
  final resolverSource = File(
    'lib/app/initial_route_resolver.dart',
  ).readAsStringSync();
  final routerSource = File('lib/app/router.dart').readAsStringSync();
  final radarSource = File(
    'lib/modules/marka_kalkan/sahte_ikiz_sicili/presentation/'
    'counterfeit_twin_public_radar_page.dart',
  ).readAsStringSync();
  final detailSource = File(
    'lib/modules/marka_kalkan/sahte_ikiz_sicili/presentation/'
    'counterfeit_twin_public_detail_page.dart',
  ).readAsStringSync();
  final contractSource = File(
    'lib/modules/marka_kalkan/sahte_ikiz_sicili/models/'
    'counterfeit_twin_public_contract.dart',
  ).readAsStringSync();
  final indexSource = File('web/index.html').readAsStringSync();

  test('three premium public categories are visible', () {
    expect(radarSource, contains('Fiziksel Sahte İkizler'));
    expect(radarSource, contains('Dijital Sahte İkizler'));
    expect(radarSource, contains('Yapay Zekâ ve Robot Sahte İkizleri'));
  });

  test('public slogan is preserved', () {
    expect(radarSource, contains('Gerçeği doğrula, sahte ikizi görünür kıl.'));
    expect(detailSource, contains('Gerçeği doğrula, sahte ikizi görünür kıl.'));
  });

  test('clean public slug path opens detail page', () {
    expect(resolverSource, contains("segments.first != 'sahte-ikiz'"));
    expect(appSource, contains('resolveInitialCounterfeitTwinSlug(Uri.base)'));
    expect(appSource, contains('CounterfeitTwinPublicDetailPage'));
    expect(routerSource, contains('openCounterfeitTwinPublicDetail'));
    expect(
      radarSource,
      contains('RouteSettings(name: comparison.canonicalPath)'),
    );
  });

  test('detail page retrieves a published record by slug', () {
    expect(detailSource, contains('CounterfeitTwinPublicDetailService'));
    expect(detailSource, contains('getBySlug(widget.slug)'));
  });

  test('real and suspected evidence are compared visually', () {
    expect(detailSource, contains('GERÇEK'));
    expect(detailSource, contains('SAHTE / ŞÜPHELİ İKİZ'));
    expect(detailSource, contains('originalImageUrls'));
    expect(detailSource, contains('suspectedImageUrls'));
  });

  test('social sharing channels are available', () {
    for (final channel in <String>[
      'WhatsApp',
      'Facebook',
      'LinkedIn',
      'Telegram',
      'Bağlantıyı kopyala',
    ]) {
      expect(detailSource, contains(channel));
    }
    expect(detailSource, contains('twitter.com/intent/tweet'));
  });

  test('public contract carries visual and source fields', () {
    for (final field in <String>[
      'originalImageUrls',
      'suspectedImageUrls',
      'originalUrls',
      'suspectedUrls',
      'publicRecordCode',
      'canonicalPath',
    ]) {
      expect(contractSource, contains(field));
    }
  });

  test('generic web metadata no longer uses Flutter defaults', () {
    expect(indexSource, contains('MarkaKalkan | Sahte İkiz Radarı'));
    expect(indexSource, contains('og:title'));
    expect(indexSource, isNot(contains('A new Flutter project.')));
  });
}

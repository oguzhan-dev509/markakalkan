import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final dialog = File(
    'lib/modules/marka_kalkan/sahte_ikiz_sicili/presentation/'
    'counterfeit_twin_report_dialog.dart',
  ).readAsStringSync();
  final editor = File(
    'lib/modules/marka_kalkan/sahte_ikiz_sicili/presentation/'
    'counterfeit_twin_evidence_editor.dart',
  ).readAsStringSync();
  final codec = File(
    'lib/modules/marka_kalkan/sahte_ikiz_sicili/presentation/'
    'counterfeit_twin_comparison_codec.dart',
  ).readAsStringSync();
  final storage = File('storage.rules').readAsStringSync();
  final backend = File(
    'functions/counterfeit_twin/counterfeit_twin_radar.js',
  ).readAsStringSync();

  test('form exposes structured genuine and suspected comparison rows', () {
    expect(editor, contains('Kontrol noktası'));
    expect(editor, contains('Gerçek ürün / varlık'));
    expect(editor, contains('Sahte / doğrulanmamış ürün'));
    expect(editor, contains('maxComparisonRows = 8'));
    expect(dialog, contains('CounterfeitTwinComparisonCodec.encode'));
  });

  test('separate image galleries use secure storage upload', () {
    expect(editor, contains('Gerçek ürün görselleri'));
    expect(editor, contains('Sahte / şüpheli ürün görselleri'));
    expect(editor, contains('FilePicker.pickFiles'));
    expect(editor, contains('FirebaseStorage.instance.ref'));
    expect(editor, contains('maxImagesPerSide = 4'));
    expect(editor, contains('maxImageBytes = 8 * 1024 * 1024'));
    expect(dialog, contains('originalImageUrls: evidence.originalImageUrls'));
    expect(dialog, contains('suspectedImageUrls: evidence.suspectedImageUrls'));
  });

  test('price evidence is carried through the existing report contract', () {
    expect(editor, contains('Gerçek fiyat'));
    expect(editor, contains('Sahte / şüpheli fiyat'));
    expect(editor, contains('Fiyat tespit tarihi'));
    expect(dialog, contains('authorizedPriceMin: evidence.originalPrice'));
    expect(dialog, contains('suspectedPrice: evidence.suspectedPrice'));
    expect(dialog, contains('currency: evidence.currency'));
    expect(backend, contains('authorizedPriceMin'));
    expect(backend, contains('suspectedPrice'));
  });

  test('comparison codec remains readable and within backend limits', () {
    expect(codec, contains('[KARSILASTIRMA]'));
    expect(codec, contains('[FIYAT_TARIHI]'));
    expect(codec, contains('values.length > 20'));
    expect(codec, contains('value.length > 500'));
  });

  test('storage rules isolate report media by authenticated owner', () {
    expect(
      storage,
      contains(
        'match /counterfeit_twin_report_media/'
        '{ownerUid}/{sessionId}/{side}/{fileName}',
      ),
    );
    expect(storage, contains('request.auth.uid == ownerUid'));
    expect(storage, contains('request.resource.size <= 8 * 1024 * 1024'));
    expect(
      storage,
      contains("request.resource.metadata.hashAlgorithm == 'SHA-256'"),
    );
    expect(storage, contains('allow update: if false;'));
  });
  test('image evidence is optional', () {
    expect(editor, contains('Görseller isteğe bağlıdır.'));
    expect(editor, contains('if (images.isEmpty) return const <String>[];'));
    expect(dialog, contains('originalImageUrls: evidence.originalImageUrls'));
    expect(dialog, contains('suspectedImageUrls: evidence.suspectedImageUrls'));
  });
}

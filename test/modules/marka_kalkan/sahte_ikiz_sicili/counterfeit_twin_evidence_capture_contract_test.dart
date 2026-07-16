import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final dialog = File(
    'lib/modules/marka_kalkan/sahte_ikiz_sicili/presentation/'
    'counterfeit_twin_report_dialog.dart',
  ).readAsStringSync();
  final simpleEditor = File(
    'lib/modules/marka_kalkan/sahte_ikiz_sicili/presentation/'
    'counterfeit_twin_simple_evidence_editor.dart',
  ).readAsStringSync();
  final legacyEditor = File(
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

  test('public form uses one simple evidence surface', () {
    expect(
      dialog,
      contains("import 'counterfeit_twin_simple_evidence_editor.dart';"),
    );
    expect(dialog, contains('CounterfeitTwinSimpleEvidenceEditor'));
    expect(dialog, isNot(contains('CounterfeitTwinEvidenceEditor(')));
    expect(dialog, isNot(contains('CounterfeitTwinComparisonCodec.encode')));
    expect(simpleEditor, contains('Kanıt görseli ekleyin'));
    expect(simpleEditor, contains('Kanıt görseli seç'));
    expect(simpleEditor, contains('maxImages = 6'));
  });

  test('simple evidence upload keeps secure storage controls', () {
    expect(simpleEditor, contains('FilePicker.pickFiles'));
    expect(simpleEditor, contains('FirebaseStorage.instance.ref'));
    expect(simpleEditor, contains('maxImageBytes = 8 * 1024 * 1024'));
    expect(simpleEditor, contains("'hashAlgorithm': 'SHA-256'"));
    expect(simpleEditor, contains(r"'$_sessionId/evidence/$fileName'"));
    expect(dialog, contains('suspectedImageUrls: evidence.imageUrls'));
  });

  test('client and callable both require verifiable evidence', () {
    expect(dialog, contains('_hasVerifiableEvidence'));
    expect(dialog, contains('En az bir doğrulanabilir kanıt görseli'));
    expect(backend, contains('const hasVerifiableEvidence'));
    expect(
      backend,
      contains('En az bir dogrulanabilir kanit gorseli veya kaynak '),
    );
  });

  test('public explanation has clear length limits', () {
    expect(dialog, contains("'4. Olay ve kanıt açıklaması'"));
    expect(dialog, contains('maxLength: 1500'));
    expect(dialog, contains("'Olay ve kanıt açıklaması'"));
    expect(dialog, contains('30,'));
    expect(backend, contains('evidenceNotes.length < 30'));
    expect(backend, contains('"evidenceNotes",\n      1500'));
  });

  test(
    'legacy comparison infrastructure remains available for old records',
    () {
      expect(
        legacyEditor,
        contains('Yapılandırılmış gerçek–sahte karşılaştırması'),
      );
      expect(legacyEditor, contains('Gerçek fiyat'));
      expect(codec, contains('[KARSILASTIRMA]'));
      expect(codec, contains('[FIYAT_TARIHI]'));
    },
  );

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
}

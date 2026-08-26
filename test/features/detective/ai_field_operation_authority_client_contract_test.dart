import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:markakalkan/features/detective/data/ai_field_operation_service.dart';

void main() {
  test('readiness response preserves three independent server gates', () {
    final readiness = AiFieldOperationReadiness.fromValue({
      'contractVersion': AiFieldOperationService.contractVersion,
      'brand': {'brandName': 'Onaylı Marka', 'companyName': 'Şirket'},
      'gates': {
        'verifiedBrand': true,
        'serviceAccess': true,
        'operationAuthority': false,
        'ready': false,
        'reasons': ['operation_create_authority_required'],
      },
    });
    expect(readiness.verifiedBrand, isTrue);
    expect(readiness.serviceAccess, isTrue);
    expect(readiness.operationAuthority, isFalse);
    expect(readiness.ready, isFalse);
    expect(readiness.brandName, 'Onaylı Marka');
  });

  test('client uses only App Check protected callable creation', () {
    final source = File(
      'lib/features/detective/data/ai_field_operation_service.dart',
    ).readAsStringSync();
    expect(source, contains('getAiFieldOperationReadiness'));
    expect(source, contains('createAiFieldOperation'));
    expect(source, contains('AppCheckBootstrap.instance.ensureReady'));
    expect(source, isNot(contains('_firestore.batch()')));
    expect(source, isNot(contains('batch.commit()')));
  });

  test('operation form is fail closed and requires confirmation', () {
    final source = File(
      'lib/features/detective/presentation/ai_field_operation_create_page.dart',
    ).readAsStringSync();
    expect(source, contains('Doğrulanmış marka'));
    expect(source, contains('Hizmet erişimi'));
    expect(source, contains('Operasyon yetkisi'));
    expect(source, contains('En az bir somut hedef'));
    expect(source, contains('Operasyonu Onayla'));
    expect(source, contains('_readiness?.ready != true'));
  });
}

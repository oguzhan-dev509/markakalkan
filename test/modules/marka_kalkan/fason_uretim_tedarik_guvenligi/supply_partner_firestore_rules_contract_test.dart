import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String rules;

  setUpAll(() {
    rules = File('firestore.rules').readAsStringSync();
  });

  group('Supply partner Firestore rules contract', () {
    test('partner koleksiyon bloğu tenant izolasyonu uygular', () {
      expect(rules, contains('match /supply_security_partners/{partnerId}'));
      expect(
        rules,
        contains('request.resource.data.tenantId == request.auth.uid'),
      );
      expect(rules, contains('resource.data.tenantId == request.auth.uid'));
    });

    test('partner kimliği ve ilk oluşturma alanları değiştirilemez', () {
      expect(
        rules,
        contains(
          'request.resource.data.partnerCode == resource.data.partnerCode',
        ),
      );
      expect(
        rules,
        contains(
          'request.resource.data.partnerCodeNormalized\n'
          '              == resource.data.partnerCodeNormalized',
        ),
      );
      expect(
        rules,
        contains('request.resource.data.createdAt == resource.data.createdAt'),
      );
      expect(
        rules,
        contains('request.resource.data.createdBy == resource.data.createdBy'),
      );
    });

    test('rol, risk ve güven skoru sözleşmesini sınırlar', () {
      expect(rules, contains("'contract_manufacturer'"));
      expect(rules, contains("'raw_material_supplier'"));
      expect(rules, contains("'quality_laboratory'"));
      expect(rules, contains('request.resource.data.trustScore >= 0'));
      expect(rules, contains('request.resource.data.trustScore <= 100'));
      expect(rules, contains("request.resource.data.riskLevel != 'critical'"));
      expect(rules, contains('request.resource.data.auditRequired == true'));
    });

    test('fason ve alt yüklenici yetkilerini rol koşuluna bağlar', () {
      expect(
        rules,
        contains(
          'request.resource.data.contractManufacturingAuthorized == false',
        ),
      );
      expect(
        rules,
        contains('request.resource.data.subcontractingAllowed == false'),
      );
      expect(
        rules,
        contains(
          "request.resource.data.roles.hasAny([\n"
          "              'manufacturer',\n"
          "              'contract_manufacturer'",
        ),
      );
      expect(rules, contains("'subcontractor'"));
    });

    test('hassas metadata ve güvenli silme koşulları tanımlıdır', () {
      expect(rules, contains("'formulaContent'"));
      expect(rules, contains("'privateKey'"));
      expect(rules, contains("resource.data.status == 'archived'"));
      expect(rules, contains('resource.data.relatedFacilityIds.size() == 0'));
      expect(rules, contains('resource.data.relatedProductIds.size() == 0'));
      expect(
        rules,
        contains('resource.data.certificateDocumentIds.size() == 0'),
      );
    });
  });
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String rules;

  setUpAll(() {
    rules = File('firestore.rules').readAsStringSync();
  });

  group('Supply facility Firestore rules contract', () {
    test('tesis koleksiyonu tenant izolasyonu uygular', () {
      expect(rules, contains('match /supply_security_facilities/{facilityId}'));
      expect(
        rules,
        contains('request.resource.data.tenantId == request.auth.uid'),
      );
      expect(rules, contains('resource.data.tenantId == request.auth.uid'));
    });

    test('tesis kimlik alanları güncellemede değiştirilemez', () {
      expect(
        rules,
        contains('request.resource.data.partnerId == resource.data.partnerId'),
      );
      expect(
        rules,
        contains(
          'request.resource.data.facilityCode\n'
          '              == resource.data.facilityCode',
        ),
      );
      expect(
        rules,
        contains(
          'request.resource.data.facilityCodeNormalized\n'
          '              == resource.data.facilityCodeNormalized',
        ),
      );
    });

    test('kritik risk ve yetki sözleşmesini zorunlu kılar', () {
      expect(rules, contains("request.resource.data.riskLevel != 'critical'"));
      expect(rules, contains('request.resource.data.auditRequired == true'));
      expect(
        rules,
        contains("request.resource.data.authorizationStatus != 'authorized'"),
      );
      expect(
        rules,
        contains(
          "request.resource.data.facilityType\n"
          "                != 'suspected_unauthorized_site'",
        ),
      );
    });

    test('kapasite ve koordinat sınırları tanımlıdır', () {
      expect(rules, contains('request.resource.data.latitude >= -90'));
      expect(rules, contains('request.resource.data.longitude <= 180'));
      expect(rules, contains('request.resource.data.monthlyCapacity >= 0'));
      expect(rules, contains('request.resource.data.capacityUnit.size() > 0'));
    });

    test('arşiv ve güvenli silme koruması tanımlıdır', () {
      expect(rules, contains("resource.data.status == 'archived'"));
      expect(rules, contains('resource.data.relatedProductIds.size() == 0'));
      expect(
        rules,
        contains('resource.data.certificateDocumentIds.size() == 0'),
      );
      expect(rules, contains('resource.data.auditDocumentIds.size() == 0'));
    });
  });
}

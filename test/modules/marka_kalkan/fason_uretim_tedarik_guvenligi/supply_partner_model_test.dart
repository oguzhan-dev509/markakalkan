import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markakalkan/modules/marka_kalkan/fason_uretim_tedarik_guvenligi/constants/supply_security_enums.dart';
import 'package:markakalkan/modules/marka_kalkan/fason_uretim_tedarik_guvenligi/models/supply_partner_model.dart';

void main() {
  group('SupplyPartnerModel', () {
    test('partner kodunu normalize eder ve rolleri serileştirir', () {
      final model = _model(
        partnerCode: ' fsn-001 ',
        roles: const <SupplyPartnerRole>[
          SupplyPartnerRole.contractManufacturer,
          SupplyPartnerRole.packagingSupplier,
        ],
      );

      final map = model.toMap();

      expect(model.normalizedPartnerCode, 'FSN-001');
      expect(map['partnerCode'], 'fsn-001');
      expect(map['partnerCodeNormalized'], 'FSN-001');
      expect(
        map['roles'],
        containsAll(<String>['contract_manufacturer', 'packaging_supplier']),
      );
    });

    test('üretim rolü ve yüksek risk yardımcılarını doğru hesaplar', () {
      final model = _model(
        roles: const <SupplyPartnerRole>[
          SupplyPartnerRole.contractManufacturer,
        ],
        riskLevel: SupplyPartnerRiskLevel.critical,
        trustScore: 30,
      );

      expect(model.hasManufacturingRole, isTrue);
      expect(model.hasOperationalRole, isTrue);
      expect(model.isHighRisk, isTrue);
    });

    test('Firestore haritasından tarih ve enumları geri yükler', () {
      final model = SupplyPartnerModel.fromMap(
        id: 'partner-1',
        data: <String, dynamic>{
          'tenantId': 'tenant-1',
          'brandId': 'brand-1',
          'partnerCode': 'FSN-002',
          'legalName': 'Örnek Fason Üretim A.Ş.',
          'roles': <String>['contract_manufacturer'],
          'status': 'active',
          'verificationStatus': 'verified',
          'riskLevel': 'medium',
          'trustScore': 82,
          'createdAt': Timestamp.fromDate(DateTime.utc(2026, 7, 7)),
          'createdBy': 'user-1',
        },
      );

      expect(model.status, SupplyPartnerStatus.active);
      expect(
        model.verificationStatus,
        SupplyPartnerVerificationStatus.verified,
      );
      expect(model.riskLevel, SupplyPartnerRiskLevel.medium);
      expect(model.trustScore, 82);
      expect(model.createdAt.toUtc(), DateTime.utc(2026, 7, 7));
    });

    test('güven skorunu Firestore okumasında 0-100 aralığına sınırlar', () {
      final high = SupplyPartnerModel.fromMap(
        id: 'high',
        data: _map(trustScore: 140),
      );
      final low = SupplyPartnerModel.fromMap(
        id: 'low',
        data: _map(trustScore: -20),
      );

      expect(high.trustScore, 100);
      expect(low.trustScore, 0);
    });

    test('güncelleme haritasında değişmez kimlik alanlarını çıkarır', () {
      final map = _model().toUpdateMap(actorId: 'editor-1');

      expect(map.containsKey('tenantId'), isFalse);
      expect(map.containsKey('brandId'), isFalse);
      expect(map.containsKey('partnerCode'), isFalse);
      expect(map.containsKey('partnerCodeNormalized'), isFalse);
      expect(map.containsKey('createdAt'), isFalse);
      expect(map.containsKey('createdBy'), isFalse);
      expect(map['updatedBy'], 'editor-1');
      expect(map['updatedAt'], isA<FieldValue>());
    });
  });
}

SupplyPartnerModel _model({
  String partnerCode = 'FSN-001',
  List<SupplyPartnerRole> roles = const <SupplyPartnerRole>[
    SupplyPartnerRole.rawMaterialSupplier,
  ],
  SupplyPartnerRiskLevel riskLevel = SupplyPartnerRiskLevel.medium,
  int trustScore = 70,
}) {
  return SupplyPartnerModel(
    id: 'partner-1',
    tenantId: 'tenant-1',
    brandId: 'brand-1',
    partnerCode: partnerCode,
    legalName: 'Örnek Tedarik A.Ş.',
    roles: roles,
    status: SupplyPartnerStatus.active,
    verificationStatus: SupplyPartnerVerificationStatus.verified,
    riskLevel: riskLevel,
    trustScore: trustScore,
    createdAt: DateTime.utc(2026, 7, 7),
    createdBy: 'user-1',
  );
}

Map<String, dynamic> _map({required int trustScore}) {
  return <String, dynamic>{
    'tenantId': 'tenant-1',
    'brandId': 'brand-1',
    'partnerCode': 'FSN-003',
    'legalName': 'Örnek Partner',
    'roles': <String>['raw_material_supplier'],
    'status': 'active',
    'verificationStatus': 'verified',
    'riskLevel': 'medium',
    'trustScore': trustScore,
    'createdAt': Timestamp.fromDate(DateTime.utc(2026, 7, 7)),
    'createdBy': 'user-1',
  };
}

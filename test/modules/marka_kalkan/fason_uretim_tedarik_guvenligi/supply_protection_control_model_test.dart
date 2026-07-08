import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markakalkan/modules/marka_kalkan/fason_uretim_tedarik_guvenligi/constants/supply_protection_control_enums.dart';
import 'package:markakalkan/modules/marka_kalkan/fason_uretim_tedarik_guvenligi/models/supply_protection_control_model.dart';

void main() {
  group('SupplyProtectionControlModel', () {
    final createdAt = DateTime.utc(2026, 7, 7, 12);

    SupplyProtectionControlModel buildModel({
      SupplyProtectionControlScope scope =
          SupplyProtectionControlScope.partnerAndFacility,
      SupplyProtectionControlStatus status =
          SupplyProtectionControlStatus.planned,
      SupplyProtectionControlResult result =
          SupplyProtectionControlResult.notEvaluated,
      SupplyProtectionControlRiskLevel riskLevel =
          SupplyProtectionControlRiskLevel.medium,
      String? partnerId = 'partner-1',
      String? facilityId = 'facility-1',
      DateTime? completedAt,
      String? correctiveAction,
      DateTime? correctiveActionCompletedAt,
      String? archiveReason,
      DateTime? archivedAt,
    }) {
      return SupplyProtectionControlModel(
        id: 'control-1',
        tenantId: 'tenant-1',
        brandId: 'brand-1',
        controlCode: ' ctrl-001 ',
        title: 'Üretim Güvenliği Kontrolü',
        controlType: SupplyProtectionControlType.productionSecurity,
        scope: scope,
        status: status,
        result: result,
        riskLevel: riskLevel,
        partnerId: partnerId,
        facilityId: facilityId,
        plannedAt: DateTime.utc(2026, 7, 10),
        completedAt: completedAt,
        correctiveAction: correctiveAction,
        correctiveActionCompletedAt: correctiveActionCompletedAt,
        archiveReason: archiveReason,
        archivedAt: archivedAt,
        evidenceDocumentIds: const <String>[
          ' evidence-1 ',
          'evidence-1',
          'evidence-2',
        ],
        createdAt: createdAt,
        createdBy: 'user-1',
      );
    }

    test('normalizes code and cleans repeated evidence ids', () {
      final model = buildModel();
      final map = model.toMap();

      expect(model.normalizedControlCode, 'CTRL-001');
      expect(map['controlCodeNormalized'], 'CTRL-001');
      expect(map['evidenceDocumentIds'], <String>['evidence-1', 'evidence-2']);
    });

    test('validates target ids according to scope', () {
      expect(buildModel().hasValidScopeTarget, isTrue);

      expect(
        buildModel(
          scope: SupplyProtectionControlScope.partner,
          facilityId: null,
        ).hasValidScopeTarget,
        isTrue,
      );

      expect(
        buildModel(
          scope: SupplyProtectionControlScope.facility,
          partnerId: null,
        ).hasValidScopeTarget,
        isTrue,
      );

      expect(
        buildModel(
          scope: SupplyProtectionControlScope.partner,
        ).hasValidScopeTarget,
        isFalse,
      );
    });

    test('detects critical failure and open corrective action', () {
      final model = buildModel(
        result: SupplyProtectionControlResult.criticalFailure,
        riskLevel: SupplyProtectionControlRiskLevel.critical,
        correctiveAction: 'Yetkisiz üretim hattını durdur.',
      );

      expect(model.hasFailure, isTrue);
      expect(model.isHighRisk, isTrue);
      expect(model.correctiveActionRequired, isTrue);
      expect(model.hasOpenCorrectiveAction, isTrue);
    });

    test('serializes Firestore timestamps from map', () {
      final model = SupplyProtectionControlModel.fromMap(
        id: 'control-2',
        data: <String, dynamic>{
          'tenantId': 'tenant-1',
          'brandId': 'brand-1',
          'controlCode': 'CTRL-002',
          'title': 'Tesis Denetimi',
          'controlType': 'facility_inspection',
          'scope': 'facility',
          'status': 'completed',
          'result': 'passed',
          'riskLevel': 'low',
          'facilityId': 'facility-2',
          'completedAt': Timestamp.fromDate(DateTime.utc(2026, 7, 6)),
          'createdAt': Timestamp.fromDate(createdAt),
          'createdBy': 'user-1',
        },
      );

      expect(model.controlType, SupplyProtectionControlType.facilityInspection);

      expect(model.completedAt?.toUtc(), DateTime.utc(2026, 7, 6));

      expect(model.hasValidScopeTarget, isTrue);
      expect(model.isCompleted, isTrue);
    });

    test('update map protects immutable identity fields', () {
      final map = buildModel().toUpdateMap(actorId: 'user-2');

      expect(map.containsKey('tenantId'), isFalse);
      expect(map.containsKey('brandId'), isFalse);
      expect(map.containsKey('controlCode'), isFalse);
      expect(map.containsKey('controlCodeNormalized'), isFalse);
      expect(map.containsKey('createdAt'), isFalse);
      expect(map.containsKey('createdBy'), isFalse);
      expect(map['updatedBy'], 'user-2');
      expect(map['updatedAt'], isA<FieldValue>());
    });
  });
}

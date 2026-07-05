import 'package:flutter_test/flutter_test.dart';
import 'package:markakalkan/modules/marka_kalkan/fikri_mulkiyet_belgeler/constants/ip_trade_secret_detail_enums.dart';
import 'package:markakalkan/modules/marka_kalkan/fikri_mulkiyet_belgeler/models/ip_trade_secret_disclosure_model.dart';

void main() {
  group('IpTradeSecretDisclosureModel', () {
    IpTradeSecretDisclosureModel buildModel({
      IpTradeSecretDisclosureStatus status =
          IpTradeSecretDisclosureStatus.completed,
      IpTradeSecretDisclosureRecipientType recipientType =
          IpTradeSecretDisclosureRecipientType.supplier,
      IpTradeSecretDisclosureChannel channel =
          IpTradeSecretDisclosureChannel.securePortal,
      bool requiresApproval = true,
      bool approvalCompleted = true,
      bool returnOrDestructionRequired = false,
      bool returnOrDestructionCompleted = false,
      DateTime? returnOrDestructionDueAt,
      DateTime? returnOrDestructionCompletedAt,
      bool crossBorderTransfer = false,
      String? recipientCountryCode,
      bool exportControlReviewRequired = false,
      bool exportControlReviewCompleted = false,
      int disclosureRiskScore = 40,
      List<String> approvalDocumentIds = const <String>['approval-1'],
      Map<String, dynamic> metadata = const <String, dynamic>{},
      DateTime? cancelledAt,
      String? cancelledBy,
    }) {
      return IpTradeSecretDisclosureModel(
        id: 'disclosure-1',
        tenantId: 'tenant-1',
        brandId: 'brand-1',
        tradeSecretId: 'secret-1',
        componentIds: const <String>['component-1'],
        accessGrantId: 'grant-1',
        disclosureCode: 'DISC-001',
        recipientType: recipientType,
        recipientId: 'recipient-1',
        recipientName: 'Örnek Tedarikçi',
        recipientCountryCode: recipientCountryCode,
        status: status,
        channel: channel,
        purpose: IpTradeSecretDisclosurePurpose.manufacturing,
        ndaDocumentIds: const <String>['nda-1'],
        approvalDocumentIds: approvalDocumentIds,
        disclosedAt: DateTime.utc(2026, 7, 5),
        disclosedBy: 'user-1',
        requiresApproval: requiresApproval,
        approvalCompleted: approvalCompleted,
        returnOrDestructionRequired: returnOrDestructionRequired,
        returnOrDestructionCompleted: returnOrDestructionCompleted,
        returnOrDestructionDueAt: returnOrDestructionDueAt,
        returnOrDestructionCompletedAt: returnOrDestructionCompletedAt,
        encryptedTransferUsed: true,
        recipientIdentityVerified: true,
        recipientAcknowledgementReceived: true,
        crossBorderTransfer: crossBorderTransfer,
        exportControlReviewRequired: exportControlReviewRequired,
        exportControlReviewCompleted: exportControlReviewCompleted,
        disclosureRiskScore: disclosureRiskScore,
        legalProtectionScore: 85,
        metadata: metadata,
        cancelledAt: cancelledAt,
        cancelledBy: cancelledBy,
        createdAt: DateTime.utc(2026, 7, 5),
        createdBy: 'admin-1',
      );
    }

    test('temel açıklama kimliğini ve hukuki dayanağı üretir', () {
      final model = buildModel();

      expect(model.hasCompleteIdentity, isTrue);
      expect(model.hasLegalFoundation, isTrue);
      expect(model.storesPlaintextSecretContent, isFalse);
    });

    test('enum değerlerini doğru serileştirir', () {
      final model = buildModel();

      final map = model.toMap();

      expect(map['recipientType'], 'supplier');
      expect(map['status'], 'completed');
      expect(map['channel'], 'secure_portal');
      expect(map['purpose'], 'manufacturing');
    });

    test('harici açıklamayı tespit eder', () {
      final model = buildModel();

      expect(model.isExternalDisclosure, isTrue);
      expect(model.requiresEnhancedProtection, isTrue);
    });

    test('çalışan alıcısını kurum içi kabul eder', () {
      final model = buildModel(
        recipientType: IpTradeSecretDisclosureRecipientType.employee,
      );

      expect(model.isExternalDisclosure, isFalse);
    });

    test('onay tamamlanmadan tamamlanmış açıklamayı reddeder', () {
      final model = buildModel(
        requiresApproval: true,
        approvalCompleted: false,
      );

      expect(model.toMap, throwsA(isA<StateError>()));
    });

    test('iade veya imha zorunluysa son tarih ister', () {
      final model = buildModel(returnOrDestructionRequired: true);

      expect(model.toMap, throwsA(isA<StateError>()));
    });

    test('tamamlanan imha için tamamlanma tarihi ister', () {
      final model = buildModel(
        returnOrDestructionRequired: true,
        returnOrDestructionCompleted: true,
        returnOrDestructionDueAt: DateTime.utc(2026, 8, 1),
      );

      expect(model.toMap, throwsA(isA<StateError>()));
    });

    test('geçerli iade veya imha kaydı serileşir', () {
      final model = buildModel(
        returnOrDestructionRequired: true,
        returnOrDestructionCompleted: true,
        returnOrDestructionDueAt: DateTime.utc(2026, 8, 1),
        returnOrDestructionCompletedAt: DateTime.utc(2026, 7, 20),
      );

      expect(model.toMap()['returnOrDestructionCompleted'], isTrue);
    });

    test('sınır ötesi aktarımda ülke kodunu zorunlu tutar', () {
      final model = buildModel(crossBorderTransfer: true);

      expect(model.toMap, throwsA(isA<StateError>()));
    });

    test('ihracat kontrolü tamamlanmadan açıklamayı kapatmaz', () {
      final model = buildModel(
        crossBorderTransfer: true,
        recipientCountryCode: 'DE',
        exportControlReviewRequired: true,
        exportControlReviewCompleted: false,
      );

      expect(model.toMap, throwsA(isA<StateError>()));
    });

    test('kamuya açık yayında onay belgesini zorunlu tutar', () {
      final model = buildModel(
        channel: IpTradeSecretDisclosureChannel.publicPublication,
        approvalDocumentIds: const <String>[],
      );

      expect(model.toMap, throwsA(isA<StateError>()));
    });

    test('metadata içinde ticari sır içeriğini reddeder', () {
      final model = buildModel(
        metadata: const <String, dynamic>{'formulaContent': 'gizli-formül'},
      );

      expect(model.toMap, throwsA(isA<StateError>()));
    });

    test('iptal edilen kayıtta iptal bilgilerini zorunlu tutar', () {
      final model = buildModel(status: IpTradeSecretDisclosureStatus.cancelled);

      expect(model.toMap, throwsA(isA<StateError>()));
    });

    test('geçerli iptal kaydını serileştirir', () {
      final model = buildModel(
        status: IpTradeSecretDisclosureStatus.cancelled,
        cancelledAt: DateTime.utc(2026, 7, 6),
        cancelledBy: 'admin-1',
      );

      expect(model.toMap()['status'], 'cancelled');
      expect(model.isCancelled, isTrue);
    });

    test('0–100 dışındaki risk skorunu reddeder', () {
      final model = buildModel(disclosureRiskScore: 101);

      expect(model.toMap, throwsA(isA<RangeError>()));
    });
  });
}

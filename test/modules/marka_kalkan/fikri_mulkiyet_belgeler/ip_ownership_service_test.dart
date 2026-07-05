import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:markakalkan/modules/marka_kalkan/fikri_mulkiyet_belgeler/constants/ip_enums.dart';
import 'package:markakalkan/modules/marka_kalkan/fikri_mulkiyet_belgeler/models/ip_asset_model.dart';
import 'package:markakalkan/modules/marka_kalkan/fikri_mulkiyet_belgeler/models/ip_ownership_record_model.dart';
import 'package:markakalkan/modules/marka_kalkan/fikri_mulkiyet_belgeler/repositories/ip_ownership_repository_port.dart';
import 'package:markakalkan/modules/marka_kalkan/fikri_mulkiyet_belgeler/repositories/ip_repository_ports.dart';
import 'package:markakalkan/modules/marka_kalkan/fikri_mulkiyet_belgeler/services/ip_ownership_service.dart';

void main() {
  const tenantId = 'tenant-1';
  const brandId = 'brand-1';
  const assetId = 'asset-1';

  final now = DateTime.utc(2026, 7, 5, 9);

  late _FakeOwnershipRepository ownershipRepository;
  late _FakeAssetRepository assetRepository;
  late IpOwnershipService service;

  setUp(() {
    ownershipRepository = _FakeOwnershipRepository();

    assetRepository = _FakeAssetRepository(
      assets: <IpAssetModel>[
        _asset(
          id: assetId,
          tenantId: tenantId,
          brandId: brandId,
          createdAt: now,
        ),
      ],
    );

    service = IpOwnershipService(
      tenantId: tenantId,
      ownershipRepository: ownershipRepository,
      assetRepository: assetRepository,
      clock: () => now,
    );
  });

  tearDown(() async {
    await ownershipRepository.dispose();
  });

  group('IpOwnershipService oluşturma güvenliği', () {
    test('geçerli kaydı normalize ederek repositoryye aktarır', () async {
      final record = _ownership(
        tenantId: tenantId,
        brandId: brandId,
        assetId: assetId,
        recordCode: ' OWN-001 ',
        partyName: ' Marka Sahibi A.Ş. ',
        partyId: ' party-1 ',
        partyCountryCode: ' tr ',
        partyContactEmail: ' LEGAL@EXAMPLE.COM ',
        countryCodes: const <String>['tr', ' DE ', 'tr'],
        documentIds: const <String>[' doc-1 ', 'doc-1', ''],
        status: IpOwnershipStatus.active,
        ownershipPercentage: 60,
        isPrimaryOwner: true,
        createdAt: now,
      );

      final createdId = await service.createRecord(record);

      expect(createdId, 'ownership-1');
      expect(ownershipRepository.createdRecords, hasLength(1));

      final created = ownershipRepository.createdRecords.single;

      expect(created.recordCode, 'OWN-001');
      expect(created.partyName, 'Marka Sahibi A.Ş.');
      expect(created.partyId, 'party-1');
      expect(created.partyCountryCode, 'TR');
      expect(created.partyContactEmail, 'legal@example.com');
      expect(created.countryCodes, <String>['TR', 'DE']);
      expect(created.documentIds, <String>['doc-1']);
      expect(created.ownershipPercentage, 60);
      expect(created.isPrimaryOwner, isTrue);
    });

    test('mevcut olmayan fikri varlık için kayıt oluşturmaz', () async {
      final record = _ownership(
        tenantId: tenantId,
        brandId: brandId,
        assetId: 'missing-asset',
        recordCode: 'OWN-MISSING',
        status: IpOwnershipStatus.active,
        createdAt: now,
      );

      await expectLater(
        service.createRecord(record),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('fikri varlık bulunamadı'),
          ),
        ),
      );

      expect(ownershipRepository.createdRecords, isEmpty);
    });

    test('farklı tenant adına kayıt oluşturulmasını reddeder', () async {
      final record = _ownership(
        tenantId: 'tenant-2',
        brandId: brandId,
        assetId: assetId,
        recordCode: 'OWN-FOREIGN',
        status: IpOwnershipStatus.active,
        createdAt: now,
      );

      await expectLater(
        service.createRecord(record),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('farklı tenant'),
          ),
        ),
      );

      expect(assetRepository.getByIdCalls, 0);
    });

    test('varlık ile marka kimliği uyuşmayan kaydı reddeder', () async {
      final record = _ownership(
        tenantId: tenantId,
        brandId: 'brand-2',
        assetId: assetId,
        recordCode: 'OWN-WRONG-BRAND',
        status: IpOwnershipStatus.active,
        createdAt: now,
      );

      await expectLater(
        service.createRecord(record),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('marka kimliğiyle eşleşmiyor'),
          ),
        ),
      );
    });

    test('çakışan sahiplik toplamı yüzde 100 değerini aşamaz', () async {
      ownershipRepository.records = <IpOwnershipRecordModel>[
        _ownership(
          id: 'ownership-existing',
          tenantId: tenantId,
          brandId: brandId,
          assetId: assetId,
          recordCode: 'OWN-EXISTING',
          ownershipKind: IpOwnershipKind.jointOwner,
          status: IpOwnershipStatus.active,
          ownershipPercentage: 70,
          effectiveFrom: DateTime.utc(2026, 1, 1),
          createdAt: now,
        ),
      ];

      final candidate = _ownership(
        tenantId: tenantId,
        brandId: brandId,
        assetId: assetId,
        recordCode: 'OWN-CANDIDATE',
        ownershipKind: IpOwnershipKind.jointOwner,
        status: IpOwnershipStatus.active,
        ownershipPercentage: 40,
        effectiveFrom: DateTime.utc(2026, 2, 1),
        createdAt: now,
      );

      await expectLater(
        service.createRecord(candidate),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('100 değerini aşamaz'),
          ),
        ),
      );
    });

    test('çakışan ikinci aktif birincil hak sahibini reddeder', () async {
      ownershipRepository.records = <IpOwnershipRecordModel>[
        _ownership(
          id: 'primary-existing',
          tenantId: tenantId,
          brandId: brandId,
          assetId: assetId,
          recordCode: 'PRIMARY-1',
          status: IpOwnershipStatus.active,
          ownershipPercentage: 60,
          isPrimaryOwner: true,
          effectiveFrom: DateTime.utc(2026, 1, 1),
          effectiveUntil: DateTime.utc(2026, 12, 31),
          createdAt: now,
        ),
      ];

      final candidate = _ownership(
        tenantId: tenantId,
        brandId: brandId,
        assetId: assetId,
        recordCode: 'PRIMARY-2',
        status: IpOwnershipStatus.active,
        ownershipPercentage: 40,
        isPrimaryOwner: true,
        effectiveFrom: DateTime.utc(2026, 6, 1),
        createdAt: now,
      );

      await expectLater(
        service.createRecord(candidate),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('birden fazla aktif birincil'),
          ),
        ),
      );
    });

    test(
      'çakışmayan dönemlerde farklı birincil hak sahiplerine izin verir',
      () async {
        ownershipRepository.records = <IpOwnershipRecordModel>[
          _ownership(
            id: 'primary-old',
            tenantId: tenantId,
            brandId: brandId,
            assetId: assetId,
            recordCode: 'PRIMARY-OLD',
            status: IpOwnershipStatus.active,
            ownershipPercentage: 100,
            isPrimaryOwner: true,
            effectiveFrom: DateTime.utc(2025, 1, 1),
            effectiveUntil: DateTime.utc(2025, 12, 31),
            createdAt: now,
          ),
        ];

        final candidate = _ownership(
          tenantId: tenantId,
          brandId: brandId,
          assetId: assetId,
          recordCode: 'PRIMARY-NEW',
          status: IpOwnershipStatus.active,
          ownershipPercentage: 100,
          isPrimaryOwner: true,
          effectiveFrom: DateTime.utc(2026, 1, 1),
          createdAt: now,
        );

        final createdId = await service.createRecord(candidate);

        expect(createdId, 'ownership-2');
        expect(ownershipRepository.createdRecords, hasLength(1));
      },
    );

    test('devir kaydı için belge veya sözleşme numarası zorunludur', () async {
      final record = _ownership(
        tenantId: tenantId,
        brandId: brandId,
        assetId: assetId,
        recordCode: 'ASSIGNMENT-1',
        acquisitionType: IpOwnershipAcquisitionType.assignment,
        ownershipKind: IpOwnershipKind.assignee,
        status: IpOwnershipStatus.active,
        createdAt: now,
      );

      await expectLater(
        service.createRecord(record),
        throwsA(
          isA<ArgumentError>().having(
            (error) => error.message,
            'message',
            contains('Devir kaydında'),
          ),
        ),
      );
    });

    test('lisans kaydı için belge veya sözleşme numarası zorunludur', () async {
      final record = _ownership(
        tenantId: tenantId,
        brandId: brandId,
        assetId: assetId,
        recordCode: 'LICENSE-1',
        acquisitionType: IpOwnershipAcquisitionType.license,
        ownershipKind: IpOwnershipKind.licensee,
        status: IpOwnershipStatus.active,
        ownershipPercentage: 0,
        createdAt: now,
      );

      await expectLater(
        service.createRecord(record),
        throwsA(
          isA<ArgumentError>().having(
            (error) => error.message,
            'message',
            contains('Lisans kaydında'),
          ),
        ),
      );
    });
  });

  group('IpOwnershipService hesaplama ve zincir', () {
    test(
      'aktif sahiplik yüzdesini yalnız sahiplik rollerinden hesaplar',
      () async {
        ownershipRepository.records = <IpOwnershipRecordModel>[
          _ownership(
            id: 'owner-1',
            tenantId: tenantId,
            brandId: brandId,
            assetId: assetId,
            recordCode: 'OWNER-1',
            ownershipKind: IpOwnershipKind.legalOwner,
            status: IpOwnershipStatus.active,
            ownershipPercentage: 60,
            effectiveFrom: DateTime.utc(2026, 1, 1),
            createdAt: now,
          ),
          _ownership(
            id: 'owner-2',
            tenantId: tenantId,
            brandId: brandId,
            assetId: assetId,
            recordCode: 'OWNER-2',
            ownershipKind: IpOwnershipKind.jointOwner,
            status: IpOwnershipStatus.active,
            ownershipPercentage: 40,
            effectiveFrom: DateTime.utc(2026, 1, 1),
            createdAt: now,
          ),
          _ownership(
            id: 'creator-1',
            tenantId: tenantId,
            brandId: brandId,
            assetId: assetId,
            recordCode: 'CREATOR-1',
            ownershipKind: IpOwnershipKind.creator,
            status: IpOwnershipStatus.active,
            ownershipPercentage: 25,
            effectiveFrom: DateTime.utc(2026, 1, 1),
            createdAt: now,
          ),
        ];

        final percentage = await service.calculateActiveOwnershipPercentage(
          assetId: assetId,
          effectiveAt: now,
        );

        expect(percentage, 100);
      },
    );

    test(
      'sahiplik zincirini başlangıç tarihine göre kronolojik sıralar',
      () async {
        ownershipRepository.records = <IpOwnershipRecordModel>[
          _ownership(
            id: 'record-2026',
            tenantId: tenantId,
            brandId: brandId,
            assetId: assetId,
            recordCode: 'OWN-2026',
            status: IpOwnershipStatus.active,
            effectiveFrom: DateTime.utc(2026, 1, 1),
            createdAt: DateTime.utc(2026, 1, 1),
          ),
          _ownership(
            id: 'record-2024',
            tenantId: tenantId,
            brandId: brandId,
            assetId: assetId,
            recordCode: 'OWN-2024',
            status: IpOwnershipStatus.transferred,
            effectiveFrom: DateTime.utc(2024, 1, 1),
            createdAt: DateTime.utc(2024, 1, 1),
          ),
          _ownership(
            id: 'record-2025',
            tenantId: tenantId,
            brandId: brandId,
            assetId: assetId,
            recordCode: 'OWN-2025',
            status: IpOwnershipStatus.transferred,
            effectiveFrom: DateTime.utc(2025, 1, 1),
            createdAt: DateTime.utc(2025, 1, 1),
          ),
        ];

        final chain = await service.loadOwnershipChain(assetId: assetId);

        expect(chain.map((record) => record.id).toList(), <String>[
          'record-2024',
          'record-2025',
          'record-2026',
        ]);
      },
    );
  });

  group('IpOwnershipService doğrulama ve durum aktarımı', () {
    test('dayanak belgesi olmayan kaydı doğrulamaz', () async {
      ownershipRepository.records = <IpOwnershipRecordModel>[
        _ownership(
          id: 'unverified-record',
          tenantId: tenantId,
          brandId: brandId,
          assetId: assetId,
          recordCode: 'VERIFY-EMPTY',
          status: IpOwnershipStatus.active,
          createdAt: now,
        ),
      ];

      await expectLater(
        service.verifyOwnership(
          ownershipRecordId: 'unverified-record',
          actorId: 'verifier-1',
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('Dayanak belgesi olmayan'),
          ),
        ),
      );
    });

    test('doğrulama çağrısını tarih ve aktörle repositoryye aktarır', () async {
      ownershipRepository.records = <IpOwnershipRecordModel>[
        _ownership(
          id: 'verified-record',
          tenantId: tenantId,
          brandId: brandId,
          assetId: assetId,
          recordCode: 'VERIFY-1',
          status: IpOwnershipStatus.active,
          documentIds: const <String>['doc-1'],
          createdAt: now,
        ),
      ];

      await service.verifyOwnership(
        ownershipRecordId: ' verified-record ',
        actorId: ' verifier-1 ',
      );

      final call = ownershipRepository.verificationCalls.single;

      expect(call.ownershipRecordId, 'verified-record');
      expect(call.verificationDate, now);
      expect(call.verifiedBy, 'verifier-1');
    });

    test(
      'durum güncellemesini temizlenmiş değerlerle repositoryye aktarır',
      () async {
        ownershipRepository.records = <IpOwnershipRecordModel>[
          _ownership(
            id: 'status-record',
            tenantId: tenantId,
            brandId: brandId,
            assetId: assetId,
            recordCode: 'STATUS-1',
            status: IpOwnershipStatus.active,
            createdAt: now,
          ),
        ];

        await service.updateStatus(
          ownershipRecordId: ' status-record ',
          status: IpOwnershipStatus.archived,
          actorId: ' user-1 ',
        );

        final call = ownershipRepository.statusCalls.single;

        expect(call.ownershipRecordId, 'status-record');
        expect(call.status, IpOwnershipStatus.archived);
        expect(call.updatedBy, 'user-1');
      },
    );
  });

  group('IpOwnershipService güvenli silme', () {
    test('aktif kaydın kalıcı silinmesini engeller', () async {
      ownershipRepository.records = <IpOwnershipRecordModel>[
        _ownership(
          id: 'active-record',
          tenantId: tenantId,
          brandId: brandId,
          assetId: assetId,
          recordCode: 'ACTIVE-1',
          status: IpOwnershipStatus.active,
          createdAt: now,
        ),
      ];

      await expectLater(
        service.deleteRecord('active-record'),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('Yalnız taslak'),
          ),
        ),
      );
    });

    test('bağlantılı taslak kaydın silinmesini engeller', () async {
      ownershipRepository.records = <IpOwnershipRecordModel>[
        _ownership(
          id: 'linked-draft',
          tenantId: tenantId,
          brandId: brandId,
          assetId: assetId,
          recordCode: 'DRAFT-LINKED',
          status: IpOwnershipStatus.draft,
          documentIds: const <String>['doc-1'],
          createdAt: now,
        ),
      ];

      await expectLater(
        service.deleteRecord('linked-draft'),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('Bağlantılı hak sahipliği'),
          ),
        ),
      );
    });

    test('bağlantısız taslak kaydı repository üzerinden siler', () async {
      ownershipRepository.records = <IpOwnershipRecordModel>[
        _ownership(
          id: 'clean-draft',
          tenantId: tenantId,
          brandId: brandId,
          assetId: assetId,
          recordCode: 'DRAFT-CLEAN',
          status: IpOwnershipStatus.draft,
          createdAt: now,
        ),
      ];

      await service.deleteRecord(' clean-draft ');

      expect(ownershipRepository.deletedIds, <String>['clean-draft']);
    });
  });

  group('IpOwnershipService tenant izolasyonu', () {
    test('listeleme sonucundaki yabancı tenant kaydını reddeder', () async {
      ownershipRepository.records = <IpOwnershipRecordModel>[
        _ownership(
          id: 'foreign-record',
          tenantId: 'tenant-2',
          brandId: brandId,
          assetId: assetId,
          recordCode: 'FOREIGN-1',
          status: IpOwnershipStatus.active,
          createdAt: now,
        ),
      ];

      await expectLater(
        service.listForAsset(assetId: assetId),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('farklı tenant'),
          ),
        ),
      );
    });

    test('canlı akıştaki yabancı tenant kaydını reddeder', () async {
      final expectation = expectLater(
        service.watchForAsset(assetId: assetId),
        emitsError(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('farklı tenant'),
          ),
        ),
      );

      await Future<void>.delayed(Duration.zero);

      ownershipRepository.emit(<IpOwnershipRecordModel>[
        _ownership(
          id: 'foreign-stream-record',
          tenantId: 'tenant-2',
          brandId: brandId,
          assetId: assetId,
          recordCode: 'FOREIGN-STREAM',
          status: IpOwnershipStatus.active,
          createdAt: now,
        ),
      ]);

      await expectation;
    });
  });
}

class _FakeOwnershipRepository implements IpOwnershipRepositoryPort {
  final StreamController<List<IpOwnershipRecordModel>> _controller =
      StreamController<List<IpOwnershipRecordModel>>.broadcast();

  List<IpOwnershipRecordModel> records = <IpOwnershipRecordModel>[];

  final List<IpOwnershipRecordModel> createdRecords =
      <IpOwnershipRecordModel>[];

  final List<String> deletedIds = <String>[];

  final List<_StatusCall> statusCalls = <_StatusCall>[];

  final List<_VerificationCall> verificationCalls = <_VerificationCall>[];

  Future<void> dispose() async {
    await _controller.close();
  }

  void emit(List<IpOwnershipRecordModel> value) {
    records = List<IpOwnershipRecordModel>.from(value);
    _controller.add(value);
  }

  @override
  Future<String> create(IpOwnershipRecordModel record) async {
    final id = record.id.trim().isEmpty
        ? 'ownership-${records.length + 1}'
        : record.id.trim();

    final created = record.copyWith(id: id);

    records.add(created);
    createdRecords.add(created);

    return id;
  }

  @override
  Future<void> update(IpOwnershipRecordModel record) async {
    final index = records.indexWhere((item) => item.id == record.id);

    if (index >= 0) {
      records[index] = record;
    }
  }

  @override
  Future<IpOwnershipRecordModel?> getById(String ownershipRecordId) async {
    for (final record in records) {
      if (record.id == ownershipRecordId) {
        return record;
      }
    }

    return null;
  }

  @override
  Future<IpOwnershipRecordModel?> findByRecordCode({
    required String brandId,
    required String recordCode,
  }) async {
    for (final record in records) {
      if (record.brandId == brandId && record.recordCode == recordCode) {
        return record;
      }
    }

    return null;
  }

  @override
  Future<List<IpOwnershipRecordModel>> listAll({
    String? brandId,
    String? assetId,
    String? partyId,
    String? rightId,
    IpOwnershipKind? ownershipKind,
    IpOwnershipPartyType? partyType,
    IpOwnershipAcquisitionType? acquisitionType,
    IpOwnershipStatus? status,
    bool? isPrimaryOwner,
    bool? isOwnershipVerified,
    int limit = 200,
  }) async {
    return _filter(
      source: records,
      brandId: brandId,
      assetId: assetId,
      partyId: partyId,
      rightId: rightId,
      ownershipKind: ownershipKind,
      partyType: partyType,
      acquisitionType: acquisitionType,
      status: status,
      isPrimaryOwner: isPrimaryOwner,
      isOwnershipVerified: isOwnershipVerified,
      limit: limit,
    );
  }

  @override
  Stream<List<IpOwnershipRecordModel>> watchAll({
    String? brandId,
    String? assetId,
    String? partyId,
    String? rightId,
    IpOwnershipKind? ownershipKind,
    IpOwnershipPartyType? partyType,
    IpOwnershipAcquisitionType? acquisitionType,
    IpOwnershipStatus? status,
    bool? isPrimaryOwner,
    bool? isOwnershipVerified,
    int limit = 200,
  }) {
    return _controller.stream.map(
      (items) => _filter(
        source: items,
        brandId: brandId,
        assetId: assetId,
        partyId: partyId,
        rightId: rightId,
        ownershipKind: ownershipKind,
        partyType: partyType,
        acquisitionType: acquisitionType,
        status: status,
        isPrimaryOwner: isPrimaryOwner,
        isOwnershipVerified: isOwnershipVerified,
        limit: limit,
      ),
    );
  }

  @override
  Future<List<IpOwnershipRecordModel>> listActiveForAsset({
    required String assetId,
    DateTime? effectiveAt,
    int limit = 200,
  }) async {
    final targetDate = effectiveAt ?? DateTime.now();

    return records
        .where(
          (record) =>
              record.assetId == assetId && record.isEffectiveAt(targetDate),
        )
        .take(limit)
        .toList(growable: false);
  }

  @override
  Future<List<IpOwnershipRecordModel>> listOwnershipChain({
    required String assetId,
    int limit = 500,
  }) async {
    return records
        .where((record) => record.assetId == assetId)
        .take(limit)
        .toList(growable: false);
  }

  @override
  Future<List<IpOwnershipRecordModel>> listByParty({
    required String partyId,
    bool activeOnly = false,
    int limit = 200,
  }) async {
    return records
        .where(
          (record) =>
              record.partyId == partyId && (!activeOnly || record.isActive),
        )
        .take(limit)
        .toList(growable: false);
  }

  @override
  Future<void> updateStatus({
    required String ownershipRecordId,
    required IpOwnershipStatus status,
    required String updatedBy,
  }) async {
    statusCalls.add(
      _StatusCall(
        ownershipRecordId: ownershipRecordId,
        status: status,
        updatedBy: updatedBy,
      ),
    );
  }

  @override
  Future<void> markVerified({
    required String ownershipRecordId,
    required DateTime verificationDate,
    required String verifiedBy,
  }) async {
    verificationCalls.add(
      _VerificationCall(
        ownershipRecordId: ownershipRecordId,
        verificationDate: verificationDate,
        verifiedBy: verifiedBy,
      ),
    );
  }

  @override
  Future<void> delete(String ownershipRecordId) async {
    deletedIds.add(ownershipRecordId);

    records.removeWhere((record) => record.id == ownershipRecordId);
  }

  static List<IpOwnershipRecordModel> _filter({
    required Iterable<IpOwnershipRecordModel> source,
    required String? brandId,
    required String? assetId,
    required String? partyId,
    required String? rightId,
    required IpOwnershipKind? ownershipKind,
    required IpOwnershipPartyType? partyType,
    required IpOwnershipAcquisitionType? acquisitionType,
    required IpOwnershipStatus? status,
    required bool? isPrimaryOwner,
    required bool? isOwnershipVerified,
    required int limit,
  }) {
    return source
        .where((record) {
          if (brandId != null && record.brandId != brandId) {
            return false;
          }

          if (assetId != null && record.assetId != assetId) {
            return false;
          }

          if (partyId != null && record.partyId != partyId) {
            return false;
          }

          if (rightId != null && record.rightId != rightId) {
            return false;
          }

          if (ownershipKind != null && record.ownershipKind != ownershipKind) {
            return false;
          }

          if (partyType != null && record.partyType != partyType) {
            return false;
          }

          if (acquisitionType != null &&
              record.acquisitionType != acquisitionType) {
            return false;
          }

          if (status != null && record.status != status) {
            return false;
          }

          if (isPrimaryOwner != null &&
              record.isPrimaryOwner != isPrimaryOwner) {
            return false;
          }

          if (isOwnershipVerified != null &&
              record.isOwnershipVerified != isOwnershipVerified) {
            return false;
          }

          return true;
        })
        .take(limit)
        .toList(growable: false);
  }
}

class _FakeAssetRepository implements IpAssetRepositoryPort {
  _FakeAssetRepository({List<IpAssetModel> assets = const <IpAssetModel>[]})
    : assets = List<IpAssetModel>.from(assets);

  List<IpAssetModel> assets;

  int getByIdCalls = 0;

  @override
  Future<String> create(IpAssetModel asset) async {
    final id = asset.id.trim().isEmpty
        ? 'asset-${assets.length + 1}'
        : asset.id.trim();

    assets.add(asset.copyWith(id: id));

    return id;
  }

  @override
  Future<void> update(IpAssetModel asset) async {
    final index = assets.indexWhere((item) => item.id == asset.id);

    if (index >= 0) {
      assets[index] = asset;
    }
  }

  @override
  Future<IpAssetModel?> getById(String assetId) async {
    getByIdCalls += 1;

    for (final asset in assets) {
      if (asset.id == assetId) {
        return asset;
      }
    }

    return null;
  }

  @override
  Future<IpAssetModel?> findByAssetCode({
    required String brandId,
    required String assetCode,
  }) async {
    for (final asset in assets) {
      if (asset.brandId == brandId && asset.assetCode == assetCode) {
        return asset;
      }
    }

    return null;
  }

  @override
  Future<List<IpAssetModel>> listAll({
    String? brandId,
    IpAssetType? assetType,
    IpAssetStatus? status,
    IpRiskLevel? riskLevel,
    bool? containsTradeSecret,
    bool? monitoringEnabled,
    int limit = 200,
  }) async {
    return assets
        .where(
          (asset) =>
              (brandId == null || asset.brandId == brandId) &&
              (assetType == null || asset.assetType == assetType) &&
              (status == null || asset.status == status) &&
              (riskLevel == null || asset.riskLevel == riskLevel) &&
              (containsTradeSecret == null ||
                  asset.containsTradeSecret == containsTradeSecret) &&
              (monitoringEnabled == null ||
                  asset.monitoringEnabled == monitoringEnabled),
        )
        .take(limit)
        .toList(growable: false);
  }

  @override
  Stream<List<IpAssetModel>> watchAll({
    String? brandId,
    IpAssetType? assetType,
    IpAssetStatus? status,
    IpRiskLevel? riskLevel,
    bool? containsTradeSecret,
    bool? monitoringEnabled,
    int limit = 200,
  }) {
    return Stream<List<IpAssetModel>>.value(
      assets.take(limit).toList(growable: false),
    );
  }

  @override
  Future<List<IpAssetModel>> listProtectionGaps({
    String? brandId,
    int limit = 200,
  }) async {
    return assets
        .where(
          (asset) =>
              (brandId == null || asset.brandId == brandId) &&
              asset.hasProtectionGap,
        )
        .take(limit)
        .toList(growable: false);
  }

  @override
  Future<List<IpAssetModel>> listImmediateAttention({
    String? brandId,
    int limit = 200,
  }) async {
    return assets
        .where(
          (asset) =>
              (brandId == null || asset.brandId == brandId) &&
              asset.requiresImmediateAttention,
        )
        .take(limit)
        .toList(growable: false);
  }

  @override
  Future<void> updateStatus({
    required String assetId,
    required IpAssetStatus status,
    required String updatedBy,
  }) async {}

  @override
  Future<void> updateScores({
    required String assetId,
    required int rightStrengthScore,
    required int secretSecurityScore,
    required int responseReadinessScore,
    required int resilienceScore,
    required String updatedBy,
  }) async {}

  @override
  Future<void> delete(String assetId) async {
    assets.removeWhere((asset) => asset.id == assetId);
  }
}

class _StatusCall {
  const _StatusCall({
    required this.ownershipRecordId,
    required this.status,
    required this.updatedBy,
  });

  final String ownershipRecordId;
  final IpOwnershipStatus status;
  final String updatedBy;
}

class _VerificationCall {
  const _VerificationCall({
    required this.ownershipRecordId,
    required this.verificationDate,
    required this.verifiedBy,
  });

  final String ownershipRecordId;
  final DateTime verificationDate;
  final String verifiedBy;
}

IpOwnershipRecordModel _ownership({
  String id = '',
  required String tenantId,
  required String brandId,
  required String assetId,
  required String recordCode,
  String partyName = 'Hak Sahibi A.Ş.',
  String? partyId,
  String? partyCountryCode,
  String? partyContactEmail,
  IpOwnershipKind ownershipKind = IpOwnershipKind.legalOwner,
  IpOwnershipPartyType partyType = IpOwnershipPartyType.company,
  IpOwnershipAcquisitionType acquisitionType =
      IpOwnershipAcquisitionType.originalCreation,
  IpOwnershipStatus status = IpOwnershipStatus.draft,
  double ownershipPercentage = 100,
  IpJurisdictionScope jurisdictionScope = IpJurisdictionScope.national,
  List<String> countryCodes = const <String>['TR'],
  String? rightId,
  String? agreementNumber,
  DateTime? effectiveFrom,
  DateTime? effectiveUntil,
  bool isPrimaryOwner = false,
  List<String> documentIds = const <String>[],
  required DateTime createdAt,
}) {
  return IpOwnershipRecordModel(
    id: id,
    tenantId: tenantId,
    brandId: brandId,
    assetId: assetId,
    recordCode: recordCode,
    ownershipKind: ownershipKind,
    partyType: partyType,
    partyName: partyName,
    partyId: partyId,
    partyCountryCode: partyCountryCode,
    partyContactEmail: partyContactEmail,
    acquisitionType: acquisitionType,
    status: status,
    ownershipPercentage: ownershipPercentage,
    jurisdictionScope: jurisdictionScope,
    countryCodes: countryCodes,
    rightId: rightId,
    agreementNumber: agreementNumber,
    effectiveFrom: effectiveFrom,
    effectiveUntil: effectiveUntil,
    isPrimaryOwner: isPrimaryOwner,
    documentIds: documentIds,
    createdAt: createdAt,
    createdBy: 'user-1',
  );
}

IpAssetModel _asset({
  required String id,
  required String tenantId,
  required String brandId,
  required DateTime createdAt,
}) {
  return IpAssetModel(
    id: id,
    tenantId: tenantId,
    brandId: brandId,
    assetCode: 'ASSET-001',
    title: 'Test Fikri Varlığı',
    assetType: IpAssetType.trademark,
    status: IpAssetStatus.active,
    confidentialityLevel: IpConfidentialityLevel.internal,
    riskLevel: IpRiskLevel.medium,
    createdAt: createdAt,
    createdBy: 'user-1',
  );
}

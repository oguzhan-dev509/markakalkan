import 'package:cloud_functions/cloud_functions.dart';

import '../models/ip_creation_priority_record_model.dart';
import '../models/ip_creation_priority_version_model.dart';

class IpCreationPriorityDraftResult {
  const IpCreationPriorityDraftResult({
    required this.recordId,
    required this.versionId,
  });

  final String recordId;
  final String versionId;
}

class IpCreationPriorityCommandService {
  IpCreationPriorityCommandService({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'europe-west3');

  final FirebaseFunctions _functions;

  Future<String> ensureOwnerIdentity() async {
    final callable = _functions.httpsCallable(
      'ensureIpCreationRegistryOwnerIdentity',
    );

    final response = await callable.call<Map<String, dynamic>>();

    return _parseOwnerNumber(response.data);
  }

  Future<IpCreationPriorityDraftResult> createDraft({
    required IpCreationPriorityRecordModel record,
    required IpCreationPriorityVersionModel version,
  }) async {
    final callable = _functions.httpsCallable('createIpCreationPriorityDraft');

    final response = await callable.call<Map<String, dynamic>>(
      _payload(record: record, version: version, includeIds: false),
    );

    return _parseResult(response.data);
  }

  Future<IpCreationPriorityDraftResult> updateDraft({
    required IpCreationPriorityRecordModel record,
    required IpCreationPriorityVersionModel version,
  }) async {
    final recordId = _requiredId(record.id, fieldName: 'record.id');
    _requiredId(version.id, fieldName: 'version.id');

    if (version.recordId.trim() != recordId) {
      throw StateError('Taslak sürüm, yaratım öncelik kaydıyla eşleşmiyor.');
    }

    final callable = _functions.httpsCallable('updateIpCreationPriorityDraft');

    final response = await callable.call<Map<String, dynamic>>(
      _payload(record: record, version: version, includeIds: true),
    );

    return _parseResult(response.data);
  }

  Future<String> sealRecord({
    required String recordId,
    required String versionId,
  }) async {
    final cleanedRecordId = _requiredId(recordId, fieldName: 'recordId');
    final cleanedVersionId = _requiredId(versionId, fieldName: 'versionId');
    final callable = _functions.httpsCallable('sealIpCreationPriorityRecord');

    final response = await callable.call<Map<String, dynamic>>(
      <String, dynamic>{
        'recordId': cleanedRecordId,
        'versionId': cleanedVersionId,
      },
    );

    return _parseContentHash(response.data);
  }

  Future<IpCreationPriorityDraftResult> createVersion({
    required IpCreationPriorityRecordModel record,
    required IpCreationPriorityVersionModel version,
  }) async {
    final recordId = _requiredId(record.id, fieldName: 'record.id');
    final callable = _functions.httpsCallable(
      'createIpCreationPriorityVersion',
    );

    final response = await callable.call<Map<String, dynamic>>(
      <String, dynamic>{'recordId': recordId, ..._versionPayload(version)},
    );

    return _parseResult(response.data);
  }

  static Map<String, dynamic> _payload({
    required IpCreationPriorityRecordModel record,
    required IpCreationPriorityVersionModel version,
    required bool includeIds,
  }) {
    return <String, dynamic>{
      if (includeIds) 'recordId': record.id.trim(),
      if (includeIds) 'versionId': version.id.trim(),
      if (!includeIds) 'recordCode': record.recordCode.trim(),
      'title': record.title.trim(),
      'summary': _cleanNullable(record.summary),
      'creatorName': _cleanNullable(record.creatorName),
      'creationType': record.creationType.value,
      'confidentialityLevel': record.confidentialityLevel.value,
      'coCreatorIds': List<String>.from(record.coCreatorIds),
      'authorizedUserIds': List<String>.from(record.authorizedUserIds),
      'tags': List<String>.from(record.tags),
      'relatedAssetIds': List<String>.from(record.relatedAssetIds),
      'firstThoughtAt': _dateToIso(record.firstThoughtAt),
      'metadata': Map<String, dynamic>.from(record.metadata),
      ..._versionPayload(version),
    };
  }

  static Map<String, dynamic> _versionPayload(
    IpCreationPriorityVersionModel version,
  ) {
    return <String, dynamic>{
      'versionTitle': version.title.trim(),
      'versionSummary': _cleanNullable(version.summary),
      'description': _cleanNullable(version.description),
      'originalElements': _cleanNullable(version.originalElements),
      'problemStatement': _cleanNullable(version.problemStatement),
      'developmentStage': version.developmentStage.value,
      'fileManifest': version.fileManifest
          .map((item) => Map<String, dynamic>.from(item))
          .toList(growable: false),
      'versionMetadata': Map<String, dynamic>.from(version.metadata),
    };
  }

  static String _parseOwnerNumber(Map<String, dynamic> data) {
    final ownerNumber = data['registryOwnerNumber'];

    if (ownerNumber is! String ||
        !RegExp(r'^MK-SH-[A-Z0-9]{4}-[A-Z0-9]{4}$').hasMatch(ownerNumber)) {
      throw StateError('Sunucu geçerli Sicil Sahibi No döndürmedi.');
    }

    return ownerNumber;
  }

  static String _parseContentHash(Map<String, dynamic> data) {
    final contentHash = data['contentHash'];

    if (contentHash is! String ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(contentHash)) {
      throw StateError('Sunucu geçerli SHA-256 içerik özeti döndürmedi.');
    }

    return contentHash;
  }

  static IpCreationPriorityDraftResult _parseResult(Map<String, dynamic> data) {
    final recordId = data['recordId'];
    final versionId = data['versionId'];

    if (recordId is! String || recordId.trim().isEmpty) {
      throw StateError('Sunucu yaratım öncelik kayıt kimliğini döndürmedi.');
    }

    if (versionId is! String || versionId.trim().isEmpty) {
      throw StateError('Sunucu yaratım öncelik sürüm kimliğini döndürmedi.');
    }

    return IpCreationPriorityDraftResult(
      recordId: recordId.trim(),
      versionId: versionId.trim(),
    );
  }

  static String _requiredId(String value, {required String fieldName}) {
    final cleaned = value.trim();

    if (cleaned.isEmpty || cleaned.contains('/')) {
      throw ArgumentError.value(value, fieldName, '$fieldName geçersiz.');
    }

    return cleaned;
  }

  static String? _dateToIso(DateTime? value) {
    return value?.toUtc().toIso8601String();
  }

  static String? _cleanNullable(String? value) {
    final cleaned = value?.trim();

    return cleaned == null || cleaned.isEmpty ? null : cleaned;
  }
}

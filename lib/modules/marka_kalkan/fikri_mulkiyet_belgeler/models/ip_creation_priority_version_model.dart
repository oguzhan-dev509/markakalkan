import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants/ip_creation_priority_enums.dart';
import '../utils/ip_model_utils.dart';

class IpCreationPriorityVersionModel {
  const IpCreationPriorityVersionModel({
    required this.id,
    required this.tenantId,
    required this.brandId,
    required this.recordId,
    required this.versionNumber,
    required this.title,
    required this.developmentStage,
    required this.sealStatus,
    required this.createdAt,
    required this.createdBy,
    this.summary,
    this.description,
    this.originalElements,
    this.problemStatement,
    this.previousVersionId,
    this.previousVersionHash,
    this.contentHash,
    this.hashAlgorithm = 'SHA-256',
    this.fileManifest = const <Map<String, dynamic>>[],
    this.sealedAt,
    this.timestampedAt,
    this.timestampAuthority,
    this.metadata = const <String, dynamic>{},
  });

  final String id;
  final String tenantId;
  final String brandId;
  final String recordId;
  final int versionNumber;

  final String title;
  final String? summary;
  final String? description;
  final String? originalElements;
  final String? problemStatement;

  final IpCreationDevelopmentStage developmentStage;
  final IpCreationSealStatus sealStatus;

  final String? previousVersionId;
  final String? previousVersionHash;
  final String? contentHash;
  final String hashAlgorithm;

  final List<Map<String, dynamic>> fileManifest;

  final DateTime? sealedAt;
  final DateTime? timestampedAt;
  final String? timestampAuthority;

  final Map<String, dynamic> metadata;

  final DateTime createdAt;
  final String createdBy;

  factory IpCreationPriorityVersionModel.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();

    if (data == null) {
      throw StateError(
        'Yarat\u0131m \u00f6ncelik s\u00fcr\u00fcm\u00fc veri i\u00e7ermiyor: ${document.id}',
      );
    }

    return IpCreationPriorityVersionModel.fromMap(id: document.id, data: data);
  }

  factory IpCreationPriorityVersionModel.fromMap({
    required String id,
    required Map<String, dynamic> data,
  }) {
    final createdAt = IpModelUtils.dateTimeFromValue(data['createdAt']);

    if (createdAt == null) {
      throw StateError(
        'Yarat\u0131m \u00f6ncelik s\u00fcr\u00fcm\u00fc olu\u015fturma tarihi eksik: $id',
      );
    }

    return IpCreationPriorityVersionModel(
      id: id.trim(),
      tenantId: IpModelUtils.requiredString(data['tenantId']),
      brandId: IpModelUtils.requiredString(data['brandId']),
      recordId: IpModelUtils.requiredString(data['recordId']),
      versionNumber: _positiveVersion(data['versionNumber']),
      title: IpModelUtils.requiredString(data['title']),
      summary: IpModelUtils.nullableString(data['summary']),
      description: IpModelUtils.nullableString(data['description']),
      originalElements: IpModelUtils.nullableString(data['originalElements']),
      problemStatement: IpModelUtils.nullableString(data['problemStatement']),
      developmentStage: IpCreationDevelopmentStage.fromValue(
        data['developmentStage']?.toString(),
      ),
      sealStatus: IpCreationSealStatus.fromValue(
        data['sealStatus']?.toString(),
      ),
      previousVersionId: IpModelUtils.nullableString(data['previousVersionId']),
      previousVersionHash: IpModelUtils.nullableString(
        data['previousVersionHash'],
      ),
      contentHash: IpModelUtils.nullableString(data['contentHash']),
      hashAlgorithm:
          IpModelUtils.nullableString(data['hashAlgorithm']) ?? 'SHA-256',
      fileManifest: _mapList(data['fileManifest']),
      sealedAt: IpModelUtils.dateTimeFromValue(data['sealedAt']),
      timestampedAt: IpModelUtils.dateTimeFromValue(data['timestampedAt']),
      timestampAuthority: IpModelUtils.nullableString(
        data['timestampAuthority'],
      ),
      metadata: IpModelUtils.mapFromValue(data['metadata']),
      createdAt: createdAt,
      createdBy: IpModelUtils.requiredString(data['createdBy']),
    );
  }

  bool get hasCompleteIdentity {
    return tenantId.trim().isNotEmpty &&
        brandId.trim().isNotEmpty &&
        recordId.trim().isNotEmpty &&
        versionNumber > 0 &&
        title.trim().isNotEmpty;
  }

  bool get isSealed {
    return sealStatus == IpCreationSealStatus.sealed ||
        sealStatus == IpCreationSealStatus.timestampPending ||
        sealStatus == IpCreationSealStatus.timestamped;
  }

  bool get hasCryptographicFingerprint {
    return contentHash != null && contentHash!.trim().isNotEmpty;
  }

  bool get hasValidChainLink {
    if (versionNumber == 1) {
      return previousVersionId == null && previousVersionHash == null;
    }

    return previousVersionId != null &&
        previousVersionId!.trim().isNotEmpty &&
        previousVersionHash != null &&
        previousVersionHash!.trim().isNotEmpty;
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'tenantId': tenantId.trim(),
      'brandId': brandId.trim(),
      'recordId': recordId.trim(),
      'versionNumber': versionNumber < 1 ? 1 : versionNumber,
      'title': title.trim(),
      'summary': IpModelUtils.cleanNullable(summary),
      'description': IpModelUtils.cleanNullable(description),
      'originalElements': IpModelUtils.cleanNullable(originalElements),
      'problemStatement': IpModelUtils.cleanNullable(problemStatement),
      'developmentStage': developmentStage.value,
      'sealStatus': sealStatus.value,
      'previousVersionId': IpModelUtils.cleanNullable(previousVersionId),
      'previousVersionHash': IpModelUtils.cleanNullable(previousVersionHash),
      'contentHash': IpModelUtils.cleanNullable(contentHash),
      'hashAlgorithm': IpModelUtils.cleanNullable(hashAlgorithm) ?? 'SHA-256',
      'fileManifest': fileManifest
          .map((item) => Map<String, dynamic>.from(item))
          .toList(growable: false),
      'sealedAt': IpModelUtils.timestampOrNull(sealedAt),
      'timestampedAt': IpModelUtils.timestampOrNull(timestampedAt),
      'timestampAuthority': IpModelUtils.cleanNullable(timestampAuthority),
      'metadata': Map<String, dynamic>.from(metadata),
      'createdAt': Timestamp.fromDate(createdAt),
      'createdBy': createdBy.trim(),
    };
  }

  Map<String, dynamic> toCreateMap() {
    final map = toMap();

    map['createdAt'] = FieldValue.serverTimestamp();

    return map;
  }

  static int _positiveVersion(Object? value) {
    final parsed = IpModelUtils.intFromValue(value, fallback: 1);

    return parsed < 1 ? 1 : parsed;
  }

  static List<Map<String, dynamic>> _mapList(Object? value) {
    if (value is! Iterable) {
      return const <Map<String, dynamic>>[];
    }

    final items = <Map<String, dynamic>>[];

    for (final item in value) {
      if (item is Map<String, dynamic>) {
        items.add(Map<String, dynamic>.from(item));
      } else if (item is Map) {
        items.add(
          item.map((key, mapValue) => MapEntry(key.toString(), mapValue)),
        );
      }
    }

    return items;
  }
}

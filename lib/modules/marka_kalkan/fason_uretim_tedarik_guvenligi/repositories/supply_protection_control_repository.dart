import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants/supply_protection_control_enums.dart';
import '../models/supply_protection_control_model.dart';
import 'supply_protection_control_command_service.dart';
import 'supply_security_firestore_refs.dart';

class SupplyProtectionControlRepository {
  const SupplyProtectionControlRepository({
    required SupplySecurityFirestoreRefs refs,
    SupplyProtectionControlCommandService? commandService,
  }) : _refs = refs,
       _commandService = commandService;

  factory SupplyProtectionControlRepository.instance({
    required String tenantId,
  }) {
    return SupplyProtectionControlRepository(
      refs: SupplySecurityFirestoreRefs.instance(tenantId: tenantId),
      commandService: SupplyProtectionControlCommandService(),
    );
  }

  final SupplySecurityFirestoreRefs _refs;
  final SupplyProtectionControlCommandService? _commandService;

  Future<String> create(SupplyProtectionControlModel control) async {
    _validateTenant(control.tenantId);
    _validateControl(control);

    final commandService =
        _commandService ?? SupplyProtectionControlCommandService();

    return commandService.create(control);
  }

  Future<void> update(SupplyProtectionControlModel control) async {
    _validateTenant(control.tenantId);
    _validateControl(control);
    _validateRequiredId(control.id, fieldName: 'controlId');

    final commandService =
        _commandService ?? SupplyProtectionControlCommandService();

    await commandService.update(control);
  }

  Future<SupplyProtectionControlModel?> getById(String controlId) async {
    final snapshot = await _refs.protectionControlDocument(controlId).get();

    if (!snapshot.exists || snapshot.data() == null) {
      return null;
    }

    final control = SupplyProtectionControlModel.fromDocument(snapshot);

    _validateTenant(control.tenantId);

    return control;
  }

  Future<SupplyProtectionControlModel?> findByControlCode({
    required String brandId,
    required String controlCode,
  }) async {
    final cleanedBrandId = _validateRequiredId(brandId, fieldName: 'brandId');

    final normalizedCode = _validateRequiredText(
      controlCode,
      fieldName: 'controlCode',
    ).toUpperCase();

    final snapshot = await _refs
        .tenantQuery(_refs.protectionControls)
        .where('brandId', isEqualTo: cleanedBrandId)
        .where('controlCodeNormalized', isEqualTo: normalizedCode)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) {
      return null;
    }

    return SupplyProtectionControlModel.fromDocument(snapshot.docs.first);
  }

  Future<List<SupplyProtectionControlModel>> listAll({
    String? brandId,
    String? partnerId,
    String? facilityId,
    SupplyProtectionControlStatus? status,
    SupplyProtectionControlResult? result,
    SupplyProtectionControlRiskLevel? riskLevel,
    int limit = 200,
  }) async {
    final query = _buildQuery(
      brandId: brandId,
      partnerId: partnerId,
      facilityId: facilityId,
      status: status,
      result: result,
      riskLevel: riskLevel,
    );

    final snapshot = await query
        .orderBy('createdAt', descending: true)
        .limit(_validateLimit(limit))
        .get();

    return snapshot.docs
        .map(SupplyProtectionControlModel.fromDocument)
        .toList(growable: false);
  }

  Stream<List<SupplyProtectionControlModel>> watchAll({
    String? brandId,
    String? partnerId,
    String? facilityId,
    SupplyProtectionControlStatus? status,
    SupplyProtectionControlResult? result,
    SupplyProtectionControlRiskLevel? riskLevel,
    int limit = 200,
  }) {
    return _buildQuery(
          brandId: brandId,
          partnerId: partnerId,
          facilityId: facilityId,
          status: status,
          result: result,
          riskLevel: riskLevel,
        )
        .orderBy('createdAt', descending: true)
        .limit(_validateLimit(limit))
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(SupplyProtectionControlModel.fromDocument)
              .toList(growable: false),
        );
  }

  Future<List<SupplyProtectionControlModel>> listOpenHighRisk({
    String? brandId,
    int limit = 200,
  }) async {
    final controls = await listAll(brandId: brandId, limit: 500);

    return controls
        .where(
          (control) =>
              !control.isArchived && !control.isCompleted && control.isHighRisk,
        )
        .take(_validateLimit(limit))
        .toList(growable: false);
  }

  Future<void> complete({
    required String controlId,
    required SupplyProtectionControlResult result,
    required SupplyProtectionControlRiskLevel riskLevel,
    required String findings,
    required String updatedBy,
    String? correctiveAction,
    String? correctiveActionOwnerId,
    String? correctiveActionOwnerName,
    DateTime? correctiveActionDueAt,
    DateTime? nextControlAt,
  }) async {
    if (result == SupplyProtectionControlResult.notEvaluated) {
      throw ArgumentError('Tamamlanan kontrolde sonuç seçilmelidir.');
    }

    final cleanedFindings = _validateRequiredText(
      findings,
      fieldName: 'findings',
    );

    final actorId = _validateRequiredId(updatedBy, fieldName: 'updatedBy');

    final document = _refs.protectionControlDocument(controlId);

    final control = await _requireControl(document);

    _validateTenant(control.tenantId);

    if (control.isArchived) {
      throw StateError('Arşivlenmiş kontrol tamamlanamaz.');
    }

    final isFailure =
        result == SupplyProtectionControlResult.failed ||
        result == SupplyProtectionControlResult.criticalFailure;

    final cleanedCorrectiveAction = _cleanNullable(correctiveAction);

    if (isFailure && cleanedCorrectiveAction == null) {
      throw ArgumentError('Uygunsuz kontrolde düzeltici faaliyet zorunludur.');
    }

    await document.update(<String, dynamic>{
      'status': SupplyProtectionControlStatus.completed.value,
      'result': result.value,
      'riskLevel': riskLevel.value,
      'findings': cleanedFindings,
      'completedAt': FieldValue.serverTimestamp(),
      'correctiveAction': cleanedCorrectiveAction,
      'correctiveActionOwnerId': _cleanNullable(correctiveActionOwnerId),
      'correctiveActionOwnerName': _cleanNullable(correctiveActionOwnerName),
      'correctiveActionDueAt': correctiveActionDueAt == null
          ? null
          : Timestamp.fromDate(correctiveActionDueAt),
      'nextControlAt': nextControlAt == null
          ? null
          : Timestamp.fromDate(nextControlAt),
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': actorId,
    });
  }

  Future<void> markCorrectiveActionCompleted({
    required String controlId,
    required String updatedBy,
  }) async {
    final actorId = _validateRequiredId(updatedBy, fieldName: 'updatedBy');

    final document = _refs.protectionControlDocument(controlId);

    final control = await _requireControl(document);

    _validateTenant(control.tenantId);

    if (control.isArchived) {
      throw StateError('Arşivlenmiş kontrolde faaliyet kapatılamaz.');
    }

    if (!control.hasFailure) {
      throw StateError('Uygun sonuçlu kontrolde düzeltici faaliyet bulunmaz.');
    }

    if (control.correctiveAction == null ||
        control.correctiveAction!.trim().isEmpty) {
      throw StateError('Kapatılacak düzeltici faaliyet bulunamadı.');
    }

    await document.update(<String, dynamic>{
      'correctiveActionCompletedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': actorId,
    });
  }

  Future<void> archive({
    required String controlId,
    required String archiveReason,
    required String updatedBy,
  }) async {
    final reason = _validateRequiredText(
      archiveReason,
      fieldName: 'archiveReason',
    );

    final actorId = _validateRequiredId(updatedBy, fieldName: 'updatedBy');

    final document = _refs.protectionControlDocument(controlId);

    final control = await _requireControl(document);

    _validateTenant(control.tenantId);

    if (control.isArchived) {
      throw StateError('Koruma kontrolü zaten arşivlenmiş.');
    }

    await document.update(<String, dynamic>{
      'status': SupplyProtectionControlStatus.archived.value,
      'archiveReason': reason,
      'archivedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': actorId,
    });
  }

  Query<Map<String, dynamic>> _buildQuery({
    String? brandId,
    String? partnerId,
    String? facilityId,
    SupplyProtectionControlStatus? status,
    SupplyProtectionControlResult? result,
    SupplyProtectionControlRiskLevel? riskLevel,
  }) {
    Query<Map<String, dynamic>> query = _refs.tenantQuery(
      _refs.protectionControls,
    );

    final cleanedBrandId = _cleanNullable(brandId);
    final cleanedPartnerId = _cleanNullable(partnerId);
    final cleanedFacilityId = _cleanNullable(facilityId);

    if (cleanedBrandId != null) {
      query = query.where('brandId', isEqualTo: cleanedBrandId);
    }

    if (cleanedPartnerId != null) {
      query = query.where('partnerId', isEqualTo: cleanedPartnerId);
    }

    if (cleanedFacilityId != null) {
      query = query.where('facilityId', isEqualTo: cleanedFacilityId);
    }

    if (status != null) {
      query = query.where('status', isEqualTo: status.value);
    }

    if (result != null) {
      query = query.where('result', isEqualTo: result.value);
    }

    if (riskLevel != null) {
      query = query.where('riskLevel', isEqualTo: riskLevel.value);
    }

    return query;
  }

  Future<SupplyProtectionControlModel> _requireControl(
    DocumentReference<Map<String, dynamic>> document,
  ) async {
    final snapshot = await document.get();

    if (!snapshot.exists || snapshot.data() == null) {
      throw StateError(
        'İşlem yapılacak koruma kontrolü bulunamadı: '
        '${document.id}',
      );
    }

    return SupplyProtectionControlModel.fromDocument(snapshot);
  }

  void _validateControl(SupplyProtectionControlModel control) {
    if (control.brandId.trim().isEmpty ||
        control.controlCode.trim().isEmpty ||
        control.title.trim().isEmpty) {
      throw ArgumentError('Marka, kontrol kodu ve kontrol adı zorunludur.');
    }

    if (!control.hasValidScopeTarget) {
      throw ArgumentError('Kontrol kapsamı ile hedef bağlantıları uyumsuz.');
    }

    if (control.title.trim().length > 200) {
      throw ArgumentError.value(
        control.title,
        'title',
        'Kontrol adı 200 karakteri aşamaz.',
      );
    }

    if (control.description != null &&
        control.description!.trim().length > 5000) {
      throw ArgumentError.value(
        control.description,
        'description',
        'Açıklama 5000 karakteri aşamaz.',
      );
    }

    if (control.findings != null && control.findings!.trim().length > 10000) {
      throw ArgumentError.value(
        control.findings,
        'findings',
        'Bulgular 10000 karakteri aşamaz.',
      );
    }

    if (control.isArchived &&
        (control.archiveReason == null ||
            control.archiveReason!.trim().isEmpty)) {
      throw ArgumentError('Arşivlenen kontrolde arşiv gerekçesi zorunludur.');
    }

    if (control.isCompleted &&
        control.result == SupplyProtectionControlResult.notEvaluated) {
      throw ArgumentError('Tamamlanan kontrolde sonuç zorunludur.');
    }

    if (control.hasFailure &&
        (control.findings == null || control.findings!.trim().isEmpty)) {
      throw ArgumentError('Uygunsuz kontrolde bulgu zorunludur.');
    }

    if (control.hasFailure &&
        (control.correctiveAction == null ||
            control.correctiveAction!.trim().isEmpty)) {
      throw ArgumentError('Uygunsuz kontrolde düzeltici faaliyet zorunludur.');
    }
  }

  void _validateTenant(String tenantId) {
    if (tenantId.trim() != _refs.tenantId) {
      throw StateError(
        'Koruma kontrolü tenant kimliği repository ile eşleşmiyor.',
      );
    }
  }

  static String _validateRequiredId(String value, {required String fieldName}) {
    final cleaned = value.trim();

    if (cleaned.isEmpty) {
      throw ArgumentError.value(value, fieldName, '$fieldName boş olamaz.');
    }

    if (cleaned.contains('/')) {
      throw ArgumentError.value(
        value,
        fieldName,
        '$fieldName "/" karakteri içeremez.',
      );
    }

    return cleaned;
  }

  static String _validateRequiredText(
    String value, {
    required String fieldName,
  }) {
    final cleaned = value.trim();

    if (cleaned.isEmpty) {
      throw ArgumentError.value(value, fieldName, '$fieldName boş olamaz.');
    }

    return cleaned;
  }

  static int _validateLimit(int value) {
    if (value < 1 || value > 500) {
      throw RangeError.range(value, 1, 500, 'limit');
    }

    return value;
  }

  static String? _cleanNullable(String? value) {
    final cleaned = value?.trim();

    return cleaned == null || cleaned.isEmpty ? null : cleaned;
  }
}

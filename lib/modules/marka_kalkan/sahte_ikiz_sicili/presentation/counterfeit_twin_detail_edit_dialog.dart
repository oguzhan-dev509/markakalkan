import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:markakalkan/core/theme/markakalkan_theme.dart';

import '../constants/counterfeit_twin_enums.dart';
import '../models/counterfeit_twin_model.dart';
import '../repositories/counterfeit_twin_repository.dart';

Future<bool> showCounterfeitTwinDetailEditDialog({
  required BuildContext context,
  required User user,
  required CounterfeitTwinRepository repository,
  required CounterfeitTwinModel record,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _CounterfeitTwinDetailEditDialog(
      user: user,
      repository: repository,
      record: record,
    ),
  );
  return result == true;
}

class _CounterfeitTwinDetailEditDialog extends StatefulWidget {
  const _CounterfeitTwinDetailEditDialog({
    required this.user,
    required this.repository,
    required this.record,
  });

  final User user;
  final CounterfeitTwinRepository repository;
  final CounterfeitTwinModel record;

  @override
  State<_CounterfeitTwinDetailEditDialog> createState() =>
      _CounterfeitTwinDetailEditDialogState();
}

class _CounterfeitTwinDetailEditDialogState
    extends State<_CounterfeitTwinDetailEditDialog> {
  late final TextEditingController _title;
  late final TextEditingController _suspectedBrandName;
  late final TextEditingController _suspectedProductName;
  late final TextEditingController _cloneFamilyId;
  late final TextEditingController _waveId;
  late final TextEditingController _dismissReason;
  late final TextEditingController _archiveReason;
  late final TextEditingController _notes;

  late CounterfeitTwinStatus _status;
  late CounterfeitTwinConfidenceLevel _confidence;
  late CounterfeitTwinRiskLevel _risk;
  late CounterfeitTwinReviewStatus _review;
  late CounterfeitTwinCloneMethod _method;
  late double _overallScore;

  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final record = widget.record;
    _title = TextEditingController(text: record.title);
    _suspectedBrandName = TextEditingController(
      text: record.suspectedBrandName ?? '',
    );
    _suspectedProductName = TextEditingController(
      text: record.suspectedProductName ?? '',
    );
    _cloneFamilyId = TextEditingController(text: record.cloneFamilyId ?? '');
    _waveId = TextEditingController(text: record.waveId ?? '');
    _dismissReason = TextEditingController(text: record.dismissReason ?? '');
    _archiveReason = TextEditingController(text: record.archiveReason ?? '');
    _notes = TextEditingController(text: record.notes ?? '');
    _status = record.status;
    _confidence = record.confidenceLevel;
    _risk = record.riskLevel;
    _review = record.reviewStatus;
    _method = record.primaryCloneMethod;
    _overallScore = record.overallSimilarityScore.toDouble();
  }

  @override
  void dispose() {
    for (final controller in <TextEditingController>[
      _title,
      _suspectedBrandName,
      _suspectedProductName,
      _cloneFamilyId,
      _waveId,
      _dismissReason,
      _archiveReason,
      _notes,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  String? _nullable(String value) {
    final cleaned = value.trim();
    return cleaned.isEmpty ? null : cleaned;
  }

  Future<void> _save() async {
    if (_isSaving) return;

    if (_title.text.trim().isEmpty) {
      setState(() => _error = 'Kayıt başlığı zorunludur.');
      return;
    }

    if (_status == CounterfeitTwinStatus.dismissed &&
        _dismissReason.text.trim().isEmpty) {
      setState(() => _error = 'Çürütülen kayıt için gerekçe zorunludur.');
      return;
    }

    if (_status == CounterfeitTwinStatus.archived &&
        _archiveReason.text.trim().isEmpty) {
      setState(() => _error = 'Arşivlenen kayıt için gerekçe zorunludur.');
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      final old = widget.record;
      final updated = CounterfeitTwinModel(
        id: old.id,
        tenantId: old.tenantId,
        brandId: old.brandId,
        recordCode: old.recordCode,
        title: _title.text.trim(),
        status: _status,
        confidenceLevel: _confidence,
        riskLevel: _risk,
        reviewStatus: _review,
        primaryCloneMethod: _method,
        originalProductId: old.originalProductId,
        originalIpAssetId: old.originalIpAssetId,
        originalBrandName: old.originalBrandName,
        originalProductName: old.originalProductName,
        originalVariantName: old.originalVariantName,
        suspectedBrandName: _nullable(_suspectedBrandName.text),
        suspectedProductName: _nullable(_suspectedProductName.text),
        suspectedVariantName: old.suspectedVariantName,
        claimedManufacturer: old.claimedManufacturer,
        countryCode: old.countryCode,
        region: old.region,
        cloneMethods: old.cloneMethods.contains(_method)
            ? old.cloneMethods
            : <CounterfeitTwinCloneMethod>[...old.cloneMethods, _method],
        visualSimilarityScore: old.visualSimilarityScore,
        packagingSimilarityScore: old.packagingSimilarityScore,
        logoSimilarityScore: old.logoSimilarityScore,
        nameSimilarityScore: old.nameSimilarityScore,
        textSimilarityScore: old.textSimilarityScore,
        priceAnomalyScore: old.priceAnomalyScore,
        overallSimilarityScore: _overallScore.round(),
        sourceIds: old.sourceIds,
        listingIds: old.listingIds,
        sellerIds: old.sellerIds,
        storeIds: old.storeIds,
        monitoredPageIds: old.monitoredPageIds,
        mediaAssetIds: old.mediaAssetIds,
        evidencePackageIds: old.evidencePackageIds,
        monitoringEventIds: old.monitoringEventIds,
        monitoringSignalIds: old.monitoringSignalIds,
        cloneFamilyId: _nullable(_cloneFamilyId.text),
        waveId: _nullable(_waveId.text),
        relatedTwinRecordIds: old.relatedTwinRecordIds,
        recurrenceCount: old.recurrenceCount,
        firstSeenAt: old.firstSeenAt,
        lastSeenAt: old.lastSeenAt,
        confirmedAt: old.confirmedAt,
        dismissedAt: old.dismissedAt,
        dismissReason: _nullable(_dismissReason.text),
        archivedAt: old.archivedAt,
        archiveReason: _nullable(_archiveReason.text),
        notes: _nullable(_notes.text),
        metadata: old.metadata,
        createdAt: old.createdAt,
        createdBy: old.createdBy,
        updatedAt: DateTime.now(),
        updatedBy: widget.user.uid,
      );

      await widget.repository.update(updated, actorId: widget.user.uid);

      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width < 860
        ? MediaQuery.sizeOf(context).width - 32
        : 820.0;

    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      insetPadding: const EdgeInsets.all(16),
      title: Text(
        '${widget.record.recordCode} · Sahte İkiz Dosyası',
        style: const TextStyle(
          color: MarkaKalkanTheme.navy,
          fontWeight: FontWeight.w900,
        ),
      ),
      content: SizedBox(
        width: width,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _title,
                decoration: const InputDecoration(labelText: 'Kayıt başlığı *'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<CounterfeitTwinStatus>(
                initialValue: _status,
                decoration: const InputDecoration(labelText: 'Durum'),
                items: CounterfeitTwinStatus.values
                    .map(
                      (item) => DropdownMenuItem(
                        value: item,
                        child: Text(item.label),
                      ),
                    )
                    .toList(growable: false),
                onChanged: _isSaving
                    ? null
                    : (value) => setState(() => _status = value ?? _status),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<CounterfeitTwinRiskLevel>(
                initialValue: _risk,
                decoration: const InputDecoration(labelText: 'Risk'),
                items: CounterfeitTwinRiskLevel.values
                    .map(
                      (item) => DropdownMenuItem(
                        value: item,
                        child: Text(item.label),
                      ),
                    )
                    .toList(growable: false),
                onChanged: _isSaving
                    ? null
                    : (value) => setState(() => _risk = value ?? _risk),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<CounterfeitTwinReviewStatus>(
                initialValue: _review,
                decoration: const InputDecoration(labelText: 'İnceleme durumu'),
                items: CounterfeitTwinReviewStatus.values
                    .map(
                      (item) => DropdownMenuItem(
                        value: item,
                        child: Text(item.label),
                      ),
                    )
                    .toList(growable: false),
                onChanged: _isSaving
                    ? null
                    : (value) => setState(() => _review = value ?? _review),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<CounterfeitTwinConfidenceLevel>(
                initialValue: _confidence,
                decoration: const InputDecoration(labelText: 'Güven düzeyi'),
                items: CounterfeitTwinConfidenceLevel.values
                    .map(
                      (item) => DropdownMenuItem(
                        value: item,
                        child: Text(item.label),
                      ),
                    )
                    .toList(growable: false),
                onChanged: _isSaving
                    ? null
                    : (value) =>
                          setState(() => _confidence = value ?? _confidence),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<CounterfeitTwinCloneMethod>(
                initialValue: _method,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Ana klon yöntemi',
                ),
                items: CounterfeitTwinCloneMethod.values
                    .map(
                      (item) => DropdownMenuItem(
                        value: item,
                        child: Text(item.label),
                      ),
                    )
                    .toList(growable: false),
                onChanged: _isSaving
                    ? null
                    : (value) => setState(() => _method = value ?? _method),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _suspectedBrandName,
                decoration: const InputDecoration(labelText: 'Şüpheli marka'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _suspectedProductName,
                decoration: const InputDecoration(labelText: 'Şüpheli ürün'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _cloneFamilyId,
                decoration: const InputDecoration(labelText: 'Klon ailesi ID'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _waveId,
                decoration: const InputDecoration(labelText: 'Dalga ID'),
              ),
              const SizedBox(height: 16),
              Text(
                'Genel benzerlik skoru: %${_overallScore.round()}',
                style: const TextStyle(
                  color: MarkaKalkanTheme.navy,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Slider(
                value: _overallScore,
                min: 0,
                max: 100,
                divisions: 100,
                onChanged: _isSaving
                    ? null
                    : (value) => setState(() => _overallScore = value),
              ),
              const SizedBox(height: 10),
              _ConnectionSummary(record: widget.record),
              if (_status == CounterfeitTwinStatus.dismissed) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _dismissReason,
                  minLines: 2,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'Çürütme gerekçesi *',
                  ),
                ),
              ],
              if (_status == CounterfeitTwinStatus.archived) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _archiveReason,
                  minLines: 2,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'Arşiv gerekçesi *',
                  ),
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: _notes,
                minLines: 3,
                maxLines: 7,
                decoration: const InputDecoration(labelText: 'Notlar'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 14),
                Text(
                  _error!,
                  style: const TextStyle(
                    color: Color(0xFFB42318),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Kapat'),
        ),
        FilledButton.icon(
          onPressed: _isSaving ? null : _save,
          icon: _isSaving
              ? const SizedBox(
                  width: 17,
                  height: 17,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.save_outlined),
          label: Text(_isSaving ? 'Kaydediliyor...' : 'Değişiklikleri Kaydet'),
        ),
      ],
    );
  }
}

class _ConnectionSummary extends StatelessWidget {
  const _ConnectionSummary({required this.record});

  final CounterfeitTwinModel record;

  @override
  Widget build(BuildContext context) {
    final rows = <MapEntry<String, int>>[
      MapEntry('Kaynak', record.sourceIds.length),
      MapEntry('İlan', record.listingIds.length),
      MapEntry('Satıcı', record.sellerIds.length),
      MapEntry('Mağaza', record.storeIds.length),
      MapEntry('İzlenen sayfa', record.monitoredPageIds.length),
      MapEntry('Medya', record.mediaAssetIds.length),
      MapEntry('Kanıt paketi', record.evidencePackageIds.length),
      MapEntry('Olay', record.monitoringEventIds.length),
      MapEntry('Sinyal', record.monitoringSignalIds.length),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F9FA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0E7EC)),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: rows
            .map((item) => Chip(label: Text('${item.key}: ${item.value}')))
            .toList(growable: false),
      ),
    );
  }
}

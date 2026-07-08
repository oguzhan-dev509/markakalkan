import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:markakalkan/core/theme/markakalkan_theme.dart';

import '../constants/counterfeit_twin_enums.dart';
import '../models/counterfeit_twin_model.dart';
import '../repositories/counterfeit_twin_repository.dart';

Future<bool> showCounterfeitTwinCreateDialog({
  required BuildContext context,
  required User user,
  required CounterfeitTwinRepository repository,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) =>
        _CounterfeitTwinCreateDialog(user: user, repository: repository),
  );
  return result == true;
}

class _CounterfeitTwinCreateDialog extends StatefulWidget {
  const _CounterfeitTwinCreateDialog({
    required this.user,
    required this.repository,
  });

  final User user;
  final CounterfeitTwinRepository repository;

  @override
  State<_CounterfeitTwinCreateDialog> createState() =>
      _CounterfeitTwinCreateDialogState();
}

class _CounterfeitTwinCreateDialogState
    extends State<_CounterfeitTwinCreateDialog> {
  final _formKey = GlobalKey<FormState>();

  final _recordCode = TextEditingController();
  final _title = TextEditingController();
  final _originalBrandName = TextEditingController();
  final _originalProductName = TextEditingController();
  final _suspectedBrandName = TextEditingController();
  final _suspectedProductName = TextEditingController();
  final _countryCode = TextEditingController();
  final _region = TextEditingController();
  final _cloneFamilyId = TextEditingController();
  final _waveId = TextEditingController();
  final _notes = TextEditingController();

  CounterfeitTwinStatus _status = CounterfeitTwinStatus.suspected;
  CounterfeitTwinConfidenceLevel _confidence =
      CounterfeitTwinConfidenceLevel.medium;
  CounterfeitTwinRiskLevel _risk = CounterfeitTwinRiskLevel.medium;
  CounterfeitTwinReviewStatus _review = CounterfeitTwinReviewStatus.notStarted;
  CounterfeitTwinCloneMethod _method = CounterfeitTwinCloneMethod.unknown;

  double _overallScore = 0;
  bool _isSaving = false;
  String? _error;

  @override
  void dispose() {
    for (final controller in <TextEditingController>[
      _recordCode,
      _title,
      _originalBrandName,
      _originalProductName,
      _suspectedBrandName,
      _suspectedProductName,
      _countryCode,
      _region,
      _cloneFamilyId,
      _waveId,
      _notes,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  String? _required(String? value, String label, int maxLength) {
    final cleaned = value?.trim() ?? '';
    if (cleaned.isEmpty) return '$label zorunludur.';
    if (cleaned.length > maxLength) {
      return '$label en fazla $maxLength karakter olabilir.';
    }
    return null;
  }

  String? _optional(String? value, String label, int maxLength) {
    final cleaned = value?.trim() ?? '';
    if (cleaned.length > maxLength) {
      return '$label en fazla $maxLength karakter olabilir.';
    }
    return null;
  }

  String? _nullable(String value) {
    final cleaned = value.trim();
    return cleaned.isEmpty ? null : cleaned;
  }

  Future<void> _save() async {
    if (_isSaving || !(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      final now = DateTime.now();
      final record = CounterfeitTwinModel(
        id: '',
        tenantId: widget.user.uid,
        brandId: widget.user.uid,
        recordCode: _recordCode.text.trim(),
        title: _title.text.trim(),
        status: _status,
        confidenceLevel: _confidence,
        riskLevel: _risk,
        reviewStatus: _review,
        primaryCloneMethod: _method,
        originalBrandName: _nullable(_originalBrandName.text),
        originalProductName: _nullable(_originalProductName.text),
        suspectedBrandName: _nullable(_suspectedBrandName.text),
        suspectedProductName: _nullable(_suspectedProductName.text),
        countryCode: _nullable(_countryCode.text),
        region: _nullable(_region.text),
        cloneMethods: <CounterfeitTwinCloneMethod>[_method],
        overallSimilarityScore: _overallScore.round(),
        cloneFamilyId: _nullable(_cloneFamilyId.text),
        waveId: _nullable(_waveId.text),
        firstSeenAt: now,
        notes: _nullable(_notes.text),
        createdAt: now,
        createdBy: widget.user.uid,
      );

      await widget.repository.create(record);

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
      title: const Text(
        'Yeni Sahte İkiz Kaydı',
        style: TextStyle(
          color: MarkaKalkanTheme.navy,
          fontWeight: FontWeight.w900,
        ),
      ),
      content: SizedBox(
        width: width,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _recordCode,
                  enabled: !_isSaving,
                  decoration: const InputDecoration(
                    labelText: 'Kayıt kodu *',
                    hintText: 'Örn. SİZ-2026-001',
                  ),
                  validator: (value) => _required(value, 'Kayıt kodu', 100),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _title,
                  enabled: !_isSaving,
                  decoration: const InputDecoration(
                    labelText: 'Kayıt başlığı *',
                  ),
                  validator: (value) => _required(value, 'Kayıt başlığı', 240),
                ),
                const SizedBox(height: 12),
                _EnumRow(
                  children: [
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
                          : (value) =>
                                setState(() => _status = value ?? _status),
                    ),
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
                  ],
                ),
                const SizedBox(height: 12),
                _EnumRow(
                  children: [
                    DropdownButtonFormField<CounterfeitTwinConfidenceLevel>(
                      initialValue: _confidence,
                      decoration: const InputDecoration(
                        labelText: 'Güven düzeyi',
                      ),
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
                          : (value) => setState(
                              () => _confidence = value ?? _confidence,
                            ),
                    ),
                    DropdownButtonFormField<CounterfeitTwinReviewStatus>(
                      initialValue: _review,
                      decoration: const InputDecoration(
                        labelText: 'İnceleme durumu',
                      ),
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
                          : (value) =>
                                setState(() => _review = value ?? _review),
                    ),
                  ],
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
                _TextPair(
                  left: TextFormField(
                    controller: _originalBrandName,
                    decoration: const InputDecoration(
                      labelText: 'Orijinal marka',
                    ),
                    validator: (value) =>
                        _optional(value, 'Orijinal marka', 240),
                  ),
                  right: TextFormField(
                    controller: _originalProductName,
                    decoration: const InputDecoration(
                      labelText: 'Orijinal ürün',
                    ),
                    validator: (value) =>
                        _optional(value, 'Orijinal ürün', 500),
                  ),
                ),
                const SizedBox(height: 12),
                _TextPair(
                  left: TextFormField(
                    controller: _suspectedBrandName,
                    decoration: const InputDecoration(
                      labelText: 'Şüpheli marka',
                    ),
                    validator: (value) =>
                        _optional(value, 'Şüpheli marka', 240),
                  ),
                  right: TextFormField(
                    controller: _suspectedProductName,
                    decoration: const InputDecoration(
                      labelText: 'Şüpheli ürün',
                    ),
                    validator: (value) => _optional(value, 'Şüpheli ürün', 500),
                  ),
                ),
                const SizedBox(height: 12),
                _TextPair(
                  left: TextFormField(
                    controller: _countryCode,
                    decoration: const InputDecoration(labelText: 'Ülke kodu'),
                    validator: (value) => _optional(value, 'Ülke kodu', 16),
                  ),
                  right: TextFormField(
                    controller: _region,
                    decoration: const InputDecoration(labelText: 'Bölge'),
                    validator: (value) => _optional(value, 'Bölge', 240),
                  ),
                ),
                const SizedBox(height: 12),
                _TextPair(
                  left: TextFormField(
                    controller: _cloneFamilyId,
                    decoration: const InputDecoration(
                      labelText: 'Klon ailesi ID',
                    ),
                    validator: (value) =>
                        _optional(value, 'Klon ailesi ID', 240),
                  ),
                  right: TextFormField(
                    controller: _waveId,
                    decoration: const InputDecoration(labelText: 'Dalga ID'),
                    validator: (value) => _optional(value, 'Dalga ID', 240),
                  ),
                ),
                const SizedBox(height: 18),
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
                  label: _overallScore.round().toString(),
                  onChanged: _isSaving
                      ? null
                      : (value) => setState(() => _overallScore = value),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _notes,
                  minLines: 3,
                  maxLines: 6,
                  decoration: const InputDecoration(labelText: 'Notlar'),
                  validator: (value) => _optional(value, 'Notlar', 10000),
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
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Vazgeç'),
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
              : const Icon(Icons.add_circle_outline),
          label: Text(_isSaving ? 'Kaydediliyor...' : 'Kaydı Oluştur'),
        ),
      ],
    );
  }
}

class _EnumRow extends StatelessWidget {
  const _EnumRow({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, constraints) {
        if (constraints.maxWidth < 680) {
          return Column(
            children: [
              children.first,
              const SizedBox(height: 12),
              children.last,
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: children.first),
            const SizedBox(width: 12),
            Expanded(child: children.last),
          ],
        );
      },
    );
  }
}

class _TextPair extends StatelessWidget {
  const _TextPair({required this.left, required this.right});

  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, constraints) {
        if (constraints.maxWidth < 680) {
          return Column(children: [left, const SizedBox(height: 12), right]);
        }
        return Row(
          children: [
            Expanded(child: left),
            const SizedBox(width: 12),
            Expanded(child: right),
          ],
        );
      },
    );
  }
}

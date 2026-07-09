import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:markakalkan/core/theme/markakalkan_theme.dart';

import '../constants/ip_creation_priority_enums.dart';
import '../models/ip_creation_priority_record_model.dart';
import '../models/ip_creation_priority_version_model.dart';
import '../repositories/ip_creation_priority_repository.dart';

Future<bool> showIpCreationPriorityCreateDialog({
  required BuildContext context,
  required User user,
  required IpCreationPriorityRepository repository,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) =>
        _IpCreationPriorityCreateDialog(user: user, repository: repository),
  );

  return result == true;
}

class _IpCreationPriorityCreateDialog extends StatefulWidget {
  const _IpCreationPriorityCreateDialog({
    required this.user,
    required this.repository,
  });

  final User user;
  final IpCreationPriorityRepository repository;

  @override
  State<_IpCreationPriorityCreateDialog> createState() =>
      _IpCreationPriorityCreateDialogState();
}

class _IpCreationPriorityCreateDialogState
    extends State<_IpCreationPriorityCreateDialog> {
  final _formKey = GlobalKey<FormState>();

  final _recordCode = TextEditingController();
  final _title = TextEditingController();
  final _summary = TextEditingController();
  final _creatorName = TextEditingController();
  final _description = TextEditingController();
  final _originalElements = TextEditingController();
  final _problemStatement = TextEditingController();
  final _tags = TextEditingController();

  IpCreationType _creationType = IpCreationType.creativeIdea;
  IpCreationConfidentialityLevel _confidentiality =
      IpCreationConfidentialityLevel.private;
  IpCreationDevelopmentStage _developmentStage =
      IpCreationDevelopmentStage.initialIdea;

  DateTime _firstThoughtAt = DateTime.now();
  bool _isSaving = false;
  String? _error;

  bool get _showPatentDisclosureWarning {
    return _confidentiality == IpCreationConfidentialityLevel.publicStatement &&
        (_creationType == IpCreationType.invention ||
            _creationType == IpCreationType.utilityModel ||
            _creationType == IpCreationType.industrialDesign);
  }

  @override
  void dispose() {
    for (final controller in <TextEditingController>[
      _recordCode,
      _title,
      _summary,
      _creatorName,
      _description,
      _originalElements,
      _problemStatement,
      _tags,
    ]) {
      controller.dispose();
    }

    super.dispose();
  }

  String? _required(String? value, String label, int maxLength) {
    final cleaned = value?.trim() ?? '';

    if (cleaned.isEmpty) {
      return '$label zorunludur.';
    }

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

  List<String> _tagList(String value) {
    final seen = <String>{};
    final result = <String>[];

    for (final item in value.split(',')) {
      final cleaned = item.trim();

      if (cleaned.isNotEmpty && seen.add(cleaned)) {
        result.add(cleaned);
      }
    }

    return result;
  }

  Future<void> _pickFirstThoughtDate() async {
    if (_isSaving) {
      return;
    }

    final selected = await showDatePicker(
      context: context,
      initialDate: _firstThoughtAt,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );

    if (selected == null || !mounted) {
      return;
    }

    setState(() {
      _firstThoughtAt = DateTime(
        selected.year,
        selected.month,
        selected.day,
        _firstThoughtAt.hour,
        _firstThoughtAt.minute,
      );
    });
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
      const localRecordId = 'pending-record';
      const localVersionId = 'pending-version';

      final record = IpCreationPriorityRecordModel(
        id: localRecordId,
        tenantId: widget.user.uid,
        brandId: widget.user.uid,
        recordCode: _recordCode.text.trim(),
        title: _title.text.trim(),
        summary: _nullable(_summary.text),
        creatorName: _nullable(_creatorName.text),
        creationType: _creationType,
        status: IpCreationPriorityStatus.draft,
        confidentialityLevel: _confidentiality,
        sealStatus: IpCreationSealStatus.unsealed,
        currentVersion: 1,
        activeVersionId: localVersionId,
        tags: _tagList(_tags.text),
        firstThoughtAt: _firstThoughtAt,
        createdAt: now,
        createdBy: widget.user.uid,
      );

      final version = IpCreationPriorityVersionModel(
        id: localVersionId,
        tenantId: widget.user.uid,
        brandId: widget.user.uid,
        recordId: localRecordId,
        versionNumber: 1,
        title: _title.text.trim(),
        summary: _nullable(_summary.text),
        description: _nullable(_description.text),
        originalElements: _nullable(_originalElements.text),
        problemStatement: _nullable(_problemStatement.text),
        developmentStage: _developmentStage,
        sealStatus: IpCreationSealStatus.unsealed,
        createdAt: now,
        createdBy: widget.user.uid,
      );

      await widget.repository.createDraft(record: record, version: version);

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewportWidth = MediaQuery.sizeOf(context).width;
    final width = viewportWidth < 900 ? viewportWidth - 32 : 860.0;

    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      insetPadding: const EdgeInsets.all(16),
      title: const Text(
        'Yeni Yaratım Öncelik Kaydı',
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
                const _LegalNotice(),
                const SizedBox(height: 18),
                TextFormField(
                  controller: _recordCode,
                  enabled: !_isSaving,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Kayıt kodu *',
                    hintText: 'Örn. YÖS-2026-001',
                  ),
                  validator: (value) => _required(value, 'Kayıt kodu', 100),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _title,
                  enabled: !_isSaving,
                  decoration: const InputDecoration(
                    labelText: 'Yaratım başlığı *',
                  ),
                  validator: (value) =>
                      _required(value, 'Yaratım başlığı', 240),
                ),
                const SizedBox(height: 12),
                _ResponsiveRow(
                  children: [
                    DropdownButtonFormField<IpCreationType>(
                      initialValue: _creationType,
                      decoration: const InputDecoration(
                        labelText: 'Yaratım türü',
                      ),
                      items: IpCreationType.values
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
                              () => _creationType = value ?? _creationType,
                            ),
                    ),
                    DropdownButtonFormField<IpCreationConfidentialityLevel>(
                      initialValue: _confidentiality,
                      decoration: const InputDecoration(labelText: 'Gizlilik'),
                      items: IpCreationConfidentialityLevel.values
                          .map(
                            (item) => DropdownMenuItem(
                              value: item,
                              child: Text(
                                item.label,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: _isSaving
                          ? null
                          : (value) => setState(
                              () =>
                                  _confidentiality = value ?? _confidentiality,
                            ),
                    ),
                  ],
                ),
                if (_showPatentDisclosureWarning) ...[
                  const SizedBox(height: 12),
                  const _PatentDisclosureWarning(),
                ],
                const SizedBox(height: 12),
                _ResponsiveRow(
                  children: [
                    DropdownButtonFormField<IpCreationDevelopmentStage>(
                      initialValue: _developmentStage,
                      decoration: const InputDecoration(
                        labelText: 'Gelişim aşaması',
                      ),
                      items: IpCreationDevelopmentStage.values
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
                              () => _developmentStage =
                                  value ?? _developmentStage,
                            ),
                    ),
                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: _isSaving ? null : _pickFirstThoughtDate,
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'İlk düşünce tarihi',
                          suffixIcon: Icon(Icons.calendar_today_outlined),
                        ),
                        child: Text(_formatDate(_firstThoughtAt)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _creatorName,
                  enabled: !_isSaving,
                  decoration: const InputDecoration(
                    labelText: 'Yaratıcı / buluş sahibi',
                  ),
                  validator: (value) => _optional(value, 'Yaratıcı adı', 160),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _summary,
                  enabled: !_isSaving,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Kısa özet'),
                  validator: (value) => _optional(value, 'Kısa özet', 1000),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _description,
                  enabled: !_isSaving,
                  minLines: 4,
                  maxLines: 8,
                  decoration: const InputDecoration(
                    labelText: 'Ayrıntılı açıklama',
                    alignLabelWithHint: true,
                  ),
                  validator: (value) =>
                      _optional(value, 'Ayrıntılı açıklama', 12000),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _originalElements,
                  enabled: !_isSaving,
                  minLines: 3,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    labelText: 'Özgün unsurlar',
                    hintText:
                        'Yaratımı benzerlerinden ayıran özgün yönleri yazın.',
                    alignLabelWithHint: true,
                  ),
                  validator: (value) =>
                      _optional(value, 'Özgün unsurlar', 8000),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _problemStatement,
                  enabled: !_isSaving,
                  minLines: 3,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    labelText: 'Çözülen problem / amaç',
                    alignLabelWithHint: true,
                  ),
                  validator: (value) =>
                      _optional(value, 'Problem tanımı', 8000),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _tags,
                  enabled: !_isSaving,
                  decoration: const InputDecoration(
                    labelText: 'Etiketler',
                    hintText: 'Virgülle ayırın',
                  ),
                  validator: (value) => _optional(value, 'Etiketler', 1000),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  _ErrorBox(message: _error!),
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
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_outlined),
          label: Text(_isSaving ? 'Kaydediliyor...' : 'Taslağı Kaydet'),
        ),
      ],
    );
  }

  static String _formatDate(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    return '$day.$month.${value.year}';
  }
}

class _ResponsiveRow extends StatelessWidget {
  const _ResponsiveRow({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 650) {
          return Column(
            children: [
              for (var index = 0; index < children.length; index++) ...[
                children[index],
                if (index != children.length - 1) const SizedBox(height: 12),
              ],
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var index = 0; index < children.length; index++) ...[
              Expanded(child: children[index]),
              if (index != children.length - 1) const SizedBox(width: 12),
            ],
          ],
        );
      },
    );
  }
}

class _LegalNotice extends StatelessWidget {
  const _LegalNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF071B36), Color(0xFF073A4A), Color(0xFF0A5C67)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1D7480)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22051A2F),
            blurRadius: 14,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lock_outline_rounded, color: Color(0xFFFFC857), size: 26),
          SizedBox(width: 12),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: TextStyle(
                  color: Colors.white,
                  height: 1.5,
                  fontWeight: FontWeight.w700,
                ),
                children: [
                  TextSpan(
                    text: 'Bu kayıt bir tescil değildir. ',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  TextSpan(
                    text:
                        'Yaratımınızın ne zaman ve hangi içerikle sizde '
                        'bulunduğunu belgeleyen ilk taslağı oluşturur. ',
                  ),
                  TextSpan(
                    text:
                        'Taslak kaydedildikten sonra kayıt içeriği '
                        'değiştirilemez. ',
                    style: TextStyle(
                      color: Color(0xFFFFC857),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  TextSpan(
                    text:
                        'Mühürleme işlemi kayıt oluşturulduktan sonra '
                        'ayrıca yapılır.',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PatentDisclosureWarning extends StatelessWidget {
  const _PatentDisclosureWarning();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7E6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFFD28A)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: Color(0xFF9A5A00)),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Dikkat: Patent, faydalı model veya endüstriyel tasarım '
              'adayını kamuya açıklamak yenilik değerlendirmesini '
              'etkileyebilir. Varsayılan ve önerilen seçenek '
              '“Tamamen özel”dir.',
              style: TextStyle(
                color: Color(0xFF7A4B00),
                fontWeight: FontWeight.w700,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEEEE),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFB7B7)),
      ),
      child: Text(
        message,
        style: const TextStyle(
          color: Color(0xFF8F1D1D),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

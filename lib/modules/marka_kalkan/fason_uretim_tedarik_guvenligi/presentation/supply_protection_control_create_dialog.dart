import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:markakalkan/core/theme/markakalkan_theme.dart';

import '../constants/supply_protection_control_enums.dart';
import '../models/supply_facility_model.dart';
import '../models/supply_partner_model.dart';
import '../models/supply_protection_control_model.dart';
import '../repositories/supply_facility_repository.dart';
import '../repositories/supply_partner_repository.dart';
import '../repositories/supply_protection_control_repository.dart';

Future<bool> showSupplyProtectionControlCreateDialog({
  required BuildContext context,
  required User user,
  required SupplyProtectionControlRepository controlRepository,
  required SupplyPartnerRepository partnerRepository,
  required SupplyFacilityRepository facilityRepository,
}) async {
  final results = await Future.wait<Object>([
    partnerRepository.listAll(limit: 500),
    facilityRepository.listAll(limit: 500),
  ]);

  if (!context.mounted) {
    return false;
  }

  final partners = (results[0] as List<SupplyPartnerModel>)
      .where((item) => !item.isArchived)
      .toList(growable: false);

  final facilities = (results[1] as List<SupplyFacilityModel>)
      .where((item) => !item.isArchived)
      .toList(growable: false);

  if (partners.isEmpty && facilities.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Koruma kontrolü oluşturmak için önce en az bir '
          'aktif partner veya tesis kaydı oluşturun.',
        ),
      ),
    );

    return false;
  }

  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return _SupplyProtectionControlCreateDialog(
        user: user,
        controlRepository: controlRepository,
        partners: partners,
        facilities: facilities,
      );
    },
  );

  return result == true;
}

class _SupplyProtectionControlCreateDialog extends StatefulWidget {
  const _SupplyProtectionControlCreateDialog({
    required this.user,
    required this.controlRepository,
    required this.partners,
    required this.facilities,
  });

  final User user;
  final SupplyProtectionControlRepository controlRepository;
  final List<SupplyPartnerModel> partners;
  final List<SupplyFacilityModel> facilities;

  @override
  State<_SupplyProtectionControlCreateDialog> createState() {
    return _SupplyProtectionControlCreateDialogState();
  }
}

class _SupplyProtectionControlCreateDialogState
    extends State<_SupplyProtectionControlCreateDialog> {
  final _formKey = GlobalKey<FormState>();

  final _controlCodeController = TextEditingController();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _assignedToNameController = TextEditingController();
  final _notesController = TextEditingController();

  SupplyProtectionControlType _controlType =
      SupplyProtectionControlType.facilityInspection;

  SupplyProtectionControlScope _scope = SupplyProtectionControlScope.partner;

  SupplyProtectionControlRiskLevel _riskLevel =
      SupplyProtectionControlRiskLevel.medium;

  String? _selectedPartnerId;
  String? _selectedFacilityId;
  DateTime? _plannedAt;

  bool _isSaving = false;
  String? _errorMessage;

  List<SupplyFacilityModel> get _availableFacilities {
    if (_scope != SupplyProtectionControlScope.partnerAndFacility) {
      return widget.facilities;
    }

    if (_selectedPartnerId == null) {
      return const <SupplyFacilityModel>[];
    }

    return widget.facilities
        .where((facility) => facility.partnerId == _selectedPartnerId)
        .toList(growable: false);
  }

  @override
  void dispose() {
    _controlCodeController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _assignedToNameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  String? _requiredText(
    String? value, {
    required String label,
    required int maxLength,
  }) {
    final cleaned = value?.trim() ?? '';

    if (cleaned.isEmpty) {
      return '$label zorunludur.';
    }

    if (cleaned.length > maxLength) {
      return '$label en fazla $maxLength karakter olabilir.';
    }

    return null;
  }

  String? _optionalText(
    String? value, {
    required String label,
    required int maxLength,
  }) {
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

  void _changeScope(SupplyProtectionControlScope value) {
    setState(() {
      _scope = value;

      switch (value) {
        case SupplyProtectionControlScope.partner:
          _selectedFacilityId = null;
          break;

        case SupplyProtectionControlScope.facility:
          _selectedPartnerId = null;
          break;

        case SupplyProtectionControlScope.partnerAndFacility:
          if (_selectedFacilityId != null) {
            SupplyFacilityModel? selectedFacility;

            for (final facility in widget.facilities) {
              if (facility.id == _selectedFacilityId) {
                selectedFacility = facility;
                break;
              }
            }

            if (selectedFacility != null) {
              _selectedPartnerId = selectedFacility.partnerId;
            }
          }
          break;
      }
    });
  }

  Future<void> _selectPlannedDate() async {
    final today = DateTime.now();

    final selected = await showDatePicker(
      context: context,
      initialDate: _plannedAt ?? today.add(const Duration(days: 1)),
      firstDate: DateTime(today.year, today.month, today.day),
      lastDate: DateTime(today.year + 10),
    );

    if (selected == null || !mounted) {
      return;
    }

    setState(() {
      _plannedAt = selected;
    });
  }

  Future<void> _save() async {
    if (_isSaving) {
      return;
    }

    setState(() {
      _errorMessage = null;
    });

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    if (_plannedAt == null) {
      setState(() {
        _errorMessage = 'Planlanan kontrol tarihini seçin.';
      });
      return;
    }

    if (_scope == SupplyProtectionControlScope.partner &&
        (_selectedPartnerId == null || _selectedPartnerId!.trim().isEmpty)) {
      setState(() {
        _errorMessage = 'Kontrol partnerini seçin.';
      });
      return;
    }

    if (_scope == SupplyProtectionControlScope.facility &&
        (_selectedFacilityId == null || _selectedFacilityId!.trim().isEmpty)) {
      setState(() {
        _errorMessage = 'Kontrol tesisini seçin.';
      });
      return;
    }

    if (_scope == SupplyProtectionControlScope.partnerAndFacility &&
        ((_selectedPartnerId == null || _selectedPartnerId!.trim().isEmpty) ||
            (_selectedFacilityId == null ||
                _selectedFacilityId!.trim().isEmpty))) {
      setState(() {
        _errorMessage = 'Partner ve tesis hedeflerini birlikte seçin.';
      });
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final now = DateTime.now();

      final control = SupplyProtectionControlModel(
        id: '',
        tenantId: widget.user.uid,
        brandId: widget.user.uid,
        controlCode: _controlCodeController.text.trim(),
        title: _titleController.text.trim(),
        controlType: _controlType,
        scope: _scope,
        status: SupplyProtectionControlStatus.planned,
        result: SupplyProtectionControlResult.notEvaluated,
        riskLevel: _riskLevel,
        partnerId: _scope == SupplyProtectionControlScope.facility
            ? null
            : _selectedPartnerId,
        facilityId: _scope == SupplyProtectionControlScope.partner
            ? null
            : _selectedFacilityId,
        description: _nullable(_descriptionController.text),
        assignedToName: _nullable(_assignedToNameController.text),
        plannedAt: _plannedAt,
        notes: _nullable(_notesController.text),
        createdAt: now,
        createdBy: widget.user.uid,
      );

      await widget.controlRepository.create(control);

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final dialogWidth = screenWidth < 820 ? screenWidth - 32 : 780.0;

    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      insetPadding: const EdgeInsets.all(16),
      title: const Text(
        'Yeni Koruma Kontrolü',
        style: TextStyle(
          color: MarkaKalkanTheme.navy,
          fontWeight: FontWeight.w900,
        ),
      ),
      content: SizedBox(
        width: dialogWidth,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _controlCodeController,
                  enabled: !_isSaving,
                  decoration: const InputDecoration(
                    labelText: 'Kontrol kodu *',
                    hintText: 'Örn. KNT-2026-001',
                  ),
                  validator: (value) => _requiredText(
                    value,
                    label: 'Kontrol kodu',
                    maxLength: 100,
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _titleController,
                  enabled: !_isSaving,
                  decoration: const InputDecoration(labelText: 'Kontrol adı *'),
                  validator: (value) => _requiredText(
                    value,
                    label: 'Kontrol adı',
                    maxLength: 200,
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<SupplyProtectionControlType>(
                  initialValue: _controlType,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Kontrol türü *',
                  ),
                  items: SupplyProtectionControlType.values
                      .map(
                        (item) => DropdownMenuItem<SupplyProtectionControlType>(
                          value: item,
                          child: Text(item.label),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: _isSaving
                      ? null
                      : (value) {
                          if (value != null) {
                            setState(() {
                              _controlType = value;
                            });
                          }
                        },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<SupplyProtectionControlScope>(
                  initialValue: _scope,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Kontrol kapsamı *',
                  ),
                  items: SupplyProtectionControlScope.values
                      .map(
                        (item) =>
                            DropdownMenuItem<SupplyProtectionControlScope>(
                              value: item,
                              child: Text(item.label),
                            ),
                      )
                      .toList(growable: false),
                  onChanged: _isSaving
                      ? null
                      : (value) {
                          if (value != null) {
                            _changeScope(value);
                          }
                        },
                ),
                const SizedBox(height: 12),
                if (_scope != SupplyProtectionControlScope.facility)
                  DropdownButtonFormField<String>(
                    initialValue: _selectedPartnerId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Partner *'),
                    items: widget.partners
                        .map(
                          (partner) => DropdownMenuItem<String>(
                            value: partner.id,
                            child: Text(
                              '${partner.partnerCode} — '
                              '${partner.legalName}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: _isSaving
                        ? null
                        : (value) {
                            setState(() {
                              _selectedPartnerId = value;

                              if (_scope ==
                                  SupplyProtectionControlScope
                                      .partnerAndFacility) {
                                final selectedFacilityId = _selectedFacilityId;

                                final isValid = _availableFacilities.any(
                                  (item) => item.id == selectedFacilityId,
                                );

                                if (!isValid) {
                                  _selectedFacilityId = null;
                                }
                              }
                            });
                          },
                  ),
                if (_scope != SupplyProtectionControlScope.facility)
                  const SizedBox(height: 12),
                if (_scope != SupplyProtectionControlScope.partner)
                  DropdownButtonFormField<String>(
                    key: ValueKey(
                      'facility-${_selectedPartnerId ?? 'all'}-'
                      '${_selectedFacilityId ?? 'none'}',
                    ),
                    initialValue: _selectedFacilityId,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Tesis *',
                      helperText:
                          _scope ==
                                  SupplyProtectionControlScope
                                      .partnerAndFacility &&
                              _selectedPartnerId == null
                          ? 'Önce partner seçin.'
                          : null,
                    ),
                    items: _availableFacilities
                        .map(
                          (facility) => DropdownMenuItem<String>(
                            value: facility.id,
                            child: Text(
                              '${facility.facilityCode} — '
                              '${facility.name}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(growable: false),
                    onChanged:
                        _isSaving ||
                            (_scope ==
                                    SupplyProtectionControlScope
                                        .partnerAndFacility &&
                                _selectedPartnerId == null)
                        ? null
                        : (value) {
                            setState(() {
                              _selectedFacilityId = value;
                            });
                          },
                  ),
                const SizedBox(height: 12),
                DropdownButtonFormField<SupplyProtectionControlRiskLevel>(
                  initialValue: _riskLevel,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Başlangıç risk seviyesi *',
                  ),
                  items: SupplyProtectionControlRiskLevel.values
                      .map(
                        (item) =>
                            DropdownMenuItem<SupplyProtectionControlRiskLevel>(
                              value: item,
                              child: Text(item.label),
                            ),
                      )
                      .toList(growable: false),
                  onChanged: _isSaving
                      ? null
                      : (value) {
                          if (value != null) {
                            setState(() {
                              _riskLevel = value;
                            });
                          }
                        },
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.event_outlined,
                    color: MarkaKalkanTheme.teal,
                  ),
                  title: const Text('Planlanan kontrol tarihi *'),
                  subtitle: Text(
                    _plannedAt == null
                        ? 'Tarih seçilmedi'
                        : _formatDate(_plannedAt!),
                  ),
                  trailing: OutlinedButton(
                    onPressed: _isSaving ? null : _selectPlannedDate,
                    child: const Text('Tarih Seç'),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _assignedToNameController,
                  enabled: !_isSaving,
                  decoration: const InputDecoration(labelText: 'Sorumlu kişi'),
                  validator: (value) => _optionalText(
                    value,
                    label: 'Sorumlu kişi',
                    maxLength: 200,
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descriptionController,
                  enabled: !_isSaving,
                  minLines: 3,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    labelText: 'Kontrol açıklaması',
                  ),
                  validator: (value) =>
                      _optionalText(value, label: 'Açıklama', maxLength: 5000),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _notesController,
                  enabled: !_isSaving,
                  minLines: 2,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'Planlama notları',
                  ),
                  validator: (value) =>
                      _optionalText(value, label: 'Notlar', maxLength: 5000),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 14),
                  Text(
                    _errorMessage!,
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
              : const Icon(Icons.add_task_outlined),
          label: Text(_isSaving ? 'Kaydediliyor...' : 'Kontrolü Oluştur'),
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

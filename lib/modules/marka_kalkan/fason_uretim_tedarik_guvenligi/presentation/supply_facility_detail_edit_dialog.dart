import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:markakalkan/core/theme/markakalkan_theme.dart';

import '../constants/supply_facility_enums.dart';
import '../models/supply_facility_model.dart';
import '../models/supply_partner_model.dart';
import '../repositories/supply_facility_repository.dart';
import '../repositories/supply_partner_repository.dart';

Future<bool> showSupplyFacilityDetailEditDialog({
  required BuildContext context,
  required User user,
  required SupplyFacilityModel facility,
  required SupplyFacilityRepository facilityRepository,
  required SupplyPartnerRepository partnerRepository,
}) async {
  final partner = await partnerRepository.getById(facility.partnerId);

  if (!context.mounted) {
    return false;
  }

  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return _SupplyFacilityDetailEditDialog(
        user: user,
        facility: facility,
        partner: partner,
        repository: facilityRepository,
      );
    },
  );

  return result == true;
}

class _SupplyFacilityDetailEditDialog extends StatefulWidget {
  const _SupplyFacilityDetailEditDialog({
    required this.user,
    required this.facility,
    required this.partner,
    required this.repository,
  });

  final User user;
  final SupplyFacilityModel facility;
  final SupplyPartnerModel? partner;
  final SupplyFacilityRepository repository;

  @override
  State<_SupplyFacilityDetailEditDialog> createState() {
    return _SupplyFacilityDetailEditDialogState();
  }
}

class _SupplyFacilityDetailEditDialogState
    extends State<_SupplyFacilityDetailEditDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _countryCodeController;
  late final TextEditingController _cityController;
  late final TextEditingController _regionController;
  late final TextEditingController _addressController;
  late final TextEditingController _capacityController;
  late final TextEditingController _capacityUnitController;
  late final TextEditingController _riskReasonController;
  late final TextEditingController _notesController;

  late final Set<SupplyShiftCode> _shiftCodes;

  late SupplyFacilityType _facilityType;
  late SupplyFacilityStatus _status;
  late SupplyFacilityVerificationStatus _verificationStatus;
  late SupplyFacilityRiskLevel _riskLevel;
  late SupplyFacilityAuthorizationStatus _authorizationStatus;

  late bool _isPrimaryFacility;
  late bool _isCriticalFacility;

  late bool _productionAuthorized;
  late bool _storageAuthorized;
  late bool _packagingAuthorized;
  late bool _labelPrintingAuthorized;
  late bool _destructionAuthorized;

  late bool _subcontractingObserved;
  late bool _suspiciousNightShiftObserved;
  late bool _capacityMismatchObserved;
  late bool _unregisteredShipmentObserved;
  late bool _auditRequired;

  bool _isSaving = false;
  bool _isArchiving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    final facility = widget.facility;

    _nameController = TextEditingController(text: facility.name);
    _countryCodeController = TextEditingController(
      text: facility.countryCode ?? '',
    );
    _cityController = TextEditingController(text: facility.city ?? '');
    _regionController = TextEditingController(text: facility.region ?? '');
    _addressController = TextEditingController(text: facility.address ?? '');
    _capacityController = TextEditingController(
      text: facility.monthlyCapacity?.toString() ?? '',
    );
    _capacityUnitController = TextEditingController(
      text: facility.capacityUnit ?? '',
    );
    _riskReasonController = TextEditingController(
      text: facility.riskReason ?? '',
    );
    _notesController = TextEditingController(text: facility.notes ?? '');

    _shiftCodes = facility.shiftCodes.toSet();

    _facilityType = facility.facilityType;
    _status = facility.status;
    _verificationStatus = facility.verificationStatus;
    _riskLevel = facility.riskLevel;
    _authorizationStatus = facility.authorizationStatus;

    _isPrimaryFacility = facility.isPrimaryFacility;
    _isCriticalFacility = facility.isCriticalFacility;

    _productionAuthorized = facility.productionAuthorized;
    _storageAuthorized = facility.storageAuthorized;
    _packagingAuthorized = facility.packagingAuthorized;
    _labelPrintingAuthorized = facility.labelPrintingAuthorized;
    _destructionAuthorized = facility.destructionAuthorized;

    _subcontractingObserved = facility.subcontractingObserved;
    _suspiciousNightShiftObserved = facility.suspiciousNightShiftObserved;
    _capacityMismatchObserved = facility.capacityMismatchObserved;
    _unregisteredShipmentObserved = facility.unregisteredShipmentObserved;
    _auditRequired = facility.auditRequired;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _countryCodeController.dispose();
    _cityController.dispose();
    _regionController.dispose();
    _addressController.dispose();
    _capacityController.dispose();
    _capacityUnitController.dispose();
    _riskReasonController.dispose();
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

  String? _capacityValidator(String? value) {
    final cleaned = value?.trim() ?? '';

    if (cleaned.isEmpty) {
      return null;
    }

    final parsed = int.tryParse(cleaned);

    if (parsed == null) {
      return 'Aylık kapasite tam sayı olmalıdır.';
    }

    if (parsed < 0) {
      return 'Aylık kapasite negatif olamaz.';
    }

    if (_capacityUnitController.text.trim().isEmpty) {
      return 'Kapasite girildiğinde kapasite birimi zorunludur.';
    }

    return null;
  }

  String? _nullable(String value) {
    final cleaned = value.trim();
    return cleaned.isEmpty ? null : cleaned;
  }

  int? _nullableInt(String value) {
    final cleaned = value.trim();
    return cleaned.isEmpty ? null : int.parse(cleaned);
  }

  bool get _hasOperationAuthorization {
    return _productionAuthorized ||
        _storageAuthorized ||
        _packagingAuthorized ||
        _labelPrintingAuthorized ||
        _destructionAuthorized;
  }

  void _changeRiskLevel(SupplyFacilityRiskLevel value) {
    setState(() {
      _riskLevel = value;

      if (value == SupplyFacilityRiskLevel.critical) {
        _isCriticalFacility = true;
        _auditRequired = true;
      }
    });
  }

  void _changeFacilityType(SupplyFacilityType value) {
    setState(() {
      _facilityType = value;

      if (value == SupplyFacilityType.suspectedUnauthorizedSite) {
        _authorizationStatus = SupplyFacilityAuthorizationStatus.unauthorized;

        _productionAuthorized = false;
        _storageAuthorized = false;
        _packagingAuthorized = false;
        _labelPrintingAuthorized = false;
        _destructionAuthorized = false;

        _auditRequired = true;

        if (_riskLevel == SupplyFacilityRiskLevel.low) {
          _riskLevel = SupplyFacilityRiskLevel.high;
        }
      }
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

    if (_authorizationStatus == SupplyFacilityAuthorizationStatus.authorized &&
        !_hasOperationAuthorization) {
      setState(() {
        _errorMessage =
            'Yetkili tesiste en az bir operasyon yetkisi seçilmelidir.';
      });
      return;
    }

    if (_facilityType == SupplyFacilityType.suspectedUnauthorizedSite &&
        _authorizationStatus == SupplyFacilityAuthorizationStatus.authorized) {
      setState(() {
        _errorMessage =
            'Şüpheli yetkisiz üretim noktası Yetkili durumunda olamaz.';
      });
      return;
    }

    if (_riskLevel == SupplyFacilityRiskLevel.critical && !_auditRequired) {
      setState(() {
        _errorMessage = 'Kritik risk seviyesindeki tesiste denetim zorunludur.';
      });
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final source = widget.facility;

      final updated = SupplyFacilityModel(
        id: source.id,
        tenantId: source.tenantId,
        brandId: source.brandId,
        partnerId: source.partnerId,
        facilityCode: source.facilityCode,
        name: _nameController.text.trim(),
        facilityType: _facilityType,
        status: _status,
        verificationStatus: _verificationStatus,
        riskLevel: _riskLevel,
        authorizationStatus: _authorizationStatus,
        parentFacilityId: source.parentFacilityId,
        countryCode: _nullable(_countryCodeController.text)?.toUpperCase(),
        city: _nullable(_cityController.text),
        region: _nullable(_regionController.text),
        address: _nullable(_addressController.text),
        latitude: source.latitude,
        longitude: source.longitude,
        monthlyCapacity: _nullableInt(_capacityController.text),
        capacityUnit: _nullable(_capacityUnitController.text),
        shiftCodes: _shiftCodes.toList(growable: false),
        relatedProductIds: source.relatedProductIds,
        productCategoryCodes: source.productCategoryCodes,
        certificateDocumentIds: source.certificateDocumentIds,
        auditDocumentIds: source.auditDocumentIds,
        isPrimaryFacility: _isPrimaryFacility,
        isCriticalFacility: _isCriticalFacility,
        productionAuthorized: _productionAuthorized,
        storageAuthorized: _storageAuthorized,
        packagingAuthorized: _packagingAuthorized,
        labelPrintingAuthorized: _labelPrintingAuthorized,
        destructionAuthorized: _destructionAuthorized,
        subcontractingObserved: _subcontractingObserved,
        suspiciousNightShiftObserved: _suspiciousNightShiftObserved,
        capacityMismatchObserved: _capacityMismatchObserved,
        unregisteredShipmentObserved: _unregisteredShipmentObserved,
        auditRequired: _auditRequired,
        lastAuditAt: source.lastAuditAt,
        nextAuditAt: source.nextAuditAt,
        lastVerifiedAt: source.lastVerifiedAt,
        riskReason: _nullable(_riskReasonController.text),
        notes: _nullable(_notesController.text),
        archiveReason: source.archiveReason,
        archivedAt: source.archivedAt,
        metadata: source.metadata,
        createdAt: source.createdAt,
        createdBy: source.createdBy,
        updatedAt: source.updatedAt,
        updatedBy: widget.user.uid,
      );

      await widget.repository.update(updated);

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

  Future<void> _archive() async {
    if (_isSaving || _isArchiving) {
      return;
    }

    final reasonController = TextEditingController();
    String? validationMessage;

    final archiveReason = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (confirmationContext) {
        return StatefulBuilder(
          builder: (context, setConfirmationState) {
            return AlertDialog(
              title: const Text('Tesisi Arşivle'),
              content: SizedBox(
                width: 520,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '${widget.facility.facilityCode} — '
                      '${widget.facility.name}',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Bu işlem tesisi silmez. Kayıt, arşiv gerekçesi ve '
                      'zaman damgasıyla korunur; aktif sicilden çıkarılır.',
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: reasonController,
                      autofocus: true,
                      minLines: 3,
                      maxLines: 5,
                      maxLength: 1000,
                      decoration: InputDecoration(
                        labelText: 'Arşiv gerekçesi *',
                        hintText:
                            'Örn. Tesis faaliyeti sona erdi ve sözleşme kapatıldı.',
                        errorText: validationMessage,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(confirmationContext).pop();
                  },
                  child: const Text('Vazgeç'),
                ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFB42318),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    final cleanedReason = reasonController.text.trim();

                    if (cleanedReason.isEmpty) {
                      setConfirmationState(() {
                        validationMessage = 'Arşiv gerekçesi zorunludur.';
                      });
                      return;
                    }

                    Navigator.of(confirmationContext).pop(cleanedReason);
                  },
                  icon: const Icon(Icons.archive_outlined),
                  label: const Text('Arşivlemeyi Onayla'),
                ),
              ],
            );
          },
        );
      },
    );

    reasonController.dispose();

    if (!mounted || archiveReason == null) {
      return;
    }

    if (archiveReason.trim().isEmpty) {
      return;
    }

    setState(() {
      _isArchiving = true;
      _errorMessage = null;
    });

    try {
      await widget.repository.archive(
        facilityId: widget.facility.id,
        archiveReason: archiveReason,
        updatedBy: widget.user.uid,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Tesis kaydı arşivlendi.')));

      Navigator.of(context).pop(false);
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
          _isArchiving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final dialogWidth = screenWidth < 820 ? screenWidth - 32 : 780.0;

    final partnerLabel = widget.partner == null
        ? widget.facility.partnerId
        : '${widget.partner!.partnerCode} — ${widget.partner!.legalName}';

    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      insetPadding: const EdgeInsets.all(16),
      titlePadding: const EdgeInsets.fromLTRB(24, 22, 24, 0),
      contentPadding: const EdgeInsets.fromLTRB(24, 18, 24, 10),
      actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tesis Detayı ve Düzenleme',
            style: TextStyle(
              color: MarkaKalkanTheme.navy,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            '${widget.facility.facilityCode} — ${widget.facility.name}',
            style: const TextStyle(
              color: Color(0xFF687580),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: dialogWidth,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Section(
                  title: 'Değişmez kayıt bağlantıları',
                  children: [
                    TextFormField(
                      initialValue: widget.facility.facilityCode,
                      enabled: false,
                      decoration: const InputDecoration(
                        labelText: 'Tesis kodu',
                        helperText:
                            'Tesis kodu kayıt oluşturulduktan sonra değiştirilemez.',
                      ),
                    ),
                    TextFormField(
                      initialValue: partnerLabel,
                      enabled: false,
                      decoration: const InputDecoration(
                        labelText: 'Bağlı partner',
                        helperText:
                            'Tesisin bağlı olduğu partner değiştirilemez.',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _Section(
                  title: 'Tesis kimliği',
                  children: [
                    TextFormField(
                      controller: _nameController,
                      enabled: !_isSaving,
                      decoration: const InputDecoration(
                        labelText: 'Tesis adı *',
                      ),
                      validator: (value) => _requiredText(
                        value,
                        label: 'Tesis adı',
                        maxLength: 300,
                      ),
                    ),
                    DropdownButtonFormField<SupplyFacilityType>(
                      initialValue: _facilityType,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Tesis türü',
                      ),
                      items: SupplyFacilityType.values
                          .map(
                            (item) => DropdownMenuItem<SupplyFacilityType>(
                              value: item,
                              child: Text(item.label),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: _isSaving
                          ? null
                          : (value) {
                              if (value != null) {
                                _changeFacilityType(value);
                              }
                            },
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _Section(
                  title: 'Durum ve değerlendirme',
                  children: [
                    DropdownButtonFormField<SupplyFacilityStatus>(
                      initialValue: _status,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Tesis durumu',
                      ),
                      items: SupplyFacilityStatus.values
                          .where(
                            (item) => item != SupplyFacilityStatus.archived,
                          )
                          .map(
                            (item) => DropdownMenuItem<SupplyFacilityStatus>(
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
                                  _status = value;
                                });
                              }
                            },
                    ),
                    DropdownButtonFormField<SupplyFacilityVerificationStatus>(
                      initialValue: _verificationStatus,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Doğrulama durumu',
                      ),
                      items: SupplyFacilityVerificationStatus.values
                          .map(
                            (item) =>
                                DropdownMenuItem<
                                  SupplyFacilityVerificationStatus
                                >(value: item, child: Text(item.label)),
                          )
                          .toList(growable: false),
                      onChanged: _isSaving
                          ? null
                          : (value) {
                              if (value != null) {
                                setState(() {
                                  _verificationStatus = value;
                                });
                              }
                            },
                    ),
                    DropdownButtonFormField<SupplyFacilityRiskLevel>(
                      initialValue: _riskLevel,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Risk seviyesi',
                      ),
                      items: SupplyFacilityRiskLevel.values
                          .map(
                            (item) => DropdownMenuItem<SupplyFacilityRiskLevel>(
                              value: item,
                              child: Text(item.label),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: _isSaving
                          ? null
                          : (value) {
                              if (value != null) {
                                _changeRiskLevel(value);
                              }
                            },
                    ),
                    DropdownButtonFormField<SupplyFacilityAuthorizationStatus>(
                      initialValue: _authorizationStatus,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Yetkilendirme durumu',
                      ),
                      items: SupplyFacilityAuthorizationStatus.values
                          .map(
                            (item) =>
                                DropdownMenuItem<
                                  SupplyFacilityAuthorizationStatus
                                >(value: item, child: Text(item.label)),
                          )
                          .toList(growable: false),
                      onChanged:
                          _isSaving ||
                              _facilityType ==
                                  SupplyFacilityType.suspectedUnauthorizedSite
                          ? null
                          : (value) {
                              if (value != null) {
                                setState(() {
                                  _authorizationStatus = value;
                                });
                              }
                            },
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _Section(
                  title: 'Konum',
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _countryCodeController,
                            enabled: !_isSaving,
                            textCapitalization: TextCapitalization.characters,
                            decoration: const InputDecoration(
                              labelText: 'Ülke kodu',
                            ),
                            validator: (value) => _optionalText(
                              value,
                              label: 'Ülke kodu',
                              maxLength: 8,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: _cityController,
                            enabled: !_isSaving,
                            decoration: const InputDecoration(
                              labelText: 'Şehir',
                            ),
                            validator: (value) => _optionalText(
                              value,
                              label: 'Şehir',
                              maxLength: 160,
                            ),
                          ),
                        ),
                      ],
                    ),
                    TextFormField(
                      controller: _regionController,
                      enabled: !_isSaving,
                      decoration: const InputDecoration(
                        labelText: 'İlçe / bölge',
                      ),
                      validator: (value) => _optionalText(
                        value,
                        label: 'İlçe / bölge',
                        maxLength: 200,
                      ),
                    ),
                    TextFormField(
                      controller: _addressController,
                      enabled: !_isSaving,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(labelText: 'Adres'),
                      validator: (value) =>
                          _optionalText(value, label: 'Adres', maxLength: 1000),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _Section(
                  title: 'Kapasite ve vardiyalar',
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _capacityController,
                            enabled: !_isSaving,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Aylık kapasite',
                            ),
                            validator: _capacityValidator,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _capacityUnitController,
                            enabled: !_isSaving,
                            decoration: const InputDecoration(
                              labelText: 'Kapasite birimi',
                            ),
                            validator: (value) => _optionalText(
                              value,
                              label: 'Kapasite birimi',
                              maxLength: 80,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: SupplyShiftCode.values
                          .map(
                            (shift) => FilterChip(
                              label: Text(shift.label),
                              selected: _shiftCodes.contains(shift),
                              onSelected: _isSaving
                                  ? null
                                  : (selected) {
                                      setState(() {
                                        if (selected) {
                                          _shiftCodes.add(shift);
                                        } else {
                                          _shiftCodes.remove(shift);
                                        }
                                      });
                                    },
                            ),
                          )
                          .toList(growable: false),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _Section(
                  title: 'Operasyon yetkileri',
                  children: [
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: _isPrimaryFacility,
                      onChanged: _isSaving
                          ? null
                          : (value) {
                              setState(() {
                                _isPrimaryFacility = value;
                              });
                            },
                      title: const Text('Ana tesis'),
                    ),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: _isCriticalFacility,
                      onChanged: _isSaving
                          ? null
                          : (value) {
                              setState(() {
                                _isCriticalFacility = value;
                              });
                            },
                      title: const Text('Kritik tesis'),
                    ),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: _productionAuthorized,
                      onChanged: _isSaving
                          ? null
                          : (value) {
                              setState(() {
                                _productionAuthorized = value;
                              });
                            },
                      title: const Text('Üretim yetkisi'),
                    ),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: _storageAuthorized,
                      onChanged: _isSaving
                          ? null
                          : (value) {
                              setState(() {
                                _storageAuthorized = value;
                              });
                            },
                      title: const Text('Depolama yetkisi'),
                    ),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: _packagingAuthorized,
                      onChanged: _isSaving
                          ? null
                          : (value) {
                              setState(() {
                                _packagingAuthorized = value;
                              });
                            },
                      title: const Text('Paketleme yetkisi'),
                    ),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: _labelPrintingAuthorized,
                      onChanged: _isSaving
                          ? null
                          : (value) {
                              setState(() {
                                _labelPrintingAuthorized = value;
                              });
                            },
                      title: const Text('Etiket / baskı yetkisi'),
                    ),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: _destructionAuthorized,
                      onChanged: _isSaving
                          ? null
                          : (value) {
                              setState(() {
                                _destructionAuthorized = value;
                              });
                            },
                      title: const Text('İmha yetkisi'),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _Section(
                  title: 'Risk işaretleri ve denetim',
                  children: [
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: _subcontractingObserved,
                      onChanged: _isSaving
                          ? null
                          : (value) {
                              setState(() {
                                _subcontractingObserved = value;
                              });
                            },
                      title: const Text('Alt yüklenici faaliyeti gözlendi'),
                    ),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: _suspiciousNightShiftObserved,
                      onChanged: _isSaving
                          ? null
                          : (value) {
                              setState(() {
                                _suspiciousNightShiftObserved = value;
                              });
                            },
                      title: const Text('Şüpheli gece vardiyası gözlendi'),
                    ),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: _capacityMismatchObserved,
                      onChanged: _isSaving
                          ? null
                          : (value) {
                              setState(() {
                                _capacityMismatchObserved = value;
                              });
                            },
                      title: const Text('Kapasite uyumsuzluğu gözlendi'),
                    ),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: _unregisteredShipmentObserved,
                      onChanged: _isSaving
                          ? null
                          : (value) {
                              setState(() {
                                _unregisteredShipmentObserved = value;
                              });
                            },
                      title: const Text('Kayıt dışı sevkiyat gözlendi'),
                    ),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: _auditRequired,
                      onChanged:
                          _isSaving ||
                              _riskLevel == SupplyFacilityRiskLevel.critical
                          ? null
                          : (value) {
                              setState(() {
                                _auditRequired = value;
                              });
                            },
                      title: const Text('Denetim gerekli'),
                    ),
                    TextFormField(
                      controller: _riskReasonController,
                      enabled: !_isSaving,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Risk nedeni',
                      ),
                      validator: (value) => _optionalText(
                        value,
                        label: 'Risk nedeni',
                        maxLength: 2000,
                      ),
                    ),
                    TextFormField(
                      controller: _notesController,
                      enabled: !_isSaving,
                      minLines: 3,
                      maxLines: 6,
                      decoration: const InputDecoration(
                        labelText: 'Değerlendirme notu',
                      ),
                      validator: (value) => _optionalText(
                        value,
                        label: 'Notlar',
                        maxLength: 5000,
                      ),
                    ),
                  ],
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF1F0),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFECACA)),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                        color: Color(0xFFB42318),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton.icon(
          style: TextButton.styleFrom(foregroundColor: const Color(0xFFB42318)),
          onPressed: _isSaving || _isArchiving ? null : _archive,
          icon: _isArchiving
              ? const SizedBox(
                  width: 17,
                  height: 17,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.archive_outlined),
          label: Text(_isArchiving ? 'Arşivleniyor...' : 'Tesisi Arşivle'),
        ),
        TextButton(
          onPressed: _isSaving || _isArchiving
              ? null
              : () => Navigator.of(context).pop(false),
          child: const Text('Kapat'),
        ),
        FilledButton.icon(
          onPressed: _isSaving || _isArchiving ? null : _save,
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

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0E7EC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: MarkaKalkanTheme.navy,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          ...children.expand(
            (child) => <Widget>[child, const SizedBox(height: 12)],
          ),
        ],
      ),
    );
  }
}

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:markakalkan/core/theme/markakalkan_theme.dart';

import '../constants/supply_facility_enums.dart';
import '../models/supply_facility_model.dart';
import '../models/supply_partner_model.dart';
import '../repositories/supply_facility_repository.dart';
import '../repositories/supply_partner_repository.dart';

Future<bool> showSupplyFacilityCreateDialog({
  required BuildContext context,
  required User user,
  required SupplyFacilityRepository facilityRepository,
  required SupplyPartnerRepository partnerRepository,
}) async {
  final partners = await partnerRepository.listAll(limit: 500);

  if (!context.mounted) {
    return false;
  }

  if (partners.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Tesis oluşturmak için önce en az bir partner kaydı oluşturun.',
        ),
      ),
    );
    return false;
  }

  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return _SupplyFacilityCreateDialog(
        user: user,
        repository: facilityRepository,
        partners: partners,
      );
    },
  );

  return result == true;
}

class _SupplyFacilityCreateDialog extends StatefulWidget {
  const _SupplyFacilityCreateDialog({
    required this.user,
    required this.repository,
    required this.partners,
  });

  final User user;
  final SupplyFacilityRepository repository;
  final List<SupplyPartnerModel> partners;

  @override
  State<_SupplyFacilityCreateDialog> createState() {
    return _SupplyFacilityCreateDialogState();
  }
}

class _SupplyFacilityCreateDialogState
    extends State<_SupplyFacilityCreateDialog> {
  final _formKey = GlobalKey<FormState>();

  final _facilityCodeController = TextEditingController();
  final _nameController = TextEditingController();
  final _countryCodeController = TextEditingController(text: 'TR');
  final _cityController = TextEditingController();
  final _regionController = TextEditingController();
  final _addressController = TextEditingController();
  final _capacityController = TextEditingController();
  final _capacityUnitController = TextEditingController();
  final _notesController = TextEditingController();

  final Set<SupplyShiftCode> _shiftCodes = <SupplyShiftCode>{};

  String? _selectedPartnerId;
  SupplyFacilityType _facilityType =
      SupplyFacilityType.contractManufacturingPlant;

  SupplyFacilityAuthorizationStatus _authorizationStatus =
      SupplyFacilityAuthorizationStatus.pending;

  bool _isPrimaryFacility = false;
  bool _productionAuthorized = false;
  bool _storageAuthorized = false;
  bool _packagingAuthorized = false;
  bool _labelPrintingAuthorized = false;
  bool _destructionAuthorized = false;
  bool _auditRequired = false;
  bool _isSaving = false;

  String? _errorMessage;

  @override
  void dispose() {
    _facilityCodeController.dispose();
    _nameController.dispose();
    _countryCodeController.dispose();
    _cityController.dispose();
    _regionController.dispose();
    _addressController.dispose();
    _capacityController.dispose();
    _capacityUnitController.dispose();
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

  void _changeFacilityType(SupplyFacilityType type) {
    setState(() {
      _facilityType = type;

      if (type == SupplyFacilityType.suspectedUnauthorizedSite) {
        _authorizationStatus = SupplyFacilityAuthorizationStatus.unauthorized;

        _productionAuthorized = false;
        _storageAuthorized = false;
        _packagingAuthorized = false;
        _labelPrintingAuthorized = false;
        _destructionAuthorized = false;
        _auditRequired = true;
      } else if (_authorizationStatus ==
          SupplyFacilityAuthorizationStatus.unauthorized) {
        _authorizationStatus = SupplyFacilityAuthorizationStatus.pending;
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

    if (_selectedPartnerId == null || _selectedPartnerId!.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Tesisin bağlı olduğu partneri seçin.';
      });
      return;
    }

    if (_authorizationStatus == SupplyFacilityAuthorizationStatus.authorized &&
        !_hasOperationAuthorization) {
      setState(() {
        _errorMessage =
            'Yetkili tesis için en az bir operasyon yetkisi seçilmelidir.';
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

    setState(() {
      _isSaving = true;
    });

    try {
      final facility = SupplyFacilityModel(
        id: '',
        tenantId: widget.user.uid,
        brandId: widget.user.uid,
        partnerId: _selectedPartnerId!,
        facilityCode: _facilityCodeController.text.trim(),
        name: _nameController.text.trim(),
        facilityType: _facilityType,
        status: SupplyFacilityStatus.draft,
        verificationStatus: SupplyFacilityVerificationStatus.unverified,
        riskLevel: _facilityType == SupplyFacilityType.suspectedUnauthorizedSite
            ? SupplyFacilityRiskLevel.high
            : SupplyFacilityRiskLevel.low,
        authorizationStatus: _authorizationStatus,
        countryCode: _nullable(_countryCodeController.text)?.toUpperCase(),
        city: _nullable(_cityController.text),
        region: _nullable(_regionController.text),
        address: _nullable(_addressController.text),
        monthlyCapacity: _nullableInt(_capacityController.text),
        capacityUnit: _nullable(_capacityUnitController.text),
        shiftCodes: _shiftCodes.toList(growable: false),
        isPrimaryFacility: _isPrimaryFacility,
        productionAuthorized: _productionAuthorized,
        storageAuthorized: _storageAuthorized,
        packagingAuthorized: _packagingAuthorized,
        labelPrintingAuthorized: _labelPrintingAuthorized,
        destructionAuthorized: _destructionAuthorized,
        auditRequired: _auditRequired,
        notes: _nullable(_notesController.text),
        createdAt: DateTime.now(),
        createdBy: widget.user.uid,
      );

      await widget.repository.create(facility);

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
    final dialogWidth = screenWidth < 780 ? screenWidth - 32 : 740.0;

    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      insetPadding: const EdgeInsets.all(16),
      titlePadding: const EdgeInsets.fromLTRB(24, 22, 24, 0),
      contentPadding: const EdgeInsets.fromLTRB(24, 18, 24, 10),
      actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
      title: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Yeni Tesis Kaydı',
            style: TextStyle(
              color: MarkaKalkanTheme.navy,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 5),
          Text(
            'Tesisi kayıtlı partnerlerden birine bağlayarak sicile ekleyin.',
            style: TextStyle(
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
                _FormSection(
                  title: 'Tesis bağlantısı ve kimliği',
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: _selectedPartnerId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Bağlı partner *',
                      ),
                      items: widget.partners
                          .map((partner) {
                            return DropdownMenuItem<String>(
                              value: partner.id,
                              child: Text(
                                '${partner.partnerCode} — ${partner.legalName}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          })
                          .toList(growable: false),
                      onChanged: _isSaving
                          ? null
                          : (value) {
                              setState(() {
                                _selectedPartnerId = value;
                              });
                            },
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Bağlı partner zorunludur.';
                        }

                        return null;
                      },
                    ),
                    TextFormField(
                      controller: _facilityCodeController,
                      enabled: !_isSaving,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        labelText: 'Tesis kodu *',
                        hintText: 'Örn. TES-IST-001',
                      ),
                      validator: (value) => _requiredText(
                        value,
                        label: 'Tesis kodu',
                        maxLength: 100,
                      ),
                    ),
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
                        labelText: 'Tesis türü *',
                      ),
                      items: SupplyFacilityType.values
                          .map((type) {
                            return DropdownMenuItem<SupplyFacilityType>(
                              value: type,
                              child: Text(type.label),
                            );
                          })
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
                _FormSection(
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
                        labelText: 'İlçe / Bölge',
                      ),
                      validator: (value) => _optionalText(
                        value,
                        label: 'İlçe / Bölge',
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
                _FormSection(
                  title: 'Kapasite ve vardiya',
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
                              hintText: 'adet / kg / ton',
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
                          .map((shift) {
                            return FilterChip(
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
                            );
                          })
                          .toList(growable: false),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _FormSection(
                  title: 'Yetkilendirme ve operasyon',
                  children: [
                    DropdownButtonFormField<SupplyFacilityAuthorizationStatus>(
                      initialValue: _authorizationStatus,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Yetkilendirme durumu',
                      ),
                      items: SupplyFacilityAuthorizationStatus.values
                          .map((status) {
                            return DropdownMenuItem<
                              SupplyFacilityAuthorizationStatus
                            >(value: status, child: Text(status.label));
                          })
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
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: _auditRequired,
                      onChanged: _isSaving
                          ? null
                          : (value) {
                              setState(() {
                                _auditRequired = value;
                              });
                            },
                      title: const Text('Denetim gerekli'),
                    ),
                    TextFormField(
                      controller: _notesController,
                      enabled: !_isSaving,
                      minLines: 3,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        labelText: 'İlk değerlendirme notu',
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
              : const Icon(Icons.save_outlined),
          label: Text(_isSaving ? 'Kaydediliyor...' : 'Taslak Kaydet'),
        ),
      ],
    );
  }
}

class _FormSection extends StatelessWidget {
  const _FormSection({required this.title, required this.children});

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

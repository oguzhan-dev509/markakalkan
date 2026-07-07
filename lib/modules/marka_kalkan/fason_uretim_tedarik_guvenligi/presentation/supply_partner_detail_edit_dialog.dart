import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:markakalkan/core/theme/markakalkan_theme.dart';

import '../constants/supply_security_enums.dart';
import '../models/supply_partner_model.dart';
import '../repositories/supply_partner_repository.dart';

Future<bool> showSupplyPartnerDetailEditDialog({
  required BuildContext context,
  required User user,
  required SupplyPartnerModel partner,
  required SupplyPartnerRepository repository,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return _SupplyPartnerDetailEditDialog(
        user: user,
        partner: partner,
        repository: repository,
      );
    },
  );

  return result == true;
}

class _SupplyPartnerDetailEditDialog extends StatefulWidget {
  const _SupplyPartnerDetailEditDialog({
    required this.user,
    required this.partner,
    required this.repository,
  });

  final User user;
  final SupplyPartnerModel partner;
  final SupplyPartnerRepository repository;

  @override
  State<_SupplyPartnerDetailEditDialog> createState() {
    return _SupplyPartnerDetailEditDialogState();
  }
}

class _SupplyPartnerDetailEditDialogState
    extends State<_SupplyPartnerDetailEditDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _legalNameController;
  late final TextEditingController _tradeNameController;
  late final TextEditingController _cityController;
  late final TextEditingController _contactNameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _trustScoreController;
  late final TextEditingController _notesController;

  late final Set<SupplyPartnerRole> _roles;
  late SupplyPartnerStatus _status;
  late SupplyPartnerVerificationStatus _verificationStatus;
  late SupplyPartnerRiskLevel _riskLevel;

  late bool _isCriticalPartner;
  late bool _contractManufacturingAuthorized;
  late bool _subcontractingAllowed;
  late bool _hasNda;
  late bool _auditRequired;

  bool _isSaving = false;
  bool _isArchiving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    final partner = widget.partner;

    _legalNameController = TextEditingController(text: partner.legalName);
    _tradeNameController = TextEditingController(text: partner.tradeName ?? '');
    _cityController = TextEditingController(text: partner.city ?? '');
    _contactNameController = TextEditingController(
      text: partner.contactPersonName ?? '',
    );
    _emailController = TextEditingController(text: partner.email ?? '');
    _phoneController = TextEditingController(text: partner.phone ?? '');
    _trustScoreController = TextEditingController(
      text: partner.trustScore.toString(),
    );
    _notesController = TextEditingController(text: partner.notes ?? '');

    _roles = partner.roles.toSet();
    _status = partner.status;
    _verificationStatus = partner.verificationStatus;
    _riskLevel = partner.riskLevel;

    _isCriticalPartner = partner.isCriticalPartner;
    _contractManufacturingAuthorized = partner.contractManufacturingAuthorized;
    _subcontractingAllowed = partner.subcontractingAllowed;
    _hasNda = partner.hasNda;
    _auditRequired = partner.auditRequired;
  }

  @override
  void dispose() {
    _legalNameController.dispose();
    _tradeNameController.dispose();
    _cityController.dispose();
    _contactNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _trustScoreController.dispose();
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

  String? _optionalEmail(String? value) {
    final cleaned = value?.trim() ?? '';

    if (cleaned.isEmpty) {
      return null;
    }

    final expression = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

    if (!expression.hasMatch(cleaned)) {
      return 'Geçerli bir e-posta adresi girin.';
    }

    return null;
  }

  String? _trustScoreValidator(String? value) {
    final score = int.tryParse(value?.trim() ?? '');

    if (score == null) {
      return 'Güven skoru tam sayı olmalıdır.';
    }

    if (score < 0 || score > 100) {
      return 'Güven skoru 0 ile 100 arasında olmalıdır.';
    }

    return null;
  }

  String? _nullable(String value) {
    final cleaned = value.trim();
    return cleaned.isEmpty ? null : cleaned;
  }

  bool get _hasManufacturingRole {
    return _roles.contains(SupplyPartnerRole.manufacturer) ||
        _roles.contains(SupplyPartnerRole.contractManufacturer);
  }

  bool get _hasOperationalRole {
    return _hasManufacturingRole ||
        _roles.contains(SupplyPartnerRole.subcontractor);
  }

  void _toggleRole(SupplyPartnerRole role, bool selected) {
    setState(() {
      if (selected) {
        _roles.add(role);
      } else {
        _roles.remove(role);

        if (!_hasManufacturingRole) {
          _contractManufacturingAuthorized = false;
        }

        if (!_hasOperationalRole) {
          _subcontractingAllowed = false;
        }
      }
    });
  }

  void _changeRiskLevel(SupplyPartnerRiskLevel value) {
    setState(() {
      _riskLevel = value;

      if (value == SupplyPartnerRiskLevel.critical) {
        _isCriticalPartner = true;
        _auditRequired = true;
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

    if (_status == SupplyPartnerStatus.active && _roles.isEmpty) {
      setState(() {
        _errorMessage = 'Aktif partnerde en az bir rol zorunludur.';
      });
      return;
    }

    if (_contractManufacturingAuthorized && !_hasManufacturingRole) {
      setState(() {
        _errorMessage =
            'Fason üretim yetkisi için üretici veya fason üretici '
            'rolü seçilmelidir.';
      });
      return;
    }

    if (_subcontractingAllowed && !_hasOperationalRole) {
      setState(() {
        _errorMessage =
            'Alt yüklenici izni için üretici, fason üretici veya '
            'alt yüklenici rolü seçilmelidir.';
      });
      return;
    }

    if (_riskLevel == SupplyPartnerRiskLevel.critical && !_auditRequired) {
      setState(() {
        _errorMessage = 'Kritik risk seviyesinde denetim zorunlu olmalıdır.';
      });
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final source = widget.partner;

      final updated = SupplyPartnerModel(
        id: source.id,
        tenantId: source.tenantId,
        brandId: source.brandId,
        partnerCode: source.partnerCode,
        legalName: _legalNameController.text.trim(),
        tradeName: _nullable(_tradeNameController.text),
        taxNumber: source.taxNumber,
        registrationNumber: source.registrationNumber,
        roles: _roles.toList(growable: false),
        status: _status,
        verificationStatus: _verificationStatus,
        riskLevel: _riskLevel,
        trustScore: int.parse(_trustScoreController.text.trim()),
        countryCode: source.countryCode,
        city: _nullable(_cityController.text),
        region: source.region,
        address: source.address,
        website: source.website,
        contactPersonName: _nullable(_contactNameController.text),
        email: _nullable(_emailController.text)?.toLowerCase(),
        phone: _nullable(_phoneController.text),
        isCriticalPartner: _isCriticalPartner,
        contractManufacturingAuthorized: _contractManufacturingAuthorized,
        subcontractingAllowed: _subcontractingAllowed,
        hasNda: _hasNda,
        auditRequired: _auditRequired,
        lastAuditAt: source.lastAuditAt,
        nextAuditAt: source.nextAuditAt,
        certificateDocumentIds: source.certificateDocumentIds,
        relatedFacilityIds: source.relatedFacilityIds,
        relatedProductIds: source.relatedProductIds,
        productCategoryCodes: source.productCategoryCodes,
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
              title: const Text('Partneri Arşivle'),
              content: SizedBox(
                width: 520,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '${widget.partner.partnerCode} — '
                      '${widget.partner.legalName}',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Bu işlem partneri silmez. Kayıt, arşiv gerekçesi ve '
                      'zaman damgasıyla korunur; aktif sicilden çıkarılır.',
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Bağlı aktif tesis bulunuyorsa arşivleme güvenlik '
                      'nedeniyle engellenir.',
                      style: TextStyle(
                        color: Color(0xFFB42318),
                        fontWeight: FontWeight.w700,
                      ),
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
                            'Örn. Partner ilişkisi ve sözleşmesi sona erdi.',
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
        partnerId: widget.partner.id,
        archiveReason: archiveReason,
        updatedBy: widget.user.uid,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Partner kaydı arşivlendi.')),
      );

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
    final dialogWidth = screenWidth < 800 ? screenWidth - 32 : 760.0;

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
            'Partner Detayı ve Düzenleme',
            style: TextStyle(
              color: MarkaKalkanTheme.navy,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            '${widget.partner.partnerCode} — ${widget.partner.legalName}',
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
                  title: 'Değişmez kayıt kimliği',
                  children: [
                    TextFormField(
                      initialValue: widget.partner.partnerCode,
                      enabled: false,
                      decoration: const InputDecoration(
                        labelText: 'Partner kodu',
                        helperText:
                            'Partner kodu kayıt oluşturulduktan sonra değiştirilemez.',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _Section(
                  title: 'Kurumsal kimlik',
                  children: [
                    TextFormField(
                      controller: _legalNameController,
                      enabled: !_isSaving,
                      decoration: const InputDecoration(
                        labelText: 'Yasal unvan *',
                      ),
                      validator: (value) => _requiredText(
                        value,
                        label: 'Yasal unvan',
                        maxLength: 300,
                      ),
                    ),
                    TextFormField(
                      controller: _tradeNameController,
                      enabled: !_isSaving,
                      decoration: const InputDecoration(labelText: 'Ticari ad'),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _Section(
                  title: 'Roller',
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: SupplyPartnerRole.values
                          .map(
                            (role) => FilterChip(
                              label: Text(role.label),
                              selected: _roles.contains(role),
                              onSelected: _isSaving
                                  ? null
                                  : (selected) => _toggleRole(role, selected),
                            ),
                          )
                          .toList(growable: false),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _Section(
                  title: 'Durum ve değerlendirme',
                  children: [
                    DropdownButtonFormField<SupplyPartnerStatus>(
                      initialValue: _status,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Partner durumu',
                      ),
                      items: SupplyPartnerStatus.values
                          .where((item) => item != SupplyPartnerStatus.archived)
                          .map(
                            (item) => DropdownMenuItem<SupplyPartnerStatus>(
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
                    DropdownButtonFormField<SupplyPartnerVerificationStatus>(
                      initialValue: _verificationStatus,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Doğrulama durumu',
                      ),
                      items: SupplyPartnerVerificationStatus.values
                          .map(
                            (item) =>
                                DropdownMenuItem<
                                  SupplyPartnerVerificationStatus
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
                    DropdownButtonFormField<SupplyPartnerRiskLevel>(
                      initialValue: _riskLevel,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Risk seviyesi',
                      ),
                      items: SupplyPartnerRiskLevel.values
                          .map(
                            (item) => DropdownMenuItem<SupplyPartnerRiskLevel>(
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
                    TextFormField(
                      controller: _trustScoreController,
                      enabled: !_isSaving,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Güven skoru',
                        helperText: '0 ile 100 arasında tam sayı.',
                      ),
                      validator: _trustScoreValidator,
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _Section(
                  title: 'İletişim',
                  children: [
                    TextFormField(
                      controller: _cityController,
                      enabled: !_isSaving,
                      decoration: const InputDecoration(labelText: 'Şehir'),
                    ),
                    TextFormField(
                      controller: _contactNameController,
                      enabled: !_isSaving,
                      decoration: const InputDecoration(
                        labelText: 'Yetkili kişi',
                      ),
                    ),
                    TextFormField(
                      controller: _emailController,
                      enabled: !_isSaving,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'E-posta'),
                      validator: _optionalEmail,
                    ),
                    TextFormField(
                      controller: _phoneController,
                      enabled: !_isSaving,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(labelText: 'Telefon'),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _Section(
                  title: 'Yetki ve güvenlik',
                  children: [
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: _isCriticalPartner,
                      onChanged: _isSaving
                          ? null
                          : (value) {
                              setState(() {
                                _isCriticalPartner = value;
                              });
                            },
                      title: const Text('Kritik partner'),
                    ),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: _contractManufacturingAuthorized,
                      onChanged: !_isSaving && _hasManufacturingRole
                          ? (value) {
                              setState(() {
                                _contractManufacturingAuthorized = value;
                              });
                            }
                          : null,
                      title: const Text('Fason üretim yetkisi'),
                    ),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: _subcontractingAllowed,
                      onChanged: !_isSaving && _hasOperationalRole
                          ? (value) {
                              setState(() {
                                _subcontractingAllowed = value;
                              });
                            }
                          : null,
                      title: const Text('Alt yüklenici kullanabilir'),
                    ),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: _hasNda,
                      onChanged: _isSaving
                          ? null
                          : (value) {
                              setState(() {
                                _hasNda = value;
                              });
                            },
                      title: const Text('Gizlilik sözleşmesi mevcut'),
                    ),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: _auditRequired,
                      onChanged:
                          _isSaving ||
                              _riskLevel == SupplyPartnerRiskLevel.critical
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
                      maxLines: 6,
                      decoration: const InputDecoration(
                        labelText: 'Değerlendirme notu',
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
          label: Text(_isArchiving ? 'Arşivleniyor...' : 'Partneri Arşivle'),
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

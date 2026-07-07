import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:markakalkan/core/theme/markakalkan_theme.dart';

import '../constants/supply_security_enums.dart';
import '../models/supply_partner_model.dart';
import '../repositories/supply_partner_repository.dart';

Future<bool> showSupplyPartnerCreateDialog({
  required BuildContext context,
  required User user,
  required SupplyPartnerRepository repository,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return _SupplyPartnerCreateDialog(user: user, repository: repository);
    },
  );

  return result == true;
}

class _SupplyPartnerCreateDialog extends StatefulWidget {
  const _SupplyPartnerCreateDialog({
    required this.user,
    required this.repository,
  });

  final User user;
  final SupplyPartnerRepository repository;

  @override
  State<_SupplyPartnerCreateDialog> createState() {
    return _SupplyPartnerCreateDialogState();
  }
}

class _SupplyPartnerCreateDialogState
    extends State<_SupplyPartnerCreateDialog> {
  final _formKey = GlobalKey<FormState>();

  final _partnerCodeController = TextEditingController();
  final _legalNameController = TextEditingController();
  final _tradeNameController = TextEditingController();
  final _taxNumberController = TextEditingController();
  final _countryCodeController = TextEditingController(text: 'TR');
  final _cityController = TextEditingController();
  final _contactNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _notesController = TextEditingController();

  final Set<SupplyPartnerRole> _roles = <SupplyPartnerRole>{};

  bool _contractManufacturingAuthorized = false;
  bool _subcontractingAllowed = false;
  bool _hasNda = false;
  bool _auditRequired = false;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void dispose() {
    _partnerCodeController.dispose();
    _legalNameController.dispose();
    _tradeNameController.dispose();
    _taxNumberController.dispose();
    _countryCodeController.dispose();
    _cityController.dispose();
    _contactNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
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

  String? _optionalEmail(String? value) {
    final cleaned = value?.trim() ?? '';

    if (cleaned.isEmpty) {
      return null;
    }

    if (cleaned.length > 200) {
      return 'E-posta en fazla 200 karakter olabilir.';
    }

    final emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

    if (!emailPattern.hasMatch(cleaned)) {
      return 'Geçerli bir e-posta adresi girin.';
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

    if (_roles.isEmpty) {
      setState(() {
        _errorMessage = 'En az bir partner rolü seçin.';
      });
      return;
    }

    if (_contractManufacturingAuthorized && !_hasManufacturingRole) {
      setState(() {
        _errorMessage =
            'Fason üretim yetkisi için Üretici veya Fason Üretici '
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

    setState(() {
      _isSaving = true;
    });

    try {
      final now = DateTime.now();

      final partner = SupplyPartnerModel(
        id: '',
        tenantId: widget.user.uid,
        brandId: widget.user.uid,
        partnerCode: _partnerCodeController.text.trim(),
        legalName: _legalNameController.text.trim(),
        tradeName: _nullable(_tradeNameController.text),
        taxNumber: _nullable(_taxNumberController.text),
        roles: _roles.toList(growable: false),
        status: SupplyPartnerStatus.draft,
        verificationStatus: SupplyPartnerVerificationStatus.unverified,
        riskLevel: SupplyPartnerRiskLevel.low,
        trustScore: 50,
        countryCode: _nullable(_countryCodeController.text)?.toUpperCase(),
        city: _nullable(_cityController.text),
        contactPersonName: _nullable(_contactNameController.text),
        email: _nullable(_emailController.text)?.toLowerCase(),
        phone: _nullable(_phoneController.text),
        contractManufacturingAuthorized: _contractManufacturingAuthorized,
        subcontractingAllowed: _subcontractingAllowed,
        hasNda: _hasNda,
        auditRequired: _auditRequired,
        notes: _nullable(_notesController.text),
        createdAt: now,
        createdBy: widget.user.uid,
      );

      await widget.repository.create(partner);

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
    final dialogWidth = screenWidth < 760 ? screenWidth - 32 : 720.0;

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
            'Yeni Partner Kaydı',
            style: TextStyle(
              color: MarkaKalkanTheme.navy,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 5),
          Text(
            'Fason üretici veya tedarikçiyi taslak olarak sicile ekleyin.',
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
                  title: 'Temel kimlik',
                  children: [
                    TextFormField(
                      controller: _partnerCodeController,
                      enabled: !_isSaving,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        labelText: 'Partner kodu *',
                        hintText: 'Örn. FSN-001',
                      ),
                      validator: (value) => _requiredText(
                        value,
                        label: 'Partner kodu',
                        maxLength: 100,
                      ),
                    ),
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
                      validator: (value) => _optionalText(
                        value,
                        label: 'Ticari ad',
                        maxLength: 300,
                      ),
                    ),
                    TextFormField(
                      controller: _taxNumberController,
                      enabled: !_isSaving,
                      decoration: const InputDecoration(
                        labelText: 'Vergi numarası',
                      ),
                      validator: (value) => _optionalText(
                        value,
                        label: 'Vergi numarası',
                        maxLength: 80,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _FormSection(
                  title: 'Partner rolleri *',
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: SupplyPartnerRole.values
                          .map((role) {
                            return FilterChip(
                              label: Text(role.label),
                              selected: _roles.contains(role),
                              onSelected: _isSaving
                                  ? null
                                  : (selected) => _toggleRole(role, selected),
                            );
                          })
                          .toList(growable: false),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _FormSection(
                  title: 'İletişim ve konum',
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
                      controller: _contactNameController,
                      enabled: !_isSaving,
                      decoration: const InputDecoration(
                        labelText: 'Yetkili kişi',
                      ),
                      validator: (value) => _optionalText(
                        value,
                        label: 'Yetkili kişi',
                        maxLength: 200,
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
                      validator: (value) =>
                          _optionalText(value, label: 'Telefon', maxLength: 80),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _FormSection(
                  title: 'Yetki ve güvenlik',
                  children: [
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
                      subtitle: const Text(
                        'Üretici veya Fason Üretici rolü gerektirir.',
                      ),
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
                      subtitle: const Text(
                        'Üretici, Fason Üretici veya Alt Yüklenici '
                        'rolü gerektirir.',
                      ),
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

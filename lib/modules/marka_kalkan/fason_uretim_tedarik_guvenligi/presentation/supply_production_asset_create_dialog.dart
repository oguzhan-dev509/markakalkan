import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:markakalkan/core/theme/markakalkan_theme.dart';

import '../constants/supply_production_asset_enums.dart';
import '../models/supply_facility_model.dart';
import '../models/supply_partner_model.dart';
import '../models/supply_production_asset_model.dart';
import '../repositories/supply_facility_repository.dart';
import '../repositories/supply_partner_repository.dart';
import '../repositories/supply_production_asset_repository.dart';

Future<bool> showSupplyProductionAssetCreateDialog({
  required BuildContext context,
  required User user,
  required SupplyProductionAssetRepository repository,
  required SupplyPartnerRepository partnerRepository,
  required SupplyFacilityRepository facilityRepository,
}) async {
  final results = await Future.wait<Object>([
    partnerRepository.listAll(limit: 500),
    facilityRepository.listAll(limit: 500),
  ]);
  if (!context.mounted) return false;
  final partners = (results[0] as List<SupplyPartnerModel>)
      .where((item) => !item.isArchived)
      .toList(growable: false);
  final facilities = (results[1] as List<SupplyFacilityModel>)
      .where((item) => !item.isArchived)
      .toList(growable: false);
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _Dialog(
      user: user,
      repository: repository,
      partners: partners,
      facilities: facilities,
    ),
  );
  return result == true;
}

class _Dialog extends StatefulWidget {
  const _Dialog({
    required this.user,
    required this.repository,
    required this.partners,
    required this.facilities,
  });
  final User user;
  final SupplyProductionAssetRepository repository;
  final List<SupplyPartnerModel> partners;
  final List<SupplyFacilityModel> facilities;
  @override
  State<_Dialog> createState() => _DialogState();
}

class _DialogState extends State<_Dialog> {
  final _formKey = GlobalKey<FormState>();
  final _code = TextEditingController();
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _physicalLocation = TextEditingController();
  final _digitalStorage = TextEditingController();
  final _version = TextEditingController();
  final _hash = TextEditingController();
  final _notes = TextEditingController();
  SupplyProductionAssetClass _assetClass = SupplyProductionAssetClass.physical;
  SupplyProductionAssetType _assetType =
      SupplyProductionAssetType.injectionMold;
  String? _partnerId;
  String? _facilityId;
  bool _saving = false;
  String? _error;

  bool get _physical => _assetClass != SupplyProductionAssetClass.digital;
  bool get _digital => _assetClass != SupplyProductionAssetClass.physical;
  List<SupplyFacilityModel> get _facilities => _partnerId == null
      ? widget.facilities
      : widget.facilities
            .where((f) => f.partnerId == _partnerId)
            .toList(growable: false);

  @override
  void dispose() {
    for (final c in [
      _code,
      _name,
      _description,
      _physicalLocation,
      _digitalStorage,
      _version,
      _hash,
      _notes,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _required(String? value, String label, int max) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return '$label zorunludur.';
    if (v.length > max) return '$label en fazla $max karakter olabilir.';
    return null;
  }

  String? _optional(String? value, String label, int max) {
    if ((value?.trim().length ?? 0) > max) {
      return '$label en fazla $max karakter olabilir.';
    }
    return null;
  }

  String? _nullable(String value) => value.trim().isEmpty ? null : value.trim();

  Future<void> _save() async {
    if (_saving || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final now = DateTime.now();
      final asset = SupplyProductionAssetModel(
        id: '',
        tenantId: widget.user.uid,
        brandId: widget.user.uid,
        assetCode: _code.text.trim(),
        name: _name.text.trim(),
        assetClass: _assetClass,
        assetType: _assetType,
        status: SupplyProductionAssetStatus.draft,
        partnerId: _partnerId,
        facilityId: _facilityId,
        description: _nullable(_description.text),
        physicalLocation: _physical ? _nullable(_physicalLocation.text) : null,
        digitalStorageReference: _digital
            ? _nullable(_digitalStorage.text)
            : null,
        version: _digital ? _nullable(_version.text) : null,
        fileHash: _digital ? _nullable(_hash.text) : null,
        notes: _nullable(_notes.text),
        createdAt: now,
        createdBy: widget.user.uid,
      );
      await widget.repository.create(asset);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: Colors.white,
    surfaceTintColor: Colors.white,
    title: const Text(
      'Yeni Üretim Varlığı',
      style: TextStyle(
        color: MarkaKalkanTheme.navy,
        fontWeight: FontWeight.w900,
      ),
    ),
    content: SizedBox(
      width: MediaQuery.sizeOf(context).width < 820
          ? MediaQuery.sizeOf(context).width - 32
          : 760,
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _code,
                decoration: const InputDecoration(labelText: 'Varlık kodu *'),
                validator: (v) => _required(v, 'Varlık kodu', 100),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Varlık adı *'),
                validator: (v) => _required(v, 'Varlık adı', 200),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<SupplyProductionAssetClass>(
                initialValue: _assetClass,
                decoration: const InputDecoration(labelText: 'Varlık sınıfı *'),
                items: SupplyProductionAssetClass.values
                    .map(
                      (e) => DropdownMenuItem(value: e, child: Text(e.label)),
                    )
                    .toList(),
                onChanged: _saving
                    ? null
                    : (v) {
                        if (v != null) setState(() => _assetClass = v);
                      },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<SupplyProductionAssetType>(
                initialValue: _assetType,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Varlık türü *'),
                items: SupplyProductionAssetType.values
                    .map(
                      (e) => DropdownMenuItem(value: e, child: Text(e.label)),
                    )
                    .toList(),
                onChanged: _saving
                    ? null
                    : (v) {
                        if (v != null) setState(() => _assetType = v);
                      },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _partnerId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Bağlı partner'),
                items: widget.partners
                    .map(
                      (e) => DropdownMenuItem(
                        value: e.id,
                        child: Text('${e.partnerCode} — ${e.legalName}'),
                      ),
                    )
                    .toList(),
                onChanged: _saving
                    ? null
                    : (v) => setState(() {
                        _partnerId = v;
                        _facilityId = null;
                      }),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: ValueKey(
                  'facility-${_partnerId ?? 'all'}-${_facilityId ?? 'none'}',
                ),
                initialValue: _facilityId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Bağlı tesis'),
                items: _facilities
                    .map(
                      (e) => DropdownMenuItem(
                        value: e.id,
                        child: Text('${e.facilityCode} — ${e.name}'),
                      ),
                    )
                    .toList(),
                onChanged: _saving
                    ? null
                    : (v) => setState(() => _facilityId = v),
              ),
              const SizedBox(height: 12),
              if (_physical)
                TextFormField(
                  controller: _physicalLocation,
                  decoration: const InputDecoration(
                    labelText: 'Fiziksel konum',
                  ),
                  validator: (v) => _optional(v, 'Fiziksel konum', 500),
                ),
              if (_physical) const SizedBox(height: 12),
              if (_digital)
                TextFormField(
                  controller: _digitalStorage,
                  decoration: const InputDecoration(
                    labelText: 'Dijital saklama referansı',
                  ),
                  validator: (v) =>
                      _optional(v, 'Dijital saklama referansı', 1000),
                ),
              if (_digital) const SizedBox(height: 12),
              if (_digital)
                TextFormField(
                  controller: _version,
                  decoration: const InputDecoration(labelText: 'Sürüm'),
                  validator: (v) => _optional(v, 'Sürüm', 100),
                ),
              if (_digital) const SizedBox(height: 12),
              if (_digital)
                TextFormField(
                  controller: _hash,
                  decoration: const InputDecoration(
                    labelText: 'Dosya hash değeri',
                  ),
                  validator: (v) => _optional(v, 'Dosya hash değeri', 500),
                ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _description,
                minLines: 3,
                maxLines: 5,
                decoration: const InputDecoration(labelText: 'Açıklama'),
                validator: (v) => _optional(v, 'Açıklama', 5000),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notes,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'Notlar'),
                validator: (v) => _optional(v, 'Notlar', 5000),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: Color(0xFFB42318))),
              ],
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _saving ? null : () => Navigator.of(context).pop(false),
        child: const Text('Vazgeç'),
      ),
      FilledButton.icon(
        onPressed: _saving ? null : _save,
        icon: const Icon(Icons.save_outlined),
        label: Text(_saving ? 'Kaydediliyor...' : 'Taslak Kaydet'),
      ),
    ],
  );
}

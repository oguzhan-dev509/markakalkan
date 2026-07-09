import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:markakalkan/core/theme/markakalkan_theme.dart';

import '../constants/supply_production_asset_enums.dart';
import '../models/supply_production_asset_model.dart';
import '../repositories/supply_facility_repository.dart';
import '../repositories/supply_partner_repository.dart';
import '../repositories/supply_production_asset_repository.dart';
import 'supply_production_asset_create_dialog.dart';

class SupplyProductionAssetRegistryPage extends StatefulWidget {
  const SupplyProductionAssetRegistryPage({super.key});

  @override
  State<SupplyProductionAssetRegistryPage> createState() =>
      _SupplyProductionAssetRegistryPageState();
}

class _SupplyProductionAssetRegistryPageState
    extends State<SupplyProductionAssetRegistryPage> {
  final _searchController = TextEditingController();
  SupplyProductionAssetClass? _classFilter;
  SupplyProductionAssetType? _typeFilter;
  SupplyProductionAssetStatus? _statusFilter;
  String _searchText = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool get _hasActiveFilter =>
      _classFilter != null ||
      _typeFilter != null ||
      _statusFilter != null ||
      _searchText.isNotEmpty;

  void _clearFilters() {
    _searchController.clear();
    setState(() {
      _classFilter = null;
      _typeFilter = null;
      _statusFilter = null;
      _searchText = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const _SignedOutPage();

    final repository = SupplyProductionAssetRepository(tenantId: user.uid);

    return Scaffold(
      backgroundColor: MarkaKalkanTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text(
          'Üretim Varlıkları Sicili',
          style: TextStyle(
            color: MarkaKalkanTheme.navy,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final created = await showSupplyProductionAssetCreateDialog(
            context: context,
            user: user,
            repository: repository,
            partnerRepository: SupplyPartnerRepository.instance(
              tenantId: user.uid,
            ),
            facilityRepository: SupplyFacilityRepository.instance(
              tenantId: user.uid,
            ),
          );
          if (created && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Üretim varlığı taslak olarak sicile eklendi.'),
              ),
            );
          }
        },
        backgroundColor: MarkaKalkanTheme.teal,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.precision_manufacturing_outlined),
        label: const Text(
          'Yeni Varlık',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: StreamBuilder<List<SupplyProductionAssetModel>>(
        stream: repository.watchAll(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _RegistryMessage(
              icon: Icons.error_outline,
              title: 'Üretim varlıkları yüklenemedi',
              description: snapshot.error.toString(),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final assets = snapshot.data ?? const <SupplyProductionAssetModel>[];
          final visible = assets
              .where((item) => !item.isArchived)
              .where(_matchesFilters)
              .toList(growable: false);

          int classCount(SupplyProductionAssetClass value) => assets
              .where((item) => !item.isArchived && item.assetClass == value)
              .length;

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 104),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1180),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _SummaryStrip(
                      total: assets.where((item) => !item.isArchived).length,
                      physical: classCount(SupplyProductionAssetClass.physical),
                      digital: classCount(SupplyProductionAssetClass.digital),
                      hybrid: classCount(SupplyProductionAssetClass.hybrid),
                      destroyed: assets
                          .where((item) => item.isDestroyed)
                          .length,
                      archived: assets.where((item) => item.isArchived).length,
                    ),
                    const SizedBox(height: 18),
                    _FilterPanel(
                      searchController: _searchController,
                      assetClass: _classFilter,
                      assetType: _typeFilter,
                      status: _statusFilter,
                      hasActiveFilter: _hasActiveFilter,
                      onSearchChanged: (value) => setState(
                        () => _searchText = value.trim().toLowerCase(),
                      ),
                      onClassChanged: (value) =>
                          setState(() => _classFilter = value),
                      onTypeChanged: (value) =>
                          setState(() => _typeFilter = value),
                      onStatusChanged: (value) =>
                          setState(() => _statusFilter = value),
                      onClear: _clearFilters,
                    ),
                    const SizedBox(height: 18),
                    if (assets.isEmpty)
                      const _RegistryMessage(
                        icon: Icons.precision_manufacturing_outlined,
                        title: 'Henüz üretim varlığı yok',
                        description:
                            'Kalıp, aparat, şablon, üretim programı veya '
                            'hassas dijital üretim dosyası eklendiğinde '
                            'kayıtlar burada görüntülenecek.',
                      )
                    else if (visible.isEmpty)
                      const _RegistryMessage(
                        icon: Icons.filter_alt_off_outlined,
                        title: 'Filtrelerle eşleşen varlık yok',
                        description:
                            'Filtreleri temizleyerek tüm kayıtları görün.',
                      )
                    else ...[
                      Text(
                        '${visible.length} varlık gösteriliyor',
                        style: const TextStyle(
                          color: MarkaKalkanTheme.navy,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...visible.map(
                        (asset) => Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: _AssetCard(asset: asset),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  bool _matchesFilters(SupplyProductionAssetModel asset) {
    if (_classFilter != null && asset.assetClass != _classFilter) return false;
    if (_typeFilter != null && asset.assetType != _typeFilter) return false;
    if (_statusFilter != null && asset.status != _statusFilter) return false;
    if (_searchText.isEmpty) return true;

    final text = <String>[
      asset.assetCode,
      asset.name,
      asset.assetType.label,
      asset.internalReference ?? '',
      asset.serialNumber ?? '',
      asset.physicalLocation ?? '',
      asset.digitalStorageReference ?? '',
    ].join(' ').toLowerCase();
    return text.contains(_searchText);
  }
}

class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({
    required this.total,
    required this.physical,
    required this.digital,
    required this.hybrid,
    required this.destroyed,
    required this.archived,
  });
  final int total, physical, digital, hybrid, destroyed, archived;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 12,
    runSpacing: 12,
    children: [
      _MetricCard(label: 'Sicildeki varlık', value: '$total'),
      _MetricCard(label: 'Fiziksel', value: '$physical'),
      _MetricCard(label: 'Dijital', value: '$digital'),
      _MetricCard(label: 'Hibrit', value: '$hybrid'),
      _MetricCard(label: 'İmha edilen', value: '$destroyed'),
      _MetricCard(label: 'Arşivlenen', value: '$archived'),
    ],
  );
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value});
  final String label, value;
  @override
  Widget build(BuildContext context) => Container(
    width: 174,
    padding: const EdgeInsets.all(17),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFE0E7EC)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            color: MarkaKalkanTheme.navy,
            fontSize: 25,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF687580),
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

class _FilterPanel extends StatelessWidget {
  const _FilterPanel({
    required this.searchController,
    required this.assetClass,
    required this.assetType,
    required this.status,
    required this.hasActiveFilter,
    required this.onSearchChanged,
    required this.onClassChanged,
    required this.onTypeChanged,
    required this.onStatusChanged,
    required this.onClear,
  });
  final TextEditingController searchController;
  final SupplyProductionAssetClass? assetClass;
  final SupplyProductionAssetType? assetType;
  final SupplyProductionAssetStatus? status;
  final bool hasActiveFilter;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<SupplyProductionAssetClass?> onClassChanged;
  final ValueChanged<SupplyProductionAssetType?> onTypeChanged;
  final ValueChanged<SupplyProductionAssetStatus?> onStatusChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFE0E7EC)),
    ),
    child: Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.end,
      children: [
        SizedBox(
          width: 270,
          child: TextField(
            controller: searchController,
            onChanged: onSearchChanged,
            decoration: const InputDecoration(
              labelText: 'Ara',
              hintText: 'Kod, ad, seri no veya konum',
              prefixIcon: Icon(Icons.search),
            ),
          ),
        ),
        SizedBox(
          width: 190,
          child: DropdownButtonFormField<SupplyProductionAssetClass>(
            key: ValueKey('class-${assetClass?.value ?? 'all'}'),
            initialValue: assetClass,
            decoration: const InputDecoration(labelText: 'Sınıf'),
            items: SupplyProductionAssetClass.values
                .map(
                  (item) =>
                      DropdownMenuItem(value: item, child: Text(item.label)),
                )
                .toList(growable: false),
            onChanged: onClassChanged,
          ),
        ),
        SizedBox(
          width: 220,
          child: DropdownButtonFormField<SupplyProductionAssetType>(
            key: ValueKey('type-${assetType?.value ?? 'all'}'),
            initialValue: assetType,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Tür'),
            items: SupplyProductionAssetType.values
                .map(
                  (item) =>
                      DropdownMenuItem(value: item, child: Text(item.label)),
                )
                .toList(growable: false),
            onChanged: onTypeChanged,
          ),
        ),
        SizedBox(
          width: 190,
          child: DropdownButtonFormField<SupplyProductionAssetStatus>(
            key: ValueKey('status-${status?.value ?? 'all'}'),
            initialValue: status,
            decoration: const InputDecoration(labelText: 'Durum'),
            items: SupplyProductionAssetStatus.values
                .map(
                  (item) =>
                      DropdownMenuItem(value: item, child: Text(item.label)),
                )
                .toList(growable: false),
            onChanged: onStatusChanged,
          ),
        ),
        OutlinedButton.icon(
          onPressed: hasActiveFilter ? onClear : null,
          icon: const Icon(Icons.filter_alt_off_outlined),
          label: const Text('Filtreleri Temizle'),
        ),
      ],
    ),
  );
}

class _AssetCard extends StatelessWidget {
  const _AssetCard({required this.asset});
  final SupplyProductionAssetModel asset;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFE0E7EC)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          asset.name,
          style: const TextStyle(
            color: MarkaKalkanTheme.navy,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 5),
        Text('${asset.assetCode} · ${asset.assetType.label}'),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _Badge(label: asset.assetClass.label),
            _Badge(label: asset.status.label),
            if (asset.partnerId != null)
              _Badge(label: 'Partner: ${asset.partnerId}'),
            if (asset.facilityId != null)
              _Badge(label: 'Tesis: ${asset.facilityId}'),
            if (asset.physicalLocation != null)
              _Badge(label: 'Konum: ${asset.physicalLocation}'),
            if (asset.version != null) _Badge(label: 'Sürüm: ${asset.version}'),
          ],
        ),
      ],
    ),
  );
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: const Color(0xFFF3F7F9),
      borderRadius: BorderRadius.circular(99),
    ),
    child: Text(
      label,
      style: const TextStyle(
        color: Color(0xFF4D6470),
        fontSize: 12,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

class _RegistryMessage extends StatelessWidget {
  const _RegistryMessage({
    required this.icon,
    required this.title,
    required this.description,
  });
  final IconData icon;
  final String title, description;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: MarkaKalkanTheme.teal),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: MarkaKalkanTheme.navy,
              fontSize: 21,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Text(description, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}

class _SignedOutPage extends StatelessWidget {
  const _SignedOutPage();
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Üretim Varlıkları Sicili')),
    body: const _RegistryMessage(
      icon: Icons.lock_outline,
      title: 'Oturum gerekli',
      description: 'Bu sicili görüntülemek için marka hesabıyla giriş yapın.',
    ),
  );
}

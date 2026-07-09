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
  int _refreshVersion = 0;

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
            setState(() {
              _refreshVersion++;
            });
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
      body: FutureBuilder<List<SupplyProductionAssetModel>>(
        key: ValueKey(_refreshVersion),
        future: repository.listAllFromServer(),
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
                    const _ProductionAssetHero(),
                    const SizedBox(height: 18),
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

class _ProductionAssetHero extends StatelessWidget {
  const _ProductionAssetHero();

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 860;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [MarkaKalkanTheme.navy, Color(0xFF17324A), Color(0xFF155E75)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x24101C2C),
            blurRadius: 26,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Stack(
        children: [
          const Positioned(
            right: -90,
            top: -110,
            child: _HeroGlow(size: 300, opacity: 0.12),
          ),
          const Positioned(
            left: -70,
            bottom: -110,
            child: _HeroGlow(size: 250, opacity: 0.08),
          ),
          Padding(
            padding: EdgeInsets.all(compact ? 24 : 34),
            child: compact
                ? const Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _HeroCopy(),
                      SizedBox(height: 26),
                      _EquipmentBoard(),
                    ],
                  )
                : const Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(flex: 6, child: _HeroCopy()),
                      SizedBox(width: 34),
                      Expanded(flex: 5, child: _EquipmentBoard()),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _HeroCopy extends StatelessWidget {
  const _HeroCopy();

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'ÜRETİM VARLIKLARI SİCİLİ',
        style: TextStyle(
          color: Color(0xFF78E0D8),
          fontSize: 13,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.8,
        ),
      ),
      const SizedBox(height: 16),
      const Text(
        'Kalıbı kontrol eden üretimi,\n'
        'üretimi kontrol eden pazarı yönlendirir.',
        style: TextStyle(
          color: Colors.white,
          fontSize: 30,
          height: 1.18,
          fontWeight: FontWeight.w900,
        ),
      ),
      const SizedBox(height: 16),
      const Text(
        'Kalıp, aparat, fikstür, üretim programı ve kritik dijital '
        'dosyalarınızı tek merkezde kayıt altına alın, ilişkilendirin '
        've delillendirin.',
        style: TextStyle(
          color: Color(0xFFD9E7EE),
          fontSize: 15,
          height: 1.55,
          fontWeight: FontWeight.w500,
        ),
      ),
      const SizedBox(height: 22),
      const Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          _HeroChip(label: 'Fiziksel', icon: Icons.precision_manufacturing),
          _HeroChip(label: 'Dijital', icon: Icons.memory_outlined),
          _HeroChip(label: 'Hibrit', icon: Icons.hub_outlined),
        ],
      ),
    ],
  );
}

class _HeroChip extends StatelessWidget {
  const _HeroChip({required this.label, required this.icon});
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(99),
      border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: const Color(0xFF8DE8E0)),
        const SizedBox(width: 7),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );
}

class _EquipmentBoard extends StatelessWidget {
  const _EquipmentBoard();

  static const _items = <({IconData icon, String label})>[
    (icon: Icons.view_in_ar_outlined, label: 'Kalıp'),
    (icon: Icons.settings_outlined, label: 'Dişli'),
    (icon: Icons.straighten_outlined, label: 'Ölçüm'),
    (icon: Icons.precision_manufacturing_outlined, label: 'CNC'),
    (icon: Icons.draw_outlined, label: 'CAD/CAM'),
    (icon: Icons.view_in_ar_outlined, label: '3D Model'),
    (icon: Icons.developer_board_outlined, label: 'PCB'),
    (icon: Icons.shield_outlined, label: 'Koruma'),
  ];

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: const Color(0x14FFFFFF),
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: const Color(0x26FFFFFF)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Row(
          children: [
            Icon(Icons.account_tree_outlined, color: Color(0xFF78E0D8)),
            SizedBox(width: 9),
            Expanded(
              child: Text(
                'ÜRETİM EKİPMANI HARİTASI',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _items.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.02,
          ),
          itemBuilder: (context, index) {
            final item = _items[index];
            return _EquipmentTile(icon: item.icon, label: item.label);
          },
        ),
        const SizedBox(height: 14),
        const Row(
          children: [
            Expanded(child: _ControlQuestion(text: 'Kimin elinde?')),
            SizedBox(width: 8),
            Expanded(child: _ControlQuestion(text: 'Hangi tesiste?')),
          ],
        ),
        const SizedBox(height: 8),
        const Row(
          children: [
            Expanded(child: _ControlQuestion(text: 'Hangi sürüm?')),
            SizedBox(width: 8),
            Expanded(child: _ControlQuestion(text: 'Hangi delille?')),
          ],
        ),
      ],
    ),
  );
}

class _EquipmentTile extends StatelessWidget {
  const _EquipmentTile({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
    decoration: BoxDecoration(
      color: const Color(0x12FFFFFF),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0x1FFFFFFF)),
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: const Color(0xFF8DE8E0), size: 25),
        const SizedBox(height: 6),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFFE7F2F6),
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );
}

class _ControlQuestion extends StatelessWidget {
  const _ControlQuestion({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: const Color(0xFF101C2C).withValues(alpha: 0.32),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: const TextStyle(
        color: Color(0xFFDDEBF0),
        fontSize: 10,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _HeroGlow extends StatelessWidget {
  const _HeroGlow({required this.size, required this.opacity});
  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Colors.white.withValues(alpha: opacity),
    ),
  );
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
    child: LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isCompact = width < 620;
        final isMedium = width >= 620 && width < 980;
        final fieldWidth = isCompact
            ? width
            : isMedium
            ? (width - 12) / 2
            : null;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.end,
          children: [
            SizedBox(
              width: fieldWidth ?? 270,
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
              width: fieldWidth ?? 190,
              child: DropdownButtonFormField<SupplyProductionAssetClass>(
                key: ValueKey('class-${assetClass?.value ?? 'all'}'),
                initialValue: assetClass,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Sınıf'),
                items: SupplyProductionAssetClass.values
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
                onChanged: onClassChanged,
              ),
            ),
            SizedBox(
              width: fieldWidth ?? 220,
              child: DropdownButtonFormField<SupplyProductionAssetType>(
                key: ValueKey('type-${assetType?.value ?? 'all'}'),
                initialValue: assetType,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Tür'),
                items: SupplyProductionAssetType.values
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
                onChanged: onTypeChanged,
              ),
            ),
            SizedBox(
              width: fieldWidth ?? 190,
              child: DropdownButtonFormField<SupplyProductionAssetStatus>(
                key: ValueKey('status-${status?.value ?? 'all'}'),
                initialValue: status,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Durum'),
                items: SupplyProductionAssetStatus.values
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
                onChanged: onStatusChanged,
              ),
            ),
            SizedBox(
              width: isCompact ? width : null,
              child: OutlinedButton.icon(
                onPressed: hasActiveFilter ? onClear : null,
                icon: const Icon(Icons.filter_alt_off_outlined),
                label: const Text('Filtreleri Temizle'),
              ),
            ),
          ],
        );
      },
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

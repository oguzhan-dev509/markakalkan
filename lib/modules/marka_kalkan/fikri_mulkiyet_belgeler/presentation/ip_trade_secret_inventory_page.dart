import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:markakalkan/core/theme/markakalkan_theme.dart';

import '../constants/ip_enums.dart';
import '../constants/ip_trade_secret_detail_enums.dart';
import '../constants/ip_trade_secret_enums.dart';
import '../models/ip_trade_secret_component_model.dart';
import '../models/ip_trade_secret_model.dart';
import '../repositories/ip_trade_secret_component_repository.dart';
import '../repositories/ip_trade_secret_repository.dart';

class IpTradeSecretInventoryPage extends StatefulWidget {
  const IpTradeSecretInventoryPage({super.key});

  @override
  State<IpTradeSecretInventoryPage> createState() =>
      _IpTradeSecretInventoryPageState();
}

class _IpTradeSecretInventoryPageState
    extends State<IpTradeSecretInventoryPage> {
  IpTradeSecretRepository? _secretRepository;
  IpTradeSecretComponentRepository? _componentRepository;
  String? _selectedSecretId;
  String _search = '';
  IpTradeSecretStatus? _statusFilter;
  IpRiskLevel? _riskFilter;
  IpTradeSecretType? _typeFilter;
  IpConfidentialityLevel? _confidentialityFilter;
  bool _onlyActive = false;

  User? get _user => FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    final uid = _user?.uid;
    if (uid != null && uid.isNotEmpty) {
      _secretRepository = IpTradeSecretRepository.instance(tenantId: uid);
      _componentRepository = IpTradeSecretComponentRepository.instance(
        tenantId: uid,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;
    final secretRepository = _secretRepository;
    final componentRepository = _componentRepository;

    if (user == null ||
        secretRepository == null ||
        componentRepository == null) {
      return const Scaffold(
        body: Center(
          child: Text('Formül envanterini açmak için oturum açılmalıdır.'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: MarkaKalkanTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text(
          'Formül ve Bileşen Envanteri',
          style: TextStyle(
            color: MarkaKalkanTheme.navy,
            fontWeight: FontWeight.w900,
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () => _showCreateSecretDialog(user.uid),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Yeni Formül Ekle'),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: StreamBuilder<List<IpTradeSecretModel>>(
        stream: secretRepository.watchAll(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _ErrorPanel(
              message: 'Formül kayıtları yüklenemedi: ${snapshot.error}',
            );
          }

          final secrets = snapshot.data ?? const <IpTradeSecretModel>[];
          final filtered = secrets.where(_matchesFilters).toList();

          if (_selectedSecretId == null && filtered.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && _selectedSecretId == null) {
                setState(() => _selectedSecretId = filtered.first.id);
              }
            });
          }

          final selected = _findSelected(secrets);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(22),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1500),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _HeaderActions(
                      hasSelectedFormula: selected != null,
                      onCreateFormula: () => _showCreateSecretDialog(user.uid),
                      onCreateComponent: selected == null
                          ? null
                          : () =>
                                _showCreateComponentDialog(selected, user.uid),
                      onImport: () => _showInfoMessage(
                        'İçe aktarma sihirbazı sonraki fazda etkinleştirilecek.',
                      ),
                      onExport: () => _showInfoMessage(
                        'Envanter dışa aktarma sonraki fazda etkinleştirilecek.',
                      ),
                    ),
                    const SizedBox(height: 18),
                    _MetricsRow(secrets: secrets),
                    const SizedBox(height: 18),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final narrow = constraints.maxWidth < 1050;

                        final filterPanel = _InventoryFilterPanel(
                          secrets: secrets,
                          typeFilter: _typeFilter,
                          confidentialityFilter: _confidentialityFilter,
                          onlyActive: _onlyActive,
                          onTypeChanged: (value) =>
                              setState(() => _typeFilter = value),
                          onConfidentialityChanged: (value) =>
                              setState(() => _confidentialityFilter = value),
                          onOnlyActiveChanged: (value) =>
                              setState(() => _onlyActive = value),
                          onClear: _clearFilters,
                        );

                        final content = Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _FilterBar(
                              search: _search,
                              statusFilter: _statusFilter,
                              riskFilter: _riskFilter,
                              onSearchChanged: (value) =>
                                  setState(() => _search = value),
                              onStatusChanged: (value) =>
                                  setState(() => _statusFilter = value),
                              onRiskChanged: (value) =>
                                  setState(() => _riskFilter = value),
                              onClear: _clearFilters,
                            ),
                            const SizedBox(height: 14),
                            _FormulaTable(
                              secrets: filtered,
                              selectedId: selected?.id,
                              onSelect: (item) =>
                                  setState(() => _selectedSecretId = item.id),
                            ),
                            const SizedBox(height: 14),
                            if (selected == null)
                              const _EmptyPanel(
                                title: 'Henüz formül kaydı yok',
                                message:
                                    'İlk formül veya ticari sır dosyanızı oluşturarak başlayın.',
                              )
                            else
                              _SelectedSecretSection(
                                secret: selected,
                                repository: componentRepository,
                                actorId: user.uid,
                                onCreateComponent: () =>
                                    _showCreateComponentDialog(
                                      selected,
                                      user.uid,
                                    ),
                              ),
                          ],
                        );

                        if (narrow) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              filterPanel,
                              const SizedBox(height: 14),
                              content,
                            ],
                          );
                        }

                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(width: 250, child: filterPanel),
                            const SizedBox(width: 14),
                            Expanded(child: content),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  bool _matchesFilters(IpTradeSecretModel item) {
    final query = _search.trim().toLowerCase();
    final matchesText =
        query.isEmpty ||
        item.title.toLowerCase().contains(query) ||
        item.secretCode.toLowerCase().contains(query) ||
        item.brandId.toLowerCase().contains(query);
    final matchesStatus = _statusFilter == null || item.status == _statusFilter;
    final matchesRisk = _riskFilter == null || item.riskLevel == _riskFilter;
    final matchesType = _typeFilter == null || item.secretType == _typeFilter;
    final matchesConfidentiality =
        _confidentialityFilter == null ||
        item.confidentialityLevel == _confidentialityFilter;
    final matchesActive =
        !_onlyActive || item.status == IpTradeSecretStatus.active;

    return matchesText &&
        matchesStatus &&
        matchesRisk &&
        matchesType &&
        matchesConfidentiality &&
        matchesActive;
  }

  void _clearFilters() {
    setState(() {
      _search = '';
      _statusFilter = null;
      _riskFilter = null;
      _typeFilter = null;
      _confidentialityFilter = null;
      _onlyActive = false;
    });
  }

  void _showInfoMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  IpTradeSecretModel? _findSelected(List<IpTradeSecretModel> secrets) {
    for (final item in secrets) {
      if (item.id == _selectedSecretId) return item;
    }
    return secrets.isEmpty ? null : secrets.first;
  }

  Future<void> _showCreateSecretDialog(String actorId) async {
    final repository = _secretRepository;
    if (repository == null) return;

    final brandController = TextEditingController();
    final codeController = TextEditingController();
    final titleController = TextEditingController();
    IpTradeSecretType type = IpTradeSecretType.formula;
    IpConfidentialityLevel confidentiality =
        IpConfidentialityLevel.highlyConfidential;
    IpRiskLevel risk = IpRiskLevel.high;

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Yeni Formül / Ticari Sır'),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: brandController,
                    decoration: const InputDecoration(
                      labelText: 'Marka kimliği',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: codeController,
                    decoration: const InputDecoration(labelText: 'Formül kodu'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(labelText: 'Formül adı'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<IpTradeSecretType>(
                    initialValue: type,
                    decoration: const InputDecoration(labelText: 'Tür'),
                    items: IpTradeSecretType.values
                        .map(
                          (e) =>
                              DropdownMenuItem(value: e, child: Text(e.label)),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) setDialogState(() => type = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<IpConfidentialityLevel>(
                    initialValue: confidentiality,
                    decoration: const InputDecoration(labelText: 'Gizlilik'),
                    items: IpConfidentialityLevel.values
                        .map(
                          (e) =>
                              DropdownMenuItem(value: e, child: Text(e.label)),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => confidentiality = value);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<IpRiskLevel>(
                    initialValue: risk,
                    decoration: const InputDecoration(
                      labelText: 'Risk seviyesi',
                    ),
                    items: IpRiskLevel.values
                        .map(
                          (e) =>
                              DropdownMenuItem(value: e, child: Text(e.label)),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) setDialogState(() => risk = value);
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              onPressed: () async {
                try {
                  final model = IpTradeSecretModel(
                    id: '',
                    tenantId: actorId,
                    brandId: brandController.text.trim(),
                    secretCode: codeController.text.trim(),
                    title: titleController.text.trim(),
                    secretType: type,
                    status: IpTradeSecretStatus.active,
                    confidentialityLevel: confidentiality,
                    riskLevel: risk,
                    protectionMode: IpSecretProtectionMode.metadataOnly,
                    disclosureScope: IpSecretDisclosureScope.needToKnow,
                    legalBasisStatus: IpSecretLegalBasisStatus.undocumented,
                    compartmentalizationLevel:
                        IpSecretCompartmentalizationLevel.basic,
                    economicValueLevel: IpSecretEconomicValueLevel.high,
                    createdAt: DateTime.now().toUtc(),
                    createdBy: actorId,
                  );
                  final id = await repository.create(model);
                  if (!dialogContext.mounted) return;
                  Navigator.pop(dialogContext, true);
                  if (mounted) setState(() => _selectedSecretId = id);
                } catch (error) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(content: Text('Kayıt oluşturulamadı: $error')),
                  );
                }
              },
              child: const Text('Kaydet'),
            ),
          ],
        ),
      ),
    );

    brandController.dispose();
    codeController.dispose();
    titleController.dispose();

    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Formül kaydı oluşturuldu.')),
      );
    }
  }

  Future<void> _showCreateComponentDialog(
    IpTradeSecretModel secret,
    String actorId,
  ) async {
    final repository = _componentRepository;
    if (repository == null) return;

    final codeController = TextEditingController();
    final titleController = TextEditingController();
    final departmentController = TextEditingController();
    IpTradeSecretComponentType type = IpTradeSecretComponentType.ingredient;
    IpTradeSecretComponentCriticality criticality =
        IpTradeSecretComponentCriticality.high;
    IpConfidentialityLevel confidentiality = secret.confidentialityLevel;
    IpRiskLevel risk = secret.riskLevel;

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('${secret.title} — Bileşen Ekle'),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: codeController,
                    decoration: const InputDecoration(
                      labelText: 'Bileşen kodu',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(labelText: 'Bileşen adı'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: departmentController,
                    decoration: const InputDecoration(
                      labelText: 'Sorumlu birim',
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<IpTradeSecretComponentType>(
                    initialValue: type,
                    decoration: const InputDecoration(
                      labelText: 'Bileşen türü',
                    ),
                    items: IpTradeSecretComponentType.values
                        .map(
                          (e) =>
                              DropdownMenuItem(value: e, child: Text(e.label)),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) setDialogState(() => type = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<IpTradeSecretComponentCriticality>(
                    initialValue: criticality,
                    decoration: const InputDecoration(labelText: 'Kritiklik'),
                    items: IpTradeSecretComponentCriticality.values
                        .map(
                          (e) =>
                              DropdownMenuItem(value: e, child: Text(e.label)),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => criticality = value);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<IpConfidentialityLevel>(
                    initialValue: confidentiality,
                    decoration: const InputDecoration(labelText: 'Gizlilik'),
                    items: IpConfidentialityLevel.values
                        .map(
                          (e) =>
                              DropdownMenuItem(value: e, child: Text(e.label)),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => confidentiality = value);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<IpRiskLevel>(
                    initialValue: risk,
                    decoration: const InputDecoration(labelText: 'Risk'),
                    items: IpRiskLevel.values
                        .map(
                          (e) =>
                              DropdownMenuItem(value: e, child: Text(e.label)),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) setDialogState(() => risk = value);
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              onPressed: () async {
                try {
                  final model = IpTradeSecretComponentModel(
                    id: '',
                    tenantId: actorId,
                    brandId: secret.brandId,
                    tradeSecretId: secret.id,
                    componentCode: codeController.text.trim(),
                    title: titleController.text.trim(),
                    componentType: type,
                    status: IpTradeSecretComponentStatus.active,
                    criticality: criticality,
                    confidentialityLevel: confidentiality,
                    riskLevel: risk,
                    storageMode: IpTradeSecretComponentStorageMode.metadataOnly,
                    ownerDepartment: departmentController.text.trim(),
                    createdAt: DateTime.now().toUtc(),
                    createdBy: actorId,
                  );
                  await repository.create(model);
                  if (!dialogContext.mounted) return;
                  Navigator.pop(dialogContext, true);
                } catch (error) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(content: Text('Bileşen oluşturulamadı: $error')),
                  );
                }
              },
              child: const Text('Kaydet'),
            ),
          ],
        ),
      ),
    );

    codeController.dispose();
    titleController.dispose();
    departmentController.dispose();

    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bileşen kaydı oluşturuldu.')),
      );
    }
  }
}

class _HeaderActions extends StatelessWidget {
  const _HeaderActions({
    required this.hasSelectedFormula,
    required this.onCreateFormula,
    required this.onCreateComponent,
    required this.onImport,
    required this.onExport,
  });

  final bool hasSelectedFormula;
  final VoidCallback onCreateFormula;
  final VoidCallback? onCreateComponent;
  final VoidCallback onImport;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 880;

        final title = const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Formül ve Bileşen Envanteri',
              style: TextStyle(
                color: MarkaKalkanTheme.navy,
                fontSize: 26,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Formülleri, bileşenleri, kritik oranları, bağımlılıkları ve ticari sır hassasiyetini güvenle yönetin.',
              style: TextStyle(color: Color(0xFF687580), height: 1.45),
            ),
          ],
        );

        final actions = Wrap(
          spacing: 10,
          runSpacing: 10,
          alignment: WrapAlignment.end,
          children: [
            FilledButton.icon(
              onPressed: onCreateFormula,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Yeni Formül Ekle'),
            ),
            OutlinedButton.icon(
              onPressed: hasSelectedFormula ? onCreateComponent : null,
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('Bileşen Ekle'),
            ),
            OutlinedButton.icon(
              onPressed: onImport,
              icon: const Icon(Icons.upload_file_outlined),
              label: const Text('İçe Aktar'),
            ),
            OutlinedButton.icon(
              onPressed: onExport,
              icon: const Icon(Icons.download_outlined),
              label: const Text('Envanteri Dışa Aktar'),
            ),
          ],
        );

        if (narrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [title, const SizedBox(height: 14), actions],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: title),
            const SizedBox(width: 18),
            Flexible(child: actions),
          ],
        );
      },
    );
  }
}

class _MetricsRow extends StatelessWidget {
  const _MetricsRow({required this.secrets});

  final List<IpTradeSecretModel> secrets;

  @override
  Widget build(BuildContext context) {
    final active = secrets
        .where((item) => item.status == IpTradeSecretStatus.active)
        .length;
    final critical = secrets
        .where((item) => item.riskLevel == IpRiskLevel.critical)
        .length;
    final highConfidentiality = secrets
        .where(
          (item) =>
              item.confidentialityLevel ==
                  IpConfidentialityLevel.highlyConfidential ||
              item.confidentialityLevel == IpConfidentialityLevel.tradeSecret,
        )
        .length;
    final reviewDue = secrets.where((item) {
      final date = item.nextAccessReviewAt;
      return date != null && date.isBefore(DateTime.now().toUtc());
    }).length;
    final leakage = secrets.where((item) => item.leakageSuspected).length;
    final legalHold = secrets.where((item) => item.legalHoldActive).length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 650
            ? 1
            : constraints.maxWidth < 980
            ? 2
            : 3;
        const spacing = 14.0;
        final width =
            (constraints.maxWidth - ((columns - 1) * spacing)) / columns;

        final items = [
          _MetricData(
            'Toplam Formül',
            '${secrets.length}',
            '$active aktif',
            Icons.description_outlined,
            const Color(0xFFE9F0FF),
            const Color(0xFF1646C0),
          ),
          _MetricData(
            'Aktif Formül',
            '$active',
            secrets.isEmpty
                ? '%0'
                : '%${((active / secrets.length) * 100).round()}',
            Icons.check_circle_outline,
            const Color(0xFFE8F8EE),
            const Color(0xFF16824A),
          ),
          _MetricData(
            'Kritik Risk',
            '$critical',
            'Acil inceleme',
            Icons.warning_amber_rounded,
            const Color(0xFFFFF0EA),
            const Color(0xFFD75A21),
          ),
          _MetricData(
            'Yüksek Gizlilik',
            '$highConfidentiality',
            'Ticari sır seviyesi',
            Icons.shield_outlined,
            const Color(0xFFE9F6F5),
            MarkaKalkanTheme.teal,
          ),
          _MetricData(
            'Revizyon Bekleyen',
            '$reviewDue',
            'Erişim incelemesi',
            Icons.history_rounded,
            const Color(0xFFF1ECFF),
            const Color(0xFF6B4FD3),
          ),
          _MetricData(
            'Hukuki / Sızıntı',
            '${legalHold + leakage}',
            '$legalHold muhafaza • $leakage şüphe',
            Icons.gavel_outlined,
            const Color(0xFFFFF7E6),
            const Color(0xFFA96B00),
          ),
        ];

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: items
              .map((item) => SizedBox(width: width, child: _MetricCard(item)))
              .toList(),
        );
      },
    );
  }
}

class _MetricData {
  const _MetricData(
    this.title,
    this.value,
    this.detail,
    this.icon,
    this.background,
    this.foreground,
  );

  final String title;
  final String value;
  final String detail;
  final IconData icon;
  final Color background;
  final Color foreground;
}

class _MetricCard extends StatelessWidget {
  const _MetricCard(this.item);

  final _MetricData item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _panelDecoration(),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: item.background,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(item.icon, color: item.foreground),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF687580),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  item.value,
                  style: const TextStyle(
                    color: MarkaKalkanTheme.navy,
                    fontSize: 25,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  item.detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: item.foreground,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InventoryFilterPanel extends StatelessWidget {
  const _InventoryFilterPanel({
    required this.secrets,
    required this.typeFilter,
    required this.confidentialityFilter,
    required this.onlyActive,
    required this.onTypeChanged,
    required this.onConfidentialityChanged,
    required this.onOnlyActiveChanged,
    required this.onClear,
  });

  final List<IpTradeSecretModel> secrets;
  final IpTradeSecretType? typeFilter;
  final IpConfidentialityLevel? confidentialityFilter;
  final bool onlyActive;
  final ValueChanged<IpTradeSecretType?> onTypeChanged;
  final ValueChanged<IpConfidentialityLevel?> onConfidentialityChanged;
  final ValueChanged<bool> onOnlyActiveChanged;
  final VoidCallback onClear;

  int _typeCount(IpTradeSecretType type) =>
      secrets.where((item) => item.secretType == type).length;

  int _confidentialityCount(IpConfidentialityLevel level) =>
      secrets.where((item) => item.confidentialityLevel == level).length;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Gelişmiş Filtreler',
                  style: TextStyle(
                    color: MarkaKalkanTheme.navy,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              TextButton(onPressed: onClear, child: const Text('Temizle')),
            ],
          ),
          const Divider(height: 24),
          const Text(
            'Formül Grupları',
            style: TextStyle(
              color: MarkaKalkanTheme.navy,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          _FilterChoice(
            label: 'Tümü',
            count: secrets.length,
            selected: typeFilter == null,
            onTap: () => onTypeChanged(null),
          ),
          ...IpTradeSecretType.values
              .take(6)
              .map(
                (type) => _FilterChoice(
                  label: type.label,
                  count: _typeCount(type),
                  selected: typeFilter == type,
                  onTap: () => onTypeChanged(type),
                ),
              ),
          const Divider(height: 28),
          const Text(
            'Hassasiyet Seviyesi',
            style: TextStyle(
              color: MarkaKalkanTheme.navy,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          _FilterChoice(
            label: 'Tümü',
            count: secrets.length,
            selected: confidentialityFilter == null,
            onTap: () => onConfidentialityChanged(null),
          ),
          ...IpConfidentialityLevel.values.map(
            (level) => _FilterChoice(
              label: level.label,
              count: _confidentialityCount(level),
              selected: confidentialityFilter == level,
              onTap: () => onConfidentialityChanged(level),
            ),
          ),
          const Divider(height: 28),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'Sadece aktif',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            value: onlyActive,
            onChanged: onOnlyActiveChanged,
          ),
          const SizedBox(height: 8),
          const _IndexCard(),
        ],
      ),
    );
  }
}

class _FilterChoice extends StatelessWidget {
  const _FilterChoice({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              size: 17,
              color: selected ? MarkaKalkanTheme.blue : const Color(0xFF9AA6AE),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected
                      ? MarkaKalkanTheme.blue
                      : const Color(0xFF4B5963),
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ),
            Text(
              '$count',
              style: const TextStyle(
                color: Color(0xFF687580),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IndexCard extends StatelessWidget {
  const _IndexCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF5FAFA),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFFD9ECE9)),
      ),
      child: const Column(
        children: [
          Text(
            'IP Dayanıklılık Endeksi',
            style: TextStyle(
              color: MarkaKalkanTheme.navy,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 12),
          SizedBox(
            width: 78,
            height: 78,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: 0.82,
                  strokeWidth: 9,
                  backgroundColor: Color(0xFFDDEBE9),
                  color: MarkaKalkanTheme.teal,
                ),
                Text(
                  '82',
                  style: TextStyle(
                    color: MarkaKalkanTheme.navy,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Güçlü',
            style: TextStyle(
              color: MarkaKalkanTheme.teal,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.search,
    required this.statusFilter,
    required this.riskFilter,
    required this.onSearchChanged,
    required this.onStatusChanged,
    required this.onRiskChanged,
    required this.onClear,
  });

  final String search;
  final IpTradeSecretStatus? statusFilter;
  final IpRiskLevel? riskFilter;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<IpTradeSecretStatus?> onStatusChanged;
  final ValueChanged<IpRiskLevel?> onRiskChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _panelDecoration(),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 820;
          final fieldWidth = compact
              ? constraints.maxWidth
              : (constraints.maxWidth - 36) / 4;

          return Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: compact ? constraints.maxWidth : fieldWidth * 1.6,
                child: TextFormField(
                  key: ValueKey(search),
                  initialValue: search,
                  onChanged: onSearchChanged,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Formül adı, kodu veya marka kimliği ara...',
                  ),
                ),
              ),
              SizedBox(
                width: compact ? constraints.maxWidth : fieldWidth,
                child: DropdownButtonFormField<IpTradeSecretStatus?>(
                  initialValue: statusFilter,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Durum'),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text(
                        'Tümü',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    ...IpTradeSecretStatus.values.map(
                      (item) => DropdownMenuItem(
                        value: item,
                        child: Text(
                          item.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                  onChanged: onStatusChanged,
                ),
              ),
              SizedBox(
                width: compact ? constraints.maxWidth : fieldWidth,
                child: DropdownButtonFormField<IpRiskLevel?>(
                  initialValue: riskFilter,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Risk'),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text(
                        'Tümü',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    ...IpRiskLevel.values.map(
                      (item) => DropdownMenuItem(
                        value: item,
                        child: Text(
                          item.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                  onChanged: onRiskChanged,
                ),
              ),
              SizedBox(
                width: compact ? constraints.maxWidth : fieldWidth * 0.8,
                child: OutlinedButton.icon(
                  onPressed: onClear,
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
}

class _FormulaTable extends StatelessWidget {
  const _FormulaTable({
    required this.secrets,
    required this.selectedId,
    required this.onSelect,
  });

  final List<IpTradeSecretModel> secrets;
  final String? selectedId;
  final ValueChanged<IpTradeSecretModel> onSelect;

  @override
  Widget build(BuildContext context) {
    if (secrets.isEmpty) {
      return const _EmptyPanel(
        title: 'Filtreye uygun formül bulunamadı',
        message: 'Filtreleri temizleyerek tüm kayıtları yeniden görüntüleyin.',
      );
    }

    return Container(
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              showCheckboxColumn: false,
              headingRowColor: WidgetStateProperty.all(const Color(0xFFF7F9FB)),
              columns: const [
                DataColumn(label: Text('Formül Kodu')),
                DataColumn(label: Text('Formül Adı')),
                DataColumn(label: Text('Kategori')),
                DataColumn(label: Text('Sahip')),
                DataColumn(label: Text('Gizlilik')),
                DataColumn(label: Text('Risk')),
                DataColumn(label: Text('Durum')),
                DataColumn(label: Text('Son Revizyon')),
              ],
              rows: secrets.map((item) {
                final selected = item.id == selectedId;
                return DataRow(
                  selected: selected,
                  onSelectChanged: (_) => onSelect(item),
                  cells: [
                    DataCell(
                      Text(
                        item.secretCode,
                        style: const TextStyle(
                          color: MarkaKalkanTheme.blue,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        item.title,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    DataCell(Text(item.secretType.label)),
                    DataCell(Text(item.ownerDepartment ?? '—')),
                    DataCell(_Badge(item.confidentialityLevel.label)),
                    DataCell(_Badge(item.riskLevel.label)),
                    DataCell(_Badge(item.status.label)),
                    DataCell(Text(_date(item.updatedAt ?? item.createdAt))),
                  ],
                );
              }).toList(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
            child: Row(
              children: [
                Text(
                  'Toplam ${secrets.length} formül',
                  style: const TextStyle(
                    color: Color(0xFF687580),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                const Text(
                  'Sayfa 1',
                  style: TextStyle(
                    color: MarkaKalkanTheme.blue,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectedSecretSection extends StatelessWidget {
  const _SelectedSecretSection({
    required this.secret,
    required this.repository,
    required this.actorId,
    required this.onCreateComponent,
  });

  final IpTradeSecretModel secret;
  final IpTradeSecretComponentRepository repository;
  final String actorId;
  final VoidCallback onCreateComponent;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<IpTradeSecretComponentModel>>(
      stream: repository.watch(tradeSecretId: secret.id),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _ErrorPanel(
            message: 'Bileşen kayıtları yüklenemedi: ${snapshot.error}',
          );
        }

        final components =
            snapshot.data ?? const <IpTradeSecretComponentModel>[];
        final critical = components
            .where((item) => item.isCriticalComponent)
            .length;
        final immediate = components
            .where((item) => item.requiresImmediateReview)
            .length;
        final protected = components.where((item) {
          final score =
              (item.accessControlScore +
                  item.technicalProtectionScore +
                  item.operationalProtectionScore) /
              3;
          return score >= 70;
        }).length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SelectedFormulaHeader(
              secret: secret,
              componentCount: components.length,
              criticalCount: critical,
              onCreateComponent: onCreateComponent,
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth < 760
                    ? 1
                    : constraints.maxWidth < 1180
                    ? 2
                    : 4;
                const spacing = 14.0;
                final width =
                    (constraints.maxWidth - ((columns - 1) * spacing)) /
                    columns;

                return Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: [
                    SizedBox(
                      width: width,
                      child: _ComponentSummaryPanel(
                        total: components.length,
                        critical: critical,
                        protected: protected,
                      ),
                    ),
                    SizedBox(
                      width: width,
                      child: _DependencyPanel(components: components),
                    ),
                    SizedBox(
                      width: width,
                      child: _AlertsPanel(
                        secret: secret,
                        components: components,
                        immediate: immediate,
                      ),
                    ),
                    SizedBox(
                      width: width,
                      child: _ActivityPanel(
                        secret: secret,
                        components: components,
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 14),
            _VersionHistoryPanel(secret: secret),
            const SizedBox(height: 14),
            _ComponentTable(components: components, repository: repository),
          ],
        );
      },
    );
  }
}

class _SelectedFormulaHeader extends StatelessWidget {
  const _SelectedFormulaHeader({
    required this.secret,
    required this.componentCount,
    required this.criticalCount,
    required this.onCreateComponent,
  });

  final IpTradeSecretModel secret;
  final int componentCount;
  final int criticalCount;
  final VoidCallback onCreateComponent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _panelDecoration(),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 760;
          final identity = Row(
            children: [
              const _IconBubble(Icons.science_outlined),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          secret.title,
                          style: const TextStyle(
                            color: MarkaKalkanTheme.navy,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        _Badge(secret.confidentialityLevel.label),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${secret.secretCode} • ${secret.secretType.label} • ${secret.status.label}',
                      style: const TextStyle(color: Color(0xFF687580)),
                    ),
                  ],
                ),
              ),
            ],
          );

          final actions = Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _Badge('$componentCount bileşen'),
              _Badge('$criticalCount kritik'),
              FilledButton.icon(
                onPressed: onCreateComponent,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Bileşen Ekle'),
              ),
            ],
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [identity, const SizedBox(height: 14), actions],
            );
          }

          return Row(
            children: [
              Expanded(child: identity),
              const SizedBox(width: 16),
              actions,
            ],
          );
        },
      ),
    );
  }
}

class _ComponentSummaryPanel extends StatelessWidget {
  const _ComponentSummaryPanel({
    required this.total,
    required this.critical,
    required this.protected,
  });

  final int total;
  final int critical;
  final int protected;

  @override
  Widget build(BuildContext context) {
    final active = total - critical;
    final value = total == 0 ? 0.0 : protected / total;

    return _InsightPanel(
      title: 'Seçili Formül Özeti',
      icon: Icons.donut_large_outlined,
      child: Row(
        children: [
          SizedBox(
            width: 92,
            height: 92,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: value,
                  strokeWidth: 11,
                  backgroundColor: const Color(0xFFE7EEF2),
                  color: MarkaKalkanTheme.teal,
                ),
                Text(
                  '$total',
                  style: const TextStyle(
                    color: MarkaKalkanTheme.navy,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              children: [
                _SummaryLine('Aktif / normal', active, Colors.green),
                _SummaryLine('Kritik', critical, Colors.redAccent),
                _SummaryLine('Koruma skoru ≥70', protected, Colors.blue),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine(this.label, this.value, this.color);

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Color(0xFF687580), fontSize: 12),
            ),
          ),
          Text(
            '$value',
            style: const TextStyle(
              color: MarkaKalkanTheme.navy,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _DependencyPanel extends StatelessWidget {
  const _DependencyPanel({required this.components});

  final List<IpTradeSecretComponentModel> components;

  @override
  Widget build(BuildContext context) {
    final items = components.take(3).toList();

    return _InsightPanel(
      title: 'Bağımlılık Zinciri',
      icon: Icons.link_outlined,
      child: items.isEmpty
          ? const _SmallEmptyText('Henüz bileşen bağımlılığı bulunmuyor.')
          : Column(
              children: items.map((item) {
                final risk = item.riskLevel == IpRiskLevel.critical
                    ? 'Yüksek Risk'
                    : item.riskLevel == IpRiskLevel.high
                    ? 'Orta Risk'
                    : 'Düşük Risk';
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFB),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE3E9ED)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.account_tree_outlined,
                        size: 18,
                        color: MarkaKalkanTheme.blue,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: MarkaKalkanTheme.navy,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      _Badge(risk),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }
}

class _AlertsPanel extends StatelessWidget {
  const _AlertsPanel({
    required this.secret,
    required this.components,
    required this.immediate,
  });

  final IpTradeSecretModel secret;
  final List<IpTradeSecretComponentModel> components;
  final int immediate;

  @override
  Widget build(BuildContext context) {
    final alerts = <String>[
      if (secret.leakageSuspected) 'Sızıntı şüphesi açık',
      if (secret.legalHoldActive) 'Hukuki muhafaza aktif',
      if (secret.nextAccessReviewAt?.isBefore(DateTime.now().toUtc()) == true)
        'Erişim incelemesi gecikmiş',
      if (immediate > 0) '$immediate bileşen acil inceleme bekliyor',
      if (components.any((item) => item.leakageSuspected))
        'Bileşen düzeyinde sızıntı şüphesi',
    ];

    return _InsightPanel(
      title: 'Uyarılar ve Açıklar',
      icon: Icons.crisis_alert_outlined,
      child: alerts.isEmpty
          ? const _SmallEmptyText('Aktif kritik uyarı bulunmuyor.')
          : Column(
              children: alerts
                  .take(4)
                  .map(
                    (message) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.warning_amber_rounded,
                            size: 18,
                            color: Color(0xFFD75A21),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              message,
                              style: const TextStyle(
                                color: Color(0xFF4B5963),
                                fontSize: 12,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
    );
  }
}

class _ActivityPanel extends StatelessWidget {
  const _ActivityPanel({required this.secret, required this.components});

  final IpTradeSecretModel secret;
  final List<IpTradeSecretComponentModel> components;

  @override
  Widget build(BuildContext context) {
    final latestComponent = components.isEmpty ? null : components.first;

    return _InsightPanel(
      title: 'Son İşlemler',
      icon: Icons.history_toggle_off_outlined,
      child: Column(
        children: [
          _ActivityRow(
            label: 'Formül kaydı oluşturuldu',
            date: _date(secret.createdAt),
          ),
          if (secret.updatedAt != null)
            _ActivityRow(
              label: 'Formül güncellendi',
              date: _date(secret.updatedAt!),
            ),
          if (latestComponent != null)
            _ActivityRow(
              label: '${latestComponent.title} bileşeni kaydedildi',
              date: _date(
                latestComponent.updatedAt ?? latestComponent.createdAt,
              ),
            ),
          _ActivityRow(
            label: '${components.length} bileşen izleniyor',
            date: 'Güncel',
          ),
        ],
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.label, required this.date});

  final String label;
  final String date;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              color: MarkaKalkanTheme.teal,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xFF4B5963), fontSize: 12),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            date,
            style: const TextStyle(color: Color(0xFF8A969E), fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _VersionHistoryPanel extends StatelessWidget {
  const _VersionHistoryPanel({required this.secret});

  final IpTradeSecretModel secret;

  @override
  Widget build(BuildContext context) {
    return _InsightPanel(
      title: 'Versiyon Geçmişi',
      icon: Icons.layers_outlined,
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          _VersionChip(
            version: secret.updatedAt == null ? 'v1.0' : 'v1.1',
            date: _date(secret.updatedAt ?? secret.createdAt),
            status: secret.status.label,
          ),
          _VersionChip(
            version: 'Başlangıç',
            date: _date(secret.createdAt),
            status: 'Oluşturuldu',
          ),
          _VersionChip(
            version: 'Koruma',
            date: _date(secret.firstProtectedAt ?? secret.createdAt),
            status: secret.protectionMode.label,
          ),
        ],
      ),
    );
  }
}

class _VersionChip extends StatelessWidget {
  const _VersionChip({
    required this.version,
    required this.date,
    required this.status,
  });

  final String version;
  final String date;
  final String status;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 180),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE3E9ED)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.verified_outlined,
            size: 18,
            color: MarkaKalkanTheme.teal,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  version,
                  style: const TextStyle(
                    color: MarkaKalkanTheme.navy,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  '$date • $status',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF687580),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ComponentTable extends StatelessWidget {
  const _ComponentTable({required this.components, required this.repository});

  final List<IpTradeSecretComponentModel> components;
  final IpTradeSecretComponentRepository repository;

  @override
  Widget build(BuildContext context) {
    if (components.isEmpty) {
      return const _EmptyPanel(
        title: 'Henüz bileşen kaydı yok',
        message: 'Seçili formüle ilk bileşeni ekleyerek başlayın.',
      );
    }

    return Container(
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(18, 16, 18, 6),
            child: Text(
              'Bileşen Envanteri',
              style: TextStyle(
                color: MarkaKalkanTheme.navy,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Bileşen Kodu')),
                DataColumn(label: Text('Bileşen Adı')),
                DataColumn(label: Text('Tür')),
                DataColumn(label: Text('Kritiklik')),
                DataColumn(label: Text('Gizlilik')),
                DataColumn(label: Text('Risk')),
                DataColumn(label: Text('Sorumlu Birim')),
                DataColumn(label: Text('Koruma Skoru')),
                DataColumn(label: Text('İşlem')),
              ],
              rows: components.map((item) {
                final score =
                    ((item.accessControlScore +
                                item.technicalProtectionScore +
                                item.operationalProtectionScore) /
                            3)
                        .round();
                return DataRow(
                  cells: [
                    DataCell(Text(item.componentCode)),
                    DataCell(Text(item.title)),
                    DataCell(Text(item.componentType.label)),
                    DataCell(_Badge(item.criticality.label)),
                    DataCell(_Badge(item.confidentialityLevel.label)),
                    DataCell(_Badge(item.riskLevel.label)),
                    DataCell(Text(item.ownerDepartment ?? '—')),
                    DataCell(Text('$score / 100')),
                    DataCell(
                      IconButton(
                        tooltip: 'Sil',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () =>
                            _confirmDelete(context, item, repository),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    IpTradeSecretComponentModel item,
    IpTradeSecretComponentRepository repository,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Bileşeni sil'),
        content: Text('${item.title} kaydı silinsin mi?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await repository.delete(item.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Bileşen silindi.')));
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Silme işlemi başarısız: $error')));
    }
  }
}

class _InsightPanel extends StatelessWidget {
  const _InsightPanel({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 230),
      padding: const EdgeInsets.all(16),
      decoration: _panelDecoration(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 19, color: MarkaKalkanTheme.blue),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: MarkaKalkanTheme.navy,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _SmallEmptyText extends StatelessWidget {
  const _SmallEmptyText(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Color(0xFF8A969E),
          fontSize: 12,
          height: 1.4,
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final normalized = label.toLowerCase();
    final isCritical =
        normalized.contains('kritik') ||
        normalized.contains('çok yüksek') ||
        normalized.contains('sızıntı');
    final isPositive =
        normalized.contains('aktif') ||
        normalized.contains('düşük') ||
        normalized.contains('doğrulandı');

    final background = isCritical
        ? const Color(0xFFFFECEA)
        : isPositive
        ? const Color(0xFFE7F8EE)
        : const Color(0xFFFFF5E4);
    final foreground = isCritical
        ? const Color(0xFFD64545)
        : isPositive
        ? const Color(0xFF15804A)
        : const Color(0xFFB56A00);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: foreground,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _IconBubble extends StatelessWidget {
  const _IconBubble(this.icon);

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: const Color(0xFFE8F6F4),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Icon(icon, color: MarkaKalkanTheme.teal),
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(36),
      decoration: _panelDecoration(),
      child: Column(
        children: [
          const Icon(
            Icons.inventory_2_outlined,
            size: 50,
            color: MarkaKalkanTheme.teal,
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(
              color: MarkaKalkanTheme.navy,
              fontSize: 19,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF687580)),
          ),
        ],
      ),
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(24),
        decoration: _panelDecoration(),
        child: Text(message, style: const TextStyle(color: Colors.redAccent)),
      ),
    );
  }
}

BoxDecoration _panelDecoration() {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(18),
    border: Border.all(color: const Color(0xFFE0E7EC)),
    boxShadow: const [
      BoxShadow(color: Color(0x0C000000), blurRadius: 18, offset: Offset(0, 8)),
    ],
  );
}

String _date(DateTime value) {
  final local = value.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  return '$day.$month.${local.year}';
}

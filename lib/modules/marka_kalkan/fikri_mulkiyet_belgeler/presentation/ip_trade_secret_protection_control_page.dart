import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:markakalkan/core/theme/markakalkan_theme.dart';

import '../constants/ip_trade_secret_detail_enums.dart';
import '../models/ip_trade_secret_model.dart';
import '../models/ip_trade_secret_protection_control_model.dart';
import '../repositories/ip_trade_secret_protection_control_repository.dart';
import '../repositories/ip_trade_secret_repository.dart';

class IpTradeSecretProtectionControlPage extends StatefulWidget {
  const IpTradeSecretProtectionControlPage({super.key});

  @override
  State<IpTradeSecretProtectionControlPage> createState() =>
      _IpTradeSecretProtectionControlPageState();
}

class _IpTradeSecretProtectionControlPageState
    extends State<IpTradeSecretProtectionControlPage> {
  IpTradeSecretRepository? _secretRepository;
  IpTradeSecretProtectionControlRepository? _controlRepository;
  final ScrollController _tableScrollController = ScrollController();

  String _search = '';

  int _filterResetVersion = 0;
  String? _tradeSecretId;
  IpTradeSecretProtectionControlCategory? _category;
  IpTradeSecretProtectionControlStatus? _status;
  _ControlDomain? _domain;
  _EffectivenessFilter? _effectiveness;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _secretRepository = IpTradeSecretRepository.instance(tenantId: user.uid);
      _controlRepository = IpTradeSecretProtectionControlRepository.instance(
        tenantId: user.uid,
      );
    }
  }

  @override
  void dispose() {
    _tableScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final secretRepository = _secretRepository;
    final controlRepository = _controlRepository;

    if (user == null || secretRepository == null || controlRepository == null) {
      return const Scaffold(
        body: Center(
          child: Text('Koruma kontrollerini açmak için oturum açılmalıdır.'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: MarkaKalkanTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text(
          'Koruma Kontrolleri',
          style: TextStyle(
            color: MarkaKalkanTheme.navy,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: StreamBuilder<List<IpTradeSecretModel>>(
        stream: secretRepository.watchAll(),
        builder: (context, secretSnapshot) {
          if (secretSnapshot.hasError) {
            return _ErrorPanel(
              'Formül kayıtları yüklenemedi: ${secretSnapshot.error}',
            );
          }

          final secrets = secretSnapshot.data ?? const <IpTradeSecretModel>[];

          return StreamBuilder<List<IpTradeSecretProtectionControlModel>>(
            stream: controlRepository.watch(tradeSecretId: _tradeSecretId),
            builder: (context, controlSnapshot) {
              if (controlSnapshot.connectionState == ConnectionState.waiting &&
                  !controlSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              if (controlSnapshot.hasError) {
                return _ErrorPanel(
                  'Koruma kontrolleri yüklenemedi: ${controlSnapshot.error}',
                );
              }

              final all =
                  controlSnapshot.data ??
                  const <IpTradeSecretProtectionControlModel>[];
              final filtered = all
                  .where((item) => _matches(item, secrets))
                  .toList(growable: false);
              final secretMap = <String, IpTradeSecretModel>{
                for (final secret in secrets) secret.id: secret,
              };

              return SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1480),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _Header(
                          total: all.length,
                          visible: filtered.length,
                          onCreate: () => _openCreateDialog(
                            actorId: user.uid,
                            secrets: secrets,
                            repository: controlRepository,
                          ),
                        ),
                        const SizedBox(height: 18),
                        _KpiGrid(items: _metrics(all)),
                        const SizedBox(height: 18),
                        _Filters(
                          key: ValueKey('filters-$_filterResetVersion'),
                          search: _search,
                          tradeSecretId: _tradeSecretId,
                          category: _category,
                          status: _status,
                          domain: _domain,
                          effectiveness: _effectiveness,
                          secrets: secrets,
                          onSearch: (value) => setState(() => _search = value),
                          onSecret: (value) =>
                              setState(() => _tradeSecretId = value),
                          onCategory: (value) =>
                              setState(() => _category = value),
                          onStatus: (value) => setState(() => _status = value),
                          onDomain: (value) => setState(() => _domain = value),
                          onEffectiveness: (value) =>
                              setState(() => _effectiveness = value),
                          onClear: _clearFilters,
                        ),
                        const SizedBox(height: 18),
                        _AlertStrip(controls: all),
                        const SizedBox(height: 18),
                        if (filtered.isEmpty)
                          _EmptyPanel(
                            hasRecords: all.isNotEmpty,
                            onCreate: () => _openCreateDialog(
                              actorId: user.uid,
                              secrets: secrets,
                              repository: controlRepository,
                            ),
                            onClear: _clearFilters,
                          )
                        else
                          LayoutBuilder(
                            builder: (context, constraints) {
                              if (constraints.maxWidth >= 1120) {
                                return _ControlTable(
                                  controls: filtered,
                                  secretMap: secretMap,
                                  scrollController: _tableScrollController,
                                  onOpen: (item) => _openDetails(
                                    item,
                                    secretMap[item.tradeSecretId],
                                    controlRepository,
                                  ),
                                );
                              }
                              return _ControlCards(
                                controls: filtered,
                                secretMap: secretMap,
                                onOpen: (item) => _openDetails(
                                  item,
                                  secretMap[item.tradeSecretId],
                                  controlRepository,
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  List<_Metric> _metrics(List<IpTradeSecretProtectionControlModel> controls) {
    return [
      _Metric(
        'Toplam Kontrol',
        controls.length,
        Icons.verified_user_outlined,
        const Color(0xFFE8F2FA),
        const Color(0xFF28658F),
      ),
      _Metric(
        'Aktif Kontrol',
        controls.where((item) => item.isActive).length,
        Icons.shield_outlined,
        const Color(0xFFE3F5F2),
        const Color(0xFF14796D),
      ),
      _Metric(
        'Etkili Kontrol',
        controls.where((item) => item.isEffective).length,
        Icons.task_alt_outlined,
        const Color(0xFFE8F6EA),
        const Color(0xFF34733C),
      ),
      _Metric(
        'Süresi Geçen',
        controls
            .where((item) => item.isOverdueForTest || item.isOverdueForReview)
            .length,
        Icons.event_busy_outlined,
        const Color(0xFFFFF0DF),
        const Color(0xFFAA5E12),
      ),
      _Metric(
        'İyileştirme Gereken',
        controls
            .where(
              (item) =>
                  item.remediationRequired ||
                  item.status ==
                      IpTradeSecretProtectionControlStatus.remediationRequired,
            )
            .length,
        Icons.build_circle_outlined,
        const Color(0xFFF1EAFE),
        const Color(0xFF6D3FA0),
      ),
      _Metric(
        'Acil İnceleme',
        controls.where((item) => item.requiresImmediateReview).length,
        Icons.warning_amber_rounded,
        const Color(0xFFFFE8E6),
        const Color(0xFFB7372E),
      ),
    ];
  }

  bool _matches(
    IpTradeSecretProtectionControlModel item,
    List<IpTradeSecretModel> secrets,
  ) {
    IpTradeSecretModel? secret;
    for (final candidate in secrets) {
      if (candidate.id == item.tradeSecretId) {
        secret = candidate;
        break;
      }
    }

    final query = _search.trim().toLowerCase();
    final textMatches =
        query.isEmpty ||
        item.controlCode.toLowerCase().contains(query) ||
        item.name.toLowerCase().contains(query) ||
        item.ownerUserId.toLowerCase().contains(query) ||
        (item.ownerDepartmentId ?? '').toLowerCase().contains(query) ||
        (item.controlObjective ?? '').toLowerCase().contains(query) ||
        (secret?.secretCode ?? '').toLowerCase().contains(query) ||
        (secret?.title ?? '').toLowerCase().contains(query);

    final effectivenessMatches = switch (_effectiveness) {
      null => true,
      _EffectivenessFilter.effective => item.isEffective,
      _EffectivenessFilter.partiallyEffective =>
        item.status == IpTradeSecretProtectionControlStatus.partiallyEffective,
      _EffectivenessFilter.ineffective =>
        item.status == IpTradeSecretProtectionControlStatus.ineffective ||
            item.testPassed == false,
      _EffectivenessFilter.incomplete => _isIncomplete(item),
      _EffectivenessFilter.overdue =>
        item.isOverdueForTest || item.isOverdueForReview,
      _EffectivenessFilter.remediation =>
        item.remediationRequired ||
            item.status ==
                IpTradeSecretProtectionControlStatus.remediationRequired,
      _EffectivenessFilter.urgent => item.requiresImmediateReview,
    };

    return textMatches &&
        (_tradeSecretId == null || item.tradeSecretId == _tradeSecretId) &&
        (_category == null || item.category == _category) &&
        (_status == null || item.status == _status) &&
        (_domain == null || _domainFor(item.category) == _domain) &&
        effectivenessMatches;
  }

  bool _isIncomplete(IpTradeSecretProtectionControlModel item) {
    final noDocuments =
        item.procedureDocumentIds.isEmpty &&
        item.policyDocumentIds.isEmpty &&
        item.evidenceDocumentIds.isEmpty &&
        item.testDocumentIds.isEmpty;

    return noDocuments ||
        (item.controlObjective ?? '').trim().isEmpty ||
        (item.scopeDescription ?? '').trim().isEmpty ||
        item.nextTestAt == null ||
        item.nextReviewAt == null ||
        item.designEffectivenessScore == 0 ||
        item.operatingEffectivenessScore == 0 ||
        item.coverageScore == 0;
  }

  void _clearFilters() {
    setState(() {
      _search = '';
      _tradeSecretId = null;
      _category = null;
      _status = null;
      _domain = null;
      _effectiveness = null;
      _filterResetVersion++;
    });
  }

  Future<void> _openCreateDialog({
    required String actorId,
    required List<IpTradeSecretModel> secrets,
    required IpTradeSecretProtectionControlRepository repository,
  }) async {
    if (secrets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Önce Formül ve Bileşen Envanteri içinde bir kayıt oluşturun.',
          ),
        ),
      );
      return;
    }

    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _CreateControlDialog(
        actorId: actorId,
        secrets: secrets,
        repository: repository,
      ),
    );

    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Koruma kontrolü oluşturuldu.')),
      );
    }
  }

  Future<void> _openDetails(
    IpTradeSecretProtectionControlModel item,
    IpTradeSecretModel? secret,
    IpTradeSecretProtectionControlRepository repository,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => _DetailsDialog(
        item: item,
        secret: secret,
        onDelete: () async {
          final confirmed = await showDialog<bool>(
            context: dialogContext,
            builder: (confirmContext) => AlertDialog(
              title: const Text('Kontrolü sil'),
              content: Text(
                '${item.controlCode} — ${item.name} kalıcı olarak silinsin mi?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(confirmContext, false),
                  child: const Text('Vazgeç'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.red.shade700,
                  ),
                  onPressed: () => Navigator.pop(confirmContext, true),
                  child: const Text('Sil'),
                ),
              ],
            ),
          );

          if (confirmed != true) return;
          await repository.delete(item.id);
          if (dialogContext.mounted) Navigator.pop(dialogContext);
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.total,
    required this.visible,
    required this.onCreate,
  });

  final int total;
  final int visible;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [MarkaKalkanTheme.navy, Color(0xFF17445A)],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 760;
          final text = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Koruma Kontrolleri Merkezi',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 25,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Fiziksel, dijital, sözleşmesel ve operasyonel korumaları; '
                'sahiplik, kanıt, test, etkinlik, kapsam ve iyileştirme '
                'boyutlarıyla yönetin.',
                style: TextStyle(color: Color(0xFFDDEAF0), height: 1.5),
              ),
              const SizedBox(height: 12),
              Text(
                '$total kayıt • $visible görünür kontrol',
                style: const TextStyle(
                  color: Color(0xFF8ED9CF),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          );

          final button = FilledButton.icon(
            onPressed: onCreate,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: MarkaKalkanTheme.navy,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
            ),
            icon: const Icon(Icons.add_circle_outline),
            label: const Text('Yeni Koruma Kontrolü'),
          );

          return compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [text, const SizedBox(height: 18), button],
                )
              : Row(
                  children: [
                    Expanded(child: text),
                    const SizedBox(width: 24),
                    button,
                  ],
                );
        },
      ),
    );
  }
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.items});

  final List<_Metric> items;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 620
            ? 1
            : constraints.maxWidth < 980
            ? 2
            : 3;
        const gap = 14.0;
        final width = (constraints.maxWidth - (columns - 1) * gap) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: items
              .map(
                (item) => SizedBox(
                  width: width,
                  child: Container(
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
                                style: const TextStyle(
                                  color: Color(0xFF65727C),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                item.value.toString(),
                                style: const TextStyle(
                                  color: MarkaKalkanTheme.navy,
                                  fontSize: 25,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
              .toList(growable: false),
        );
      },
    );
  }
}

class _Filters extends StatelessWidget {
  const _Filters({
    super.key,
    required this.search,
    required this.tradeSecretId,
    required this.category,
    required this.status,
    required this.domain,
    required this.effectiveness,
    required this.secrets,
    required this.onSearch,
    required this.onSecret,
    required this.onCategory,
    required this.onStatus,
    required this.onDomain,
    required this.onEffectiveness,
    required this.onClear,
  });

  final String search;
  final String? tradeSecretId;
  final IpTradeSecretProtectionControlCategory? category;
  final IpTradeSecretProtectionControlStatus? status;
  final _ControlDomain? domain;
  final _EffectivenessFilter? effectiveness;
  final List<IpTradeSecretModel> secrets;
  final ValueChanged<String> onSearch;
  final ValueChanged<String?> onSecret;
  final ValueChanged<IpTradeSecretProtectionControlCategory?> onCategory;
  final ValueChanged<IpTradeSecretProtectionControlStatus?> onStatus;
  final ValueChanged<_ControlDomain?> onDomain;
  final ValueChanged<_EffectivenessFilter?> onEffectiveness;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _panelDecoration(),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 760;
          final width = compact
              ? constraints.maxWidth
              : (constraints.maxWidth - 28) / 3;

          return Wrap(
            spacing: 14,
            runSpacing: 14,
            children: [
              SizedBox(
                width: compact ? constraints.maxWidth : width * 2 + 14,
                child: TextFormField(
                  key: ValueKey(search),
                  initialValue: search,
                  onChanged: onSearch,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    labelText: 'Kod, kontrol, sahip, ekip veya formül ara',
                  ),
                ),
              ),
              SizedBox(
                width: width,
                child: DropdownButtonFormField<String?>(
                  key: ValueKey('secret-filter-$tradeSecretId'),
                  initialValue: tradeSecretId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Formül / Ticari Sır',
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Tümü'),
                    ),
                    ...secrets.map(
                      (item) => DropdownMenuItem<String?>(
                        value: item.id,
                        child: Text(
                          '${item.secretCode} — ${item.title}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                  onChanged: onSecret,
                ),
              ),
              SizedBox(
                width: width,
                child: DropdownButtonFormField<_ControlDomain?>(
                  key: ValueKey('domain-filter-$domain'),
                  initialValue: domain,
                  decoration: const InputDecoration(labelText: 'Kontrol Alanı'),
                  items: [
                    const DropdownMenuItem<_ControlDomain?>(
                      value: null,
                      child: Text('Tümü'),
                    ),
                    ..._ControlDomain.values.map(
                      (item) => DropdownMenuItem<_ControlDomain?>(
                        value: item,
                        child: Text(item.label),
                      ),
                    ),
                  ],
                  onChanged: onDomain,
                ),
              ),
              SizedBox(
                width: width,
                child:
                    DropdownButtonFormField<
                      IpTradeSecretProtectionControlCategory?
                    >(
                      key: ValueKey('category-filter-$category'),
                      initialValue: category,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Kategori'),
                      items: [
                        const DropdownMenuItem<
                          IpTradeSecretProtectionControlCategory?
                        >(value: null, child: Text('Tümü')),
                        ...IpTradeSecretProtectionControlCategory.values.map(
                          (item) =>
                              DropdownMenuItem<
                                IpTradeSecretProtectionControlCategory?
                              >(
                                value: item,
                                child: Text(
                                  item.label,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                        ),
                      ],
                      onChanged: onCategory,
                    ),
              ),
              SizedBox(
                width: width,
                child:
                    DropdownButtonFormField<
                      IpTradeSecretProtectionControlStatus?
                    >(
                      key: ValueKey('status-filter-$status'),
                      initialValue: status,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Uygulama Durumu',
                      ),
                      items: [
                        const DropdownMenuItem<
                          IpTradeSecretProtectionControlStatus?
                        >(value: null, child: Text('Tümü')),
                        ...IpTradeSecretProtectionControlStatus.values.map(
                          (item) =>
                              DropdownMenuItem<
                                IpTradeSecretProtectionControlStatus?
                              >(value: item, child: Text(item.label)),
                        ),
                      ],
                      onChanged: onStatus,
                    ),
              ),
              SizedBox(
                width: width,
                child: DropdownButtonFormField<_EffectivenessFilter?>(
                  key: ValueKey('effectiveness-filter-$effectiveness'),
                  initialValue: effectiveness,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Etkinlik / Öncelik',
                  ),
                  items: [
                    const DropdownMenuItem<_EffectivenessFilter?>(
                      value: null,
                      child: Text('Tümü'),
                    ),
                    ..._EffectivenessFilter.values.map(
                      (item) => DropdownMenuItem<_EffectivenessFilter?>(
                        value: item,
                        child: Text(item.label),
                      ),
                    ),
                  ],
                  onChanged: onEffectiveness,
                ),
              ),
              OutlinedButton.icon(
                onPressed: onClear,
                icon: const Icon(Icons.filter_alt_off_outlined),
                label: const Text('Filtreleri Temizle'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _AlertStrip extends StatelessWidget {
  const _AlertStrip({required this.controls});

  final List<IpTradeSecretProtectionControlModel> controls;

  @override
  Widget build(BuildContext context) {
    final items = [
      (
        'Süresi geçen',
        controls
            .where((item) => item.isOverdueForTest || item.isOverdueForReview)
            .length,
        Icons.schedule_outlined,
      ),
      (
        'Etkisiz',
        controls
            .where(
              (item) =>
                  item.status ==
                      IpTradeSecretProtectionControlStatus.ineffective ||
                  item.testPassed == false,
            )
            .length,
        Icons.gpp_bad_outlined,
      ),
      (
        'Açık bulgu',
        controls.fold<int>(0, (total, item) => total + item.openFindingCount),
        Icons.rule_folder_outlined,
      ),
      (
        'Yüksek kalan risk',
        controls.where((item) => item.residualRiskScore >= 80).length,
        Icons.crisis_alert_outlined,
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _panelDecoration(),
      child: Wrap(
        spacing: 24,
        runSpacing: 14,
        children: items
            .map(
              (item) => SizedBox(
                width: 245,
                child: Row(
                  children: [
                    Icon(item.$3, color: Colors.deepOrange.shade700),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        item.$1,
                        style: const TextStyle(
                          color: Color(0xFF687580),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      item.$2.toString(),
                      style: TextStyle(
                        color: Colors.deepOrange.shade700,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}

class _ControlTable extends StatelessWidget {
  const _ControlTable({
    required this.controls,
    required this.secretMap,
    required this.scrollController,
    required this.onOpen,
  });

  final List<IpTradeSecretProtectionControlModel> controls;
  final Map<String, IpTradeSecretModel> secretMap;
  final ScrollController scrollController;
  final ValueChanged<IpTradeSecretProtectionControlModel> onOpen;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _panelDecoration(),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Scrollbar(
          controller: scrollController,
          thumbVisibility: true,
          trackVisibility: true,
          interactive: true,
          scrollbarOrientation: ScrollbarOrientation.bottom,
          child: SingleChildScrollView(
            controller: scrollController,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(bottom: 14),
            child: DataTable(
              dataRowMinHeight: 68,
              dataRowMaxHeight: 76,
              headingRowColor: const WidgetStatePropertyAll(Color(0xFFF3F7F9)),
              columns: const [
                DataColumn(label: Text('Kontrol')),
                DataColumn(label: Text('Alan / Kategori')),
                DataColumn(label: Text('Durum')),
                DataColumn(label: Text('Sahip / Ekip')),
                DataColumn(label: Text('Etkinlik')),
                DataColumn(label: Text('Kapsama')),
                DataColumn(label: Text('Sonraki İnceleme')),
                DataColumn(label: Text('Öncelik')),
                DataColumn(label: Text('')),
              ],
              rows: controls
                  .map((item) {
                    final secret = secretMap[item.tradeSecretId];
                    final effectiveness = _effectivenessScore(item);

                    return DataRow(
                      cells: [
                        DataCell(
                          SizedBox(
                            width: 230,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${item.controlCode} — ${item.name}',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: MarkaKalkanTheme.navy,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(
                                  secret == null
                                      ? item.tradeSecretId
                                      : '${secret.secretCode} — ${secret.title}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Color(0xFF829099),
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        DataCell(
                          SizedBox(
                            width: 180,
                            child: Text(
                              '${_domainFor(item.category).label}\n'
                              '${item.category.label}',
                            ),
                          ),
                        ),
                        DataCell(_StatusBadge(item.status)),
                        DataCell(
                          SizedBox(
                            width: 165,
                            child: Text(
                              '${item.ownerUserId}\n'
                              '${item.ownerDepartmentId ?? "Ekip belirtilmedi"}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        DataCell(_Score(value: effectiveness)),
                        DataCell(_Score(value: item.coverageScore)),
                        DataCell(Text(_date(item.nextReviewAt))),
                        DataCell(_PriorityBadge(item)),
                        DataCell(
                          IconButton(
                            tooltip: 'Ayrıntıları aç',
                            onPressed: () => onOpen(item),
                            icon: const Icon(Icons.open_in_new_outlined),
                          ),
                        ),
                      ],
                    );
                  })
                  .toList(growable: false),
            ),
          ),
        ),
      ),
    );
  }
}

class _ControlCards extends StatelessWidget {
  const _ControlCards({
    required this.controls,
    required this.secretMap,
    required this.onOpen,
  });

  final List<IpTradeSecretProtectionControlModel> controls;
  final Map<String, IpTradeSecretModel> secretMap;
  final ValueChanged<IpTradeSecretProtectionControlModel> onOpen;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: controls
          .map((item) {
            final secret = secretMap[item.tradeSecretId];
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => onOpen(item),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: _panelDecoration(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${item.controlCode} — ${item.name}',
                              style: const TextStyle(
                                color: MarkaKalkanTheme.navy,
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          _PriorityBadge(item),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        secret == null
                            ? item.tradeSecretId
                            : '${secret.secretCode} — ${secret.title}',
                        style: const TextStyle(color: Color(0xFF7A8892)),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _Chip(_domainFor(item.category).label),
                          _Chip(item.category.label),
                          _Chip(item.type.label),
                          _StatusBadge(item.status),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: _MiniScore(
                              label: 'Etkinlik',
                              value: _effectivenessScore(item),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _MiniScore(
                              label: 'Kapsama',
                              value: item.coverageScore,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _MiniScore(
                              label: 'Kalan Risk',
                              value: item.residualRiskScore,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Sahip: ${item.ownerUserId} • '
                        'Ekip: ${item.ownerDepartmentId ?? "Belirtilmedi"}',
                        style: const TextStyle(
                          color: Color(0xFF66737C),
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        'Sonraki test: ${_date(item.nextTestAt)} • '
                        'Sonraki inceleme: ${_date(item.nextReviewAt)}',
                        style: const TextStyle(
                          color: Color(0xFF829099),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          })
          .toList(growable: false),
    );
  }
}

class _DetailsDialog extends StatelessWidget {
  const _DetailsDialog({
    required this.item,
    required this.secret,
    required this.onDelete,
  });

  final IpTradeSecretProtectionControlModel item;
  final IpTradeSecretModel? secret;
  final Future<void> Function() onDelete;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('${item.controlCode} — ${item.name}'),
      content: SizedBox(
        width: 820,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _StatusBadge(item.status),
                  _Chip(item.type.label),
                  _Chip(item.category.label),
                  _PriorityBadge(item),
                ],
              ),
              const SizedBox(height: 16),
              _Section('Kimlik ve Sorumluluk', [
                _Line(
                  'Formül / Ticari Sır',
                  secret == null
                      ? item.tradeSecretId
                      : '${secret!.secretCode} — ${secret!.title}',
                ),
                _Line('Kontrol Sahibi', item.ownerUserId),
                _Line('Sorumlu Ekip', item.ownerDepartmentId ?? 'Belirtilmedi'),
                _Line('Uygulama Tarihi', _date(item.implementedAt)),
                _Line('Sıklık', item.frequency.label),
                _Line('Otomasyon', item.automated ? 'Otomatik' : 'Manuel'),
              ]),
              const SizedBox(height: 12),
              _Section('Amaç ve Kapsam', [
                _Line('Kontrol Amacı', item.controlObjective ?? 'Belirtilmedi'),
                _Line(
                  'Uygulama',
                  item.implementationDescription ?? 'Belirtilmedi',
                ),
                _Line('Kapsam', item.scopeDescription ?? 'Belirtilmedi'),
                _Line('Koruma Kapsamı', _coverage(item)),
                _Line('Bileşenler', _join(item.componentIds)),
                _Line('Sistemler', _join(item.systemIds)),
                _Line('Lokasyonlar', _join(item.locationCodes)),
                _Line('Tedarikçiler', _join(item.supplierOrganizationIds)),
              ]),
              const SizedBox(height: 12),
              _Section('Etkinlik, Risk ve Bulgular', [
                _Line(
                  'Tasarım Etkinliği',
                  '${item.designEffectivenessScore} / 100',
                ),
                _Line(
                  'Operasyonel Etkinlik',
                  '${item.operatingEffectivenessScore} / 100',
                ),
                _Line('Kapsama', '${item.coverageScore} / 100'),
                _Line('Kalan Risk', '${item.residualRiskScore} / 100'),
                _Line(
                  'Test Sonucu',
                  item.testPassed == null
                      ? 'Test edilmedi'
                      : item.testPassed!
                      ? 'Başarılı'
                      : 'Başarısız',
                ),
                _Line(
                  'Toplam / Açık Bulgu',
                  '${item.findingCount} / ${item.openFindingCount}',
                ),
              ]),
              const SizedBox(height: 12),
              _Section('Takvim', [
                _Line('Son Test', _date(item.lastTestedAt)),
                _Line('Sonraki Test', _date(item.nextTestAt)),
                _Line('Son İnceleme', _date(item.lastReviewedAt)),
                _Line('Sonraki İnceleme', _date(item.nextReviewAt)),
              ]),
              const SizedBox(height: 12),
              _Section('Kanıt ve Belgeler', [
                _Line('Prosedür Belgeleri', _join(item.procedureDocumentIds)),
                _Line('Politika Belgeleri', _join(item.policyDocumentIds)),
                _Line('Kanıt Belgeleri', _join(item.evidenceDocumentIds)),
                _Line('Test Belgeleri', _join(item.testDocumentIds)),
              ]),
              if (item.remediationRequired) ...[
                const SizedBox(height: 12),
                _Section('İyileştirme', [
                  _Line(
                    'Sorumlu',
                    item.remediationOwnerUserId ?? 'Belirtilmedi',
                  ),
                  _Line('Son Tarih', _date(item.remediationDueAt)),
                  _Line('Plan', item.remediationPlan ?? 'Belirtilmedi'),
                ]),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton.icon(
          onPressed: onDelete,
          style: TextButton.styleFrom(foregroundColor: Colors.red.shade700),
          icon: const Icon(Icons.delete_outline),
          label: const Text('Sil'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Kapat'),
        ),
      ],
    );
  }
}

class _CreateControlDialog extends StatefulWidget {
  const _CreateControlDialog({
    required this.actorId,
    required this.secrets,
    required this.repository,
  });

  final String actorId;
  final List<IpTradeSecretModel> secrets;
  final IpTradeSecretProtectionControlRepository repository;

  @override
  State<_CreateControlDialog> createState() => _CreateControlDialogState();
}

class _CreateControlDialogState extends State<_CreateControlDialog> {
  final _formKey = GlobalKey<FormState>();
  final _code = TextEditingController();
  final _name = TextEditingController();
  final _owner = TextEditingController();
  final _department = TextEditingController();
  final _objective = TextEditingController();
  final _implementation = TextEditingController();
  final _scope = TextEditingController();
  final _componentIds = TextEditingController();
  final _procedureIds = TextEditingController();
  final _policyIds = TextEditingController();
  final _evidenceIds = TextEditingController();
  final _testIds = TextEditingController();
  final _systemIds = TextEditingController();
  final _locationCodes = TextEditingController();
  final _supplierIds = TextEditingController();
  final _remediationOwner = TextEditingController();
  final _remediationPlan = TextEditingController();
  final _notes = TextEditingController();

  late String _tradeSecretId;
  IpTradeSecretProtectionControlType _type =
      IpTradeSecretProtectionControlType.preventive;
  IpTradeSecretProtectionControlCategory _category =
      IpTradeSecretProtectionControlCategory.accessControl;
  IpTradeSecretProtectionControlStatus _status =
      IpTradeSecretProtectionControlStatus.active;
  IpTradeSecretProtectionControlFrequency _frequency =
      IpTradeSecretProtectionControlFrequency.continuous;

  bool _automated = false;
  bool _preventive = true;
  bool _detective = false;
  bool _corrective = false;
  bool _remediationRequired = false;
  bool _saving = false;
  bool? _testPassed;

  int _design = 70;
  int _operating = 70;
  int _coverageScore = 70;
  int _residualRisk = 30;
  int _findingCount = 0;
  int _openFindingCount = 0;

  late DateTime _implementedAt;
  DateTime? _lastTestedAt;
  DateTime? _nextTestAt;
  DateTime? _lastReviewedAt;
  DateTime? _nextReviewAt;
  DateTime? _remediationDueAt;

  @override
  void initState() {
    super.initState();
    _tradeSecretId = widget.secrets.first.id;
    _owner.text = widget.actorId;
    _implementedAt = DateTime.now().toUtc();
  }

  @override
  void dispose() {
    for (final controller in [
      _code,
      _name,
      _owner,
      _department,
      _objective,
      _implementation,
      _scope,
      _componentIds,
      _procedureIds,
      _policyIds,
      _evidenceIds,
      _testIds,
      _systemIds,
      _locationCodes,
      _supplierIds,
      _remediationOwner,
      _remediationPlan,
      _notes,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Yeni Koruma Kontrolü'),
      content: SizedBox(
        width: 920,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _FormSection('Kontrol Kimliği', [
                  _fields([
                    DropdownButtonFormField<String>(
                      initialValue: _tradeSecretId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Formül / Ticari Sır *',
                      ),
                      items: widget.secrets
                          .map(
                            (item) => DropdownMenuItem(
                              value: item.id,
                              child: Text(
                                '${item.secretCode} — ${item.title}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _tradeSecretId = value);
                        }
                      },
                    ),
                    TextFormField(
                      controller: _code,
                      decoration: const InputDecoration(
                        labelText: 'Kontrol Kodu *',
                      ),
                      validator: _required,
                    ),
                    TextFormField(
                      controller: _name,
                      decoration: const InputDecoration(
                        labelText: 'Kontrol Adı *',
                      ),
                      validator: _required,
                    ),
                  ]),
                  const SizedBox(height: 12),
                  _fields([
                    DropdownButtonFormField<IpTradeSecretProtectionControlType>(
                      initialValue: _type,
                      decoration: const InputDecoration(
                        labelText: 'Kontrol Türü *',
                      ),
                      items: IpTradeSecretProtectionControlType.values
                          .map(
                            (item) => DropdownMenuItem(
                              value: item,
                              child: Text(item.label),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: (value) {
                        if (value != null) setState(() => _type = value);
                      },
                    ),
                    DropdownButtonFormField<
                      IpTradeSecretProtectionControlCategory
                    >(
                      initialValue: _category,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Kategori *',
                      ),
                      items: IpTradeSecretProtectionControlCategory.values
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
                      onChanged: (value) {
                        if (value != null) setState(() => _category = value);
                      },
                    ),
                    DropdownButtonFormField<
                      IpTradeSecretProtectionControlStatus
                    >(
                      initialValue: _status,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Uygulama Durumu *',
                      ),
                      items:
                          const [
                                IpTradeSecretProtectionControlStatus.planned,
                                IpTradeSecretProtectionControlStatus
                                    .implementing,
                                IpTradeSecretProtectionControlStatus.active,
                                IpTradeSecretProtectionControlStatus
                                    .partiallyEffective,
                                IpTradeSecretProtectionControlStatus
                                    .remediationRequired,
                              ]
                              .map(
                                (item) => DropdownMenuItem(
                                  value: item,
                                  child: Text(item.label),
                                ),
                              )
                              .toList(growable: false),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _status = value;
                            if (value ==
                                IpTradeSecretProtectionControlStatus
                                    .remediationRequired) {
                              _remediationRequired = true;
                            }
                          });
                        }
                      },
                    ),
                  ]),
                ]),
                const SizedBox(height: 12),
                _FormSection('Sahiplik ve Sorumluluk', [
                  _fields([
                    TextFormField(
                      controller: _owner,
                      decoration: const InputDecoration(
                        labelText: 'Kontrol Sahibi *',
                      ),
                      validator: _required,
                    ),
                    TextFormField(
                      controller: _department,
                      decoration: const InputDecoration(
                        labelText: 'Sorumlu Ekip / Birim',
                      ),
                    ),
                    DropdownButtonFormField<
                      IpTradeSecretProtectionControlFrequency
                    >(
                      initialValue: _frequency,
                      decoration: const InputDecoration(labelText: 'Sıklık *'),
                      items: IpTradeSecretProtectionControlFrequency.values
                          .map(
                            (item) => DropdownMenuItem(
                              value: item,
                              child: Text(item.label),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: (value) {
                        if (value != null) setState(() => _frequency = value);
                      },
                    ),
                  ]),
                ]),
                const SizedBox(height: 12),
                _FormSection('Amaç ve Kapsam', [
                  TextFormField(
                    controller: _objective,
                    decoration: const InputDecoration(
                      labelText: 'Kontrol Amacı',
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _implementation,
                    decoration: const InputDecoration(
                      labelText: 'Uygulama Açıklaması',
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _scope,
                    decoration: const InputDecoration(
                      labelText: 'Kapsam Açıklaması',
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilterChip(
                        selected: _preventive,
                        label: const Text('Önleyici'),
                        onSelected: (value) =>
                            setState(() => _preventive = value),
                      ),
                      FilterChip(
                        selected: _detective,
                        label: const Text('Tespit Edici'),
                        onSelected: (value) =>
                            setState(() => _detective = value),
                      ),
                      FilterChip(
                        selected: _corrective,
                        label: const Text('Düzeltici'),
                        onSelected: (value) =>
                            setState(() => _corrective = value),
                      ),
                      FilterChip(
                        selected: _automated,
                        label: const Text('Otomatik'),
                        onSelected: (value) =>
                            setState(() => _automated = value),
                      ),
                    ],
                  ),
                ]),
                const SizedBox(height: 12),
                _FormSection('Bağlantılar ve Belgeler', [
                  _fields([
                    TextFormField(
                      controller: _componentIds,
                      decoration: const InputDecoration(
                        labelText: 'Bileşen Kimlikleri',
                        hintText: 'Virgülle ayırın',
                      ),
                    ),
                    TextFormField(
                      controller: _systemIds,
                      decoration: const InputDecoration(
                        labelText: 'Sistem Kimlikleri',
                      ),
                    ),
                    TextFormField(
                      controller: _locationCodes,
                      decoration: const InputDecoration(
                        labelText: 'Lokasyon Kodları',
                      ),
                    ),
                  ]),
                  const SizedBox(height: 10),
                  _fields([
                    TextFormField(
                      controller: _procedureIds,
                      decoration: const InputDecoration(
                        labelText: 'Prosedür Belgeleri',
                      ),
                    ),
                    TextFormField(
                      controller: _policyIds,
                      decoration: const InputDecoration(
                        labelText: 'Politika Belgeleri',
                      ),
                    ),
                    TextFormField(
                      controller: _evidenceIds,
                      decoration: const InputDecoration(
                        labelText: 'Kanıt Belgeleri',
                      ),
                    ),
                  ]),
                  const SizedBox(height: 10),
                  _fields([
                    TextFormField(
                      controller: _testIds,
                      decoration: const InputDecoration(
                        labelText: 'Test Belgeleri',
                      ),
                    ),
                    TextFormField(
                      controller: _supplierIds,
                      decoration: const InputDecoration(
                        labelText: 'Tedarikçi Kimlikleri',
                      ),
                    ),
                  ]),
                ]),
                const SizedBox(height: 12),
                _FormSection('Doğrulama ve İnceleme Takvimi', [
                  _fields([
                    _DateField(
                      label: 'Uygulama Tarihi *',
                      value: _implementedAt,
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _implementedAt = value);
                        }
                      },
                    ),
                    _DateField(
                      label: 'Son Test',
                      value: _lastTestedAt,
                      allowClear: true,
                      onChanged: (value) =>
                          setState(() => _lastTestedAt = value),
                    ),
                    _DateField(
                      label: 'Sonraki Test',
                      value: _nextTestAt,
                      allowClear: true,
                      onChanged: (value) => setState(() => _nextTestAt = value),
                    ),
                  ]),
                  const SizedBox(height: 10),
                  _fields([
                    _DateField(
                      label: 'Son İnceleme',
                      value: _lastReviewedAt,
                      allowClear: true,
                      onChanged: (value) =>
                          setState(() => _lastReviewedAt = value),
                    ),
                    _DateField(
                      label: 'Sonraki İnceleme',
                      value: _nextReviewAt,
                      allowClear: true,
                      onChanged: (value) =>
                          setState(() => _nextReviewAt = value),
                    ),
                    DropdownButtonFormField<bool?>(
                      initialValue: _testPassed,
                      decoration: const InputDecoration(
                        labelText: 'Test Sonucu',
                      ),
                      items: const [
                        DropdownMenuItem<bool?>(
                          value: null,
                          child: Text('Test edilmedi'),
                        ),
                        DropdownMenuItem<bool?>(
                          value: true,
                          child: Text('Başarılı'),
                        ),
                        DropdownMenuItem<bool?>(
                          value: false,
                          child: Text('Başarısız'),
                        ),
                      ],
                      onChanged: (value) => setState(() => _testPassed = value),
                    ),
                  ]),
                ]),
                const SizedBox(height: 12),
                _FormSection('Skorlar', [
                  _ScoreEditor(
                    label: 'Tasarım Etkinliği',
                    value: _design,
                    onChanged: (value) => setState(() => _design = value),
                  ),
                  _ScoreEditor(
                    label: 'Operasyonel Etkinlik',
                    value: _operating,
                    onChanged: (value) => setState(() => _operating = value),
                  ),
                  _ScoreEditor(
                    label: 'Kapsama',
                    value: _coverageScore,
                    onChanged: (value) =>
                        setState(() => _coverageScore = value),
                  ),
                  _ScoreEditor(
                    label: 'Kalan Risk',
                    value: _residualRisk,
                    onChanged: (value) => setState(() => _residualRisk = value),
                  ),
                ]),
                const SizedBox(height: 12),
                _FormSection('Bulgular ve İyileştirme', [
                  _fields([
                    _CountEditor(
                      label: 'Toplam Bulgu',
                      value: _findingCount,
                      onChanged: (value) =>
                          setState(() => _findingCount = value),
                    ),
                    _CountEditor(
                      label: 'Açık Bulgu',
                      value: _openFindingCount,
                      onChanged: (value) =>
                          setState(() => _openFindingCount = value),
                    ),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('İyileştirme gerekli'),
                      value: _remediationRequired,
                      onChanged: (value) =>
                          setState(() => _remediationRequired = value),
                    ),
                  ]),
                  if (_remediationRequired) ...[
                    const SizedBox(height: 10),
                    _fields([
                      TextFormField(
                        controller: _remediationOwner,
                        decoration: const InputDecoration(
                          labelText: 'İyileştirme Sorumlusu *',
                        ),
                        validator: (value) =>
                            _remediationRequired ? _required(value) : null,
                      ),
                      _DateField(
                        label: 'İyileştirme Son Tarihi *',
                        value: _remediationDueAt,
                        onChanged: (value) =>
                            setState(() => _remediationDueAt = value),
                      ),
                    ]),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _remediationPlan,
                      decoration: const InputDecoration(
                        labelText: 'İyileştirme Planı *',
                      ),
                      maxLines: 2,
                      validator: (value) =>
                          _remediationRequired ? _required(value) : null,
                    ),
                  ],
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _notes,
                    decoration: const InputDecoration(labelText: 'Notlar'),
                    maxLines: 2,
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('Vazgeç'),
        ),
        FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox(
                  width: 17,
                  height: 17,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_outlined),
          label: Text(_saving ? 'Kaydediliyor' : 'Kaydet'),
        ),
      ],
    );
  }

  Widget _fields(List<Widget> fields) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth < 720
            ? constraints.maxWidth
            : (constraints.maxWidth - (fields.length - 1) * 12) / fields.length;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: fields
              .map((field) => SizedBox(width: width, child: field))
              .toList(growable: false),
        );
      },
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_preventive && !_detective && !_corrective) {
      _error('En az bir koruma kapsamı seçilmelidir.');
      return;
    }

    if (_openFindingCount > _findingCount) {
      _error('Açık bulgu sayısı toplam bulgu sayısından fazla olamaz.');
      return;
    }

    if (_testPassed != null && _lastTestedAt == null) {
      _error('Test sonucu varsa son test tarihi zorunludur.');
      return;
    }

    if (_remediationRequired && _remediationDueAt == null) {
      _error('İyileştirme son tarihi zorunludur.');
      return;
    }

    final secret = widget.secrets.firstWhere(
      (item) => item.id == _tradeSecretId,
    );

    setState(() => _saving = true);

    try {
      final now = DateTime.now().toUtc();
      final model = IpTradeSecretProtectionControlModel(
        id: '',
        tenantId: widget.actorId,
        brandId: secret.brandId,
        tradeSecretId: secret.id,
        componentIds: _split(_componentIds.text),
        controlCode: _code.text.trim(),
        name: _name.text.trim(),
        type: _type,
        category: _category,
        status: _status,
        frequency: _frequency,
        ownerUserId: _owner.text.trim(),
        ownerDepartmentId: _nullable(_department.text),
        implementationDescription: _nullable(_implementation.text),
        controlObjective: _nullable(_objective.text),
        scopeDescription: _nullable(_scope.text),
        procedureDocumentIds: _split(_procedureIds.text),
        policyDocumentIds: _split(_policyIds.text),
        evidenceDocumentIds: _split(_evidenceIds.text),
        testDocumentIds: _split(_testIds.text),
        systemIds: _split(_systemIds.text),
        locationCodes: _split(_locationCodes.text),
        supplierOrganizationIds: _split(_supplierIds.text),
        automated: _automated,
        preventiveCoverage: _preventive,
        detectiveCoverage: _detective,
        correctiveCoverage: _corrective,
        implementedAt: _implementedAt.toUtc(),
        lastTestedAt: _lastTestedAt?.toUtc(),
        nextTestAt: _nextTestAt?.toUtc(),
        lastReviewedAt: _lastReviewedAt?.toUtc(),
        nextReviewAt: _nextReviewAt?.toUtc(),
        testPassed: _testPassed,
        designEffectivenessScore: _design,
        operatingEffectivenessScore: _operating,
        coverageScore: _coverageScore,
        residualRiskScore: _residualRisk,
        findingCount: _findingCount,
        openFindingCount: _openFindingCount,
        remediationRequired: _remediationRequired,
        remediationDueAt: _remediationDueAt?.toUtc(),
        remediationOwnerUserId: _remediationRequired
            ? _nullable(_remediationOwner.text)
            : null,
        remediationPlan: _remediationRequired
            ? _nullable(_remediationPlan.text)
            : null,
        notes: _nullable(_notes.text),
        createdAt: now,
        createdBy: widget.actorId,
      );

      await widget.repository.create(model);
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(() => _saving = false);
        _error('Koruma kontrolü oluşturulamadı: $error');
      }
    }
  }

  void _error(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onChanged,
    this.allowClear = false,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  final bool allowClear;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(labelText: label),
      child: Row(
        children: [
          Expanded(child: Text(_date(value))),
          if (allowClear && value != null)
            IconButton(
              tooltip: 'Temizle',
              onPressed: () => onChanged(null),
              icon: const Icon(Icons.close, size: 18),
            ),
          IconButton(
            tooltip: 'Tarih seç',
            onPressed: () async {
              final selected = await showDatePicker(
                context: context,
                initialDate: value?.toLocal() ?? DateTime.now(),
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
              );
              if (selected != null) {
                onChanged(
                  DateTime.utc(selected.year, selected.month, selected.day),
                );
              }
            },
            icon: const Icon(Icons.calendar_month_outlined),
          ),
        ],
      ),
    );
  }
}

class _ScoreEditor extends StatelessWidget {
  const _ScoreEditor({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 185, child: Text(label)),
        Expanded(
          child: Slider(
            value: value.toDouble(),
            min: 0,
            max: 100,
            divisions: 20,
            label: value.toString(),
            onChanged: (newValue) => onChanged(newValue.round()),
          ),
        ),
        SizedBox(
          width: 45,
          child: Text(
            value.toString(),
            textAlign: TextAlign.end,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
      ],
    );
  }
}

class _CountEditor extends StatelessWidget {
  const _CountEditor({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(labelText: label),
      child: Row(
        children: [
          IconButton(
            onPressed: value > 0 ? () => onChanged(value - 1) : null,
            icon: const Icon(Icons.remove_circle_outline),
          ),
          Expanded(
            child: Text(
              value.toString(),
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          IconButton(
            onPressed: () => onChanged(value + 1),
            icon: const Icon(Icons.add_circle_outline),
          ),
        ],
      ),
    );
  }
}

class _FormSection extends StatelessWidget {
  const _FormSection(this.title, this.children);

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E9ED)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: MarkaKalkanTheme.navy,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title, this.children);

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFB),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFFE2E9ED)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: MarkaKalkanTheme.navy,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 175,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF7C8992),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: SelectableText(value)),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge(this.status);

  final IpTradeSecretProtectionControlStatus status;

  @override
  Widget build(BuildContext context) {
    final critical =
        status == IpTradeSecretProtectionControlStatus.ineffective ||
        status == IpTradeSecretProtectionControlStatus.remediationRequired;
    final positive = status == IpTradeSecretProtectionControlStatus.active;

    return _Badge(
      status.label,
      critical
          ? const Color(0xFFFFE9E7)
          : positive
          ? const Color(0xFFE5F7F1)
          : const Color(0xFFEAF2FA),
      critical
          ? const Color(0xFFB52D24)
          : positive
          ? const Color(0xFF14745E)
          : const Color(0xFF356A95),
    );
  }
}

class _PriorityBadge extends StatelessWidget {
  const _PriorityBadge(this.item);

  final IpTradeSecretProtectionControlModel item;

  @override
  Widget build(BuildContext context) {
    if (item.requiresImmediateReview) {
      return const _Badge(
        'Acil İnceleme',
        Color(0xFFFFE9E7),
        Color(0xFFB52D24),
      );
    }
    if (item.isEffective) {
      return const _Badge('Etkili', Color(0xFFE5F7F1), Color(0xFF14745E));
    }
    return const _Badge('İzleniyor', Color(0xFFEAF2FA), Color(0xFF356A95));
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return _Badge(label, const Color(0xFFF0F4F6), const Color(0xFF52616A));
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.label, this.background, this.foreground);

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _Score extends StatelessWidget {
  const _Score({required this.value});

  final int value;

  @override
  Widget build(BuildContext context) {
    final color = value >= 70
        ? Colors.green.shade700
        : value >= 40
        ? Colors.orange.shade800
        : Colors.red.shade700;
    return SizedBox(
      width: 90,
      child: Row(
        children: [
          Expanded(
            child: LinearProgressIndicator(
              value: value / 100,
              minHeight: 7,
              color: color,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(width: 7),
          Text(
            value.toString(),
            style: TextStyle(color: color, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _MiniScore extends StatelessWidget {
  const _MiniScore({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label: $value', style: const TextStyle(fontSize: 11)),
        const SizedBox(height: 5),
        LinearProgressIndicator(
          value: value / 100,
          minHeight: 7,
          borderRadius: BorderRadius.circular(10),
        ),
      ],
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({
    required this.hasRecords,
    required this.onCreate,
    required this.onClear,
  });

  final bool hasRecords;
  final VoidCallback onCreate;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(42),
      decoration: _panelDecoration(),
      child: Column(
        children: [
          const Icon(
            Icons.verified_user_outlined,
            size: 55,
            color: MarkaKalkanTheme.teal,
          ),
          const SizedBox(height: 12),
          Text(
            hasRecords
                ? 'Filtreye uygun kontrol bulunamadı'
                : 'Henüz koruma kontrolü oluşturulmadı',
            style: const TextStyle(
              color: MarkaKalkanTheme.navy,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 16),
          if (hasRecords)
            OutlinedButton.icon(
              onPressed: onClear,
              icon: const Icon(Icons.filter_alt_off_outlined),
              label: const Text('Filtreleri Temizle'),
            )
          else
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add),
              label: const Text('İlk Kontrolü Oluştur'),
            ),
        ],
      ),
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel(this.message);

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

class _Metric {
  const _Metric(
    this.title,
    this.value,
    this.icon,
    this.background,
    this.foreground,
  );

  final String title;
  final int value;
  final IconData icon;
  final Color background;
  final Color foreground;
}

enum _ControlDomain {
  physical('Fiziksel'),
  digital('Dijital'),
  contractual('Sözleşmesel'),
  operational('Operasyonel');

  const _ControlDomain(this.label);
  final String label;
}

enum _EffectivenessFilter {
  effective('Etkili'),
  partiallyEffective('Kısmen Etkili'),
  ineffective('Etkisiz'),
  incomplete('Eksik'),
  overdue('Süresi Geçen'),
  remediation('İyileştirme Gereken'),
  urgent('Acil İnceleme');

  const _EffectivenessFilter(this.label);
  final String label;
}

_ControlDomain _domainFor(IpTradeSecretProtectionControlCategory category) {
  return switch (category) {
    IpTradeSecretProtectionControlCategory.physicalSecurity =>
      _ControlDomain.physical,
    IpTradeSecretProtectionControlCategory.contractualProtection =>
      _ControlDomain.contractual,
    IpTradeSecretProtectionControlCategory.accessControl ||
    IpTradeSecretProtectionControlCategory.identityManagement ||
    IpTradeSecretProtectionControlCategory.encryption ||
    IpTradeSecretProtectionControlCategory.dataLossPrevention ||
    IpTradeSecretProtectionControlCategory.loggingMonitoring ||
    IpTradeSecretProtectionControlCategory.secureDevelopment ||
    IpTradeSecretProtectionControlCategory.backupRecovery =>
      _ControlDomain.digital,
    _ => _ControlDomain.operational,
  };
}

int _effectivenessScore(IpTradeSecretProtectionControlModel item) {
  return ((item.designEffectivenessScore + item.operatingEffectivenessScore) /
          2)
      .round();
}

String _date(DateTime? value) {
  if (value == null) return 'Belirtilmedi';
  final local = value.toLocal();
  return '${local.day.toString().padLeft(2, '0')}.'
      '${local.month.toString().padLeft(2, '0')}.'
      '${local.year}';
}

String _join(List<String> values) {
  return values.isEmpty ? 'Belirtilmedi' : values.join(', ');
}

String _coverage(IpTradeSecretProtectionControlModel item) {
  final values = <String>[];
  if (item.preventiveCoverage) values.add('Önleyici');
  if (item.detectiveCoverage) values.add('Tespit Edici');
  if (item.correctiveCoverage) values.add('Düzeltici');
  return values.isEmpty ? 'Belirtilmedi' : values.join(', ');
}

List<String> _split(String value) {
  return value
      .split(',')
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toSet()
      .toList(growable: false);
}

String? _nullable(String value) {
  final cleaned = value.trim();
  return cleaned.isEmpty ? null : cleaned;
}

String? _required(String? value) {
  return value == null || value.trim().isEmpty ? 'Bu alan zorunludur.' : null;
}

BoxDecoration _panelDecoration() {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(18),
    border: Border.all(color: const Color(0xFFE0E7EB)),
    boxShadow: const [
      BoxShadow(color: Color(0x0B152633), blurRadius: 18, offset: Offset(0, 6)),
    ],
  );
}

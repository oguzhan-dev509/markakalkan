import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:markakalkan/core/theme/markakalkan_theme.dart';

import '../constants/ip_enums.dart';
import '../constants/ip_trade_secret_detail_enums.dart';
import '../models/ip_trade_secret_access_grant_model.dart';
import '../models/ip_trade_secret_disclosure_model.dart';
import '../models/ip_trade_secret_model.dart';
import '../repositories/ip_trade_secret_access_grant_repository.dart';
import '../repositories/ip_trade_secret_disclosure_repository.dart';
import '../repositories/ip_trade_secret_repository.dart';

class IpTradeSecretAccessDisclosurePage extends StatefulWidget {
  const IpTradeSecretAccessDisclosurePage({super.key});

  @override
  State<IpTradeSecretAccessDisclosurePage> createState() =>
      _IpTradeSecretAccessDisclosurePageState();
}

class _IpTradeSecretAccessDisclosurePageState
    extends State<IpTradeSecretAccessDisclosurePage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  IpTradeSecretRepository? _secretRepo;
  IpTradeSecretAccessGrantRepository? _accessRepo;
  IpTradeSecretDisclosureRepository? _disclosureRepo;

  String _search = '';
  String? _tradeSecretId;
  IpTradeSecretAccessGrantStatus? _accessStatus;
  IpTradeSecretDisclosureStatus? _disclosureStatus;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _secretRepo = IpTradeSecretRepository.instance(tenantId: user.uid);
      _accessRepo = IpTradeSecretAccessGrantRepository.instance(
        tenantId: user.uid,
      );
      _disclosureRepo = IpTradeSecretDisclosureRepository.instance(
        tenantId: user.uid,
      );
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null ||
        _secretRepo == null ||
        _accessRepo == null ||
        _disclosureRepo == null) {
      return const Scaffold(
        body: Center(child: Text('Bu sayfa için oturum açmanız gerekir.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Erişim ve İfşa Sicili'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(
              icon: Icon(Icons.admin_panel_settings_outlined),
              text: 'Erişim Yetkileri',
            ),
            Tab(icon: Icon(Icons.ios_share_outlined), text: 'İfşa Kayıtları'),
          ],
        ),
      ),
      body: StreamBuilder<List<IpTradeSecretModel>>(
        stream: _secretRepo!.watchAll(),
        builder: (context, secretSnapshot) {
          if (secretSnapshot.hasError) {
            return _ErrorPanel(
              'Formül kayıtları yüklenemedi: ${secretSnapshot.error}',
            );
          }

          final secrets = secretSnapshot.data ?? const <IpTradeSecretModel>[];

          return TabBarView(
            controller: _tabs,
            children: [
              _AccessView(
                secrets: secrets,
                repository: _accessRepo!,
                actorId: user.uid,
                tradeSecretId: _tradeSecretId,
                search: _search,
                status: _accessStatus,
                onTradeSecretChanged: (value) =>
                    setState(() => _tradeSecretId = value),
                onSearchChanged: (value) => setState(() => _search = value),
                onStatusChanged: (value) =>
                    setState(() => _accessStatus = value),
              ),
              _DisclosureView(
                secrets: secrets,
                repository: _disclosureRepo!,
                actorId: user.uid,
                tradeSecretId: _tradeSecretId,
                search: _search,
                status: _disclosureStatus,
                onTradeSecretChanged: (value) =>
                    setState(() => _tradeSecretId = value),
                onSearchChanged: (value) => setState(() => _search = value),
                onStatusChanged: (value) =>
                    setState(() => _disclosureStatus = value),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _AccessView extends StatelessWidget {
  const _AccessView({
    required this.secrets,
    required this.repository,
    required this.actorId,
    required this.tradeSecretId,
    required this.search,
    required this.status,
    required this.onTradeSecretChanged,
    required this.onSearchChanged,
    required this.onStatusChanged,
  });

  final List<IpTradeSecretModel> secrets;
  final IpTradeSecretAccessGrantRepository repository;
  final String actorId;
  final String? tradeSecretId;
  final String search;
  final IpTradeSecretAccessGrantStatus? status;
  final ValueChanged<String?> onTradeSecretChanged;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<IpTradeSecretAccessGrantStatus?> onStatusChanged;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<IpTradeSecretAccessGrantModel>>(
      stream: repository.watch(tradeSecretId: tradeSecretId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _ErrorPanel('Erişim kayıtları yüklenemedi: ${snapshot.error}');
        }

        final all = snapshot.data ?? const <IpTradeSecretAccessGrantModel>[];
        final query = search.trim().toLowerCase();
        final filtered = all.where((item) {
          final matchesText =
              query.isEmpty ||
              item.grantCode.toLowerCase().contains(query) ||
              item.subjectName.toLowerCase().contains(query);
          final matchesStatus = status == null || item.status == status;
          return matchesText && matchesStatus;
        }).toList();

        return _RegistryPage(
          title: 'Erişim Yetkileri',
          subtitle:
              'Kimlerin hangi formül veya bileşene hangi kapsam ve dayanakla erişebildiğini yönetin.',
          actionLabel: 'Yeni Erişim Yetkisi',
          onAction: () => _showAccessDialog(
            context,
            actorId: actorId,
            secrets: secrets,
            repository: repository,
          ),
          metrics: [
            _Metric('Toplam Yetki', all.length, Icons.badge_outlined),
            _Metric(
              'Aktif',
              all.where((item) => item.isActive).length,
              Icons.verified_user_outlined,
            ),
            _Metric(
              'Acil İnceleme',
              all.where((item) => item.requiresImmediateReview).length,
              Icons.warning_amber_rounded,
            ),
            _Metric(
              'Hukuki Dayanaklı',
              all.where((item) => item.hasLegalFoundation).length,
              Icons.gavel_outlined,
            ),
            _Metric(
              'Hassas İşlem',
              all.where((item) => item.grantsSensitiveOperations).length,
              Icons.download_outlined,
            ),
            _Metric(
              'Süresi Dolan',
              all.where((item) => item.isExpired).length,
              Icons.timer_off_outlined,
            ),
          ],
          filters: _AccessFilters(
            secrets: secrets,
            tradeSecretId: tradeSecretId,
            search: search,
            status: status,
            onTradeSecretChanged: onTradeSecretChanged,
            onSearchChanged: onSearchChanged,
            onStatusChanged: onStatusChanged,
          ),
          body: filtered.isEmpty
              ? const _EmptyPanel(
                  'Erişim kaydı bulunamadı',
                  'Yeni erişim yetkisi oluşturarak sicili başlatın.',
                )
              : _AccessTable(filtered),
        );
      },
    );
  }
}

class _DisclosureView extends StatelessWidget {
  const _DisclosureView({
    required this.secrets,
    required this.repository,
    required this.actorId,
    required this.tradeSecretId,
    required this.search,
    required this.status,
    required this.onTradeSecretChanged,
    required this.onSearchChanged,
    required this.onStatusChanged,
  });

  final List<IpTradeSecretModel> secrets;
  final IpTradeSecretDisclosureRepository repository;
  final String actorId;
  final String? tradeSecretId;
  final String search;
  final IpTradeSecretDisclosureStatus? status;
  final ValueChanged<String?> onTradeSecretChanged;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<IpTradeSecretDisclosureStatus?> onStatusChanged;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<IpTradeSecretDisclosureModel>>(
      stream: repository.watch(tradeSecretId: tradeSecretId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _ErrorPanel('İfşa kayıtları yüklenemedi: ${snapshot.error}');
        }

        final all = snapshot.data ?? const <IpTradeSecretDisclosureModel>[];
        final query = search.trim().toLowerCase();
        final filtered = all.where((item) {
          final matchesText =
              query.isEmpty ||
              item.disclosureCode.toLowerCase().contains(query) ||
              item.recipientName.toLowerCase().contains(query);
          final matchesStatus = status == null || item.status == status;
          return matchesText && matchesStatus;
        }).toList();

        return _RegistryPage(
          title: 'İfşa Kayıtları',
          subtitle:
              'Ticari sır paylaşımlarını alıcı, kanal, amaç, onay ve koruma tedbirleriyle kalıcı sicilde tutun.',
          actionLabel: 'Yeni İfşa Kaydı',
          onAction: () => _showDisclosureDialog(
            context,
            actorId: actorId,
            secrets: secrets,
            repository: repository,
          ),
          metrics: [
            _Metric('Toplam İfşa', all.length, Icons.ios_share_outlined),
            _Metric(
              'Tamamlanan',
              all.where((item) => item.isCompleted).length,
              Icons.check_circle_outline,
            ),
            _Metric(
              'Harici Alıcı',
              all.where((item) => item.isExternalDisclosure).length,
              Icons.public_outlined,
            ),
            _Metric(
              'Acil İnceleme',
              all.where((item) => item.requiresImmediateReview).length,
              Icons.warning_amber_rounded,
            ),
            _Metric(
              'Hukuki Dayanaklı',
              all.where((item) => item.hasLegalFoundation).length,
              Icons.gavel_outlined,
            ),
            _Metric(
              'Sınır Ötesi',
              all.where((item) => item.crossBorderTransfer).length,
              Icons.flight_takeoff_outlined,
            ),
          ],
          filters: _DisclosureFilters(
            secrets: secrets,
            tradeSecretId: tradeSecretId,
            search: search,
            status: status,
            onTradeSecretChanged: onTradeSecretChanged,
            onSearchChanged: onSearchChanged,
            onStatusChanged: onStatusChanged,
          ),
          body: filtered.isEmpty
              ? const _EmptyPanel(
                  'İfşa kaydı bulunamadı',
                  'Yeni ifşa kaydı oluşturarak paylaşım sicilini başlatın.',
                )
              : _DisclosureTable(filtered),
        );
      },
    );
  }
}

class _RegistryPage extends StatelessWidget {
  const _RegistryPage({
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onAction,
    required this.metrics,
    required this.filters,
    required this.body,
  });

  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onAction;
  final List<_Metric> metrics;
  final Widget filters;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1500),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 760;
                  final heading = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: MarkaKalkanTheme.navy,
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: Color(0xFF687580),
                          height: 1.45,
                        ),
                      ),
                    ],
                  );
                  final button = FilledButton.icon(
                    onPressed: onAction,
                    icon: const Icon(Icons.add_rounded),
                    label: Text(actionLabel),
                  );
                  return compact
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            heading,
                            const SizedBox(height: 14),
                            button,
                          ],
                        )
                      : Row(
                          children: [
                            Expanded(child: heading),
                            const SizedBox(width: 18),
                            button,
                          ],
                        );
                },
              ),
              const SizedBox(height: 18),
              _MetricsGrid(metrics),
              const SizedBox(height: 18),
              filters,
              const SizedBox(height: 14),
              body,
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricsGrid extends StatelessWidget {
  const _MetricsGrid(this.items);

  final List<_Metric> items;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 650
            ? 1
            : constraints.maxWidth < 1000
            ? 2
            : 3;
        const gap = 14.0;
        final width = (constraints.maxWidth - ((columns - 1) * gap)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: items
              .map(
                (item) => SizedBox(
                  width: width,
                  child: _Panel(
                    child: Row(
                      children: [
                        _IconBox(item.icon),
                        const SizedBox(width: 14),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              style: const TextStyle(
                                color: Color(0xFF687580),
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              '${item.value}',
                              style: const TextStyle(
                                color: MarkaKalkanTheme.navy,
                                fontSize: 25,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _AccessFilters extends StatelessWidget {
  const _AccessFilters({
    required this.secrets,
    required this.tradeSecretId,
    required this.search,
    required this.status,
    required this.onTradeSecretChanged,
    required this.onSearchChanged,
    required this.onStatusChanged,
  });

  final List<IpTradeSecretModel> secrets;
  final String? tradeSecretId;
  final String search;
  final IpTradeSecretAccessGrantStatus? status;
  final ValueChanged<String?> onTradeSecretChanged;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<IpTradeSecretAccessGrantStatus?> onStatusChanged;

  @override
  Widget build(BuildContext context) {
    return _Filters(
      children: [
        TextFormField(
          key: ValueKey('access-$search'),
          initialValue: search,
          onChanged: onSearchChanged,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            labelText: 'Yetki kodu veya kişi adı ara',
          ),
        ),
        _SecretFilter(
          secrets: secrets,
          value: tradeSecretId,
          onChanged: onTradeSecretChanged,
        ),
        DropdownButtonFormField<IpTradeSecretAccessGrantStatus?>(
          initialValue: status,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Durum'),
          items: [
            const DropdownMenuItem(value: null, child: Text('Tümü')),
            ...IpTradeSecretAccessGrantStatus.values.map(
              (item) => DropdownMenuItem(value: item, child: Text(item.label)),
            ),
          ],
          onChanged: onStatusChanged,
        ),
      ],
    );
  }
}

class _DisclosureFilters extends StatelessWidget {
  const _DisclosureFilters({
    required this.secrets,
    required this.tradeSecretId,
    required this.search,
    required this.status,
    required this.onTradeSecretChanged,
    required this.onSearchChanged,
    required this.onStatusChanged,
  });

  final List<IpTradeSecretModel> secrets;
  final String? tradeSecretId;
  final String search;
  final IpTradeSecretDisclosureStatus? status;
  final ValueChanged<String?> onTradeSecretChanged;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<IpTradeSecretDisclosureStatus?> onStatusChanged;

  @override
  Widget build(BuildContext context) {
    return _Filters(
      children: [
        TextFormField(
          key: ValueKey('disclosure-$search'),
          initialValue: search,
          onChanged: onSearchChanged,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            labelText: 'İfşa kodu veya alıcı adı ara',
          ),
        ),
        _SecretFilter(
          secrets: secrets,
          value: tradeSecretId,
          onChanged: onTradeSecretChanged,
        ),
        DropdownButtonFormField<IpTradeSecretDisclosureStatus?>(
          initialValue: status,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Durum'),
          items: [
            const DropdownMenuItem(value: null, child: Text('Tümü')),
            ...IpTradeSecretDisclosureStatus.values.map(
              (item) => DropdownMenuItem(value: item, child: Text(item.label)),
            ),
          ],
          onChanged: onStatusChanged,
        ),
      ],
    );
  }
}

class _SecretFilter extends StatelessWidget {
  const _SecretFilter({
    required this.secrets,
    required this.value,
    required this.onChanged,
  });

  final List<IpTradeSecretModel> secrets;
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String?>(
      initialValue: value,
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'Formül / Ticari Sır'),
      items: [
        const DropdownMenuItem(value: null, child: Text('Tümü')),
        ...secrets.map(
          (item) => DropdownMenuItem(
            value: item.id,
            child: Text(
              '${item.secretCode} — ${item.title}',
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
      onChanged: onChanged,
    );
  }
}

class _Filters extends StatelessWidget {
  const _Filters({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 860;
          final width = compact
              ? constraints.maxWidth
              : (constraints.maxWidth - 24) / 3;
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: children
                .map((child) => SizedBox(width: width, child: child))
                .toList(),
          );
        },
      ),
    );
  }
}

class _AccessTable extends StatelessWidget {
  const _AccessTable(this.items);

  final List<IpTradeSecretAccessGrantModel> items;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Yetki Kodu')),
            DataColumn(label: Text('Kişi / Birim')),
            DataColumn(label: Text('Tür')),
            DataColumn(label: Text('Erişim')),
            DataColumn(label: Text('Dayanak')),
            DataColumn(label: Text('Durum')),
            DataColumn(label: Text('Hukuki Koruma')),
            DataColumn(label: Text('Risk')),
          ],
          rows: items
              .map(
                (item) => DataRow(
                  cells: [
                    DataCell(Text(item.grantCode)),
                    DataCell(Text(item.subjectName)),
                    DataCell(Text(item.subjectType.label)),
                    DataCell(_Badge(item.accessLevel.label)),
                    DataCell(Text(item.grantBasis.label)),
                    DataCell(_Badge(item.status.label)),
                    DataCell(
                      _Badge(item.hasLegalFoundation ? 'Mevcut' : 'Eksik'),
                    ),
                    DataCell(Text('${item.accessRiskScore} / 100')),
                  ],
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

class _DisclosureTable extends StatelessWidget {
  const _DisclosureTable(this.items);

  final List<IpTradeSecretDisclosureModel> items;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('İfşa Kodu')),
            DataColumn(label: Text('Alıcı')),
            DataColumn(label: Text('Alıcı Türü')),
            DataColumn(label: Text('Kanal')),
            DataColumn(label: Text('Amaç')),
            DataColumn(label: Text('Durum')),
            DataColumn(label: Text('Koruma')),
            DataColumn(label: Text('Risk')),
          ],
          rows: items
              .map(
                (item) => DataRow(
                  cells: [
                    DataCell(Text(item.disclosureCode)),
                    DataCell(Text(item.recipientName)),
                    DataCell(Text(item.recipientType.label)),
                    DataCell(Text(item.channel.label)),
                    DataCell(Text(item.purpose.label)),
                    DataCell(_Badge(item.status.label)),
                    DataCell(
                      _Badge(item.hasLegalFoundation ? 'Mevcut' : 'Eksik'),
                    ),
                    DataCell(Text('${item.disclosureRiskScore} / 100')),
                  ],
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

Future<void> _showAccessDialog(
  BuildContext context, {
  required String actorId,
  required List<IpTradeSecretModel> secrets,
  required IpTradeSecretAccessGrantRepository repository,
}) async {
  if (secrets.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Önce bir formül kaydı oluşturun.')),
    );
    return;
  }

  final code = TextEditingController();
  final subjectId = TextEditingController();
  final subjectName = TextEditingController();
  final reason = TextEditingController();

  var secret = secrets.first;
  var subjectType = IpTradeSecretAccessSubjectType.employee;
  var accessLevel = IpAccessLevel.controlledView;
  var status = IpTradeSecretAccessGrantStatus.active;
  var basis = IpTradeSecretAccessGrantBasis.confidentialityAgreement;
  var downloadAllowed = false;
  var printAllowed = false;
  var exportAllowed = false;
  var watermarkRequired = true;

  final saved = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: const Text('Yeni Erişim Yetkisi'),
        content: SizedBox(
          width: 650,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _SecretDropdown(
                  secrets: secrets,
                  value: secret,
                  onChanged: (value) => setDialogState(() => secret = value),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: code,
                  decoration: const InputDecoration(labelText: 'Yetki kodu'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: subjectId,
                  decoration: const InputDecoration(
                    labelText: 'Kişi / birim kimliği',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: subjectName,
                  decoration: const InputDecoration(
                    labelText: 'Kişi / birim adı',
                  ),
                ),
                const SizedBox(height: 12),
                _EnumDropdown<IpTradeSecretAccessSubjectType>(
                  value: subjectType,
                  label: 'Erişen türü',
                  items: IpTradeSecretAccessSubjectType.values,
                  text: (item) => item.label,
                  onChanged: (value) =>
                      setDialogState(() => subjectType = value),
                ),
                const SizedBox(height: 12),
                _EnumDropdown<IpAccessLevel>(
                  value: accessLevel,
                  label: 'Erişim seviyesi',
                  items: IpAccessLevel.values,
                  text: (item) => item.label,
                  onChanged: (value) =>
                      setDialogState(() => accessLevel = value),
                ),
                const SizedBox(height: 12),
                _EnumDropdown<IpTradeSecretAccessGrantStatus>(
                  value: status,
                  label: 'Durum',
                  items: IpTradeSecretAccessGrantStatus.values,
                  text: (item) => item.label,
                  onChanged: (value) => setDialogState(() => status = value),
                ),
                const SizedBox(height: 12),
                _EnumDropdown<IpTradeSecretAccessGrantBasis>(
                  value: basis,
                  label: 'Dayanak',
                  items: IpTradeSecretAccessGrantBasis.values,
                  text: (item) => item.label,
                  onChanged: (value) => setDialogState(() => basis = value),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: reason,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Erişim gerekçesi',
                  ),
                ),
                CheckboxListTile(
                  value: downloadAllowed,
                  title: const Text('İndirme izni'),
                  onChanged: (value) =>
                      setDialogState(() => downloadAllowed = value ?? false),
                ),
                CheckboxListTile(
                  value: printAllowed,
                  title: const Text('Yazdırma izni'),
                  onChanged: (value) =>
                      setDialogState(() => printAllowed = value ?? false),
                ),
                CheckboxListTile(
                  value: exportAllowed,
                  title: const Text('Dışa aktarma izni'),
                  onChanged: (value) =>
                      setDialogState(() => exportAllowed = value ?? false),
                ),
                CheckboxListTile(
                  value: watermarkRequired,
                  title: const Text('Filigran zorunlu'),
                  onChanged: (value) =>
                      setDialogState(() => watermarkRequired = value ?? true),
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
                final now = DateTime.now().toUtc();
                await repository.create(
                  IpTradeSecretAccessGrantModel(
                    id: '',
                    tenantId: actorId,
                    brandId: secret.brandId,
                    tradeSecretId: secret.id,
                    grantCode: code.text.trim(),
                    subjectType: subjectType,
                    subjectId: subjectId.text.trim(),
                    subjectName: subjectName.text.trim(),
                    accessLevel: accessLevel,
                    status: status,
                    grantBasis: basis,
                    validFrom: now,
                    createdAt: now,
                    createdBy: actorId,
                    reason: reason.text.trim(),
                    downloadAllowed: downloadAllowed,
                    printAllowed: printAllowed,
                    exportAllowed: exportAllowed,
                    watermarkRequired: watermarkRequired,
                  ),
                );
                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext, true);
              } catch (error) {
                if (!dialogContext.mounted) return;
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

  code.dispose();
  subjectId.dispose();
  subjectName.dispose();
  reason.dispose();

  if (saved == true && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Erişim yetkisi oluşturuldu.')),
    );
  }
}

Future<void> _showDisclosureDialog(
  BuildContext context, {
  required String actorId,
  required List<IpTradeSecretModel> secrets,
  required IpTradeSecretDisclosureRepository repository,
}) async {
  if (secrets.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Önce bir formül kaydı oluşturun.')),
    );
    return;
  }

  final code = TextEditingController();
  final recipientId = TextEditingController();
  final recipientName = TextEditingController();
  final scope = TextEditingController();

  var secret = secrets.first;
  var recipientType = IpTradeSecretDisclosureRecipientType.supplier;
  var status = IpTradeSecretDisclosureStatus.pendingApproval;
  var channel = IpTradeSecretDisclosureChannel.securePortal;
  var purpose = IpTradeSecretDisclosurePurpose.manufacturing;
  var requiresApproval = true;
  var approvalCompleted = false;
  var watermarkApplied = true;
  var encryptedTransferUsed = true;
  var identityVerified = false;

  final saved = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: const Text('Yeni İfşa Kaydı'),
        content: SizedBox(
          width: 650,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _SecretDropdown(
                  secrets: secrets,
                  value: secret,
                  onChanged: (value) => setDialogState(() => secret = value),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: code,
                  decoration: const InputDecoration(labelText: 'İfşa kodu'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: recipientId,
                  decoration: const InputDecoration(labelText: 'Alıcı kimliği'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: recipientName,
                  decoration: const InputDecoration(labelText: 'Alıcı adı'),
                ),
                const SizedBox(height: 12),
                _EnumDropdown<IpTradeSecretDisclosureRecipientType>(
                  value: recipientType,
                  label: 'Alıcı türü',
                  items: IpTradeSecretDisclosureRecipientType.values,
                  text: (item) => item.label,
                  onChanged: (value) =>
                      setDialogState(() => recipientType = value),
                ),
                const SizedBox(height: 12),
                _EnumDropdown<IpTradeSecretDisclosureStatus>(
                  value: status,
                  label: 'Durum',
                  items: IpTradeSecretDisclosureStatus.values,
                  text: (item) => item.label,
                  onChanged: (value) => setDialogState(() => status = value),
                ),
                const SizedBox(height: 12),
                _EnumDropdown<IpTradeSecretDisclosureChannel>(
                  value: channel,
                  label: 'Kanal',
                  items: IpTradeSecretDisclosureChannel.values,
                  text: (item) => item.label,
                  onChanged: (value) => setDialogState(() => channel = value),
                ),
                const SizedBox(height: 12),
                _EnumDropdown<IpTradeSecretDisclosurePurpose>(
                  value: purpose,
                  label: 'Amaç',
                  items: IpTradeSecretDisclosurePurpose.values,
                  text: (item) => item.label,
                  onChanged: (value) => setDialogState(() => purpose = value),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: scope,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'İfşa kapsamı ve gerekçesi',
                  ),
                ),
                SwitchListTile.adaptive(
                  value: requiresApproval,
                  title: const Text('Onay gerekli'),
                  onChanged: (value) =>
                      setDialogState(() => requiresApproval = value),
                ),
                SwitchListTile.adaptive(
                  value: approvalCompleted,
                  title: const Text('Onay tamamlandı'),
                  onChanged: (value) =>
                      setDialogState(() => approvalCompleted = value),
                ),
                CheckboxListTile(
                  value: watermarkApplied,
                  title: const Text('Filigran uygulandı'),
                  onChanged: (value) =>
                      setDialogState(() => watermarkApplied = value ?? false),
                ),
                CheckboxListTile(
                  value: encryptedTransferUsed,
                  title: const Text('Şifreli aktarım kullanıldı'),
                  onChanged: (value) => setDialogState(
                    () => encryptedTransferUsed = value ?? false,
                  ),
                ),
                CheckboxListTile(
                  value: identityVerified,
                  title: const Text('Alıcı kimliği doğrulandı'),
                  onChanged: (value) =>
                      setDialogState(() => identityVerified = value ?? false),
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
                final now = DateTime.now().toUtc();
                await repository.create(
                  IpTradeSecretDisclosureModel(
                    id: '',
                    tenantId: actorId,
                    brandId: secret.brandId,
                    tradeSecretId: secret.id,
                    disclosureCode: code.text.trim(),
                    recipientType: recipientType,
                    recipientId: recipientId.text.trim(),
                    recipientName: recipientName.text.trim(),
                    status: status,
                    channel: channel,
                    purpose: purpose,
                    disclosedAt: now,
                    disclosedBy: actorId,
                    createdAt: now,
                    createdBy: actorId,
                    reason: scope.text.trim(),
                    scopeDescription: scope.text.trim(),
                    requiresApproval: requiresApproval,
                    approvalCompleted: approvalCompleted,
                    watermarkApplied: watermarkApplied,
                    encryptedTransferUsed: encryptedTransferUsed,
                    recipientIdentityVerified: identityVerified,
                  ),
                );
                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext, true);
              } catch (error) {
                if (!dialogContext.mounted) return;
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

  code.dispose();
  recipientId.dispose();
  recipientName.dispose();
  scope.dispose();

  if (saved == true && context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('İfşa kaydı oluşturuldu.')));
  }
}

class _SecretDropdown extends StatelessWidget {
  const _SecretDropdown({
    required this.secrets,
    required this.value,
    required this.onChanged,
  });

  final List<IpTradeSecretModel> secrets;
  final IpTradeSecretModel value;
  final ValueChanged<IpTradeSecretModel> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<IpTradeSecretModel>(
      initialValue: value,
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'Formül / Ticari Sır'),
      items: secrets
          .map(
            (item) => DropdownMenuItem(
              value: item,
              child: Text(
                '${item.secretCode} — ${item.title}',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(),
      onChanged: (value) {
        if (value != null) onChanged(value);
      },
    );
  }
}

class _EnumDropdown<T> extends StatelessWidget {
  const _EnumDropdown({
    required this.value,
    required this.label,
    required this.items,
    required this.text,
    required this.onChanged,
  });

  final T value;
  final String label;
  final List<T> items;
  final String Function(T) text;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: items
          .map((item) => DropdownMenuItem(value: item, child: Text(text(item))))
          .toList(),
      onChanged: (value) {
        if (value != null) onChanged(value);
      },
    );
  }
}

class _Metric {
  const _Metric(this.title, this.value, this.icon);
  final String title;
  final int value;
  final IconData icon;
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE0E7EC)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _IconBox extends StatelessWidget {
  const _IconBox(this.icon);
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: const Color(0xFFE8F6F4),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, color: MarkaKalkanTheme.teal),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    final lower = label.toLowerCase();
    final negative =
        lower.contains('eksik') ||
        lower.contains('iptal') ||
        lower.contains('süresi') ||
        lower.contains('reddedildi');
    final positive =
        lower.contains('aktif') ||
        lower.contains('mevcut') ||
        lower.contains('tamamlandı') ||
        lower.contains('onaylandı');

    final background = negative
        ? const Color(0xFFFFECEA)
        : positive
        ? const Color(0xFFE8F7EE)
        : const Color(0xFFFFF5E4);
    final foreground = negative
        ? const Color(0xFFD64545)
        : positive
        ? const Color(0xFF16824A)
        : const Color(0xFFB56A00);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
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

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel(this.title, this.message);
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 36),
        child: Column(
          children: [
            const Icon(
              Icons.fact_check_outlined,
              size: 48,
              color: MarkaKalkanTheme.teal,
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                color: MarkaKalkanTheme.navy,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF687580)),
            ),
          ],
        ),
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
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(message, style: const TextStyle(color: Colors.redAccent)),
      ),
    );
  }
}

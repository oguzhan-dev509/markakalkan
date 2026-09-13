import 'package:flutter/material.dart';

import '../data/odla_workspace_repository.dart';

class OdlaWorkspacePage extends StatefulWidget {
  const OdlaWorkspacePage({super.key, this.repository});

  final OdlaWorkspaceRepository? repository;

  @override
  State<OdlaWorkspacePage> createState() => _OdlaWorkspacePageState();
}

class _OdlaWorkspacePageState extends State<OdlaWorkspacePage> {
  late final OdlaWorkspaceRepository _repository;
  late Future<OdlaDiscoverySnapshot> _discovery;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? CallableOdlaWorkspaceRepository();
    _discovery = _repository.loadDiscovery();
  }

  void _refresh() {
    setState(() {
      _discovery = _repository.loadDiscovery();
    });
  }

  Future<void> _openCase(OdlaCaseSummary summary) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: '/odla/workspace-detail'),
        builder: (_) => _OdlaWorkspaceDetailPage(
          repository: _repository,
          summary: summary,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Orijinallik ve Laboratuvar Doğrulama'),
        actions: [
          IconButton(
            tooltip: 'Yenile',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<OdlaDiscoverySnapshot>(
        future: _discovery,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const _LoadingView(
              message: 'Yetkili ODLA çalışma alanı hazırlanıyor…',
            );
          }
          if (snapshot.hasError) {
            return _ErrorView(
              message: _safeErrorMessage(snapshot.error),
              onRetry: _refresh,
            );
          }

          final discovery = snapshot.requireData;
          return LayoutBuilder(
            builder: (context, constraints) {
              final horizontalPadding =
                  constraints.maxWidth >= 900 ? 32.0 : 16.0;
              return RefreshIndicator(
                onRefresh: () async {
                  _refresh();
                  await _discovery;
                },
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    24,
                    horizontalPadding,
                    40,
                  ),
                  children: [
                    _WorkspaceHero(discovery: discovery),
                    const SizedBox(height: 20),
                    _DiscoveryStats(discovery: discovery),
                    const SizedBox(height: 20),
                    if (discovery.cases.isEmpty)
                      _RichEmptyState(roles: discovery.roles)
                    else
                      _CaseCollection(
                        cases: discovery.cases,
                        onOpen: _openCase,
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _WorkspaceHero extends StatelessWidget {
  const _WorkspaceHero({required this.discovery});

  final OdlaDiscoverySnapshot discovery;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 760;
          final identity = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: colors.primaryContainer,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.biotech_outlined,
                      color: colors.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'ODLA Operasyon Merkezi',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                'Orijinallik ve laboratuvar doğrulama vakalarını; delil zinciri, '
                'laboratuvar talepleri ve sonuçları, bulgular ve itirazlarla '
                'birlikte tek bir yetkili çalışma alanında izleyin.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  const Chip(
                    avatar: Icon(Icons.visibility_outlined, size: 18),
                    label: Text('Salt okunur'),
                  ),
                  ...discovery.roles.map(
                    (role) => Chip(label: Text(_roleLabel(role))),
                  ),
                ],
              ),
            ],
          );

          final scope = _ScopeCard(
            tenantId: discovery.tenantId,
            brandCount: discovery.brandUids.length,
          );

          if (!wide) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                identity,
                const SizedBox(height: 20),
                scope,
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: identity),
              const SizedBox(width: 24),
              SizedBox(width: 290, child: scope),
            ],
          );
        },
      ),
    );
  }
}

class _ScopeCard extends StatelessWidget {
  const _ScopeCard({required this.tenantId, required this.brandCount});

  final String tenantId;
  final int brandCount;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Yetki kapsamı',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 10),
            _KeyValueLine(label: 'Tenant', value: _shortId(tenantId)),
            _KeyValueLine(label: 'Marka', value: '$brandCount yetkili marka'),
            const SizedBox(height: 8),
            Text(
              'Görünürlük sunucu tarafındaki read_workspace yetkisine göre belirlenir.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _DiscoveryStats extends StatelessWidget {
  const _DiscoveryStats({required this.discovery});

  final OdlaDiscoverySnapshot discovery;

  @override
  Widget build(BuildContext context) {
    final active =
        discovery.cases.where((item) => !_terminalCase(item.state)).length;
    final closed = discovery.cases.length - active;
    final stats = [
      _StatData(
        icon: Icons.folder_open_outlined,
        label: 'Görüntülenebilir vaka',
        value: '${discovery.cases.length}',
      ),
      _StatData(
        icon: Icons.hourglass_top_outlined,
        label: 'Aktif süreç',
        value: '$active',
      ),
      _StatData(
        icon: Icons.task_alt_outlined,
        label: 'Kapanmış süreç',
        value: '$closed',
      ),
      _StatData(
        icon: Icons.badge_outlined,
        label: 'Yetki rolü',
        value: '${discovery.roles.length}',
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1100
            ? 4
            : constraints.maxWidth >= 620
                ? 2
                : 1;
        const gap = 12.0;
        final width = (constraints.maxWidth - (columns - 1) * gap) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: stats
              .map(
                (stat) => SizedBox(
                  width: width,
                  child: _StatCard(data: stat),
                ),
              )
              .toList(growable: false),
        );
      },
    );
  }
}

class _StatData {
  const _StatData({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.data});

  final _StatData data;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(data.icon),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.value,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  Text(data.label),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RichEmptyState extends StatelessWidget {
  const _RichEmptyState({required this.roles});

  final List<String> roles;

  @override
  Widget build(BuildContext context) {
    final steps = const [
      _CapabilityData(
        Icons.assignment_outlined,
        'Vaka',
        'Yetkili doğrulama vakası açıldığında burada görünür.',
      ),
      _CapabilityData(
        Icons.link_outlined,
        'Delil Zinciri',
        'Numune hareketleri ve bütünlük bağlantıları kronolojik izlenir.',
      ),
      _CapabilityData(
        Icons.science_outlined,
        'Laboratuvar',
        'Test talepleri ve bağımsız laboratuvar sonuçları birlikte gösterilir.',
      ),
      _CapabilityData(
        Icons.fact_check_outlined,
        'Bulgu',
        'Kanıt-temelli bulgular ayrı ve sürümlü kayıtlar olarak izlenir.',
      ),
      _CapabilityData(
        Icons.balance_outlined,
        'İtiraz',
        'İtiraz ve ikinci laboratuvar süreçleri vaka bağlamında görünür.',
      ),
    ];

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.fact_check_outlined,
              size: 44,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 14),
            Text(
              'ODLA hazır — görüntülenebilir vaka henüz yok',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Bu alan boş bir bekleme ekranı değildir. Yetkiniz kapsamındaki '
              'ilk doğrulama vakası oluştuğunda aynı çalışma alanı vaka '
              'özetini ve tüm operasyonel doğrulama katmanlarını gösterecektir.',
            ),
            const SizedBox(height: 20),
            Text(
              'Doğrulama akışı',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 1050
                    ? 5
                    : constraints.maxWidth >= 640
                        ? 2
                        : 1;
                const gap = 12.0;
                final width =
                    (constraints.maxWidth - (columns - 1) * gap) / columns;
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: steps
                      .map(
                        (item) => SizedBox(
                          width: width,
                          child: _CapabilityCard(data: item),
                        ),
                      )
                      .toList(growable: false),
                );
              },
            ),
            if (roles.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(
                'Mevcut görünürlük rolünüz: ${roles.map(_roleLabel).join(', ')}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CapabilityData {
  const _CapabilityData(this.icon, this.title, this.description);

  final IconData icon;
  final String title;
  final String description;
}

class _CapabilityCard extends StatelessWidget {
  const _CapabilityCard({required this.data});

  final _CapabilityData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 150),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(data.icon),
          const SizedBox(height: 12),
          Text(
            data.title,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(data.description),
        ],
      ),
    );
  }
}

class _CaseCollection extends StatelessWidget {
  const _CaseCollection({
    required this.cases,
    required this.onOpen,
  });

  final List<OdlaCaseSummary> cases;
  final ValueChanged<OdlaCaseSummary> onOpen;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Yetkili vakalar',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Bir vakayı açarak operasyonel doğrulama ayrıntılarını inceleyin.',
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 1000 ? 2 : 1;
            const gap = 12.0;
            final width =
                (constraints.maxWidth - (columns - 1) * gap) / columns;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: cases
                  .map(
                    (item) => SizedBox(
                      width: width,
                      child: _CaseCard(
                        summary: item,
                        onTap: () => onOpen(item),
                      ),
                    ),
                  )
                  .toList(growable: false),
            );
          },
        ),
      ],
    );
  }
}

class _CaseCard extends StatelessWidget {
  const _CaseCard({
    required this.summary,
    required this.onTap,
  });

  final OdlaCaseSummary summary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: ValueKey('odla-case-${summary.caseId}'),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.biotech_outlined),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Vaka ${_shortId(summary.caseId)}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                  ),
                  _StatePill(state: summary.state),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (summary.countryCode != null)
                    _MetaPill(
                      icon: Icons.public,
                      text: summary.countryCode!,
                    ),
                  if (summary.productClassCode != null)
                    _MetaPill(
                      icon: Icons.category_outlined,
                      text: summary.productClassCode!,
                    ),
                  if (summary.profileCode != null)
                    _MetaPill(
                      icon: Icons.verified_outlined,
                      text: summary.profileCode!,
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Marka: ${_shortId(summary.brandUid)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OdlaWorkspaceDetailPage extends StatefulWidget {
  const _OdlaWorkspaceDetailPage({
    required this.repository,
    required this.summary,
  });

  final OdlaWorkspaceRepository repository;
  final OdlaCaseSummary summary;

  @override
  State<_OdlaWorkspaceDetailPage> createState() =>
      _OdlaWorkspaceDetailPageState();
}

class _OdlaWorkspaceDetailPageState
    extends State<_OdlaWorkspaceDetailPage> {
  late Future<OdlaWorkspaceDetail> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.repository.loadWorkspace(widget.summary);
  }

  void _retry() {
    setState(() {
      _future = widget.repository.loadWorkspace(widget.summary);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('ODLA Vaka ${_shortId(widget.summary.caseId)}'),
        actions: [
          IconButton(
            tooltip: 'Vaka ayrıntısını yenile',
            onPressed: _retry,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<OdlaWorkspaceDetail>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const _LoadingView(
              message: 'Operasyonel vaka ayrıntıları yükleniyor…',
            );
          }
          if (snapshot.hasError) {
            return _ErrorView(
              message: _safeErrorMessage(snapshot.error),
              onRetry: _retry,
            );
          }

          final detail = snapshot.requireData;
          return LayoutBuilder(
            builder: (context, constraints) {
              final horizontalPadding =
                  constraints.maxWidth >= 900 ? 32.0 : 16.0;
              return RefreshIndicator(
                onRefresh: () async {
                  _retry();
                  await _future;
                },
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    24,
                    horizontalPadding,
                    40,
                  ),
                  children: [
                    _CaseDetailHero(
                      summary: widget.summary,
                      detail: detail,
                    ),
                    const SizedBox(height: 16),
                    _OperationalCounters(detail: detail),
                    const SizedBox(height: 16),
                    const _ReadOnlyNotice(),
                    const SizedBox(height: 16),
                    _OperationalWorkspace(detail: detail),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _CaseDetailHero extends StatelessWidget {
  const _CaseDetailHero({
    required this.summary,
    required this.detail,
  });

  final OdlaCaseSummary summary;
  final OdlaWorkspaceDetail detail;

  @override
  Widget build(BuildContext context) {
    final caseId = detail.caseId.isEmpty ? summary.caseId : detail.caseId;
    final rows = <String, String>{
      'Vaka': caseId,
      'Durum': _stateLabel(detail.state),
      if (detail.countryCode != null) 'Ülke': detail.countryCode!,
      if (detail.profileCode != null)
        'Doğrulama profili': [
          detail.profileCode!,
          if (detail.profileVersion != null) 'v${detail.profileVersion}',
        ].join(' • '),
      if (detail.productClassCode != null)
        'Ürün sınıfı': detail.productClassCode!,
      if (detail.brandUid != null) 'Marka': detail.brandUid!,
      if (detail.tenantId != null) 'Tenant': detail.tenantId!,
    };

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.fact_check_outlined, size: 30),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Vaka Operasyon Görünümü',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ),
                _StatePill(state: detail.state),
              ],
            ),
            const SizedBox(height: 16),
            _ResponsiveKeyValueGrid(rows: rows),
          ],
        ),
      ),
    );
  }
}

class _OperationalCounters extends StatelessWidget {
  const _OperationalCounters({required this.detail});

  final OdlaWorkspaceDetail detail;

  @override
  Widget build(BuildContext context) {
    final data = [
      _StatData(
        icon: Icons.link_outlined,
        label: 'Delil zinciri',
        value: '${detail.custodyEvents.length}',
      ),
      _StatData(
        icon: Icons.science_outlined,
        label: 'Test talebi',
        value: '${detail.testRequests.length}',
      ),
      _StatData(
        icon: Icons.analytics_outlined,
        label: 'Test sonucu',
        value: '${detail.testResults.length}',
      ),
      _StatData(
        icon: Icons.fact_check_outlined,
        label: 'Bulgu',
        value: '${detail.findings.length}',
      ),
      _StatData(
        icon: Icons.balance_outlined,
        label: 'İtiraz',
        value: '${detail.appeals.length}',
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1180
            ? 5
            : constraints.maxWidth >= 720
                ? 3
                : constraints.maxWidth >= 440
                    ? 2
                    : 1;
        const gap = 10.0;
        final width = (constraints.maxWidth - (columns - 1) * gap) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: data
              .map(
                (item) => SizedBox(
                  width: width,
                  child: _StatCard(data: item),
                ),
              )
              .toList(growable: false),
        );
      },
    );
  }
}

class _ReadOnlyNotice extends StatelessWidget {
  const _ReadOnlyNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.visibility_outlined),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Bu çalışma alanı yalnız getOdlaVerificationWorkspace üzerinden '
              'sunucunun yetkilendirdiği read_workspace görünümünü gösterir. '
              'İstemci tarafında ODLA yazma işlemi veya doğrudan Firestore erişimi yoktur.',
            ),
          ),
        ],
      ),
    );
  }
}

class _OperationalWorkspace extends StatelessWidget {
  const _OperationalWorkspace({required this.detail});

  final OdlaWorkspaceDetail detail;

  @override
  Widget build(BuildContext context) {
    final sections = <Widget>[
      _OperationalSection(
        title: 'Delil Zinciri',
        description:
            'Numunenin teslim, taşıma, mühür ve bütünlük geçmişi kronolojik olarak izlenir.',
        icon: Icons.link_outlined,
        count: detail.custodyEvents.length,
        emptyText: 'Bu vakada henüz delil zinciri olayı bulunmuyor.',
        records: detail.custodyEvents
            .map(
              (event) => _RecordView(
                title: event.eventType ?? 'Delil zinciri olayı',
                subtitle: [
                  if (event.eventSequence != null) '#${event.eventSequence}',
                  if (event.sampleId != null)
                    'Numune ${_shortId(event.sampleId!)}',
                  if (event.occurredAt != null) event.occurredAt!,
                ].join(' • '),
                state: null,
                rows: _displayRows(
                  event.raw,
                  const [
                    'eventId',
                    'eventSequence',
                    'eventType',
                    'sampleId',
                    'occurredAt',
                    'recordedAt',
                    'actorType',
                    'actorId',
                    'locationCode',
                    'sealId',
                    'previousEventId',
                    'evidenceRefs',
                    'appendOnly',
                  ],
                ),
              ),
            )
            .toList(growable: false),
      ),
      _OperationalSection(
        title: 'Test Talepleri',
        description:
            'Yetkili laboratuvar, test sorusu, yöntem ve test talebi durumları birlikte gösterilir.',
        icon: Icons.science_outlined,
        count: detail.testRequests.length,
        emptyText: 'Bu vakada henüz laboratuvar test talebi bulunmuyor.',
        records: detail.testRequests
            .map(
              (request) => _RecordView(
                title: request.testQuestionCode ?? 'Laboratuvar test talebi',
                subtitle: [
                  if (request.requestSequence != null)
                    '#${request.requestSequence}',
                  if (request.methodCode != null) request.methodCode!,
                  if (request.laboratoryId != null)
                    'Lab ${_shortId(request.laboratoryId!)}',
                ].join(' • '),
                state: request.state,
                rows: _displayRows(
                  request.raw,
                  const [
                    'testRequestId',
                    'requestSequence',
                    'sampleId',
                    'laboratoryId',
                    'profileCode',
                    'profileVersion',
                    'testQuestionCode',
                    'methodCode',
                    'referenceMaterialRefs',
                    'appealOfTestRequestId',
                    'requestedByType',
                    'requestedById',
                    'state',
                    'createdAt',
                    'updatedAt',
                  ],
                ),
              ),
            )
            .toList(growable: false),
      ),
      _OperationalSection(
        title: 'Test Sonuçları',
        description:
            'Laboratuvar raporu, yöntem, sonuç kodu ve delil/referans bütünlüğü ayrı kanıt olarak görünür.',
        icon: Icons.analytics_outlined,
        count: detail.testResults.length,
        emptyText: 'Bu vakada henüz laboratuvar test sonucu bulunmuyor.',
        records: detail.testResults
            .map(
              (result) => _RecordView(
                title: result.resultSummaryCode ??
                    result.resultCode ??
                    'Laboratuvar sonucu',
                subtitle: [
                  if (result.methodCode != null) result.methodCode!,
                  if (result.laboratoryId != null)
                    'Lab ${_shortId(result.laboratoryId!)}',
                  if (result.reportedAt != null) result.reportedAt!,
                ].join(' • '),
                state: null,
                rows: _displayRows(
                  result.raw,
                  const [
                    'testResultId',
                    'testRequestId',
                    'sampleId',
                    'laboratoryId',
                    'laboratoryReportId',
                    'methodCode',
                    'resultCode',
                    'resultSummaryCode',
                    'measurementRefs',
                    'reportArtifactRef',
                    'reportSha256',
                    'custodyIntegrityVerified',
                    'referenceIntegrityVerified',
                    'reportedAt',
                    'receivedAt',
                    'appendOnly',
                  ],
                ),
              ),
            )
            .toList(growable: false),
      ),
      _OperationalSection(
        title: 'Bulgular',
        description:
            'Kanıt-temelli bulgular; güven bandı, gerekçe ve yönlendirme kodlarıyla sürümlü olarak izlenir.',
        icon: Icons.fact_check_outlined,
        count: detail.findings.length,
        emptyText: 'Bu vakada henüz değerlendirilmiş bulgu bulunmuyor.',
        records: detail.findings
            .map(
              (finding) => _RecordView(
                title: finding.findingCode ?? 'ODLA bulgusu',
                subtitle: [
                  if (finding.findingVersion != null)
                    'v${finding.findingVersion}',
                  if (finding.confidenceBand != null)
                    finding.confidenceBand!,
                  if (finding.createdAt != null) finding.createdAt!,
                ].join(' • '),
                state: null,
                rows: _displayRows(
                  finding.raw,
                  const [
                    'findingId',
                    'findingVersion',
                    'findingCode',
                    'confidenceBand',
                    'evidenceRefs',
                    'reasonCodes',
                    'healthSafetyImpact',
                    'marketplaceRecommendationCode',
                    'authorityEscalationCode',
                    'supersedesFindingId',
                    'createdByType',
                    'createdById',
                    'createdAt',
                    'appendOnly',
                  ],
                ),
              ),
            )
            .toList(growable: false),
      ),
      _OperationalSection(
        title: 'İtirazlar',
        description:
            'İtiraz, yedek numune ve ikinci laboratuvar akışı ayrı bir doğrulama katmanı olarak izlenir.',
        icon: Icons.balance_outlined,
        count: detail.appeals.length,
        emptyText: 'Bu vakada açık veya sonuçlanmış itiraz bulunmuyor.',
        records: detail.appeals
            .map(
              (appeal) => _RecordView(
                title: appeal.requestedRemedyCode ?? 'ODLA itirazı',
                subtitle: [
                  if (appeal.appealSequence != null)
                    '#${appeal.appealSequence}',
                  if (appeal.challengedFindingId != null)
                    'Bulgu ${_shortId(appeal.challengedFindingId!)}',
                  if (appeal.secondLaboratoryId != null)
                    '2. Lab ${_shortId(appeal.secondLaboratoryId!)}',
                ].join(' • '),
                state: appeal.state,
                rows: _displayRows(
                  appeal.raw,
                  const [
                    'appealId',
                    'appealSequence',
                    'appellantType',
                    'appellantId',
                    'challengedFindingId',
                    'requestedRemedyCode',
                    'reserveSampleId',
                    'secondLaboratoryId',
                    'state',
                    'createdAt',
                    'updatedAt',
                  ],
                ),
              ),
            )
            .toList(growable: false),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 1050) {
          return Column(
            children: [
              for (var i = 0; i < sections.length; i++) ...[
                sections[i],
                if (i != sections.length - 1) const SizedBox(height: 14),
              ],
            ],
          );
        }

        final width = (constraints.maxWidth - 14) / 2;
        return Wrap(
          spacing: 14,
          runSpacing: 14,
          crossAxisAlignment: WrapCrossAlignment.start,
          children: sections
              .map((section) => SizedBox(width: width, child: section))
              .toList(growable: false),
        );
      },
    );
  }
}

class _RecordView {
  const _RecordView({
    required this.title,
    required this.subtitle,
    required this.state,
    required this.rows,
  });

  final String title;
  final String subtitle;
  final String? state;
  final Map<String, String> rows;
}

class _OperationalSection extends StatelessWidget {
  const _OperationalSection({
    required this.title,
    required this.description,
    required this.icon,
    required this.count,
    required this.emptyText,
    required this.records,
  });

  final String title;
  final String description;
  final IconData icon;
  final int count;
  final String emptyText;
  final List<_RecordView> records;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ),
                _CountPill(count: count),
              ],
            ),
            const SizedBox(height: 8),
            Text(description),
            const SizedBox(height: 12),
            if (records.isEmpty)
              _SectionEmptyState(message: emptyText)
            else
              ...records.map(
                (record) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _RecordCard(record: record),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RecordCard extends StatelessWidget {
  const _RecordCard({required this.record});

  final _RecordView record;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        title: Text(
          record.title,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: record.subtitle.isEmpty && record.state == null
            ? null
            : Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (record.subtitle.isNotEmpty) Text(record.subtitle),
                    if (record.state != null) ...[
                      if (record.subtitle.isNotEmpty) const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: _StatePill(state: record.state!),
                      ),
                    ],
                  ],
                ),
              ),
        children: [
          const Divider(),
          _ResponsiveKeyValueGrid(rows: record.rows),
        ],
      ),
    );
  }
}

class _SectionEmptyState extends StatelessWidget {
  const _SectionEmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.inbox_outlined),
          const SizedBox(width: 10),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }
}

class _CountPill extends StatelessWidget {
  const _CountPill({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$count',
        style: TextStyle(
          fontWeight: FontWeight.w900,
          color: Theme.of(context).colorScheme.onPrimaryContainer,
        ),
      ),
    );
  }
}

class _StatePill extends StatelessWidget {
  const _StatePill({required this.state});

  final String state;

  @override
  Widget build(BuildContext context) {
    final terminal = _terminalCase(state) ||
        state == 'completed' ||
        state == 'resolved' ||
        state == 'rejected_ineligible';
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: terminal ? colors.secondaryContainer : colors.primaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _stateLabel(state),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: terminal
              ? colors.onSecondaryContainer
              : colors.onPrimaryContainer,
        ),
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 6),
          Text(text),
        ],
      ),
    );
  }
}

class _ResponsiveKeyValueGrid extends StatelessWidget {
  const _ResponsiveKeyValueGrid({required this.rows});

  final Map<String, String> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const Text('Görüntülenebilir ayrıntı bulunmuyor.');
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 700 ? 2 : 1;
        const gap = 10.0;
        final width =
            (constraints.maxWidth - (columns - 1) * gap) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: rows.entries
              .map(
                (entry) => SizedBox(
                  width: width,
                  child: _KeyValueTile(
                    label: _fieldLabel(entry.key),
                    value: entry.value,
                  ),
                ),
              )
              .toList(growable: false),
        );
      },
    );
  }
}

class _KeyValueTile extends StatelessWidget {
  const _KeyValueTile({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 4),
          SelectableText(value),
        ],
      ),
    );
  }
}

class _KeyValueLine extends StatelessWidget {
  const _KeyValueLine({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, size: 42),
            const SizedBox(height: 12),
            Text(
              'ODLA çalışma alanı açılamadı',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Tekrar dene'),
            ),
          ],
        ),
      ),
    );
  }
}

Map<String, String> _displayRows(
  Map<String, Object?> raw,
  List<String> preferredOrder,
) {
  final rows = <String, String>{};
  final used = <String>{};

  for (final key in preferredOrder) {
    if (!raw.containsKey(key)) continue;
    final text = _displayValue(raw[key]);
    if (text == null) continue;
    rows[key] = text;
    used.add(key);
  }

  final remaining = raw.keys.where((key) => !used.contains(key)).toList()
    ..sort();
  for (final key in remaining) {
    final text = _displayValue(raw[key]);
    if (text != null) rows[key] = text;
  }
  return rows;
}

String? _displayValue(Object? value) {
  if (value == null) return null;
  if (value is String) {
    final cleaned = value.trim();
    return cleaned.isEmpty ? null : cleaned;
  }
  if (value is bool) return value ? 'Evet' : 'Hayır';
  if (value is num) return value.toString();
  if (value is List) {
    if (value.isEmpty) return '—';
    return value.map((item) => _displayValue(item) ?? '—').join(', ');
  }
  if (value is Map) {
    final pairs = value.entries
        .map((entry) => '${entry.key}: ${_displayValue(entry.value) ?? '—'}')
        .join(' • ');
    return pairs.isEmpty ? '—' : pairs;
  }
  return value.toString();
}

String _fieldLabel(String key) {
  const labels = <String, String>{
    'eventId': 'Olay kimliği',
    'eventSequence': 'Olay sırası',
    'eventType': 'Olay türü',
    'sampleId': 'Numune',
    'occurredAt': 'Gerçekleşme zamanı',
    'recordedAt': 'Kayıt zamanı',
    'actorType': 'Aktör türü',
    'actorId': 'Aktör',
    'locationCode': 'Konum kodu',
    'sealId': 'Mühür',
    'previousEventId': 'Önceki olay',
    'evidenceRefs': 'Delil referansları',
    'appendOnly': 'Değiştirilemez kayıt',
    'testRequestId': 'Test talebi',
    'requestSequence': 'Talep sırası',
    'laboratoryId': 'Laboratuvar',
    'profileCode': 'Doğrulama profili',
    'profileVersion': 'Profil sürümü',
    'testQuestionCode': 'Test sorusu',
    'methodCode': 'Yöntem',
    'referenceMaterialRefs': 'Referans materyaller',
    'appealOfTestRequestId': 'İtiraz bağlantılı talep',
    'requestedByType': 'Talep eden tür',
    'requestedById': 'Talep eden',
    'state': 'Durum',
    'createdAt': 'Oluşturulma',
    'updatedAt': 'Güncellenme',
    'testResultId': 'Test sonucu',
    'laboratoryReportId': 'Laboratuvar raporu',
    'resultCode': 'Sonuç kodu',
    'resultSummaryCode': 'Sonuç özeti',
    'measurementRefs': 'Ölçüm referansları',
    'reportArtifactRef': 'Rapor artefaktı',
    'reportSha256': 'Rapor SHA-256',
    'custodyIntegrityVerified': 'Delil zinciri bütünlüğü',
    'referenceIntegrityVerified': 'Referans bütünlüğü',
    'reportedAt': 'Raporlama zamanı',
    'receivedAt': 'Alınma zamanı',
    'findingId': 'Bulgu',
    'findingVersion': 'Bulgu sürümü',
    'findingCode': 'Bulgu kodu',
    'confidenceBand': 'Güven bandı',
    'reasonCodes': 'Gerekçe kodları',
    'healthSafetyImpact': 'Sağlık / güvenlik etkisi',
    'marketplaceRecommendationCode': 'Pazaryeri önerisi',
    'authorityEscalationCode': 'Kurum eskalasyonu',
    'supersedesFindingId': 'Yerine geçtiği bulgu',
    'createdByType': 'Oluşturan tür',
    'createdById': 'Oluşturan',
    'appealId': 'İtiraz',
    'appealSequence': 'İtiraz sırası',
    'appellantType': 'İtiraz eden tür',
    'appellantId': 'İtiraz eden',
    'challengedFindingId': 'İtiraz edilen bulgu',
    'requestedRemedyCode': 'Talep edilen çözüm',
    'reserveSampleId': 'Yedek numune',
    'secondLaboratoryId': 'İkinci laboratuvar',
  };
  return labels[key] ?? key;
}

String _safeErrorMessage(Object? error) {
  final text = error.toString().toLowerCase();
  if (text.contains('permission-denied')) {
    return 'Bu ODLA çalışma alanı için yetkiniz bulunmuyor.';
  }
  if (text.contains('unauthenticated')) {
    return 'Oturum veya App Check doğrulaması gerekli.';
  }
  if (text.contains('failed-precondition')) {
    return 'ODLA kapsamı doğrulanamadı. Marka ve tenant bağlamını kontrol edin.';
  }
  if (text.contains('not-found')) {
    return 'ODLA vakası artık görüntülenemiyor veya bulunamadı.';
  }
  if (text.contains('format')) {
    return 'ODLA veri sözleşmesi beklenen biçimde değil. Güvenli görünüm kapalı kaldı.';
  }
  return 'Çalışma alanı güvenli biçimde kapalı kaldı. Lütfen yeniden deneyin.';
}

String _roleLabel(String role) {
  switch (role) {
    case 'verified_rightsholder':
      return 'Doğrulanmış hak sahibi';
    case 'authorized_representative':
      return 'Yetkili temsilci';
    case 'assigned_laboratory':
      return 'Atanmış laboratuvar';
    case 'authorized_operator':
      return 'Yetkili operatör';
    case 'authorized_reviewer':
      return 'Yetkili inceleyici';
    default:
      return role;
  }
}

String _stateLabel(String state) {
  const labels = <String, String>{
    'opened': 'Açık',
    'precheck': 'Ön kontrol',
    'awaiting_funding': 'Finansman bekleniyor',
    'purchase_authorized': 'Satın alma yetkili',
    'sample_in_custody': 'Numune gözetimde',
    'verification_in_progress': 'Doğrulama sürüyor',
    'awaiting_finding': 'Bulgu bekleniyor',
    'appeal_open': 'İtiraz açık',
    'conflict_review': 'Çelişki incelemesi',
    'closed': 'Kapalı',
    'integrity_conflict': 'Bütünlük çelişkisi',
    'cancelled': 'İptal',
    'requested': 'Talep edildi',
    'accepted_by_lab': 'Laboratuvar kabul etti',
    'sample_in_transit': 'Numune taşımada',
    'sample_received': 'Numune alındı',
    'testing': 'Test sürüyor',
    'result_received': 'Sonuç alındı',
    'completed': 'Tamamlandı',
    'eligibility_review': 'Uygunluk incelemesi',
    'second_lab_requested': 'İkinci laboratuvar istendi',
    'second_lab_in_progress': 'İkinci laboratuvar süreci',
    'adjudication_pending': 'Karar bekleniyor',
    'resolved': 'Sonuçlandı',
    'rejected_ineligible': 'Uygun değil',
  };
  return labels[state] ?? state;
}

bool _terminalCase(String state) =>
    state == 'closed' || state == 'integrity_conflict' || state == 'cancelled';

String _shortId(String value) {
  if (value.length <= 16) return value;
  return '${value.substring(0, 10)}…${value.substring(value.length - 4)}';
}

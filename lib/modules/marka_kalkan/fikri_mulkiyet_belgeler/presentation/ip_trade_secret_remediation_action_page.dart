import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:markakalkan/core/theme/markakalkan_theme.dart';

import '../constants/ip_trade_secret_detail_enums.dart';
import '../models/ip_trade_secret_model.dart';
import '../models/ip_trade_secret_remediation_action_model.dart';
import '../repositories/ip_trade_secret_remediation_action_repository.dart';
import '../repositories/ip_trade_secret_repository.dart';

class IpTradeSecretRemediationActionPage extends StatefulWidget {
  const IpTradeSecretRemediationActionPage({super.key});

  @override
  State<IpTradeSecretRemediationActionPage> createState() =>
      _IpTradeSecretRemediationActionPageState();
}

class _IpTradeSecretRemediationActionPageState
    extends State<IpTradeSecretRemediationActionPage> {
  IpTradeSecretRepository? _secretRepository;
  IpTradeSecretRemediationActionRepository? _actionRepository;

  String _search = '';
  String? _tradeSecretId;
  IpTradeSecretRemediationStatus? _status;
  IpTradeSecretRemediationPriority? _priority;
  int _filterResetVersion = 0;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _secretRepository = IpTradeSecretRepository.instance(tenantId: user.uid);
      _actionRepository = IpTradeSecretRemediationActionRepository.instance(
        tenantId: user.uid,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final secretsRepo = _secretRepository;
    final actionsRepo = _actionRepository;

    if (user == null || secretsRepo == null || actionsRepo == null) {
      return const Scaffold(
        body: Center(
          child: Text('Düzeltici aksiyonları açmak için oturum açılmalıdır.'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: MarkaKalkanTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text(
          'Düzeltici Aksiyonlar',
          style: TextStyle(
            color: MarkaKalkanTheme.navy,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: StreamBuilder<List<IpTradeSecretModel>>(
        stream: secretsRepo.watchAll(),
        builder: (context, secretSnapshot) {
          if (secretSnapshot.hasError) {
            return Center(
              child: Text(
                'Formül kayıtları yüklenemedi: ${secretSnapshot.error}',
              ),
            );
          }

          final secrets = secretSnapshot.data ?? const <IpTradeSecretModel>[];
          final secretMap = <String, IpTradeSecretModel>{
            for (final item in secrets) item.id: item,
          };

          return StreamBuilder<List<IpTradeSecretRemediationActionModel>>(
            stream: actionsRepo.watch(),
            builder: (context, actionSnapshot) {
              if (actionSnapshot.connectionState == ConnectionState.waiting &&
                  !actionSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              if (actionSnapshot.hasError) {
                return Center(
                  child: Text(
                    'Düzeltici aksiyonlar yüklenemedi: ${actionSnapshot.error}',
                  ),
                );
              }

              final all =
                  actionSnapshot.data ??
                  const <IpTradeSecretRemediationActionModel>[];
              final visible =
                  all
                      .where(
                        (item) => _matches(item, secretMap[item.tradeSecretId]),
                      )
                      .toList(growable: false)
                    ..sort((a, b) {
                      final priority = b.priority.level.compareTo(
                        a.priority.level,
                      );
                      if (priority != 0) return priority;
                      return (a.dueAt ?? DateTime.utc(9999)).compareTo(
                        b.dueAt ?? DateTime.utc(9999),
                      );
                    });

              return SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1400),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _Header(
                          total: all.length,
                          visible: visible.length,
                          onCreate: () =>
                              _create(user.uid, secrets, actionsRepo),
                        ),
                        const SizedBox(height: 18),
                        _Kpis(actions: all),
                        const SizedBox(height: 18),
                        _Filters(
                          key: ValueKey('filters-$_filterResetVersion'),
                          search: _search,
                          tradeSecretId: _tradeSecretId,
                          status: _status,
                          priority: _priority,
                          secrets: secrets,
                          onSearch: (value) => setState(() => _search = value),
                          onSecret: (value) =>
                              setState(() => _tradeSecretId = value),
                          onStatus: (value) => setState(() => _status = value),
                          onPriority: (value) =>
                              setState(() => _priority = value),
                          onClear: _clear,
                        ),
                        const SizedBox(height: 18),
                        _Alert(actions: all),
                        const SizedBox(height: 18),
                        if (visible.isEmpty)
                          _Empty(
                            hasRecords: all.isNotEmpty,
                            onCreate: () =>
                                _create(user.uid, secrets, actionsRepo),
                            onClear: _clear,
                          )
                        else
                          ...visible.map(
                            (item) => Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: _ActionCard(
                                item: item,
                                secret: secretMap[item.tradeSecretId],
                                onOpen: () => _details(
                                  item,
                                  secretMap[item.tradeSecretId],
                                  actionsRepo,
                                ),
                              ),
                            ),
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

  bool _matches(
    IpTradeSecretRemediationActionModel item,
    IpTradeSecretModel? secret,
  ) {
    final q = _search.trim().toLowerCase();
    final text =
        q.isEmpty ||
        item.actionCode.toLowerCase().contains(q) ||
        item.title.toLowerCase().contains(q) ||
        item.ownerUserId.toLowerCase().contains(q) ||
        item.assigneeUserId.toLowerCase().contains(q) ||
        (secret?.secretCode ?? '').toLowerCase().contains(q) ||
        (secret?.title ?? '').toLowerCase().contains(q);

    return text &&
        (_tradeSecretId == null || item.tradeSecretId == _tradeSecretId) &&
        (_status == null || item.status == _status) &&
        (_priority == null || item.priority == _priority);
  }

  void _clear() {
    setState(() {
      _search = '';
      _tradeSecretId = null;
      _status = null;
      _priority = null;
      _filterResetVersion++;
    });
  }

  Future<void> _create(
    String actorId,
    List<IpTradeSecretModel> secrets,
    IpTradeSecretRemediationActionRepository repository,
  ) async {
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
      builder: (_) => _CreateDialog(
        actorId: actorId,
        secrets: secrets,
        repository: repository,
      ),
    );

    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Düzeltici aksiyon oluşturuldu.')),
      );
    }
  }

  Future<void> _details(
    IpTradeSecretRemediationActionModel item,
    IpTradeSecretModel? secret,
    IpTradeSecretRemediationActionRepository repository,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('${item.actionCode} — ${item.title}'),
        content: SizedBox(
          width: 720,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _Badge(item.status.label),
                    _Badge(item.priority.label),
                    _Badge(item.sourceType.label),
                    _Badge(item.verificationOutcome.label),
                  ],
                ),
                const SizedBox(height: 18),
                _Line(
                  'Formül / Ticari Sır',
                  secret == null ? item.tradeSecretId : secret.title,
                ),
                _Line('Aksiyon sahibi', item.ownerUserId),
                _Line('Atanan kullanıcı', item.assigneeUserId),
                _Line('Kaynak Kayıt Kimliği', item.sourceRecordId ?? '—'),
                _Line('İlerleme', '%${item.progressPercent}'),
                _Line('Son tarih', _date(item.dueAt)),
                _Line(
                  'Risk değişimi',
                  '${item.preActionRiskScore} → ${item.postActionRiskScore}',
                ),
                _Line('Açıklama', item.description ?? '—'),
                _Line('Beklenen sonuç', item.expectedOutcome ?? '—'),
                _Line('Engel nedeni', item.blockerReason ?? '—'),
                _Line(
                  'Koruma kontrolleri',
                  item.protectionControlIds.isEmpty
                      ? '—'
                      : item.protectionControlIds.join(', '),
                ),
                _Line(
                  'Kanıt belgeleri',
                  item.evidenceDocumentIds.isEmpty
                      ? '—'
                      : item.evidenceDocumentIds.join(', '),
                ),
                _Line('Notlar', item.notes ?? '—'),
              ],
            ),
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: dialogContext,
                builder: (confirmContext) => AlertDialog(
                  title: const Text('Aksiyon silinsin mi?'),
                  content: Text('${item.actionCode} kalıcı olarak silinecek.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(confirmContext, false),
                      child: const Text('Vazgeç'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(confirmContext, true),
                      child: const Text('Sil'),
                    ),
                  ],
                ),
              );
              if (ok != true) return;
              await repository.delete(item.id);
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
            icon: const Icon(Icons.delete_outline),
            label: const Text('Sil'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Kapat'),
          ),
        ],
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
        borderRadius: BorderRadius.circular(22),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        runAlignment: WrapAlignment.center,
        spacing: 20,
        runSpacing: 18,
        children: [
          const SizedBox(
            width: 760,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Düzeltici Aksiyon Merkezi',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  'Risk, olay, kontrol açığı ve denetim bulgularından doğan '
                  'aksiyonları sorumlu, termin, ilerleme, kanıt ve doğrulama '
                  'ile yönetin.',
                  style: TextStyle(color: Color(0xFFD8E7ED), height: 1.5),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$visible / $total kayıt',
                style: const TextStyle(color: Color(0xFFD8E7ED)),
              ),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: onCreate,
                icon: const Icon(Icons.add_task_outlined),
                label: const Text('Yeni Düzeltici Aksiyon'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Kpis extends StatelessWidget {
  const _Kpis({required this.actions});

  final List<IpTradeSecretRemediationActionModel> actions;

  @override
  Widget build(BuildContext context) {
    final items = <(String, int, IconData)>[
      ('Toplam', actions.length, Icons.assignment_outlined),
      (
        'Açık',
        actions
            .where(
              (item) =>
                  item.status != IpTradeSecretRemediationStatus.closed &&
                  item.status != IpTradeSecretRemediationStatus.cancelled,
            )
            .length,
        Icons.inbox_outlined,
      ),
      (
        'Sürüyor',
        actions
            .where(
              (item) =>
                  item.status == IpTradeSecretRemediationStatus.inProgress,
            )
            .length,
        Icons.play_circle_outline,
      ),
      (
        'Gecikmiş',
        actions.where((item) => item.isOverdue).length,
        Icons.schedule_outlined,
      ),
      (
        'Engelli',
        actions.where((item) => item.blocked).length,
        Icons.block_outlined,
      ),
      (
        'Kritik',
        actions
            .where(
              (item) =>
                  item.criticalAction ||
                  item.priority == IpTradeSecretRemediationPriority.critical,
            )
            .length,
        Icons.priority_high,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 650
            ? 2
            : constraints.maxWidth < 1000
            ? 3
            : 6;
        const spacing = 12.0;
        final width =
            (constraints.maxWidth - ((columns - 1) * spacing)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: items
              .map(
                (item) => SizedBox(
                  width: width,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: _panel(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(item.$3, color: MarkaKalkanTheme.navy),
                        const SizedBox(height: 12),
                        Text(
                          '${item.$2}',
                          style: const TextStyle(
                            color: MarkaKalkanTheme.navy,
                            fontSize: 25,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          item.$1,
                          style: const TextStyle(
                            color: Color(0xFF697780),
                            fontWeight: FontWeight.w700,
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
    required this.status,
    required this.priority,
    required this.secrets,
    required this.onSearch,
    required this.onSecret,
    required this.onStatus,
    required this.onPriority,
    required this.onClear,
  });

  final String search;
  final String? tradeSecretId;
  final IpTradeSecretRemediationStatus? status;
  final IpTradeSecretRemediationPriority? priority;
  final List<IpTradeSecretModel> secrets;
  final ValueChanged<String> onSearch;
  final ValueChanged<String?> onSecret;
  final ValueChanged<IpTradeSecretRemediationStatus?> onStatus;
  final ValueChanged<IpTradeSecretRemediationPriority?> onPriority;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _panel(),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 760;
          final width = compact
              ? constraints.maxWidth
              : (constraints.maxWidth - 24) / 3;

          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: width,
                child: TextFormField(
                  initialValue: search,
                  onChanged: onSearch,
                  decoration: const InputDecoration(
                    labelText: 'Ara',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
              ),
              SizedBox(
                width: width,
                child: DropdownButtonFormField<String?>(
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
                      (secret) => DropdownMenuItem<String?>(
                        value: secret.id,
                        child: Text(
                          '${secret.secretCode} — ${secret.title}',
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
                child: DropdownButtonFormField<IpTradeSecretRemediationStatus?>(
                  initialValue: status,
                  decoration: const InputDecoration(labelText: 'Durum'),
                  items: [
                    const DropdownMenuItem<IpTradeSecretRemediationStatus?>(
                      value: null,
                      child: Text('Tümü'),
                    ),
                    ...IpTradeSecretRemediationStatus.values.map(
                      (item) =>
                          DropdownMenuItem<IpTradeSecretRemediationStatus?>(
                            value: item,
                            child: Text(item.label),
                          ),
                    ),
                  ],
                  onChanged: onStatus,
                ),
              ),
              SizedBox(
                width: width,
                child:
                    DropdownButtonFormField<IpTradeSecretRemediationPriority?>(
                      initialValue: priority,
                      decoration: const InputDecoration(labelText: 'Öncelik'),
                      items: [
                        const DropdownMenuItem<
                          IpTradeSecretRemediationPriority?
                        >(value: null, child: Text('Tümü')),
                        ...IpTradeSecretRemediationPriority.values.map(
                          (item) =>
                              DropdownMenuItem<
                                IpTradeSecretRemediationPriority?
                              >(value: item, child: Text(item.label)),
                        ),
                      ],
                      onChanged: onPriority,
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

class _Alert extends StatelessWidget {
  const _Alert({required this.actions});

  final List<IpTradeSecretRemediationActionModel> actions;

  @override
  Widget build(BuildContext context) {
    final urgent = actions
        .where((item) => item.requiresImmediateEscalation)
        .length;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: urgent > 0 ? const Color(0xFFFFF2ED) : const Color(0xFFF2F8F5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: urgent > 0 ? const Color(0xFFF3B49A) : const Color(0xFFB8DCC8),
        ),
      ),
      child: Text(
        urgent > 0
            ? '$urgent aksiyon acil inceleme veya yükseltme gerektiriyor.'
            : 'Acil yükseltme gerektiren aksiyon bulunmuyor.',
        style: TextStyle(
          color: urgent > 0 ? const Color(0xFF8A3515) : const Color(0xFF236343),
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.item,
    required this.secret,
    required this.onOpen,
  });

  final IpTradeSecretRemediationActionModel item;
  final IpTradeSecretModel? secret;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onOpen,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: _panel(),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final identity = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${item.actionCode} — ${item.title}',
                  style: const TextStyle(
                    color: MarkaKalkanTheme.navy,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  secret == null
                      ? item.tradeSecretId
                      : '${secret!.secretCode} — ${secret!.title}',
                  style: const TextStyle(color: Color(0xFF7A8790)),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _Badge(item.status.label),
                    _Badge(item.priority.label),
                    _Badge(item.sourceType.label),
                    if (item.criticalAction) const _Badge('Kritik'),
                    if (item.blocked) const _Badge('Engelli'),
                  ],
                ),
              ],
            );

            final progress = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'İlerleme %${item.progressPercent}',
                  style: const TextStyle(
                    color: MarkaKalkanTheme.navy,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(value: item.progressPercent / 100),
                const SizedBox(height: 10),
                Text('Sorumlu: ${item.assigneeUserId}'),
                Text('Son tarih: ${_date(item.dueAt)}'),
                Text(
                  'Risk: ${item.preActionRiskScore} → '
                  '${item.postActionRiskScore}',
                ),
              ],
            );

            if (constraints.maxWidth < 900) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [identity, const SizedBox(height: 18), progress],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: identity),
                const SizedBox(width: 24),
                Expanded(flex: 2, child: progress),
                const SizedBox(width: 12),
                const Icon(Icons.open_in_new_outlined),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({
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
      padding: const EdgeInsets.symmetric(vertical: 54, horizontal: 24),
      decoration: _panel(),
      child: Column(
        children: [
          const Icon(
            Icons.build_circle_outlined,
            size: 48,
            color: MarkaKalkanTheme.navy,
          ),
          const SizedBox(height: 14),
          Text(
            hasRecords
                ? 'Filtrelerle eşleşen aksiyon bulunamadı.'
                : 'Henüz düzeltici aksiyon oluşturulmadı.',
            style: const TextStyle(
              color: MarkaKalkanTheme.navy,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: hasRecords ? onClear : onCreate,
            child: Text(
              hasRecords ? 'Filtreleri Temizle' : 'İlk Aksiyonu Oluştur',
            ),
          ),
        ],
      ),
    );
  }
}

class _CreateDialog extends StatefulWidget {
  const _CreateDialog({
    required this.actorId,
    required this.secrets,
    required this.repository,
  });

  final String actorId;
  final List<IpTradeSecretModel> secrets;
  final IpTradeSecretRemediationActionRepository repository;

  @override
  State<_CreateDialog> createState() => _CreateDialogState();
}

class _CreateDialogState extends State<_CreateDialog> {
  final _formKey = GlobalKey<FormState>();
  final _code = TextEditingController();
  final _title = TextEditingController();
  final _owner = TextEditingController();
  final _assignee = TextEditingController();
  final _sourceRecord = TextEditingController();
  final _description = TextEditingController();
  final _expected = TextEditingController();
  final _blocker = TextEditingController();
  final _controlIds = TextEditingController();
  final _evidenceIds = TextEditingController();
  final _notes = TextEditingController();

  late String _tradeSecretId;
  IpTradeSecretRemediationStatus _status =
      IpTradeSecretRemediationStatus.planned;
  IpTradeSecretRemediationPriority _priority =
      IpTradeSecretRemediationPriority.medium;
  IpTradeSecretRemediationSourceType _sourceType =
      IpTradeSecretRemediationSourceType.other;

  int _progress = 0;
  int _preRisk = 0;
  int _postRisk = 0;
  bool _critical = false;
  bool _blocked = false;
  bool _verificationRequired = true;
  bool _legalReview = false;
  DateTime? _dueAt;
  DateTime? _startedAt;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _tradeSecretId = widget.secrets.first.id;
    _owner.text = widget.actorId;
    _assignee.text = widget.actorId;
  }

  @override
  void dispose() {
    for (final item in [
      _code,
      _title,
      _owner,
      _assignee,
      _sourceRecord,
      _description,
      _expected,
      _blocker,
      _controlIds,
      _evidenceIds,
      _notes,
    ]) {
      item.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: SizedBox(
        width: 920,
        height: MediaQuery.sizeOf(context).height * .9,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 14, 12),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Yeni Düzeltici Aksiyon',
                      style: TextStyle(
                        color: MarkaKalkanTheme.navy,
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _saving
                        ? null
                        : () => Navigator.pop(context, false),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final compact = constraints.maxWidth < 720;
                      final width = compact
                          ? constraints.maxWidth
                          : (constraints.maxWidth - 16) / 2;

                      return Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        children: [
                          SizedBox(
                            width: constraints.maxWidth,
                            child: DropdownButtonFormField<String>(
                              initialValue: _tradeSecretId,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Formül / Ticari Sır *',
                              ),
                              items: widget.secrets
                                  .map(
                                    (secret) => DropdownMenuItem(
                                      value: secret.id,
                                      child: Text(
                                        '${secret.secretCode} — ${secret.title}',
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
                          ),
                          _Text(width, _code, 'Aksiyon Kodu *', required: true),
                          _Text(width, _title, 'Başlık *', required: true),
                          _Text(
                            width,
                            _owner,
                            'Aksiyon Sahibi *',
                            required: true,
                          ),
                          _Text(
                            width,
                            _assignee,
                            'Atanan Kullanıcı *',
                            required: true,
                          ),
                          SizedBox(
                            width: width,
                            child:
                                DropdownButtonFormField<
                                  IpTradeSecretRemediationStatus
                                >(
                                  initialValue: _status,
                                  decoration: const InputDecoration(
                                    labelText: 'Durum',
                                  ),
                                  items: IpTradeSecretRemediationStatus.values
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
                                        _blocked =
                                            value ==
                                            IpTradeSecretRemediationStatus
                                                .blocked;
                                      });
                                    }
                                  },
                                ),
                          ),
                          SizedBox(
                            width: width,
                            child:
                                DropdownButtonFormField<
                                  IpTradeSecretRemediationPriority
                                >(
                                  initialValue: _priority,
                                  decoration: const InputDecoration(
                                    labelText: 'Öncelik',
                                  ),
                                  items: IpTradeSecretRemediationPriority.values
                                      .map(
                                        (item) => DropdownMenuItem(
                                          value: item,
                                          child: Text(item.label),
                                        ),
                                      )
                                      .toList(growable: false),
                                  onChanged: (value) {
                                    if (value != null) {
                                      setState(() => _priority = value);
                                    }
                                  },
                                ),
                          ),
                          SizedBox(
                            width: width,
                            child:
                                DropdownButtonFormField<
                                  IpTradeSecretRemediationSourceType
                                >(
                                  initialValue: _sourceType,
                                  decoration: const InputDecoration(
                                    labelText: 'Kaynak Türü',
                                  ),
                                  items: IpTradeSecretRemediationSourceType
                                      .values
                                      .map(
                                        (item) => DropdownMenuItem(
                                          value: item,
                                          child: Text(item.label),
                                        ),
                                      )
                                      .toList(growable: false),
                                  onChanged: (value) {
                                    if (value != null) {
                                      setState(() => _sourceType = value);
                                    }
                                  },
                                ),
                          ),
                          _Text(width, _sourceRecord, 'Kaynak Kayıt Kimliği'),
                          _Date(
                            width: width,
                            label: 'Son Tarih',
                            value: _dueAt,
                            onChanged: (value) =>
                                setState(() => _dueAt = value),
                          ),
                          _Date(
                            width: width,
                            label: 'Başlangıç Tarihi',
                            value: _startedAt,
                            onChanged: (value) =>
                                setState(() => _startedAt = value),
                          ),
                          _Slider(
                            width: width,
                            label: 'İlerleme',
                            value: _progress,
                            onChanged: (value) =>
                                setState(() => _progress = value),
                          ),
                          _Slider(
                            width: width,
                            label: 'Aksiyon Öncesi Risk',
                            value: _preRisk,
                            onChanged: (value) =>
                                setState(() => _preRisk = value),
                          ),
                          _Slider(
                            width: width,
                            label: 'Aksiyon Sonrası Risk',
                            value: _postRisk,
                            onChanged: (value) =>
                                setState(() => _postRisk = value),
                          ),
                          _Text(
                            constraints.maxWidth,
                            _description,
                            'Açıklama',
                            maxLines: 3,
                          ),
                          _Text(
                            constraints.maxWidth,
                            _expected,
                            'Beklenen Sonuç',
                            maxLines: 3,
                          ),
                          if (_blocked)
                            _Text(
                              constraints.maxWidth,
                              _blocker,
                              'Engel Nedeni *',
                              required: true,
                              maxLines: 2,
                            ),
                          _Text(
                            width,
                            _controlIds,
                            'Koruma Kontrolü Kimlikleri',
                          ),
                          _Text(
                            width,
                            _evidenceIds,
                            'Kanıt Belgesi Kimlikleri',
                          ),
                          _Text(
                            constraints.maxWidth,
                            _notes,
                            'Notlar',
                            maxLines: 3,
                          ),
                          SizedBox(
                            width: constraints.maxWidth,
                            child: Wrap(
                              spacing: 12,
                              children: [
                                FilterChip(
                                  label: const Text('Kritik aksiyon'),
                                  selected: _critical,
                                  onSelected: (value) =>
                                      setState(() => _critical = value),
                                ),
                                FilterChip(
                                  label: const Text('Engelli'),
                                  selected: _blocked,
                                  onSelected: (value) {
                                    setState(() {
                                      _blocked = value;
                                      _status = value
                                          ? IpTradeSecretRemediationStatus
                                                .blocked
                                          : IpTradeSecretRemediationStatus
                                                .planned;
                                    });
                                  },
                                ),
                                FilterChip(
                                  label: const Text('Doğrulama gerekli'),
                                  selected: _verificationRequired,
                                  onSelected: (value) => setState(
                                    () => _verificationRequired = value,
                                  ),
                                ),
                                FilterChip(
                                  label: const Text('Hukuk incelemesi'),
                                  selected: _legalReview,
                                  onSelected: (value) =>
                                      setState(() => _legalReview = value),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _saving
                        ? null
                        : () => Navigator.pop(context, false),
                    child: const Text('Vazgeç'),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Kaydet'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (_sourceType != IpTradeSecretRemediationSourceType.other &&
        _sourceRecord.text.trim().isEmpty) {
      _show('Kaynak türü diğer değilse kaynak kayıt kimliği zorunludur.');
      return;
    }

    if ((_status == IpTradeSecretRemediationStatus.assigned ||
            _status == IpTradeSecretRemediationStatus.inProgress) &&
        _dueAt == null) {
      _show('Atanmış veya yürütülen aksiyonda son tarih zorunludur.');
      return;
    }

    if (_progress == 100) {
      _show(
        'V1 oluşturma ekranında ilerleme yüzde 100 seçilmemelidir; '
        'tamamlanma ve doğrulama sonraki yaşam döngüsü adımında işlenecektir.',
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final secret = widget.secrets.firstWhere(
        (item) => item.id == _tradeSecretId,
      );

      final model = IpTradeSecretRemediationActionModel(
        id: '',
        tenantId: widget.actorId,
        brandId: secret.brandId,
        tradeSecretId: secret.id,
        protectionControlIds: _split(_controlIds.text),
        evidenceDocumentIds: _split(_evidenceIds.text),
        actionCode: _code.text.trim(),
        title: _title.text.trim(),
        status: _status,
        priority: _priority,
        sourceType: _sourceType,
        verificationOutcome: IpTradeSecretVerificationOutcome.notReviewed,
        ownerUserId: _owner.text.trim(),
        assigneeUserId: _assignee.text.trim(),
        sourceRecordId: _null(_sourceRecord.text),
        description: _null(_description.text),
        expectedOutcome: _null(_expected.text),
        blockerReason: _blocked ? _null(_blocker.text) : null,
        progressPercent: _progress,
        preActionRiskScore: _preRisk,
        postActionRiskScore: _postRisk,
        criticalAction: _critical,
        blocked: _blocked,
        verificationRequired: _verificationRequired,
        legalReviewRequired: _legalReview,
        dueAt: _dueAt,
        startedAt: _startedAt,
        notes: _null(_notes.text),
        createdAt: DateTime.now().toUtc(),
        createdBy: widget.actorId,
      );

      await widget.repository.create(model);
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(() => _saving = false);
        _show('Düzeltici aksiyon oluşturulamadı: $error');
      }
    }
  }

  void _show(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _Text extends StatelessWidget {
  const _Text(
    this.width,
    this.controller,
    this.label, {
    this.required = false,
    this.maxLines = 1,
  });

  final double width;
  final TextEditingController controller;
  final String label;
  final bool required;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        validator: required
            ? (value) =>
                  value == null || value.trim().isEmpty ? 'Zorunlu alan' : null
            : null,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }
}

class _Date extends StatelessWidget {
  const _Date({
    required this.width,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final double width;
  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: OutlinedButton.icon(
        onPressed: () async {
          final result = await showDatePicker(
            context: context,
            firstDate: DateTime(2020),
            lastDate: DateTime(2100),
            initialDate: value?.toLocal() ?? DateTime.now(),
          );
          if (result != null) {
            onChanged(DateTime.utc(result.year, result.month, result.day));
          }
        },
        icon: const Icon(Icons.calendar_month_outlined),
        label: Align(
          alignment: Alignment.centerLeft,
          child: Text('$label: ${_date(value)}'),
        ),
      ),
    );
  }
}

class _Slider extends StatelessWidget {
  const _Slider({
    required this.width,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final double width;
  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label: $value'),
          Slider(
            value: value.toDouble(),
            min: 0,
            max: 100,
            divisions: 20,
            onChanged: (value) => onChanged(value.round()),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F4F6),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF53636C),
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
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
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF78858E),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          SelectableText(value),
        ],
      ),
    );
  }
}

BoxDecoration _panel() {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(18),
    border: Border.all(color: const Color(0xFFDDE6EA)),
    boxShadow: const [
      BoxShadow(color: Color(0x0D102A3A), blurRadius: 18, offset: Offset(0, 6)),
    ],
  );
}

String _date(DateTime? value) {
  if (value == null) return '—';
  final local = value.toLocal();
  return '${local.day.toString().padLeft(2, '0')}.'
      '${local.month.toString().padLeft(2, '0')}.'
      '${local.year}';
}

List<String> _split(String value) {
  return value
      .split(',')
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toSet()
      .toList(growable: false);
}

String? _null(String value) {
  final cleaned = value.trim();
  return cleaned.isEmpty ? null : cleaned;
}

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:markakalkan/core/theme/markakalkan_theme.dart';

import '../constants/ip_trade_secret_detail_enums.dart';
import '../models/ip_trade_secret_management_decision_model.dart';
import '../models/ip_trade_secret_model.dart';
import '../repositories/ip_trade_secret_management_decision_repository.dart';
import '../repositories/ip_trade_secret_repository.dart';

class IpTradeSecretManagementDecisionPage extends StatefulWidget {
  const IpTradeSecretManagementDecisionPage({super.key});

  @override
  State<IpTradeSecretManagementDecisionPage> createState() =>
      _IpTradeSecretManagementDecisionPageState();
}

class _IpTradeSecretManagementDecisionPageState
    extends State<IpTradeSecretManagementDecisionPage> {
  IpTradeSecretRepository? _secretRepository;
  IpTradeSecretManagementDecisionRepository? _decisionRepository;

  String _search = '';
  String? _tradeSecretId;
  IpTradeSecretDecisionStatus? _status;
  IpTradeSecretDecisionType? _type;
  int _filterResetVersion = 0;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _secretRepository = IpTradeSecretRepository.instance(tenantId: user.uid);
      _decisionRepository = IpTradeSecretManagementDecisionRepository.instance(
        tenantId: user.uid,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final secretsRepo = _secretRepository;
    final decisionsRepo = _decisionRepository;

    if (user == null || secretsRepo == null || decisionsRepo == null) {
      return const Scaffold(
        body: Center(
          child: Text('Yönetim kararlarını açmak için oturum açılmalıdır.'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: MarkaKalkanTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text(
          'Yönetim Kararları',
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

          return StreamBuilder<List<IpTradeSecretManagementDecisionModel>>(
            stream: decisionsRepo.watch(),
            builder: (context, decisionSnapshot) {
              if (decisionSnapshot.connectionState == ConnectionState.waiting &&
                  !decisionSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              if (decisionSnapshot.hasError) {
                return Center(
                  child: Text(
                    'Yönetim kararları yüklenemedi: '
                    '${decisionSnapshot.error}',
                  ),
                );
              }

              final all =
                  decisionSnapshot.data ??
                  const <IpTradeSecretManagementDecisionModel>[];
              final visible =
                  all
                      .where(
                        (item) => _matches(item, secretMap[item.tradeSecretId]),
                      )
                      .toList(growable: false)
                    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

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
                              _create(user.uid, secrets, decisionsRepo),
                        ),
                        const SizedBox(height: 18),
                        _Kpis(decisions: all),
                        const SizedBox(height: 18),
                        _Filters(
                          key: ValueKey(
                            'management-filters-$_filterResetVersion',
                          ),
                          search: _search,
                          tradeSecretId: _tradeSecretId,
                          status: _status,
                          type: _type,
                          secrets: secrets,
                          onSearch: (value) => setState(() => _search = value),
                          onSecret: (value) =>
                              setState(() => _tradeSecretId = value),
                          onStatus: (value) => setState(() => _status = value),
                          onType: (value) => setState(() => _type = value),
                          onClear: _clear,
                        ),
                        const SizedBox(height: 18),
                        _Alert(decisions: all),
                        const SizedBox(height: 18),
                        if (visible.isEmpty)
                          _Empty(
                            hasRecords: all.isNotEmpty,
                            onCreate: () =>
                                _create(user.uid, secrets, decisionsRepo),
                            onClear: _clear,
                          )
                        else
                          ...visible.map(
                            (item) => Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: _DecisionCard(
                                item: item,
                                secret: secretMap[item.tradeSecretId],
                                onOpen: () => _details(
                                  item,
                                  secretMap[item.tradeSecretId],
                                  decisionsRepo,
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
    IpTradeSecretManagementDecisionModel item,
    IpTradeSecretModel? secret,
  ) {
    final query = _search.trim().toLowerCase();
    final textMatches =
        query.isEmpty ||
        item.decisionCode.toLowerCase().contains(query) ||
        item.title.toLowerCase().contains(query) ||
        item.ownerUserId.toLowerCase().contains(query) ||
        (item.decisionSummary ?? '').toLowerCase().contains(query) ||
        (item.rationale ?? '').toLowerCase().contains(query) ||
        (secret?.secretCode ?? '').toLowerCase().contains(query) ||
        (secret?.title ?? '').toLowerCase().contains(query);

    return textMatches &&
        (_tradeSecretId == null || item.tradeSecretId == _tradeSecretId) &&
        (_status == null || item.status == _status) &&
        (_type == null || item.decisionType == _type);
  }

  void _clear() {
    setState(() {
      _search = '';
      _tradeSecretId = null;
      _status = null;
      _type = null;
      _filterResetVersion++;
    });
  }

  Future<void> _create(
    String actorId,
    List<IpTradeSecretModel> secrets,
    IpTradeSecretManagementDecisionRepository repository,
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
        const SnackBar(content: Text('Yönetim kararı oluşturuldu.')),
      );
    }
  }

  Future<void> _details(
    IpTradeSecretManagementDecisionModel item,
    IpTradeSecretModel? secret,
    IpTradeSecretManagementDecisionRepository repository,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('${item.decisionCode} — ${item.title}'),
        content: SizedBox(
          width: 760,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _Badge(item.status.label),
                    _Badge(item.decisionType.label),
                    _Badge(item.votingMethod.label),
                    _Badge(item.approvalOutcome.label),
                    if (item.conditionalDecision) const _Badge('Koşullu karar'),
                    if (item.riskAcceptance) const _Badge('Risk kabulü'),
                  ],
                ),
                const SizedBox(height: 18),
                _Line(
                  'Formül / Ticari Sır',
                  secret == null
                      ? item.tradeSecretId
                      : '${secret.secretCode} — ${secret.title}',
                ),
                _Line('Karar sahibi', item.ownerUserId),
                _Line(
                  'Gerekli onay',
                  '${item.approvedUserIds.length}/'
                      '${item.requiredApprovalCount}',
                ),
                _Line('Onaylayan kullanıcılar', _join(item.approverUserIds)),
                _Line('Karar özeti', item.decisionSummary ?? '—'),
                _Line('Gerekçe', item.rationale ?? '—'),
                _Line('Koşullar', item.conditions ?? '—'),
                _Line(
                  'Talep edilen bütçe',
                  _money(item.requestedBudgetAmount, item.currencyCode),
                ),
                _Line(
                  'Onaylanan bütçe',
                  _money(item.approvedBudgetAmount, item.currencyCode),
                ),
                _Line('Karar tarihi', _date(item.decisionAt)),
                _Line('Yürürlük tarihi', _date(item.effectiveAt)),
                _Line('Sona erme tarihi', _date(item.expiresAt)),
                _Line('Yeniden değerlendirme', _date(item.reassessmentAt)),
                _Line('Düzeltici aksiyonlar', _join(item.remediationActionIds)),
                _Line('Koruma kontrolleri', _join(item.protectionControlIds)),
                _Line('Risk kayıtları', _join(item.riskAssessmentIds)),
                _Line('Olay kayıtları', _join(item.incidentIds)),
                _Line('Kanıt belgeleri', _join(item.evidenceDocumentIds)),
                _Line(
                  'İncelemeler',
                  [
                        if (item.legalReviewRequired) 'Hukuk',
                        if (item.securityReviewRequired) 'Güvenlik',
                        if (item.financeReviewRequired) 'Finans',
                        if (item.boardReviewRequired) 'Kurul',
                      ].isEmpty
                      ? '—'
                      : [
                          if (item.legalReviewRequired) 'Hukuk',
                          if (item.securityReviewRequired) 'Güvenlik',
                          if (item.financeReviewRequired) 'Finans',
                          if (item.boardReviewRequired) 'Kurul',
                        ].join(', '),
                ),
                _Line('Notlar', item.notes ?? '—'),
              ],
            ),
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: dialogContext,
                builder: (confirmContext) => AlertDialog(
                  title: const Text('Yönetim kararı silinsin mi?'),
                  content: Text(
                    '${item.decisionCode} kalıcı olarak silinecek.',
                  ),
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
              if (confirmed != true) return;
              await repository.delete(item.id);
              if (dialogContext.mounted) {
                Navigator.pop(dialogContext);
              }
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
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [MarkaKalkanTheme.navy, Color(0xFF17445A)],
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final content = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Yönetim Kararları Sicili',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Kritik ticari sır kararlarını; gerekçe, onay, koşul, '
                'bütçe ve kanıt bağlantılarıyla kalıcı sicile bağlayın.',
                style: TextStyle(color: Color(0xFFD9E5EA), height: 1.45),
              ),
              const SizedBox(height: 10),
              Text(
                'Toplam $total kayıt • Görünen $visible',
                style: const TextStyle(
                  color: Color(0xFFE4B95A),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          );

          final button = FilledButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add),
            label: const Text('Yeni Yönetim Kararı'),
          );

          if (constraints.maxWidth < 760) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [content, const SizedBox(height: 16), button],
            );
          }

          return Row(
            children: [
              Expanded(child: content),
              const SizedBox(width: 20),
              button,
            ],
          );
        },
      ),
    );
  }
}

class _Kpis extends StatelessWidget {
  const _Kpis({required this.decisions});

  final List<IpTradeSecretManagementDecisionModel> decisions;

  @override
  Widget build(BuildContext context) {
    final items = <(String, int, IconData)>[
      ('Toplam', decisions.length, Icons.account_balance_outlined),
      (
        'İncelemede',
        decisions
            .where(
              (item) => item.status == IpTradeSecretDecisionStatus.underReview,
            )
            .length,
        Icons.manage_search_outlined,
      ),
      (
        'Onay Bekliyor',
        decisions
            .where(
              (item) =>
                  item.status == IpTradeSecretDecisionStatus.pendingApproval,
            )
            .length,
        Icons.approval_outlined,
      ),
      (
        'Onaylı / Yürürlükte',
        decisions
            .where(
              (item) =>
                  item.status == IpTradeSecretDecisionStatus.approved ||
                  item.status == IpTradeSecretDecisionStatus.effective,
            )
            .length,
        Icons.verified_outlined,
      ),
      (
        'Koşullu',
        decisions.where((item) => item.conditionalDecision).length,
        Icons.rule_outlined,
      ),
      (
        'Yeniden İnceleme',
        decisions.where((item) => item.requiresReassessment).length,
        Icons.event_repeat_outlined,
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
                        const SizedBox(height: 10),
                        Text(
                          '${item.$2}',
                          style: const TextStyle(
                            color: MarkaKalkanTheme.navy,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          item.$1,
                          style: const TextStyle(
                            color: Color(0xFF6E7B84),
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
    required this.type,
    required this.secrets,
    required this.onSearch,
    required this.onSecret,
    required this.onStatus,
    required this.onType,
    required this.onClear,
  });

  final String search;
  final String? tradeSecretId;
  final IpTradeSecretDecisionStatus? status;
  final IpTradeSecretDecisionType? type;
  final List<IpTradeSecretModel> secrets;
  final ValueChanged<String> onSearch;
  final ValueChanged<String?> onSecret;
  final ValueChanged<IpTradeSecretDecisionStatus?> onStatus;
  final ValueChanged<IpTradeSecretDecisionType?> onType;
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
                child: DropdownButtonFormField<IpTradeSecretDecisionStatus?>(
                  initialValue: status,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Durum'),
                  items: [
                    const DropdownMenuItem<IpTradeSecretDecisionStatus?>(
                      value: null,
                      child: Text('Tümü'),
                    ),
                    ...IpTradeSecretDecisionStatus.values.map(
                      (item) => DropdownMenuItem<IpTradeSecretDecisionStatus?>(
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
                child: DropdownButtonFormField<IpTradeSecretDecisionType?>(
                  initialValue: type,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Karar Türü'),
                  items: [
                    const DropdownMenuItem<IpTradeSecretDecisionType?>(
                      value: null,
                      child: Text('Tümü'),
                    ),
                    ...IpTradeSecretDecisionType.values.map(
                      (item) => DropdownMenuItem<IpTradeSecretDecisionType?>(
                        value: item,
                        child: Text(item.label),
                      ),
                    ),
                  ],
                  onChanged: onType,
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
  const _Alert({required this.decisions});

  final List<IpTradeSecretManagementDecisionModel> decisions;

  @override
  Widget build(BuildContext context) {
    final attention = decisions
        .where((item) => item.shouldAppearOnDecisionDashboard)
        .length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: attention > 0
            ? const Color(0xFFFFF2ED)
            : const Color(0xFFF2F8F5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: attention > 0
              ? const Color(0xFFF3B49A)
              : const Color(0xFFB8DCC8),
        ),
      ),
      child: Text(
        attention > 0
            ? '$attention karar inceleme, onay veya yeniden değerlendirme '
                  'gerektiriyor.'
            : 'Acil yönetim incelemesi gerektiren karar bulunmuyor.',
        style: TextStyle(
          color: attention > 0
              ? const Color(0xFF8A3515)
              : const Color(0xFF236343),
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _DecisionCard extends StatelessWidget {
  const _DecisionCard({
    required this.item,
    required this.secret,
    required this.onOpen,
  });

  final IpTradeSecretManagementDecisionModel item;
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
            final left = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${item.decisionCode} — ${item.title}',
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
                    _Badge(item.decisionType.label),
                    _Badge(item.votingMethod.label),
                    if (item.conditionalDecision) const _Badge('Koşullu'),
                    if (item.riskAcceptance) const _Badge('Risk kabulü'),
                  ],
                ),
              ],
            );

            final right = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Onay ${item.approvedUserIds.length}/'
                  '${item.requiredApprovalCount}',
                  style: const TextStyle(
                    color: MarkaKalkanTheme.navy,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  item.ownerUserId,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Color(0xFF687580)),
                ),
                const SizedBox(height: 6),
                Text(
                  'Oluşturma: ${_date(item.createdAt)}',
                  style: const TextStyle(color: Color(0xFF687580)),
                ),
              ],
            );

            if (constraints.maxWidth < 760) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [left, const SizedBox(height: 16), right],
              );
            }

            return Row(
              children: [
                Expanded(flex: 3, child: left),
                const SizedBox(width: 20),
                Expanded(child: right),
                const Icon(Icons.open_in_new),
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
      padding: const EdgeInsets.all(36),
      decoration: _panel(),
      child: Column(
        children: [
          const Icon(
            Icons.account_balance_outlined,
            size: 44,
            color: MarkaKalkanTheme.navy,
          ),
          const SizedBox(height: 12),
          Text(
            hasRecords
                ? 'Filtrelerle eşleşen karar bulunamadı.'
                : 'Henüz yönetim kararı bulunmuyor.',
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
              hasRecords
                  ? 'Filtreleri Temizle'
                  : 'İlk Yönetim Kararını Oluştur',
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
  final IpTradeSecretManagementDecisionRepository repository;

  @override
  State<_CreateDialog> createState() => _CreateDialogState();
}

class _CreateDialogState extends State<_CreateDialog> {
  final _formKey = GlobalKey<FormState>();
  final _code = TextEditingController();
  final _title = TextEditingController();
  final _owner = TextEditingController();
  final _summary = TextEditingController();
  final _rationale = TextEditingController();
  final _conditions = TextEditingController();
  final _riskIds = TextEditingController();
  final _incidentIds = TextEditingController();
  final _controlIds = TextEditingController();
  final _actionIds = TextEditingController();
  final _evidenceIds = TextEditingController();
  final _reviewerIds = TextEditingController();
  final _approverIds = TextEditingController();
  final _previousOwner = TextEditingController();
  final _newOwner = TextEditingController();
  final _previousLevel = TextEditingController();
  final _newLevel = TextEditingController();
  final _requestedBudget = TextEditingController();
  final _approvedBudget = TextEditingController();
  final _currency = TextEditingController(text: 'TRY');
  final _notes = TextEditingController();

  late String _tradeSecretId;
  IpTradeSecretDecisionStatus _status = IpTradeSecretDecisionStatus.draft;
  IpTradeSecretDecisionType _type = IpTradeSecretDecisionType.other;
  IpTradeSecretDecisionVotingMethod _votingMethod =
      IpTradeSecretDecisionVotingMethod.singleApprover;

  int _requiredApprovalCount = 1;
  bool _riskAcceptance = false;
  bool _conditionalDecision = false;
  bool _legalReview = false;
  bool _securityReview = false;
  bool _financeReview = false;
  bool _boardReview = false;
  bool _reassessmentRequired = false;
  DateTime? _reassessmentAt;
  DateTime? _expiresAt;
  bool _saving = false;

  static const _safeStatuses = <IpTradeSecretDecisionStatus>[
    IpTradeSecretDecisionStatus.draft,
    IpTradeSecretDecisionStatus.underReview,
    IpTradeSecretDecisionStatus.pendingApproval,
  ];

  @override
  void initState() {
    super.initState();
    _tradeSecretId = widget.secrets.first.id;
    _owner.text = widget.actorId;
    _approverIds.text = widget.actorId;
  }

  @override
  void dispose() {
    for (final controller in [
      _code,
      _title,
      _owner,
      _summary,
      _rationale,
      _conditions,
      _riskIds,
      _incidentIds,
      _controlIds,
      _actionIds,
      _evidenceIds,
      _reviewerIds,
      _approverIds,
      _previousOwner,
      _newOwner,
      _previousLevel,
      _newLevel,
      _requestedBudget,
      _approvedBudget,
      _currency,
      _notes,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1040, maxHeight: 820),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 12, 14),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Yeni Yönetim Kararı',
                      style: TextStyle(
                        color: MarkaKalkanTheme.navy,
                        fontSize: 22,
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
                      final width = constraints.maxWidth < 760
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
                                        '${secret.secretCode} — '
                                        '${secret.title}',
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
                          _Text(width, _code, 'Karar Kodu *', required: true),
                          _Text(width, _title, 'Başlık *', required: true),
                          _Text(
                            width,
                            _owner,
                            'Karar Sahibi *',
                            required: true,
                          ),
                          SizedBox(
                            width: width,
                            child:
                                DropdownButtonFormField<
                                  IpTradeSecretDecisionStatus
                                >(
                                  initialValue: _status,
                                  decoration: const InputDecoration(
                                    labelText: 'Durum',
                                  ),
                                  items: _safeStatuses
                                      .map(
                                        (item) => DropdownMenuItem(
                                          value: item,
                                          child: Text(item.label),
                                        ),
                                      )
                                      .toList(growable: false),
                                  onChanged: (value) {
                                    if (value != null) {
                                      setState(() => _status = value);
                                    }
                                  },
                                ),
                          ),
                          SizedBox(
                            width: width,
                            child:
                                DropdownButtonFormField<
                                  IpTradeSecretDecisionType
                                >(
                                  initialValue: _type,
                                  isExpanded: true,
                                  decoration: const InputDecoration(
                                    labelText: 'Karar Türü',
                                  ),
                                  items: IpTradeSecretDecisionType.values
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
                                        _type = value;
                                        _riskAcceptance =
                                            value ==
                                            IpTradeSecretDecisionType
                                                .riskAcceptance;
                                        if (_riskAcceptance) {
                                          _reassessmentRequired = true;
                                        }
                                      });
                                    }
                                  },
                                ),
                          ),
                          SizedBox(
                            width: width,
                            child:
                                DropdownButtonFormField<
                                  IpTradeSecretDecisionVotingMethod
                                >(
                                  initialValue: _votingMethod,
                                  isExpanded: true,
                                  decoration: const InputDecoration(
                                    labelText: 'Oylama Yöntemi',
                                  ),
                                  items: IpTradeSecretDecisionVotingMethod
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
                                      setState(() => _votingMethod = value);
                                    }
                                  },
                                ),
                          ),
                          _Text(
                            width,
                            _approverIds,
                            'Onaylayan Kullanıcı Kimlikleri *',
                            required: true,
                          ),
                          _Text(
                            width,
                            _reviewerIds,
                            'İnceleyen Kullanıcı Kimlikleri',
                          ),
                          SizedBox(
                            width: width,
                            child: DropdownButtonFormField<int>(
                              initialValue: _requiredApprovalCount,
                              decoration: const InputDecoration(
                                labelText: 'Gerekli Onay Sayısı',
                              ),
                              items: List.generate(
                                10,
                                (index) => DropdownMenuItem(
                                  value: index + 1,
                                  child: Text('${index + 1}'),
                                ),
                              ),
                              onChanged: (value) {
                                if (value != null) {
                                  setState(
                                    () => _requiredApprovalCount = value,
                                  );
                                }
                              },
                            ),
                          ),
                          _Text(
                            constraints.maxWidth,
                            _summary,
                            'Karar Özeti',
                            maxLines: 3,
                          ),
                          _Text(
                            constraints.maxWidth,
                            _rationale,
                            'Gerekçe',
                            maxLines: 3,
                          ),
                          if (_conditionalDecision)
                            _Text(
                              constraints.maxWidth,
                              _conditions,
                              'Koşullar *',
                              required: true,
                              maxLines: 3,
                            ),
                          if (_type ==
                                  IpTradeSecretDecisionType.ownershipTransfer ||
                              _type ==
                                  IpTradeSecretDecisionType
                                      .responsibilityTransfer) ...[
                            _Text(
                              width,
                              _previousOwner,
                              'Önceki Sorumlu *',
                              required: true,
                            ),
                            _Text(
                              width,
                              _newOwner,
                              'Yeni Sorumlu *',
                              required: true,
                            ),
                          ],
                          if (_type ==
                                  IpTradeSecretDecisionType
                                      .protectionLevelIncrease ||
                              _type ==
                                  IpTradeSecretDecisionType
                                      .protectionLevelReduction) ...[
                            _Text(
                              width,
                              _previousLevel,
                              'Önceki Koruma Seviyesi *',
                              required: true,
                            ),
                            _Text(
                              width,
                              _newLevel,
                              'Yeni Koruma Seviyesi *',
                              required: true,
                            ),
                          ],
                          _Text(
                            width,
                            _requestedBudget,
                            'Talep Edilen Bütçe',
                            numeric: true,
                          ),
                          _Text(
                            width,
                            _approvedBudget,
                            _type == IpTradeSecretDecisionType.budgetApproval
                                ? 'Onaylanan Bütçe *'
                                : 'Onaylanan Bütçe',
                            required:
                                _type ==
                                IpTradeSecretDecisionType.budgetApproval,
                            numeric: true,
                          ),
                          _Text(width, _currency, 'Para Birimi'),
                          _Date(
                            width: width,
                            label: 'Yeniden Değerlendirme Tarihi',
                            value: _reassessmentAt,
                            onChanged: (value) =>
                                setState(() => _reassessmentAt = value),
                          ),
                          _Date(
                            width: width,
                            label: 'Sona Erme Tarihi',
                            value: _expiresAt,
                            onChanged: (value) =>
                                setState(() => _expiresAt = value),
                          ),
                          _Text(width, _riskIds, 'Risk Kayıt Kimlikleri'),
                          _Text(width, _incidentIds, 'Olay Kayıt Kimlikleri'),
                          _Text(
                            width,
                            _controlIds,
                            'Koruma Kontrolü Kimlikleri',
                          ),
                          _Text(
                            width,
                            _actionIds,
                            'Düzeltici Aksiyon Kimlikleri',
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
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                FilterChip(
                                  label: const Text('Koşullu karar'),
                                  selected: _conditionalDecision,
                                  onSelected: (value) => setState(
                                    () => _conditionalDecision = value,
                                  ),
                                ),
                                FilterChip(
                                  label: const Text('Risk kabulü'),
                                  selected: _riskAcceptance,
                                  onSelected: (value) {
                                    setState(() {
                                      _riskAcceptance = value;
                                      if (value) {
                                        _type = IpTradeSecretDecisionType
                                            .riskAcceptance;
                                        _reassessmentRequired = true;
                                      }
                                    });
                                  },
                                ),
                                FilterChip(
                                  label: const Text('Hukuk incelemesi'),
                                  selected: _legalReview,
                                  onSelected: (value) =>
                                      setState(() => _legalReview = value),
                                ),
                                FilterChip(
                                  label: const Text('Güvenlik incelemesi'),
                                  selected: _securityReview,
                                  onSelected: (value) =>
                                      setState(() => _securityReview = value),
                                ),
                                FilterChip(
                                  label: const Text('Finans incelemesi'),
                                  selected: _financeReview,
                                  onSelected: (value) =>
                                      setState(() => _financeReview = value),
                                ),
                                FilterChip(
                                  label: const Text('Kurul incelemesi'),
                                  selected: _boardReview,
                                  onSelected: (value) =>
                                      setState(() => _boardReview = value),
                                ),
                                FilterChip(
                                  label: const Text(
                                    'Yeniden değerlendirme gerekli',
                                  ),
                                  selected: _reassessmentRequired,
                                  onSelected: (value) => setState(
                                    () => _reassessmentRequired = value,
                                  ),
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
              padding: const EdgeInsets.all(16),
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
                    icon: _saving
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
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

    final approvers = _split(_approverIds.text);
    if (approvers.length < _requiredApprovalCount) {
      _show('Onaylayan kullanıcı sayısı gerekli onay sayısından az olamaz.');
      return;
    }

    if (_conditionalDecision && _conditions.text.trim().isEmpty) {
      _show('Koşullu kararda koşullar zorunludur.');
      return;
    }

    if (_riskAcceptance) {
      if (_rationale.text.trim().isEmpty ||
          _split(_riskIds.text).isEmpty ||
          _reassessmentAt == null) {
        _show(
          'Risk kabulünde gerekçe, risk kaydı ve yeniden değerlendirme '
          'tarihi zorunludur.',
        );
        return;
      }
    }

    if (_reassessmentRequired && _reassessmentAt == null) {
      _show('Yeniden değerlendirme tarihi zorunludur.');
      return;
    }

    final requestedBudget = _number(_requestedBudget.text);
    final approvedBudget = _number(_approvedBudget.text);
    if ((requestedBudget != null || approvedBudget != null) &&
        _currency.text.trim().length != 3) {
      _show('Bütçe bilgisi varsa üç harfli para birimi kodu zorunludur.');
      return;
    }

    setState(() => _saving = true);

    try {
      final secret = widget.secrets.firstWhere(
        (item) => item.id == _tradeSecretId,
      );

      final model = IpTradeSecretManagementDecisionModel(
        id: '',
        tenantId: widget.actorId,
        brandId: secret.brandId,
        tradeSecretId: secret.id,
        riskAssessmentIds: _split(_riskIds.text),
        incidentIds: _split(_incidentIds.text),
        protectionControlIds: _split(_controlIds.text),
        remediationActionIds: _split(_actionIds.text),
        evidenceDocumentIds: _split(_evidenceIds.text),
        reviewerUserIds: _split(_reviewerIds.text),
        approverUserIds: approvers,
        decisionCode: _code.text.trim(),
        title: _title.text.trim(),
        status: _status,
        decisionType: _type,
        votingMethod: _votingMethod,
        approvalOutcome: IpTradeSecretApprovalOutcome.pending,
        ownerUserId: _owner.text.trim(),
        decisionSummary: _null(_summary.text),
        rationale: _null(_rationale.text),
        conditions: _conditionalDecision ? _null(_conditions.text) : null,
        previousOwnerUserId: _null(_previousOwner.text),
        newOwnerUserId: _null(_newOwner.text),
        previousProtectionLevel: _null(_previousLevel.text),
        newProtectionLevel: _null(_newLevel.text),
        requestedBudgetAmount: requestedBudget,
        approvedBudgetAmount: approvedBudget,
        currencyCode: requestedBudget != null || approvedBudget != null
            ? _currency.text.trim().toUpperCase()
            : null,
        requiredApprovalCount: _requiredApprovalCount,
        riskAcceptance: _riskAcceptance,
        conditionalDecision: _conditionalDecision,
        legalReviewRequired: _legalReview,
        securityReviewRequired: _securityReview,
        financeReviewRequired: _financeReview,
        boardReviewRequired: _boardReview,
        reassessmentRequired: _reassessmentRequired,
        expiresAt: _expiresAt,
        reassessmentAt: _reassessmentAt,
        notes: _null(_notes.text),
        createdAt: DateTime.now().toUtc(),
        createdBy: widget.actorId,
      );

      await widget.repository.create(model);
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(() => _saving = false);
        _show('Yönetim kararı oluşturulamadı: $error');
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
    this.numeric = false,
  });

  final double width;
  final TextEditingController controller;
  final String label;
  final bool required;
  final int maxLines;
  final bool numeric;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: numeric
            ? const TextInputType.numberWithOptions(decimal: true)
            : null,
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
          final now = DateTime.now();
          final selected = await showDatePicker(
            context: context,
            initialDate: value?.toLocal() ?? now,
            firstDate: DateTime(now.year - 1),
            lastDate: DateTime(now.year + 10),
          );
          if (selected != null) {
            onChanged(
              DateTime.utc(selected.year, selected.month, selected.day),
            );
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

class _Badge extends StatelessWidget {
  const _Badge(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F4F6),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFD7E0E5)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: MarkaKalkanTheme.navy,
          fontWeight: FontWeight.w700,
          fontSize: 12,
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
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 180,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF66747D),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(color: MarkaKalkanTheme.navy, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

BoxDecoration _panel() {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(18),
    border: Border.all(color: const Color(0xFFE0E6EA)),
    boxShadow: const [
      BoxShadow(color: Color(0x0A000000), blurRadius: 14, offset: Offset(0, 4)),
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

String _join(List<String> values) {
  return values.isEmpty ? '—' : values.join(', ');
}

String _money(num? amount, String? currency) {
  if (amount == null) return '—';
  return '${amount.toString()} ${currency ?? ''}'.trim();
}

List<String> _split(String value) {
  return value
      .split(RegExp(r'[,;\n]'))
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toSet()
      .toList(growable: false);
}

String? _null(String value) {
  final cleaned = value.trim();
  return cleaned.isEmpty ? null : cleaned;
}

num? _number(String value) {
  final cleaned = value.trim().replaceAll(',', '.');
  if (cleaned.isEmpty) return null;
  return num.tryParse(cleaned);
}

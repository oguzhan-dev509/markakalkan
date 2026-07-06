import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:markakalkan/core/theme/markakalkan_theme.dart';

import '../constants/ip_trade_secret_detail_enums.dart';
import '../models/ip_trade_secret_incident_model.dart';
import '../models/ip_trade_secret_model.dart';
import '../repositories/ip_trade_secret_incident_repository.dart';
import '../repositories/ip_trade_secret_repository.dart';

class IpTradeSecretIncidentPage extends StatefulWidget {
  const IpTradeSecretIncidentPage({super.key});

  @override
  State<IpTradeSecretIncidentPage> createState() =>
      _IpTradeSecretIncidentPageState();
}

class _IpTradeSecretIncidentPageState extends State<IpTradeSecretIncidentPage> {
  IpTradeSecretRepository? _secretRepository;
  IpTradeSecretIncidentRepository? _incidentRepository;
  String _search = '';
  String? _tradeSecretId;
  IpTradeSecretIncidentStatus? _status;
  IpTradeSecretIncidentSeverity? _severity;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _secretRepository = IpTradeSecretRepository.instance(tenantId: user.uid);
      _incidentRepository = IpTradeSecretIncidentRepository.instance(
        tenantId: user.uid,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null ||
        _secretRepository == null ||
        _incidentRepository == null) {
      return const Scaffold(
        body: Center(child: Text('Bu sayfa için oturum açmanız gerekir.')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Olay ve İhlal Yönetimi')),
      body: StreamBuilder<List<IpTradeSecretModel>>(
        stream: _secretRepository!.watchAll(),
        builder: (context, secretSnapshot) {
          if (secretSnapshot.hasError) {
            return _ErrorPanel(
              'Formüller yüklenemedi: ${secretSnapshot.error}',
            );
          }
          final secrets = secretSnapshot.data ?? const <IpTradeSecretModel>[];

          return StreamBuilder<List<IpTradeSecretIncidentModel>>(
            stream: _incidentRepository!.watch(tradeSecretId: _tradeSecretId),
            builder: (context, incidentSnapshot) {
              if (incidentSnapshot.hasError) {
                return _ErrorPanel(
                  'Olaylar yüklenemedi: ${incidentSnapshot.error}',
                );
              }
              final all =
                  incidentSnapshot.data ?? const <IpTradeSecretIncidentModel>[];
              final q = _search.trim().toLowerCase();
              final filtered = all.where((item) {
                final text =
                    q.isEmpty ||
                    item.incidentCode.toLowerCase().contains(q) ||
                    item.title.toLowerCase().contains(q) ||
                    (item.summary ?? '').toLowerCase().contains(q);
                return text &&
                    (_status == null || item.status == _status) &&
                    (_severity == null || item.severity == _severity);
              }).toList();

              return _Registry(
                all: all,
                filtered: filtered,
                secrets: secrets,
                tradeSecretId: _tradeSecretId,
                search: _search,
                status: _status,
                severity: _severity,
                onTradeSecretChanged: (v) => setState(() => _tradeSecretId = v),
                onSearchChanged: (v) => setState(() => _search = v),
                onStatusChanged: (v) => setState(() => _status = v),
                onSeverityChanged: (v) => setState(() => _severity = v),
                onCreate: () => _showCreateDialog(user.uid, secrets),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _showCreateDialog(
    String actorId,
    List<IpTradeSecretModel> secrets,
  ) async {
    if (secrets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Önce bir formül kaydı oluşturun.')),
      );
      return;
    }

    final code = TextEditingController();
    final title = TextEditingController();
    final summary = TextEditingController();
    final detection = TextEditingController();
    final impact = TextEditingController();
    final actor = TextEditingController();

    var secret = secrets.first;
    var type = IpTradeSecretIncidentType.unauthorizedAccess;
    var status = IpTradeSecretIncidentStatus.reported;
    var severity = IpTradeSecretIncidentSeverity.medium;
    var source = IpTradeSecretIncidentSource.employeeReport;
    var personalData = false;
    var crossBorder = false;
    var externalParty = false;
    var regulatorNotice = false;
    var legalReview = true;
    var evidencePreservation = true;
    var accessRevocation = false;
    var continuity = false;

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Yeni Olay / İhlal Kaydı'),
          content: SizedBox(
            width: 700,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<IpTradeSecretModel>(
                    initialValue: secret,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Formül / Ticari Sır',
                    ),
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
                    onChanged: (v) {
                      if (v != null) setDialogState(() => secret = v);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: code,
                    decoration: const InputDecoration(labelText: 'Olay kodu'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: title,
                    decoration: const InputDecoration(
                      labelText: 'Olay başlığı',
                    ),
                  ),
                  const SizedBox(height: 12),
                  _EnumField<IpTradeSecretIncidentType>(
                    value: type,
                    label: 'Olay türü',
                    values: IpTradeSecretIncidentType.values,
                    text: (v) => v.label,
                    onChanged: (v) => setDialogState(() => type = v),
                  ),
                  const SizedBox(height: 12),
                  _EnumField<IpTradeSecretIncidentStatus>(
                    value: status,
                    label: 'Durum',
                    values: IpTradeSecretIncidentStatus.values,
                    text: (v) => v.label,
                    onChanged: (v) => setDialogState(() => status = v),
                  ),
                  const SizedBox(height: 12),
                  _EnumField<IpTradeSecretIncidentSeverity>(
                    value: severity,
                    label: 'Önem seviyesi',
                    values: IpTradeSecretIncidentSeverity.values,
                    text: (v) => v.label,
                    onChanged: (v) => setDialogState(() => severity = v),
                  ),
                  const SizedBox(height: 12),
                  _EnumField<IpTradeSecretIncidentSource>(
                    value: source,
                    label: 'Tespit kaynağı',
                    values: IpTradeSecretIncidentSource.values,
                    text: (v) => v.label,
                    onChanged: (v) => setDialogState(() => source = v),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: actor,
                    decoration: const InputDecoration(
                      labelText: 'Şüpheli kişi/varlık kimliği',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: summary,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Olay özeti'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: detection,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Tespit ayrıntıları',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: impact,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Etki açıklaması',
                    ),
                  ),
                  const Divider(height: 28),
                  _Switch(
                    'Kişisel veri etkilenmiş olabilir',
                    personalData,
                    (v) => setDialogState(() => personalData = v),
                  ),
                  _Switch(
                    'Sınır ötesi etki',
                    crossBorder,
                    (v) => setDialogState(() => crossBorder = v),
                  ),
                  _Switch(
                    'Harici taraf dahil',
                    externalParty,
                    (v) => setDialogState(() => externalParty = v),
                  ),
                  _Switch(
                    'Düzenleyici kurum bildirimi gerekli',
                    regulatorNotice,
                    (v) => setDialogState(() => regulatorNotice = v),
                  ),
                  _Switch(
                    'Hukuki inceleme gerekli',
                    legalReview,
                    (v) => setDialogState(() => legalReview = v),
                  ),
                  _Switch(
                    'Kanıt koruma gerekli',
                    evidencePreservation,
                    (v) => setDialogState(() => evidencePreservation = v),
                  ),
                  _Switch(
                    'Erişim iptali gerekli',
                    accessRevocation,
                    (v) => setDialogState(() => accessRevocation = v),
                  ),
                  _Switch(
                    'İş sürekliliği etkilendi',
                    continuity,
                    (v) => setDialogState(() => continuity = v),
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
                  final suspected = actor.text.trim();
                  await _incidentRepository!.create(
                    IpTradeSecretIncidentModel(
                      id: '',
                      tenantId: actorId,
                      brandId: secret.brandId,
                      tradeSecretId: secret.id,
                      incidentCode: code.text.trim(),
                      title: title.text.trim(),
                      type: type,
                      status: status,
                      severity: severity,
                      source: source,
                      detectedAt: now,
                      reportedAt: now,
                      reportedBy: actorId,
                      createdAt: now,
                      createdBy: actorId,
                      suspectedActorIds: suspected.isEmpty
                          ? const <String>[]
                          : <String>[suspected],
                      summary: summary.text.trim(),
                      detectionDetails: detection.text.trim(),
                      impactDescription: impact.text.trim(),
                      personalDataAffected: personalData,
                      crossBorderImpact: crossBorder,
                      externalPartyInvolved: externalParty,
                      regulatorNotificationRequired: regulatorNotice,
                      legalReviewRequired: legalReview,
                      evidencePreservationRequired: evidencePreservation,
                      accessRevocationRequired: accessRevocation,
                      businessContinuityAffected: continuity,
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

    for (final c in [code, title, summary, detection, impact, actor]) {
      c.dispose();
    }

    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Olay ve ihlal kaydı oluşturuldu.')),
      );
    }
  }
}

class _Registry extends StatelessWidget {
  const _Registry({
    required this.all,
    required this.filtered,
    required this.secrets,
    required this.tradeSecretId,
    required this.search,
    required this.status,
    required this.severity,
    required this.onTradeSecretChanged,
    required this.onSearchChanged,
    required this.onStatusChanged,
    required this.onSeverityChanged,
    required this.onCreate,
  });

  final List<IpTradeSecretIncidentModel> all;
  final List<IpTradeSecretIncidentModel> filtered;
  final List<IpTradeSecretModel> secrets;
  final String? tradeSecretId;
  final String search;
  final IpTradeSecretIncidentStatus? status;
  final IpTradeSecretIncidentSeverity? severity;
  final ValueChanged<String?> onTradeSecretChanged;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<IpTradeSecretIncidentStatus?> onStatusChanged;
  final ValueChanged<IpTradeSecretIncidentSeverity?> onSeverityChanged;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final open = all.where((e) => e.isOpen).length;
    final critical = all.where((e) => e.isCritical).length;
    final urgent = all.where((e) => e.requiresImmediateReview).length;
    final external = all.where((e) => e.hasExternalImpact).length;
    final evidence = all
        .where(
          (e) =>
              e.evidencePreservationRequired &&
              !e.evidencePreservationCompleted,
        )
        .length;
    final legal = all
        .where((e) => e.legalReviewRequired && !e.legalReviewCompleted)
        .length;

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
                  final heading = const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Olay ve İhlal Yönetimi',
                        style: TextStyle(
                          color: MarkaKalkanTheme.navy,
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Şüpheli erişim, sızıntı ve kötüye kullanım olaylarını kalıcı vaka sicilinde yönetin.',
                        style: TextStyle(
                          color: Color(0xFF687580),
                          height: 1.45,
                        ),
                      ),
                    ],
                  );
                  final button = FilledButton.icon(
                    onPressed: onCreate,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Yeni Olay Kaydı'),
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
              _MetricsGrid([
                _Metric('Toplam Olay', all.length, Icons.security_outlined),
                _Metric('Açık Olay', open, Icons.folder_open_outlined),
                _Metric('Kritik', critical, Icons.crisis_alert_outlined),
                _Metric('Acil İnceleme', urgent, Icons.warning_amber_rounded),
                _Metric('Kanıt Bekliyor', evidence, Icons.inventory_2_outlined),
                _Metric('Hukuki İnceleme', legal, Icons.gavel_outlined),
              ]),
              const SizedBox(height: 18),
              _Panel(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 900;
                    final width = compact
                        ? constraints.maxWidth
                        : (constraints.maxWidth - 36) / 4;
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        SizedBox(
                          width: width,
                          child: TextFormField(
                            key: ValueKey(search),
                            initialValue: search,
                            onChanged: onSearchChanged,
                            decoration: const InputDecoration(
                              prefixIcon: Icon(Icons.search),
                              labelText: 'Kod, başlık veya özet ara',
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
                              const DropdownMenuItem(
                                value: null,
                                child: Text('Tümü'),
                              ),
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
                            onChanged: onTradeSecretChanged,
                          ),
                        ),
                        SizedBox(
                          width: width,
                          child:
                              DropdownButtonFormField<
                                IpTradeSecretIncidentStatus?
                              >(
                                initialValue: status,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'Durum',
                                ),
                                items: [
                                  const DropdownMenuItem(
                                    value: null,
                                    child: Text('Tümü'),
                                  ),
                                  ...IpTradeSecretIncidentStatus.values.map(
                                    (e) => DropdownMenuItem(
                                      value: e,
                                      child: Text(e.label),
                                    ),
                                  ),
                                ],
                                onChanged: onStatusChanged,
                              ),
                        ),
                        SizedBox(
                          width: width,
                          child:
                              DropdownButtonFormField<
                                IpTradeSecretIncidentSeverity?
                              >(
                                initialValue: severity,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'Önem',
                                ),
                                items: [
                                  const DropdownMenuItem(
                                    value: null,
                                    child: Text('Tümü'),
                                  ),
                                  ...IpTradeSecretIncidentSeverity.values.map(
                                    (e) => DropdownMenuItem(
                                      value: e,
                                      child: Text(e.label),
                                    ),
                                  ),
                                ],
                                onChanged: onSeverityChanged,
                              ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 14),
              if (filtered.isEmpty)
                const _EmptyPanel(
                  'Olay kaydı bulunamadı',
                  'Yeni olay veya ihlal kaydı oluşturarak vaka sicilini başlatın.',
                )
              else
                _IncidentTable(filtered),
              if (external > 0) ...[
                const SizedBox(height: 14),
                _Panel(
                  child: Text(
                    '$external olay harici etki taşıyor. Hukuki bildirim ve kanıt koruma durumlarını inceleyin.',
                    style: const TextStyle(
                      color: MarkaKalkanTheme.navy,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _IncidentTable extends StatelessWidget {
  const _IncidentTable(this.items);
  final List<IpTradeSecretIncidentModel> items;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Olay Kodu')),
            DataColumn(label: Text('Başlık')),
            DataColumn(label: Text('Tür')),
            DataColumn(label: Text('Önem')),
            DataColumn(label: Text('Kaynak')),
            DataColumn(label: Text('Durum')),
            DataColumn(label: Text('Acil')),
            DataColumn(label: Text('Risk')),
          ],
          rows: items
              .map(
                (e) => DataRow(
                  cells: [
                    DataCell(Text(e.incidentCode)),
                    DataCell(Text(e.title)),
                    DataCell(Text(e.type.label)),
                    DataCell(_Badge(e.severity.label)),
                    DataCell(Text(e.source.label)),
                    DataCell(_Badge(e.status.label)),
                    DataCell(
                      _Badge(
                        e.requiresImmediateReview
                            ? 'İnceleme Gerekli'
                            : 'Normal',
                      ),
                    ),
                    DataCell(Text('${e.incidentRiskScore} / 100')),
                  ],
                ),
              )
              .toList(),
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
                (e) => SizedBox(
                  width: width,
                  child: _Panel(
                    child: Row(
                      children: [
                        _IconBox(e.icon),
                        const SizedBox(width: 14),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              e.title,
                              style: const TextStyle(
                                color: Color(0xFF687580),
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              '${e.value}',
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

class _EnumField<T> extends StatelessWidget {
  const _EnumField({
    required this.value,
    required this.label,
    required this.values,
    required this.text,
    required this.onChanged,
  });

  final T value;
  final String label;
  final List<T> values;
  final String Function(T) text;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: values
          .map((e) => DropdownMenuItem(value: e, child: Text(text(e))))
          .toList(),
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}

class _Switch extends StatelessWidget {
  const _Switch(this.title, this.value, this.onChanged);
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile.adaptive(
      value: value,
      title: Text(title),
      onChanged: onChanged,
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
    final bad =
        lower.contains('kritik') ||
        lower.contains('yüksek') ||
        lower.contains('gerekli');
    final good =
        lower.contains('çözüldü') ||
        lower.contains('kapatıldı') ||
        lower.contains('normal') ||
        lower.contains('kontrol');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: bad
            ? const Color(0xFFFFECEA)
            : good
            ? const Color(0xFFE8F7EE)
            : const Color(0xFFFFF5E4),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: bad
              ? const Color(0xFFD64545)
              : good
              ? const Color(0xFF16824A)
              : const Color(0xFFB56A00),
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
              Icons.security_outlined,
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

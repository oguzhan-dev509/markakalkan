import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:markakalkan/core/theme/markakalkan_theme.dart';
import 'package:markakalkan/features/admin/data/counterfeit_twin_admin_service.dart';
import 'package:markakalkan/features/admin/models/counterfeit_twin_admin_report.dart';

class CounterfeitTwinReviewQueuePage extends StatefulWidget {
  const CounterfeitTwinReviewQueuePage({super.key});

  @override
  State<CounterfeitTwinReviewQueuePage> createState() =>
      _CounterfeitTwinReviewQueuePageState();
}

class _CounterfeitTwinReviewQueuePageState
    extends State<CounterfeitTwinReviewQueuePage> {
  final CounterfeitTwinAdminService _service = CounterfeitTwinAdminService();

  late Future<List<CounterfeitTwinAdminReport>> _future;
  String _filter = 'open';

  @override
  void initState() {
    super.initState();
    _future = _service.listReports();
  }

  void _reload() {
    setState(() {
      _future = _service.listReports();
    });
  }

  List<CounterfeitTwinAdminReport> _visible(
    List<CounterfeitTwinAdminReport> reports,
  ) {
    if (_filter == 'all') return reports;
    if (_filter == 'open') {
      return reports.where((item) => item.isOpen).toList(growable: false);
    }
    return reports
        .where((item) => item.status == _filter)
        .toList(growable: false);
  }

  int _count(List<CounterfeitTwinAdminReport> reports, String filter) {
    if (filter == 'all') return reports.length;
    if (filter == 'open') {
      return reports.where((item) => item.isOpen).length;
    }
    return reports.where((item) => item.status == filter).length;
  }

  Future<void> _open(CounterfeitTwinAdminReport report) async {
    final changed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ReviewDialog(report: report, service: _service),
    );
    if (changed == true && mounted) {
      _reload();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Yönetim kararı kaydedildi.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MarkaKalkanTheme.background,
      appBar: AppBar(
        title: const Text(
          'Sahte İkiz Bildirim İnceleme',
          style: TextStyle(
            color: MarkaKalkanTheme.navy,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Yenile',
            onPressed: _reload,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: FutureBuilder<List<CounterfeitTwinAdminReport>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _Message(
              icon: Icons.cloud_off_outlined,
              title: 'İnceleme kuyruğu yüklenemedi',
              message: _errorMessage(snapshot.error),
              actionLabel: 'Yeniden Dene',
              onAction: _reload,
            );
          }

          final reports = snapshot.data ?? const <CounterfeitTwinAdminReport>[];
          final visible = _visible(reports);

          return RefreshIndicator(
            onRefresh: () async {
              _reload();
              await _future;
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 48),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1160),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _Hero(reports: reports),
                        const SizedBox(height: 20),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _Filter(
                              label: 'Açık',
                              count: _count(reports, 'open'),
                              selected: _filter == 'open',
                              onTap: () => setState(() => _filter = 'open'),
                            ),
                            _Filter(
                              label: 'Yeni',
                              count: _count(reports, 'submitted'),
                              selected: _filter == 'submitted',
                              onTap: () =>
                                  setState(() => _filter = 'submitted'),
                            ),
                            _Filter(
                              label: 'İncelemede',
                              count: _count(reports, 'under_review'),
                              selected: _filter == 'under_review',
                              onTap: () =>
                                  setState(() => _filter = 'under_review'),
                            ),
                            _Filter(
                              label: 'Yayımlandı',
                              count: _count(reports, 'published'),
                              selected: _filter == 'published',
                              onTap: () =>
                                  setState(() => _filter = 'published'),
                            ),
                            _Filter(
                              label: 'Reddedildi',
                              count: _count(reports, 'rejected'),
                              selected: _filter == 'rejected',
                              onTap: () => setState(() => _filter = 'rejected'),
                            ),
                            _Filter(
                              label: 'Tümü',
                              count: _count(reports, 'all'),
                              selected: _filter == 'all',
                              onTap: () => setState(() => _filter = 'all'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        if (visible.isEmpty)
                          const _Message(
                            icon: Icons.inbox_outlined,
                            title: 'Bu görünümde bildirim yok',
                            message:
                                'Yeni sahte ikiz bildirimleri burada listelenecek.',
                          )
                        else
                          ...visible.map(
                            (report) => Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: _ReportCard(
                                report: report,
                                onTap: () => _open(report),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.reports});

  final List<CounterfeitTwinAdminReport> reports;

  @override
  Widget build(BuildContext context) {
    final open = reports.where((item) => item.isOpen).length;
    final published = reports
        .where((item) => item.status == 'published')
        .length;

    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [MarkaKalkanTheme.navy, Color(0xFF1C5260)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final copy = const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sahte İkiz İnceleme Kuyruğu',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 27,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 9),
              Text(
                'Kullanıcı bildirimlerini ve delilleri inceleyin; '
                'incelemeye alın, gerekçeli olarak reddedin veya '
                'doğrulanmış kamu kaydı olarak yayımlayın.',
                style: TextStyle(color: Color(0xFFD9E5EA), height: 1.5),
              ),
            ],
          );

          final stats = Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _Stat(label: 'Açık', value: open),
              _Stat(label: 'Yayımlandı', value: published),
              _Stat(label: 'Toplam', value: reports.length),
            ],
          );

          if (constraints.maxWidth < 720) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [copy, const SizedBox(height: 20), stats],
            );
          }

          return Row(
            children: [
              Expanded(child: copy),
              const SizedBox(width: 24),
              stats,
            ],
          );
        },
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 100,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: [
          Text(
            '$value',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFFD9E5EA),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _Filter extends StatelessWidget {
  const _Filter({
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
    return ChoiceChip(
      selected: selected,
      onSelected: (_) => onTap(),
      label: Text('$label ($count)'),
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.report, required this.onTap});

  final CounterfeitTwinAdminReport report;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: ValueKey<String>('counterfeit-twin-admin-report-${report.id}'),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final main = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _Status(status: report.status),
                      Chip(label: Text(_category(report.publicCategory))),
                      if (report.publicSubcategory.isNotEmpty)
                        Chip(label: Text(_humanize(report.publicSubcategory))),
                    ],
                  ),
                  const SizedBox(height: 13),
                  Text(
                    '${_fallback(report.originalName)} → '
                    '${_fallback(report.suspectedName)}',
                    style: const TextStyle(
                      color: MarkaKalkanTheme.navy,
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    [
                      if (report.platformName.isNotEmpty) report.platformName,
                      if (report.storeDisplayName.isNotEmpty)
                        report.storeDisplayName,
                      'Başvuru: ${report.id}',
                    ].join(' • '),
                    style: const TextStyle(
                      color: Color(0xFF667085),
                      height: 1.4,
                    ),
                  ),
                ],
              );

              final action = Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _date(report.createdAt),
                    style: const TextStyle(
                      color: Color(0xFF667085),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 18),
                  FilledButton.tonalIcon(
                    onPressed: onTap,
                    icon: const Icon(Icons.fact_check_outlined),
                    label: Text(report.isOpen ? 'İncele' : 'Detayı Aç'),
                  ),
                ],
              );

              if (constraints.maxWidth < 700) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    main,
                    const SizedBox(height: 16),
                    Align(alignment: Alignment.centerRight, child: action),
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: main),
                  const SizedBox(width: 20),
                  action,
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ReviewDialog extends StatefulWidget {
  const _ReviewDialog({required this.report, required this.service});

  final CounterfeitTwinAdminReport report;
  final CounterfeitTwinAdminService service;

  @override
  State<_ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends State<_ReviewDialog> {
  late final TextEditingController _reviewNote;
  late final TextEditingController _publicSummary;

  String? _error;
  String? _saving;

  @override
  void initState() {
    super.initState();
    _reviewNote = TextEditingController(text: widget.report.reviewNote);
    _publicSummary = TextEditingController(text: widget.report.publicSummary);
  }

  @override
  void dispose() {
    _reviewNote.dispose();
    _publicSummary.dispose();
    super.dispose();
  }

  Future<void> _decide(String decision) async {
    final reviewNote = _reviewNote.text.trim();
    final publicSummary = _publicSummary.text.trim();

    if (decision == 'rejected' && reviewNote.isEmpty) {
      setState(() => _error = 'Ret kararı için gerekçe zorunludur.');
      return;
    }
    if (decision == 'published' && publicSummary.isEmpty) {
      setState(() => _error = 'Yayımlama için kamuya açık özet zorunludur.');
      return;
    }

    setState(() {
      _error = null;
      _saving = decision;
    });

    try {
      await widget.service.reviewReport(
        reportId: widget.report.id,
        decision: decision,
        reviewNote: reviewNote,
        publicSummary: publicSummary,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = null;
        _error = error.message ?? 'Yönetim kararı kaydedilemedi.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = null;
        _error = 'Yönetim kararı şu anda kaydedilemiyor.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final report = widget.report;
    final screen = MediaQuery.sizeOf(context);

    return Dialog(
      insetPadding: const EdgeInsets.all(18),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 960,
          maxHeight: screen.height * 0.92,
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 16, 16),
              child: Row(
                children: [
                  const Icon(
                    Icons.fact_check_outlined,
                    color: MarkaKalkanTheme.teal,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Başvuru ${report.id}',
                      style: const TextStyle(
                        color: MarkaKalkanTheme.navy,
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  _Status(status: report.status),
                  IconButton(
                    tooltip: 'Kapat',
                    onPressed: _saving == null
                        ? () => Navigator.of(context).pop(false)
                        : null,
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Section(
                      title: 'Sınıflandırma ve kimlik',
                      rows: [
                        ('Ana kategori', _category(report.publicCategory)),
                        ('Alt kategori', _humanize(report.publicSubcategory)),
                        ('Hedef türü', _humanize(report.targetType)),
                        ('Robot türü', _humanize(report.robotType)),
                        ('Gerçek varlık', _fallback(report.originalName)),
                        ('Şüpheli ikiz', _fallback(report.suspectedName)),
                        ('Olay türleri', _list(report.texts('incidentTypes'))),
                      ],
                    ),
                    _Section(
                      title: 'Kaynak ve satıcı',
                      rows: [
                        ('Platform', report.platformName),
                        ('Mağaza / hesap', report.storeDisplayName),
                        ('İlan bağlantısı', report.listingUrl),
                        (
                          'Gerçek kaynaklar',
                          _list(report.texts('originalUrls')),
                        ),
                        (
                          'Şüpheli kaynaklar',
                          _list(report.texts('suspectedUrls')),
                        ),
                      ],
                    ),
                    _Section(
                      title: 'Deliller',
                      rows: [
                        (
                          'Fark notları',
                          _list(report.texts('differenceNotes')),
                        ),
                        ('Delil açıklaması', report.evidenceNotes),
                        (
                          'Gerçek görseller',
                          _list(report.texts('originalImageUrls')),
                        ),
                        (
                          'Şüpheli görseller',
                          _list(report.texts('suspectedImageUrls')),
                        ),
                      ],
                    ),
                    _Financial(report: report),
                    _Section(
                      title: 'Başvuru bilgileri',
                      rows: [
                        ('Gönderen e-posta', report.reporterEmail),
                        ('Gönderen UID', report.reporterUid),
                        ('Gönderim zamanı', _date(report.createdAt)),
                        ('İnceleme zamanı', _date(report.reviewedAt)),
                        ('Kamu kaydı', report.publicComparisonId),
                      ],
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _reviewNote,
                      minLines: 3,
                      maxLines: 6,
                      enabled: report.isOpen && _saving == null,
                      decoration: const InputDecoration(
                        labelText: 'İç inceleme notu / ret gerekçesi',
                        helperText:
                            'Yönetim içindir; kamuya açık kayıtta gösterilmez.',
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _publicSummary,
                      minLines: 3,
                      maxLines: 7,
                      enabled: report.isOpen && _saving == null,
                      decoration: const InputDecoration(
                        labelText: 'Kamuya açık doğrulama özeti',
                        helperText:
                            'Yayımlama kararında zorunludur ve Radar kaydında görünür.',
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFEDEC),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _error!,
                          style: const TextStyle(
                            color: Color(0xFFB42318),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(18),
              child: report.isOpen
                  ? Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        TextButton(
                          onPressed: _saving == null
                              ? () => Navigator.of(context).pop(false)
                              : null,
                          child: const Text('Vazgeç'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _saving == null
                              ? () => _decide('under_review')
                              : null,
                          icon: _DecisionIcon(
                            active: _saving == 'under_review',
                            fallback: Icons.manage_search_outlined,
                          ),
                          label: const Text('İncelemeye Al'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _saving == null
                              ? () => _decide('rejected')
                              : null,
                          icon: _DecisionIcon(
                            active: _saving == 'rejected',
                            fallback: Icons.block_outlined,
                          ),
                          label: const Text('Reddet'),
                        ),
                        FilledButton.icon(
                          onPressed: _saving == null
                              ? () => _decide('published')
                              : null,
                          icon: _DecisionIcon(
                            active: _saving == 'published',
                            fallback: Icons.public_outlined,
                          ),
                          label: const Text('Doğrula ve Yayımla'),
                        ),
                      ],
                    )
                  : Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('Kapat'),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DecisionIcon extends StatelessWidget {
  const _DecisionIcon({required this.active, required this.fallback});

  final bool active;
  final IconData fallback;

  @override
  Widget build(BuildContext context) {
    if (!active) return Icon(fallback);
    return const SizedBox.square(
      dimension: 17,
      child: CircularProgressIndicator(strokeWidth: 2),
    );
  }
}

class _Financial extends StatelessWidget {
  const _Financial({required this.report});

  final CounterfeitTwinAdminReport report;

  @override
  Widget build(BuildContext context) {
    final impact = report.object('financialImpact');
    if (impact.isEmpty) return const SizedBox.shrink();

    String value(String key) => impact[key]?.toString().trim() ?? '';

    return _Section(
      title: 'Finansal etki',
      rows: [
        ('Maddi kayıp', impact['hasMonetaryLoss'] == true ? 'Var' : 'Yok'),
        ('Kayıp tutarı', value('lossAmount')),
        ('Para birimi', value('currency')),
        ('Banka / ödeme sağlayıcısı', value('bankOrPaymentProvider')),
        ('İtiraz durumu', _humanize(value('disputeStatus'))),
        ('İade tutarı', value('refundAmount')),
        ('Geri kazanım', _humanize(value('recoveryStatus'))),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.rows});

  final String title;
  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    final visible = rows
        .where((row) => row.$2.trim().isNotEmpty)
        .toList(growable: false);
    if (visible.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F9FA),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8EC)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: MarkaKalkanTheme.navy,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            ...visible.map(
              (row) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final label = Text(
                      row.$1,
                      style: const TextStyle(
                        color: Color(0xFF667085),
                        fontWeight: FontWeight.w700,
                      ),
                    );
                    final value = SelectableText(row.$2);

                    if (constraints.maxWidth < 600) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [label, const SizedBox(height: 3), value],
                      );
                    }

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(width: 190, child: label),
                        const SizedBox(width: 12),
                        Expanded(child: value),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Status extends StatelessWidget {
  const _Status({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final (label, background, foreground) = switch (status) {
      'submitted' => ('Yeni', const Color(0xFFFFF4E5), const Color(0xFF9A5B00)),
      'under_review' => (
        'İncelemede',
        const Color(0xFFEAF3FB),
        const Color(0xFF175CD3),
      ),
      'published' => (
        'Yayımlandı',
        const Color(0xFFE8F6F4),
        const Color(0xFF067647),
      ),
      'rejected' => (
        'Reddedildi',
        const Color(0xFFFFEDEC),
        const Color(0xFFB42318),
      ),
      _ => (
        _humanize(status),
        const Color(0xFFF2F4F7),
        const Color(0xFF475467),
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 620),
        margin: const EdgeInsets.symmetric(vertical: 34),
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2E8EC)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 52, color: MarkaKalkanTheme.navy),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: MarkaKalkanTheme.navy,
                fontSize: 21,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF667085), height: 1.5),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String _errorMessage(Object? error) {
  if (error is FirebaseFunctionsException) {
    return error.message ?? 'Yönetim servisi yanıt vermedi.';
  }
  return 'Yönetim servisi yanıt vermedi. Bağlantınızı kontrol edin.';
}

String _date(DateTime? value) {
  if (value == null) return '';
  final local = value.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${two(local.day)}.${two(local.month)}.${local.year} '
      '${two(local.hour)}:${two(local.minute)}';
}

String _category(String value) {
  return switch (value) {
    'physical' => 'Fiziksel',
    'digital' => 'Dijital',
    'ai_robot' => 'Yapay Zekâ ve Robot',
    _ => value.isEmpty ? 'Kategori belirtilmedi' : _humanize(value),
  };
}

String _humanize(String value) {
  final normalized = value.trim();
  if (normalized.isEmpty) return '';
  final text = normalized.split('_').where((part) => part.isNotEmpty).join(' ');
  if (text.isEmpty) return '';
  return '${text[0].toUpperCase()}${text.substring(1)}';
}

String _fallback(String value) =>
    value.trim().isEmpty ? 'Ad bilgisi belirtilmedi' : value.trim();

String _list(List<String> values) => values.isEmpty ? '' : values.join('\n');

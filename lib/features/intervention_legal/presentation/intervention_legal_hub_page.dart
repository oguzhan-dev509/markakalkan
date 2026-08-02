import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:markakalkan/features/intervention_legal/data/intervention_legal_workspace_repository.dart';

class InterventionLegalHubPage extends StatefulWidget {
  const InterventionLegalHubPage({super.key, this.repository});

  final InterventionLegalWorkspaceRepository? repository;

  @override
  State<InterventionLegalHubPage> createState() =>
      _InterventionLegalHubPageState();
}

class _InterventionLegalHubPageState extends State<InterventionLegalHubPage> {
  late final InterventionLegalWorkspaceRepository _repository;

  InterventionLegalWorkspaceSnapshot? _snapshot;
  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _repository =
        widget.repository ?? CallableInterventionLegalWorkspaceRepository();
    _reload();
  }

  Future<void> _reload() async {
    if (mounted) {
      setState(() {
        _loading = _snapshot == null;
        _error = null;
      });
    }

    try {
      final snapshot = await _repository.loadWorkspace();
      if (!mounted) {
        return;
      }
      setState(() {
        _snapshot = snapshot;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _error = error;
      });
    }
  }

  String _errorMessage(Object error) {
    if (error is FirebaseFunctionsException) {
      switch (error.code) {
        case 'unauthenticated':
          return 'Müdahale ve Hukuk Merkezi için oturum açmanız gerekir.';
        case 'failed-precondition':
          return 'Uygulama doğrulaması tamamlanamadı. Sayfayı yenileyin.';
        case 'permission-denied':
          return 'Bu çalışma alanını görüntüleme yetkiniz bulunmuyor.';
        case 'unavailable':
        case 'deadline-exceeded':
          return 'Hizmete şu anda ulaşılamıyor. Biraz sonra yeniden deneyin.';
      }
      return error.message ?? 'Müdahale ve Hukuk Merkezi yüklenemedi.';
    }
    if (error is FormatException) {
      return 'Çalışma alanı yanıtı doğrulanamadı.';
    }
    return 'Müdahale ve Hukuk Merkezi yüklenemedi.';
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _snapshot;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Müdahale ve Hukuk'),
        actions: [
          IconButton(
            key: const ValueKey<String>('intervention-legal-refresh'),
            tooltip: 'Yenile',
            onPressed: _loading ? null : _reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: _loading && snapshot == null
            ? const Center(child: CircularProgressIndicator())
            : _error != null && snapshot == null
            ? _ErrorPanel(message: _errorMessage(_error!), onRetry: _reload)
            : RefreshIndicator(
                onRefresh: _reload,
                child: _WorkspaceBody(
                  snapshot: snapshot!,
                  refreshError: _error == null ? null : _errorMessage(_error!),
                ),
              ),
      ),
    );
  }
}

class _WorkspaceBody extends StatelessWidget {
  const _WorkspaceBody({required this.snapshot, this.refreshError});

  final InterventionLegalWorkspaceSnapshot snapshot;
  final String? refreshError;

  @override
  Widget build(BuildContext context) {
    final matters = snapshot.matters;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      children: [
        const _HeroPanel(),
        const SizedBox(height: 16),
        const _ProcessStrip(),
        const SizedBox(height: 16),
        const _InformationGrid(),
        const SizedBox(height: 20),
        _SummaryGrid(counts: snapshot.counts),
        if (refreshError != null) ...[
          const SizedBox(height: 14),
          MaterialBanner(
            content: Text(refreshError!),
            actions: const [SizedBox.shrink()],
          ),
        ],
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: Text(
                'Hukuki dosyalar',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            Text(
              'Son güncelleme: ${_formatDate(snapshot.generatedAt)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (matters.isEmpty)
          const _EmptyState()
        else
          ...matters.map(
            (matter) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _LegalMatterCard(matter: matter),
            ),
          ),
      ],
    );
  }
}

class _HeroPanel extends StatelessWidget {
  const _HeroPanel();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      color: colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Wrap(
          spacing: 20,
          runSpacing: 16,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            CircleAvatar(
              radius: 34,
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
              child: const Icon(Icons.gavel_outlined, size: 34),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Doğrulanmış vakadan denetlenebilir hukuki müdahaleye',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Hukuki dosyaları, durum geçişlerini, müşteri veya hukuk '
                    'uzmanı onaylarını ve değiştirilemez karar zincirini tek '
                    'çalışma alanında izleyin.',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProcessStrip extends StatelessWidget {
  const _ProcessStrip();

  static const _steps = <(IconData, String)>[
    (Icons.folder_copy_outlined, 'Vaka ve delil bağlantısı'),
    (Icons.fact_check_outlined, 'Hukuki inceleme'),
    (Icons.verified_user_outlined, 'Yetkilendirme'),
    (Icons.description_outlined, 'Müdahale hazırlığı'),
    (Icons.account_balance_outlined, 'Başvuru ve sonuç'),
  ];

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final itemWidth = constraints.maxWidth < 720
                ? constraints.maxWidth
                : (constraints.maxWidth - 48) / 5;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _steps
                  .asMap()
                  .entries
                  .map(
                    (entry) => SizedBox(
                      width: itemWidth,
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 17,
                            child: Text('${entry.key + 1}'),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              entry.value.$2,
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(growable: false),
            );
          },
        ),
      ),
    );
  }
}

class _InformationGrid extends StatelessWidget {
  const _InformationGrid();

  static const _items = <(IconData, String, String)>[
    (
      Icons.info_outline,
      'Bu bölüm ne işe yarar?',
      'Vaka kaynaklı hukuki dosyaları, onay taleplerini ve kararları birlikte '
          'görünür kılar.',
    ),
    (
      Icons.schedule_outlined,
      'Ne zaman kullanmalısınız?',
      'Doğrulanmış bir ihlal için platform, idari, adli veya sözleşmesel '
          'müdahale değerlendirmesi başladığında.',
    ),
    (
      Icons.checklist_outlined,
      'Bu işlem için ne gerekir?',
      'Yetkili kullanıcı, kanonik marka ve vaka bağlantısı ile hukuken '
          'doğrulanabilir kapsam bilgileri gerekir.',
    ),
    (
      Icons.inventory_2_outlined,
      'İşlem sonunda ne elde edersiniz?',
      'Sürümlü hukuki dosya, değiştirilemez onay kaydı ve denetlenebilir '
          'müdahale zinciri elde edersiniz.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth < 760
            ? constraints.maxWidth
            : (constraints.maxWidth - 12) / 2;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: _items
              .map(
                (item) => SizedBox(
                  width: width,
                  child: Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(item.$1),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.$2,
                                  style: Theme.of(context).textTheme.titleSmall
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 6),
                                Text(item.$3),
                              ],
                            ),
                          ),
                        ],
                      ),
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

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.counts});

  final InterventionLegalWorkspaceCounts counts;

  @override
  Widget build(BuildContext context) {
    final items = <(IconData, String, int)>[
      (Icons.folder_open_outlined, 'Toplam dosya', counts.legalMatterCount),
      (Icons.autorenew, 'Aktif dosya', counts.activeLegalMatterCount),
      (
        Icons.pending_actions_outlined,
        'Bekleyen onay',
        counts.pendingApprovalCount,
      ),
      (Icons.verified_outlined, 'Onaylanan', counts.approvedApprovalCount),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 560 ? 2 : 4;
        final width = (constraints.maxWidth - ((columns - 1) * 12)) / columns;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: items
              .map(
                (item) => SizedBox(
                  width: width,
                  child: Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Icon(item.$1),
                          const SizedBox(height: 8),
                          Text(
                            '${item.$3}',
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.$2,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                        ],
                      ),
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

class _LegalMatterCard extends StatelessWidget {
  const _LegalMatterCard({required this.matter});

  final InterventionLegalMatterSummary matter;

  @override
  Widget build(BuildContext context) {
    final title =
        matter.title ?? 'Hukuki dosya ${_shortId(matter.legalMatterId)}';

    return Card(
      key: ValueKey<String>('legal-matter-${matter.legalMatterId}'),
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        leading: const CircleAvatar(child: Icon(Icons.balance_outlined)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _StatusChip(
                label: _matterStatusLabel(matter.status),
                icon: Icons.account_tree_outlined,
              ),
              _StatusChip(
                label: 'Sürüm ${matter.version}',
                icon: Icons.history_outlined,
              ),
              if (matter.priorityCode != null)
                _StatusChip(
                  label: _priorityLabel(matter.priorityCode!),
                  icon: Icons.flag_outlined,
                ),
              _StatusChip(
                label: matter.jurisdictionCode,
                icon: Icons.public_outlined,
              ),
            ],
          ),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        children: [
          const Divider(),
          _DetailGrid(
            items: [
              ('Hukuki dosya kimliği', matter.legalMatterId),
              ('Vaka kimliği', matter.caseId),
              ('Marka kimliği', matter.canonicalBrandId),
              ('Kapsam kodu', matter.matterScopeCode ?? 'Belirtilmedi'),
              ('Kaynak sistemi', matter.sourceSystemCode ?? 'Belirtilmedi'),
              ('Son güncelleme', _formatDate(matter.updatedAt)),
            ],
          ),
          const SizedBox(height: 18),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Onay talepleri',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 8),
          if (matter.approvalRequests.isEmpty)
            const _InlineEmpty(message: 'Bu dosyada onay talebi bulunmuyor.')
          else
            ...matter.approvalRequests.map(
              (request) => _ApprovalRequestTile(request: request),
            ),
          const SizedBox(height: 18),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Değiştirilemez kararlar',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 8),
          if (matter.approvalDecisions.isEmpty)
            const _InlineEmpty(message: 'Henüz karar kaydı bulunmuyor.')
          else
            ...matter.approvalDecisions.map(
              (decision) => _ApprovalDecisionTile(decision: decision),
            ),
        ],
      ),
    );
  }
}

class _ApprovalRequestTile extends StatelessWidget {
  const _ApprovalRequestTile({required this.request});

  final InterventionLegalApprovalRequestSummary request;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        request.status == 'approved'
            ? Icons.verified_outlined
            : request.status == 'rejected'
            ? Icons.cancel_outlined
            : Icons.pending_actions_outlined,
      ),
      title: Text(_approvalTypeLabel(request.approvalType)),
      subtitle: Text(
        '${_approvalStatusLabel(request.status)} · '
        'Talep sürümü ${request.version} · '
        '${_formatDate(request.updatedAt ?? request.createdAt)}',
      ),
      trailing: Text(_shortId(request.approvalRequestId)),
    );
  }
}

class _ApprovalDecisionTile extends StatelessWidget {
  const _ApprovalDecisionTile({required this.decision});

  final InterventionLegalApprovalDecisionSummary decision;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        decision.decision == 'approved'
            ? Icons.check_circle_outline
            : Icons.highlight_off_outlined,
      ),
      title: Text(decision.decision == 'approved' ? 'Onaylandı' : 'Reddedildi'),
      subtitle: Text(
        '${_decisionReasonLabel(decision.decisionReasonCode)} · '
        '${_formatDate(decision.decidedAt)}'
        '${decision.immutable ? ' · Değiştirilemez kayıt' : ''}',
      ),
      trailing: Text(_shortId(decision.decisionId)),
    );
  }
}

class _DetailGrid extends StatelessWidget {
  const _DetailGrid({required this.items});

  final List<(String, String)> items;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth < 680
            ? constraints.maxWidth
            : (constraints.maxWidth - 12) / 2;

        return Wrap(
          spacing: 12,
          runSpacing: 10,
          children: items
              .map(
                (item) => SizedBox(
                  width: width,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.$1,
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                          const SizedBox(height: 4),
                          SelectableText(item.$2),
                        ],
                      ),
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

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 16),
      label: Text(label),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _InlineEmpty extends StatelessWidget {
  const _InlineEmpty({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(message, style: Theme.of(context).textTheme.bodyMedium),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Card(
      key: const ValueKey<String>('intervention-legal-empty'),
      margin: EdgeInsets.zero,
      child: const Padding(
        padding: EdgeInsets.all(28),
        child: Column(
          children: [
            Icon(Icons.folder_off_outlined, size: 44),
            SizedBox(height: 12),
            Text(
              'Henüz hukuki dosya bulunmuyor.',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 6),
            Text(
              'Doğrulanmış bir vaka hukuki müdahale akışına aktarıldığında '
              'dosya burada görünür.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Card(
        margin: const EdgeInsets.all(24),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 42),
                const SizedBox(height: 12),
                Text(message, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Yeniden dene'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _matterStatusLabel(String value) {
  const labels = <String, String>{
    'intake_pending': 'Kabul bekliyor',
    'legal_review': 'Hukuki inceleme',
    'evidence_required': 'Delil gerekiyor',
    'strategy_preparation': 'Strateji hazırlanıyor',
    'awaiting_authorization': 'Yetkilendirme bekliyor',
    'approved': 'Onaylandı',
    'in_preparation': 'Hazırlanıyor',
    'submitted': 'Başvuru yapıldı',
    'in_progress': 'Devam ediyor',
    'awaiting_response': 'Cevap bekleniyor',
    'escalated': 'Üst incelemeye taşındı',
    'resolved': 'Çözüldü',
    'closed': 'Kapandı',
    'cancelled': 'İptal edildi',
    'archived': 'Arşivlendi',
  };
  return labels[value] ?? value;
}

String _approvalStatusLabel(String value) {
  const labels = <String, String>{
    'pending': 'Karar bekliyor',
    'approved': 'Onaylandı',
    'rejected': 'Reddedildi',
    'expired': 'Süresi doldu',
    'withdrawn': 'Geri çekildi',
  };
  return labels[value] ?? value;
}

String _approvalTypeLabel(String value) {
  const labels = <String, String>{
    'client_action_authorization': 'Müşteri işlem yetkilendirmesi',
    'client_budget_authorization': 'Müşteri bütçe yetkilendirmesi',
    'client_litigation_authorization': 'Dava yetkilendirmesi',
    'client_settlement_authorization': 'Uzlaşma yetkilendirmesi',
    'lawyer_legal_approval': 'Hukukçu onayı',
    'senior_legal_review': 'Kıdemli hukuk incelemesi',
  };
  return labels[value] ?? value;
}

String _decisionReasonLabel(String? value) {
  const labels = <String, String>{
    'client_action_authorized': 'Müşteri işlemi yetkilendirdi',
  };
  if (value == null) {
    return 'Gerekçe kodu bulunmuyor';
  }
  return labels[value] ?? value;
}

String _priorityLabel(String value) {
  const labels = <String, String>{
    'low': 'Düşük öncelik',
    'normal': 'Normal öncelik',
    'medium': 'Orta öncelik',
    'high': 'Yüksek öncelik',
    'urgent': 'Acil',
    'critical': 'Kritik',
  };
  return labels[value] ?? value;
}

String _formatDate(DateTime? value) {
  if (value == null) {
    return 'Tarih yok';
  }
  final local = value.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${two(local.day)}.${two(local.month)}.${local.year} '
      '${two(local.hour)}:${two(local.minute)}';
}

String _shortId(String value) {
  if (value.length <= 12) {
    return value;
  }
  return '${value.substring(0, 8)}…';
}

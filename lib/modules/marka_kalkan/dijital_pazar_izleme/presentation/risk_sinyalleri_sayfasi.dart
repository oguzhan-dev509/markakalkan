import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:markakalkan/core/theme/markakalkan_theme.dart';

import '../constants/monitoring_enums.dart';
import '../models/monitoring_signal_model.dart';
import '../repositories/monitoring_signal_repository.dart';

class RiskSinyalleriSayfasi extends StatefulWidget {
  const RiskSinyalleriSayfasi({super.key});

  @override
  State<RiskSinyalleriSayfasi> createState() => _RiskSinyalleriSayfasiState();
}

class _RiskSinyalleriSayfasiState extends State<RiskSinyalleriSayfasi> {
  final TextEditingController _searchController = TextEditingController();

  MonitoringSignalLevel? _levelFilter;
  MonitoringSignalStatus? _statusFilter;
  MonitoringSignalForwardingStatus? _forwardingFilter;

  String? _busySignalId;

  String? get _tenantId => FirebaseAuth.instance.currentUser?.uid;

  MonitoringSignalRepository? get _repository {
    final tenantId = _tenantId;

    if (tenantId == null || tenantId.trim().isEmpty) {
      return null;
    }

    return MonitoringSignalRepository.instance(tenantId: tenantId);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repository = _repository;

    return Scaffold(
      backgroundColor: MarkaKalkanTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text(
          'Risk Sinyalleri',
          style: TextStyle(
            color: MarkaKalkanTheme.navy,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: repository == null
          ? const _SignedOutState()
          : StreamBuilder<List<MonitoringSignalModel>>(
              stream: repository.watchRecent(limit: 300),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _ErrorState(error: snapshot.error);
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final signals = snapshot.data!;
                final filteredSignals = _applyFilters(signals);

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1220),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildHeader(signals),
                          const SizedBox(height: 22),
                          _buildSummary(signals),
                          const SizedBox(height: 22),
                          _buildFilters(),
                          const SizedBox(height: 20),
                          _buildResultHeader(
                            totalCount: signals.length,
                            filteredCount: filteredSignals.length,
                          ),
                          const SizedBox(height: 14),
                          if (filteredSignals.isEmpty)
                            const _EmptyState()
                          else
                            ...filteredSignals.map(
                              (signal) => Padding(
                                padding: const EdgeInsets.only(bottom: 14),
                                child: _SignalCard(
                                  signal: signal,
                                  isBusy: _busySignalId == signal.id,
                                  onStatusSelected: (status) {
                                    _changeStatus(
                                      repository: repository,
                                      signal: signal,
                                      status: status,
                                    );
                                  },
                                  onResolve: () {
                                    _showResolveDialog(
                                      repository: repository,
                                      signal: signal,
                                    );
                                  },
                                ),
                              ),
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

  Widget _buildHeader(List<MonitoringSignalModel> signals) {
    final urgentCount = signals.where((signal) {
      return signal.requiresImmediateAttention && signal.isOpen;
    }).length;

    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [MarkaKalkanTheme.navy, Color(0xFF17445A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 720;

          final icon = Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: const Color(0xFF25576B),
              borderRadius: BorderRadius.circular(19),
            ),
            child: const Icon(
              Icons.notification_important_outlined,
              size: 39,
              color: MarkaKalkanTheme.teal,
            ),
          );

          final content = Column(
            crossAxisAlignment: isNarrow
                ? CrossAxisAlignment.center
                : CrossAxisAlignment.start,
            children: [
              const Text(
                'Risk ve Uyarı Merkezi',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 9),
              const Text(
                'Kural motorunun olaylardan ürettiği risk sinyallerini '
                'inceleyin, doğrulayın, yükseltin ve sonuçlandırın.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFFD9E5EA), height: 1.5),
              ),
              const SizedBox(height: 14),
              Text(
                urgentCount == 0
                    ? 'Acil inceleme bekleyen yüksek veya kritik sinyal yok.'
                    : '$urgentCount yüksek veya kritik sinyal acil inceleme bekliyor.',
                style: const TextStyle(
                  color: MarkaKalkanTheme.teal,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          );

          if (isNarrow) {
            return Column(
              children: [icon, const SizedBox(height: 18), content],
            );
          }

          return Row(
            children: [
              icon,
              const SizedBox(width: 22),
              Expanded(child: content),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSummary(List<MonitoringSignalModel> signals) {
    final newCount = signals
        .where((signal) => signal.status == MonitoringSignalStatus.newSignal)
        .length;

    final urgentCount = signals.where((signal) {
      return signal.signalLevel == MonitoringSignalLevel.high ||
          signal.signalLevel == MonitoringSignalLevel.critical;
    }).length;

    final confirmedCount = signals.where((signal) {
      return signal.status == MonitoringSignalStatus.confirmed ||
          signal.status == MonitoringSignalStatus.escalated;
    }).length;

    final items = <_SummaryItem>[
      _SummaryItem(
        label: 'Toplam Sinyal',
        value: signals.length,
        icon: Icons.notifications_active_outlined,
      ),
      _SummaryItem(
        label: 'Yeni',
        value: newCount,
        icon: Icons.fiber_new_outlined,
      ),
      _SummaryItem(
        label: 'Yüksek / Kritik',
        value: urgentCount,
        icon: Icons.warning_amber_rounded,
      ),
      _SummaryItem(
        label: 'Doğrulandı / Yükseltildi',
        value: confirmedCount,
        icon: Icons.verified_outlined,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        int columns;
        if (width < 580) {
          columns = 1;
        } else if (width < 900) {
          columns = 2;
        } else {
          columns = 4;
        }

        const spacing = 14.0;
        final cardWidth = (width - ((columns - 1) * spacing)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: items
              .map(
                (item) => SizedBox(
                  width: cardWidth,
                  child: _SummaryCard(item: item),
                ),
              )
              .toList(growable: false),
        );
      },
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE0E7EC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Risk sinyallerinde ara',
              hintText: 'Başlık, özet, kural, sayfa, satıcı veya mağaza...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.trim().isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Aramayı temizle',
                      onPressed: () {
                        _searchController.clear();
                        setState(() {});
                      },
                      icon: const Icon(Icons.close),
                    ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 780;

              final level = _buildLevelFilter();
              final status = _buildStatusFilter();
              final forwarding = _buildForwardingFilter();

              final clearButton = OutlinedButton.icon(
                onPressed: _hasActiveFilter
                    ? () {
                        _searchController.clear();
                        setState(() {
                          _levelFilter = null;
                          _statusFilter = null;
                          _forwardingFilter = null;
                        });
                      }
                    : null,
                icon: const Icon(Icons.filter_alt_off_outlined),
                label: const Text('Filtreleri Temizle'),
              );

              if (isNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    level,
                    const SizedBox(height: 10),
                    status,
                    const SizedBox(height: 10),
                    forwarding,
                    const SizedBox(height: 10),
                    clearButton,
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: level),
                  const SizedBox(width: 12),
                  Expanded(child: status),
                  const SizedBox(width: 12),
                  Expanded(child: forwarding),
                  const SizedBox(width: 12),
                  clearButton,
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLevelFilter() {
    return DropdownButtonFormField<MonitoringSignalLevel?>(
      initialValue: _levelFilter,
      decoration: InputDecoration(
        labelText: 'Risk Seviyesi',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(13)),
      ),
      items: [
        const DropdownMenuItem<MonitoringSignalLevel?>(
          value: null,
          child: Text('Tüm seviyeler'),
        ),
        ...MonitoringSignalLevel.values.map(
          (level) => DropdownMenuItem<MonitoringSignalLevel?>(
            value: level,
            child: Text(_levelLabel(level)),
          ),
        ),
      ],
      onChanged: (value) {
        setState(() {
          _levelFilter = value;
        });
      },
    );
  }

  Widget _buildStatusFilter() {
    return DropdownButtonFormField<MonitoringSignalStatus?>(
      initialValue: _statusFilter,
      decoration: InputDecoration(
        labelText: 'İnceleme Durumu',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(13)),
      ),
      items: [
        const DropdownMenuItem<MonitoringSignalStatus?>(
          value: null,
          child: Text('Tüm durumlar'),
        ),
        ...MonitoringSignalStatus.values.map(
          (status) => DropdownMenuItem<MonitoringSignalStatus?>(
            value: status,
            child: Text(_statusLabel(status)),
          ),
        ),
      ],
      onChanged: (value) {
        setState(() {
          _statusFilter = value;
        });
      },
    );
  }

  Widget _buildForwardingFilter() {
    return DropdownButtonFormField<MonitoringSignalForwardingStatus?>(
      initialValue: _forwardingFilter,
      decoration: InputDecoration(
        labelText: 'İletim Durumu',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(13)),
      ),
      items: [
        const DropdownMenuItem<MonitoringSignalForwardingStatus?>(
          value: null,
          child: Text('Tüm iletim durumları'),
        ),
        ...MonitoringSignalForwardingStatus.values.map(
          (status) => DropdownMenuItem<MonitoringSignalForwardingStatus?>(
            value: status,
            child: Text(_forwardingLabel(status)),
          ),
        ),
      ],
      onChanged: (value) {
        setState(() {
          _forwardingFilter = value;
        });
      },
    );
  }

  Widget _buildResultHeader({
    required int totalCount,
    required int filteredCount,
  }) {
    return Row(
      children: [
        const Expanded(
          child: Text(
            'Sinyal Akışı',
            style: TextStyle(
              color: MarkaKalkanTheme.navy,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Text(
          _hasActiveFilter
              ? '$filteredCount / $totalCount kayıt'
              : '$totalCount kayıt',
          style: const TextStyle(
            color: Color(0xFF687580),
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  List<MonitoringSignalModel> _applyFilters(
    List<MonitoringSignalModel> signals,
  ) {
    final query = _searchController.text.trim().toLowerCase();

    return signals
        .where((signal) {
          if (_levelFilter != null && signal.signalLevel != _levelFilter) {
            return false;
          }

          if (_statusFilter != null && signal.status != _statusFilter) {
            return false;
          }

          if (_forwardingFilter != null &&
              signal.forwardingStatus != _forwardingFilter) {
            return false;
          }

          if (query.isEmpty) {
            return true;
          }

          final haystack = <String>[
            signal.title,
            signal.summary,
            signal.ruleName ?? '',
            signal.ruleId,
            signal.sourceId,
            signal.pageId,
            signal.listingId ?? '',
            signal.sellerId ?? '',
            signal.storeId ?? '',
            signal.eventType?.value ?? '',
            signal.eventCategory?.value ?? '',
            _levelLabel(signal.signalLevel),
            _statusLabel(signal.status),
            _forwardingLabel(signal.forwardingStatus),
            signal.forwardingError ?? '',
            signal.resolutionNote ?? '',
          ].join(' ').toLowerCase();

          return haystack.contains(query);
        })
        .toList(growable: false);
  }

  bool get _hasActiveFilter {
    return _searchController.text.trim().isNotEmpty ||
        _levelFilter != null ||
        _statusFilter != null ||
        _forwardingFilter != null;
  }

  Future<void> _changeStatus({
    required MonitoringSignalRepository repository,
    required MonitoringSignalModel signal,
    required MonitoringSignalStatus status,
  }) async {
    final reviewerId = _tenantId;

    if (reviewerId == null ||
        _busySignalId != null ||
        signal.status == status) {
      return;
    }

    setState(() {
      _busySignalId = signal.id;
    });

    try {
      await repository.updateReviewStatus(
        signalId: signal.id,
        status: status,
        reviewerId: reviewerId,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Sinyal durumu "${_statusLabel(status)}" olarak güncellendi.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sinyal durumu güncellenemedi: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _busySignalId = null;
        });
      }
    }
  }

  Future<void> _showResolveDialog({
    required MonitoringSignalRepository repository,
    required MonitoringSignalModel signal,
  }) async {
    final resolverId = _tenantId;

    if (resolverId == null || _busySignalId != null) {
      return;
    }

    final noteController = TextEditingController();

    final note = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Sinyali Çözümle'),
          content: SizedBox(
            width: 520,
            child: TextField(
              controller: noteController,
              autofocus: true,
              minLines: 3,
              maxLines: 6,
              maxLength: 1000,
              decoration: const InputDecoration(
                labelText: 'Çözüm ve değerlendirme notu',
                hintText:
                    'İnceleme sonucu, alınan önlem veya kapanış gerekçesi...',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Vazgeç'),
            ),
            FilledButton.icon(
              onPressed: () {
                final cleaned = noteController.text.trim();

                if (cleaned.isEmpty) {
                  return;
                }

                Navigator.of(dialogContext).pop(cleaned);
              },
              icon: const Icon(Icons.task_alt_outlined),
              label: const Text('Çözüldü Olarak Kapat'),
            ),
          ],
        );
      },
    );

    noteController.dispose();

    if (note == null || note.trim().isEmpty || !mounted) {
      return;
    }

    setState(() {
      _busySignalId = signal.id;
    });

    try {
      await repository.resolve(
        signalId: signal.id,
        resolverId: resolverId,
        note: note,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Risk sinyali çözüldü olarak kapatıldı.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sinyal sonuçlandırılamadı: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _busySignalId = null;
        });
      }
    }
  }
}

class _SignalCard extends StatelessWidget {
  const _SignalCard({
    required this.signal,
    required this.isBusy,
    required this.onStatusSelected,
    required this.onResolve,
  });

  final MonitoringSignalModel signal;
  final bool isBusy;
  final ValueChanged<MonitoringSignalStatus> onStatusSelected;
  final VoidCallback onResolve;

  @override
  Widget build(BuildContext context) {
    final levelColor = _levelColor(signal.signalLevel);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(
          color: signal.requiresImmediateAttention
              ? levelColor.withValues(alpha: 0.55)
              : const Color(0xFFE0E7EC),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0B000000),
            blurRadius: 15,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(height: 5, color: levelColor),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildPills(levelColor),
                  const SizedBox(height: 15),
                  Text(
                    signal.title,
                    style: const TextStyle(
                      color: MarkaKalkanTheme.navy,
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    signal.summary,
                    style: const TextStyle(
                      color: Color(0xFF53616B),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 15),
                  _buildMetadata(),
                  const SizedBox(height: 15),
                  _buildRuleBox(),
                  if (signal.forwardingError != null) ...[
                    const SizedBox(height: 12),
                    _MessageBox(
                      icon: Icons.error_outline,
                      title: 'İletim hatası',
                      text: signal.forwardingError!,
                      color: const Color(0xFFC83C4E),
                    ),
                  ],
                  if (signal.resolutionNote != null) ...[
                    const SizedBox(height: 12),
                    _MessageBox(
                      icon: Icons.task_alt_outlined,
                      title: 'Çözüm notu',
                      text: signal.resolutionNote!,
                      color: const Color(0xFF2C8F83),
                    ),
                  ],
                  const SizedBox(height: 17),
                  _buildFooter(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPills(Color levelColor) {
    return Wrap(
      spacing: 9,
      runSpacing: 9,
      children: [
        _Pill(
          label: _levelLabel(signal.signalLevel),
          icon: Icons.warning_amber_rounded,
          foreground: levelColor,
          background: levelColor.withValues(alpha: 0.10),
        ),
        _Pill(
          label: _statusLabel(signal.status),
          icon: _statusIcon(signal.status),
          foreground: _statusColor(signal.status),
          background: _statusColor(signal.status).withValues(alpha: 0.10),
        ),
        _Pill(
          label: _forwardingLabel(signal.forwardingStatus),
          icon: Icons.send_outlined,
          foreground: _forwardingColor(signal.forwardingStatus),
          background: _forwardingColor(
            signal.forwardingStatus,
          ).withValues(alpha: 0.10),
        ),
      ],
    );
  }

  Widget _buildMetadata() {
    return Wrap(
      spacing: 18,
      runSpacing: 9,
      children: [
        _MetaText(
          icon: Icons.schedule_outlined,
          text: _formatDateTime(signal.detectedAt),
        ),
        _MetaText(
          icon: Icons.language_outlined,
          text: 'Sayfa: ${signal.pageId}',
        ),
        _MetaText(icon: Icons.hub_outlined, text: 'Kaynak: ${signal.sourceId}'),
        if (signal.sellerId != null)
          _MetaText(
            icon: Icons.person_search_outlined,
            text: 'Satıcı: ${signal.sellerId}',
          ),
        if (signal.storeId != null)
          _MetaText(
            icon: Icons.storefront_outlined,
            text: 'Mağaza: ${signal.storeId}',
          ),
      ],
    );
  }

  Widget _buildRuleBox() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FA),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: const Color(0xFFE4EAEE)),
      ),
      child: Wrap(
        spacing: 18,
        runSpacing: 9,
        children: [
          _MetaText(
            icon: Icons.rule_outlined,
            text: 'Kural: ${signal.ruleName ?? signal.ruleId}',
          ),
          _MetaText(
            icon: Icons.timeline_outlined,
            text: 'Olay: ${_shortId(signal.eventId)}',
          ),
          if (signal.eventType != null)
            _MetaText(
              icon: Icons.bolt_outlined,
              text: 'Tür: ${signal.eventType!.value}',
            ),
          if (signal.eventCategory != null)
            _MetaText(
              icon: Icons.category_outlined,
              text: 'Kategori: ${signal.eventCategory!.value}',
            ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Row(
      children: [
        Expanded(
          child: Text(
            signal.isOpen
                ? 'İnceleme ve aksiyon bekliyor'
                : 'Sinyal süreci kapalı',
            style: TextStyle(
              color: signal.isOpen
                  ? const Color(0xFFDF6C2F)
                  : const Color(0xFF687580),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 12),
        if (isBusy)
          const SizedBox(
            width: 27,
            height: 27,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          )
        else
          PopupMenuButton<String>(
            tooltip: 'Sinyal işlemleri',
            onSelected: (value) {
              switch (value) {
                case 'review':
                  onStatusSelected(MonitoringSignalStatus.underReview);
                case 'confirm':
                  onStatusSelected(MonitoringSignalStatus.confirmed);
                case 'dismiss':
                  onStatusSelected(MonitoringSignalStatus.dismissed);
                case 'escalate':
                  onStatusSelected(MonitoringSignalStatus.escalated);
                case 'resolve':
                  onResolve();
                case 'archive':
                  onStatusSelected(MonitoringSignalStatus.archived);
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem<String>(
                value: 'review',
                child: Text('İncelemeye Al'),
              ),
              PopupMenuItem<String>(value: 'confirm', child: Text('Doğrula')),
              PopupMenuItem<String>(value: 'dismiss', child: Text('Reddet')),
              PopupMenuItem<String>(value: 'escalate', child: Text('Yükselt')),
              PopupMenuItem<String>(
                value: 'resolve',
                child: Text('Çözüldü Olarak Kapat'),
              ),
              PopupMenuItem<String>(value: 'archive', child: Text('Arşivle')),
            ],
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F6F4),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.fact_check_outlined,
                    color: MarkaKalkanTheme.teal,
                    size: 19,
                  ),
                  SizedBox(width: 7),
                  Text(
                    'İşlem',
                    style: TextStyle(
                      color: MarkaKalkanTheme.navy,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Icon(Icons.arrow_drop_down, color: MarkaKalkanTheme.navy),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _MessageBox extends StatelessWidget {
  const _MessageBox({
    required this.icon,
    required this.title,
    required this.text,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(color: color, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  text,
                  style: const TextStyle(color: Color(0xFF53616B), height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.item});

  final _SummaryItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 124),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: const Color(0xFFE0E7EC)),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F6F4),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(item.icon, color: MarkaKalkanTheme.teal),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${item.value}',
                  style: const TextStyle(
                    color: MarkaKalkanTheme.navy,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  item.label,
                  style: const TextStyle(
                    color: Color(0xFF687580),
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

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.icon,
    required this.foreground,
    required this.background,
  });

  final String label;
  final IconData icon;
  final Color foreground;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: foreground),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: foreground,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaText extends StatelessWidget {
  const _MetaText({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 17, color: const Color(0xFF7A8791)),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(
            color: Color(0xFF687580),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 54),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE0E7EC)),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.notification_important_outlined,
            size: 54,
            color: Color(0xFF9AA7B0),
          ),
          SizedBox(height: 14),
          Text(
            'Gösterilecek risk sinyali bulunamadı.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: MarkaKalkanTheme.navy,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 7),
          Text(
            'İzleme olayları aktif sinyal kurallarıyla eşleştiğinde '
            'risk sinyalleri burada canlı olarak görünecektir.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF687580), height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _SignedOutState extends StatelessWidget {
  const _SignedOutState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Risk sinyallerini görmek için marka hesabıyla oturum açılmalıdır.',
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error});

  final Object? error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'Risk sinyalleri yüklenemedi.\n$error',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.redAccent),
        ),
      ),
    );
  }
}

class _SummaryItem {
  const _SummaryItem({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final int value;
  final IconData icon;
}

String _levelLabel(MonitoringSignalLevel level) {
  switch (level) {
    case MonitoringSignalLevel.info:
      return 'Bilgi';
    case MonitoringSignalLevel.low:
      return 'Düşük';
    case MonitoringSignalLevel.medium:
      return 'Orta';
    case MonitoringSignalLevel.high:
      return 'Yüksek';
    case MonitoringSignalLevel.critical:
      return 'Kritik';
  }
}

String _statusLabel(MonitoringSignalStatus status) {
  switch (status) {
    case MonitoringSignalStatus.newSignal:
      return 'Yeni';
    case MonitoringSignalStatus.underReview:
      return 'İncelemede';
    case MonitoringSignalStatus.confirmed:
      return 'Doğrulandı';
    case MonitoringSignalStatus.dismissed:
      return 'Reddedildi';
    case MonitoringSignalStatus.escalated:
      return 'Yükseltildi';
    case MonitoringSignalStatus.resolved:
      return 'Çözüldü';
    case MonitoringSignalStatus.archived:
      return 'Arşivlendi';
  }
}

String _forwardingLabel(MonitoringSignalForwardingStatus status) {
  switch (status) {
    case MonitoringSignalForwardingStatus.notForwarded:
      return 'İletilmedi';
    case MonitoringSignalForwardingStatus.queued:
      return 'İletim Kuyruğunda';
    case MonitoringSignalForwardingStatus.forwarded:
      return 'İletildi';
    case MonitoringSignalForwardingStatus.failed:
      return 'İletim Başarısız';
  }
}

IconData _statusIcon(MonitoringSignalStatus status) {
  switch (status) {
    case MonitoringSignalStatus.newSignal:
      return Icons.fiber_new_outlined;
    case MonitoringSignalStatus.underReview:
      return Icons.manage_search_outlined;
    case MonitoringSignalStatus.confirmed:
      return Icons.verified_outlined;
    case MonitoringSignalStatus.dismissed:
      return Icons.cancel_outlined;
    case MonitoringSignalStatus.escalated:
      return Icons.upgrade_outlined;
    case MonitoringSignalStatus.resolved:
      return Icons.task_alt_outlined;
    case MonitoringSignalStatus.archived:
      return Icons.archive_outlined;
  }
}

Color _levelColor(MonitoringSignalLevel level) {
  switch (level) {
    case MonitoringSignalLevel.info:
      return const Color(0xFF4B7895);
    case MonitoringSignalLevel.low:
      return const Color(0xFF2C8F83);
    case MonitoringSignalLevel.medium:
      return const Color(0xFFE39A25);
    case MonitoringSignalLevel.high:
      return const Color(0xFFDF6C2F);
    case MonitoringSignalLevel.critical:
      return const Color(0xFFC83C4E);
  }
}

Color _statusColor(MonitoringSignalStatus status) {
  switch (status) {
    case MonitoringSignalStatus.newSignal:
      return const Color(0xFFC83C4E);
    case MonitoringSignalStatus.underReview:
      return const Color(0xFF4B7895);
    case MonitoringSignalStatus.confirmed:
      return const Color(0xFF2C8F83);
    case MonitoringSignalStatus.dismissed:
      return const Color(0xFF7C6A92);
    case MonitoringSignalStatus.escalated:
      return const Color(0xFFDF6C2F);
    case MonitoringSignalStatus.resolved:
      return const Color(0xFF2C8F83);
    case MonitoringSignalStatus.archived:
      return const Color(0xFF687580);
  }
}

Color _forwardingColor(MonitoringSignalForwardingStatus status) {
  switch (status) {
    case MonitoringSignalForwardingStatus.notForwarded:
      return const Color(0xFF687580);
    case MonitoringSignalForwardingStatus.queued:
      return const Color(0xFFE39A25);
    case MonitoringSignalForwardingStatus.forwarded:
      return const Color(0xFF2C8F83);
    case MonitoringSignalForwardingStatus.failed:
      return const Color(0xFFC83C4E);
  }
}

String _formatDateTime(DateTime value) {
  final local = value.toLocal();

  String twoDigits(int number) => number.toString().padLeft(2, '0');

  return '${twoDigits(local.day)}.${twoDigits(local.month)}.${local.year} '
      '${twoDigits(local.hour)}:${twoDigits(local.minute)}';
}

String _shortId(String value) {
  final cleaned = value.trim();

  if (cleaned.length <= 18) {
    return cleaned;
  }

  return '${cleaned.substring(0, 9)}…${cleaned.substring(cleaned.length - 6)}';
}

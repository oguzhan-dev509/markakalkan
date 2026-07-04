import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:markakalkan/core/theme/markakalkan_theme.dart';

import '../constants/monitoring_enums.dart';
import '../models/monitoring_event_model.dart';
import '../repositories/monitoring_event_repository.dart';

class IzlemeOlaylariSayfasi extends StatefulWidget {
  const IzlemeOlaylariSayfasi({super.key});

  @override
  State<IzlemeOlaylariSayfasi> createState() => _IzlemeOlaylariSayfasiState();
}

class _IzlemeOlaylariSayfasiState extends State<IzlemeOlaylariSayfasi> {
  final TextEditingController _searchController = TextEditingController();

  MonitoringEventCategory? _categoryFilter;
  MonitoringEventSeverity? _severityFilter;
  MonitoringEventStatus? _statusFilter;

  String? _busyEventId;

  String? get _tenantId => FirebaseAuth.instance.currentUser?.uid;

  MonitoringEventRepository? get _repository {
    final tenantId = _tenantId;

    if (tenantId == null || tenantId.trim().isEmpty) {
      return null;
    }

    return MonitoringEventRepository.instance(tenantId: tenantId);
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
          'İzleme Olayları',
          style: TextStyle(
            color: MarkaKalkanTheme.navy,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: repository == null
          ? const _SignedOutState()
          : StreamBuilder<List<MonitoringEventModel>>(
              stream: repository.watchRecent(limit: 300),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _ErrorState(error: snapshot.error);
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final events = snapshot.data!;
                final filteredEvents = _applyFilters(events);

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1220),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildHeader(events),
                          const SizedBox(height: 22),
                          _buildSummary(events),
                          const SizedBox(height: 22),
                          _buildFilters(),
                          const SizedBox(height: 20),
                          _buildResultHeader(
                            totalCount: events.length,
                            filteredCount: filteredEvents.length,
                          ),
                          const SizedBox(height: 14),
                          if (filteredEvents.isEmpty)
                            const _EmptyState()
                          else
                            ...filteredEvents.map(
                              (event) => Padding(
                                padding: const EdgeInsets.only(bottom: 14),
                                child: _EventCard(
                                  event: event,
                                  isBusy: _busyEventId == event.id,
                                  onStatusSelected: (status) {
                                    _updateStatus(
                                      repository: repository,
                                      event: event,
                                      status: status,
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

  Widget _buildHeader(List<MonitoringEventModel> events) {
    final attentionCount = events.where((event) {
      return event.requiresAttention &&
          event.status != MonitoringEventStatus.resolved &&
          event.status != MonitoringEventStatus.archived;
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
              Icons.timeline_outlined,
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
                'Değişiklik ve Olay Akışı',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 9),
              const Text(
                'Fiyat, stok, içerik, görsel, satıcı, mağaza ve sayfa '
                'durumu değişikliklerini tek merkezden inceleyin.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFFD9E5EA), height: 1.5),
              ),
              const SizedBox(height: 14),
              Text(
                attentionCount == 0
                    ? 'Acil inceleme bekleyen olay yok.'
                    : '$attentionCount yüksek veya kritik olay inceleme bekliyor.',
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

  Widget _buildSummary(List<MonitoringEventModel> events) {
    final newCount = events
        .where((event) => event.status == MonitoringEventStatus.newEvent)
        .length;

    final highCriticalCount = events.where((event) {
      return event.severity == MonitoringEventSeverity.high ||
          event.severity == MonitoringEventSeverity.critical;
    }).length;

    final reviewedCount = events.where((event) {
      return event.status == MonitoringEventStatus.reviewed ||
          event.status == MonitoringEventStatus.resolved;
    }).length;

    final items = <_SummaryItem>[
      _SummaryItem(
        label: 'Toplam Olay',
        value: events.length,
        icon: Icons.timeline_outlined,
      ),
      _SummaryItem(
        label: 'Yeni',
        value: newCount,
        icon: Icons.fiber_new_outlined,
      ),
      _SummaryItem(
        label: 'Yüksek / Kritik',
        value: highCriticalCount,
        icon: Icons.priority_high_rounded,
      ),
      _SummaryItem(
        label: 'İncelendi / Çözüldü',
        value: reviewedCount,
        icon: Icons.task_alt_outlined,
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
              labelText: 'Olaylarda ara',
              hintText: 'Özet, sayfa, satıcı, mağaza veya değer...',
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
              final isNarrow = constraints.maxWidth < 760;

              final category = _buildCategoryFilter();
              final severity = _buildSeverityFilter();
              final status = _buildStatusFilter();
              final clearButton = OutlinedButton.icon(
                onPressed: _hasActiveFilter
                    ? () {
                        _searchController.clear();
                        setState(() {
                          _categoryFilter = null;
                          _severityFilter = null;
                          _statusFilter = null;
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
                    category,
                    const SizedBox(height: 10),
                    severity,
                    const SizedBox(height: 10),
                    status,
                    const SizedBox(height: 10),
                    clearButton,
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: category),
                  const SizedBox(width: 12),
                  Expanded(child: severity),
                  const SizedBox(width: 12),
                  Expanded(child: status),
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

  Widget _buildCategoryFilter() {
    return DropdownButtonFormField<MonitoringEventCategory?>(
      initialValue: _categoryFilter,
      decoration: InputDecoration(
        labelText: 'Kategori',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(13)),
      ),
      items: [
        const DropdownMenuItem<MonitoringEventCategory?>(
          value: null,
          child: Text('Tüm kategoriler'),
        ),
        ...MonitoringEventCategory.values.map(
          (category) => DropdownMenuItem<MonitoringEventCategory?>(
            value: category,
            child: Text(_categoryLabel(category)),
          ),
        ),
      ],
      onChanged: (value) {
        setState(() {
          _categoryFilter = value;
        });
      },
    );
  }

  Widget _buildSeverityFilter() {
    return DropdownButtonFormField<MonitoringEventSeverity?>(
      initialValue: _severityFilter,
      decoration: InputDecoration(
        labelText: 'Önem',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(13)),
      ),
      items: [
        const DropdownMenuItem<MonitoringEventSeverity?>(
          value: null,
          child: Text('Tüm önem seviyeleri'),
        ),
        ...MonitoringEventSeverity.values.map(
          (severity) => DropdownMenuItem<MonitoringEventSeverity?>(
            value: severity,
            child: Text(_severityLabel(severity)),
          ),
        ),
      ],
      onChanged: (value) {
        setState(() {
          _severityFilter = value;
        });
      },
    );
  }

  Widget _buildStatusFilter() {
    return DropdownButtonFormField<MonitoringEventStatus?>(
      initialValue: _statusFilter,
      decoration: InputDecoration(
        labelText: 'Durum',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(13)),
      ),
      items: [
        const DropdownMenuItem<MonitoringEventStatus?>(
          value: null,
          child: Text('Tüm durumlar'),
        ),
        ...MonitoringEventStatus.values.map(
          (status) => DropdownMenuItem<MonitoringEventStatus?>(
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

  Widget _buildResultHeader({
    required int totalCount,
    required int filteredCount,
  }) {
    return Row(
      children: [
        const Expanded(
          child: Text(
            'Olay Akışı',
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

  List<MonitoringEventModel> _applyFilters(List<MonitoringEventModel> events) {
    final query = _searchController.text.trim().toLowerCase();

    return events
        .where((event) {
          if (_categoryFilter != null &&
              event.eventCategory != _categoryFilter) {
            return false;
          }

          if (_severityFilter != null && event.severity != _severityFilter) {
            return false;
          }

          if (_statusFilter != null && event.status != _statusFilter) {
            return false;
          }

          if (query.isEmpty) {
            return true;
          }

          final haystack = <String>[
            event.summary ?? '',
            event.pageId,
            event.listingId ?? '',
            event.sellerId ?? '',
            event.storeId ?? '',
            _eventTypeLabel(event.eventType),
            _categoryLabel(event.eventCategory),
            _severityLabel(event.severity),
            _statusLabel(event.status),
            _valueText(event.oldValue),
            _valueText(event.newValue),
          ].join(' ').toLowerCase();

          return haystack.contains(query);
        })
        .toList(growable: false);
  }

  bool get _hasActiveFilter {
    return _searchController.text.trim().isNotEmpty ||
        _categoryFilter != null ||
        _severityFilter != null ||
        _statusFilter != null;
  }

  Future<void> _updateStatus({
    required MonitoringEventRepository repository,
    required MonitoringEventModel event,
    required MonitoringEventStatus status,
  }) async {
    if (_busyEventId != null || event.status == status) {
      return;
    }

    setState(() {
      _busyEventId = event.id;
    });

    try {
      await repository.updateStatus(eventId: event.id, status: status);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Olay durumu "${_statusLabel(status)}" olarak güncellendi.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Durum güncellenemedi: $error')));
    } finally {
      if (mounted) {
        setState(() {
          _busyEventId = null;
        });
      }
    }
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({
    required this.event,
    required this.isBusy,
    required this.onStatusSelected,
  });

  final MonitoringEventModel event;
  final bool isBusy;
  final ValueChanged<MonitoringEventStatus> onStatusSelected;

  @override
  Widget build(BuildContext context) {
    final severityColor = _severityColor(event.severity);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(
          color: event.requiresAttention
              ? severityColor.withValues(alpha: 0.55)
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
            Container(height: 5, color: severityColor),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildTitleRow(severityColor),
                  const SizedBox(height: 14),
                  Text(
                    event.summary ?? _eventTypeLabel(event.eventType),
                    style: const TextStyle(
                      color: MarkaKalkanTheme.navy,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _buildMetadata(),
                  const SizedBox(height: 16),
                  _ValueComparison(
                    oldValue: event.oldValue,
                    newValue: event.newValue,
                  ),
                  if (event.changeRate != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Değişim oranı: '
                      '${(event.changeRate! * 100).toStringAsFixed(1)}%',
                      style: TextStyle(
                        color: severityColor,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  _buildFooter(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTitleRow(Color severityColor) {
    return Wrap(
      spacing: 9,
      runSpacing: 9,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _Pill(
          label: _eventTypeLabel(event.eventType),
          icon: _eventIcon(event.eventType),
          foreground: MarkaKalkanTheme.navy,
          background: const Color(0xFFEAF2F6),
        ),
        _Pill(
          label: _categoryLabel(event.eventCategory),
          icon: Icons.category_outlined,
          foreground: MarkaKalkanTheme.blue,
          background: const Color(0xFFEAF3FA),
        ),
        _Pill(
          label: _severityLabel(event.severity),
          icon: Icons.priority_high_rounded,
          foreground: severityColor,
          background: severityColor.withValues(alpha: 0.10),
        ),
        _Pill(
          label: _statusLabel(event.status),
          icon: Icons.flag_outlined,
          foreground: _statusColor(event.status),
          background: _statusColor(event.status).withValues(alpha: 0.10),
        ),
      ],
    );
  }

  Widget _buildMetadata() {
    return Wrap(
      spacing: 18,
      runSpacing: 8,
      children: [
        _MetaText(
          icon: Icons.schedule_outlined,
          text: _formatDateTime(event.detectedAt),
        ),
        _MetaText(
          icon: Icons.language_outlined,
          text: 'Sayfa: ${event.pageId}',
        ),
        if (event.sellerId != null)
          _MetaText(
            icon: Icons.person_search_outlined,
            text: 'Satıcı: ${event.sellerId}',
          ),
        if (event.storeId != null)
          _MetaText(
            icon: Icons.storefront_outlined,
            text: 'Mağaza: ${event.storeId}',
          ),
      ],
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            'Önceki: ${_shortId(event.previousSnapshotId)}  •  '
            'Yeni: ${_shortId(event.currentSnapshotId)}',
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF7A8791),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 12),
        if (isBusy)
          const SizedBox(
            width: 26,
            height: 26,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          )
        else
          PopupMenuButton<MonitoringEventStatus>(
            tooltip: 'Olay durumunu değiştir',
            onSelected: onStatusSelected,
            itemBuilder: (context) => [
              _statusMenuItem(MonitoringEventStatus.reviewed),
              _statusMenuItem(MonitoringEventStatus.resolved),
              _statusMenuItem(MonitoringEventStatus.suppressed),
              _statusMenuItem(MonitoringEventStatus.forwarded),
              _statusMenuItem(MonitoringEventStatus.archived),
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
                  SizedBox(width: 3),
                  Icon(Icons.arrow_drop_down, color: MarkaKalkanTheme.navy),
                ],
              ),
            ),
          ),
      ],
    );
  }

  PopupMenuItem<MonitoringEventStatus> _statusMenuItem(
    MonitoringEventStatus status,
  ) {
    return PopupMenuItem<MonitoringEventStatus>(
      value: status,
      enabled: event.status != status,
      child: Row(
        children: [
          Icon(_statusIcon(status), color: _statusColor(status), size: 20),
          const SizedBox(width: 10),
          Text(_statusLabel(status)),
        ],
      ),
    );
  }
}

class _ValueComparison extends StatelessWidget {
  const _ValueComparison({required this.oldValue, required this.newValue});

  final dynamic oldValue;
  final dynamic newValue;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 720;

        final oldCard = _ValueBox(
          title: 'Önceki Değer',
          value: _valueText(oldValue),
          icon: Icons.history_outlined,
        );

        final newCard = _ValueBox(
          title: 'Yeni Değer',
          value: _valueText(newValue),
          icon: Icons.update_outlined,
        );

        if (isNarrow) {
          return Column(
            children: [oldCard, const SizedBox(height: 10), newCard],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: oldCard),
            const SizedBox(width: 12),
            Expanded(child: newCard),
          ],
        );
      },
    );
  }
}

class _ValueBox extends StatelessWidget {
  const _ValueBox({
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 105),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FA),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: const Color(0xFFE4EAEE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: MarkaKalkanTheme.blue),
              const SizedBox(width: 7),
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF687580),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          SelectableText(
            value,
            style: const TextStyle(
              color: MarkaKalkanTheme.navy,
              height: 1.4,
              fontWeight: FontWeight.w600,
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
          Icon(Icons.timeline_outlined, size: 54, color: Color(0xFF9AA7B0)),
          SizedBox(height: 14),
          Text(
            'Gösterilecek izleme olayı bulunamadı.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: MarkaKalkanTheme.navy,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 7),
          Text(
            'Yeni snapshot değişiklikleri üretildiğinde olaylar burada '
            'canlı olarak görünecektir.',
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
        'İzleme olaylarını görmek için marka hesabıyla oturum açılmalıdır.',
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
          'İzleme olayları yüklenemedi.\n$error',
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

String _eventTypeLabel(MonitoringEventType type) {
  switch (type) {
    case MonitoringEventType.newListing:
      return 'Yeni İlan';
    case MonitoringEventType.listingRemoved:
      return 'İlan Kaldırıldı';
    case MonitoringEventType.listingRepublished:
      return 'İlan Yeniden Yayında';
    case MonitoringEventType.priceDecreased:
      return 'Fiyat Düştü';
    case MonitoringEventType.priceIncreased:
      return 'Fiyat Arttı';
    case MonitoringEventType.titleChanged:
      return 'Başlık Değişti';
    case MonitoringEventType.descriptionChanged:
      return 'Açıklama Değişti';
    case MonitoringEventType.imageChanged:
      return 'Görsel Değişti';
    case MonitoringEventType.sellerChanged:
      return 'Satıcı Değişti';
    case MonitoringEventType.storeChanged:
      return 'Mağaza Değişti';
    case MonitoringEventType.storeNameChanged:
      return 'Mağaza Adı Değişti';
    case MonitoringEventType.stockChanged:
      return 'Stok Değişti';
    case MonitoringEventType.contactChanged:
      return 'İletişim Bilgisi Değişti';
    case MonitoringEventType.pageBlocked:
      return 'Sayfa Engellendi';
    case MonitoringEventType.pageRedirected:
      return 'Sayfa Yönlendirildi';
    case MonitoringEventType.pageRecovered:
      return 'Sayfa Yeniden Erişilebilir';
  }
}

String _categoryLabel(MonitoringEventCategory category) {
  switch (category) {
    case MonitoringEventCategory.discovery:
      return 'Keşif';
    case MonitoringEventCategory.price:
      return 'Fiyat';
    case MonitoringEventCategory.content:
      return 'İçerik';
    case MonitoringEventCategory.media:
      return 'Görsel / Medya';
    case MonitoringEventCategory.seller:
      return 'Satıcı';
    case MonitoringEventCategory.store:
      return 'Mağaza';
    case MonitoringEventCategory.availability:
      return 'Stok / Erişilebilirlik';
    case MonitoringEventCategory.technical:
      return 'Teknik';
    case MonitoringEventCategory.identity:
      return 'Kimlik / İletişim';
  }
}

String _severityLabel(MonitoringEventSeverity severity) {
  switch (severity) {
    case MonitoringEventSeverity.info:
      return 'Bilgi';
    case MonitoringEventSeverity.low:
      return 'Düşük';
    case MonitoringEventSeverity.medium:
      return 'Orta';
    case MonitoringEventSeverity.high:
      return 'Yüksek';
    case MonitoringEventSeverity.critical:
      return 'Kritik';
  }
}

String _statusLabel(MonitoringEventStatus status) {
  switch (status) {
    case MonitoringEventStatus.newEvent:
      return 'Yeni';
    case MonitoringEventStatus.reviewed:
      return 'İncelendi';
    case MonitoringEventStatus.suppressed:
      return 'Bastırıldı';
    case MonitoringEventStatus.forwarded:
      return 'İletildi';
    case MonitoringEventStatus.resolved:
      return 'Çözüldü';
    case MonitoringEventStatus.archived:
      return 'Arşivlendi';
  }
}

IconData _eventIcon(MonitoringEventType type) {
  switch (type) {
    case MonitoringEventType.priceDecreased:
    case MonitoringEventType.priceIncreased:
      return Icons.payments_outlined;
    case MonitoringEventType.stockChanged:
      return Icons.inventory_2_outlined;
    case MonitoringEventType.imageChanged:
      return Icons.image_outlined;
    case MonitoringEventType.sellerChanged:
      return Icons.person_search_outlined;
    case MonitoringEventType.storeChanged:
    case MonitoringEventType.storeNameChanged:
      return Icons.storefront_outlined;
    case MonitoringEventType.pageBlocked:
    case MonitoringEventType.pageRedirected:
    case MonitoringEventType.pageRecovered:
      return Icons.language_outlined;
    case MonitoringEventType.titleChanged:
    case MonitoringEventType.descriptionChanged:
      return Icons.article_outlined;
    case MonitoringEventType.contactChanged:
      return Icons.contact_phone_outlined;
    case MonitoringEventType.newListing:
    case MonitoringEventType.listingRemoved:
    case MonitoringEventType.listingRepublished:
      return Icons.list_alt_outlined;
  }
}

IconData _statusIcon(MonitoringEventStatus status) {
  switch (status) {
    case MonitoringEventStatus.newEvent:
      return Icons.fiber_new_outlined;
    case MonitoringEventStatus.reviewed:
      return Icons.fact_check_outlined;
    case MonitoringEventStatus.suppressed:
      return Icons.visibility_off_outlined;
    case MonitoringEventStatus.forwarded:
      return Icons.forward_to_inbox_outlined;
    case MonitoringEventStatus.resolved:
      return Icons.task_alt_outlined;
    case MonitoringEventStatus.archived:
      return Icons.archive_outlined;
  }
}

Color _severityColor(MonitoringEventSeverity severity) {
  switch (severity) {
    case MonitoringEventSeverity.info:
      return const Color(0xFF4B7895);
    case MonitoringEventSeverity.low:
      return const Color(0xFF2C8F83);
    case MonitoringEventSeverity.medium:
      return const Color(0xFFE39A25);
    case MonitoringEventSeverity.high:
      return const Color(0xFFDF6C2F);
    case MonitoringEventSeverity.critical:
      return const Color(0xFFC83C4E);
  }
}

Color _statusColor(MonitoringEventStatus status) {
  switch (status) {
    case MonitoringEventStatus.newEvent:
      return const Color(0xFFC83C4E);
    case MonitoringEventStatus.reviewed:
      return const Color(0xFF4B7895);
    case MonitoringEventStatus.suppressed:
      return const Color(0xFF7C6A92);
    case MonitoringEventStatus.forwarded:
      return const Color(0xFFDF6C2F);
    case MonitoringEventStatus.resolved:
      return const Color(0xFF2C8F83);
    case MonitoringEventStatus.archived:
      return const Color(0xFF687580);
  }
}

String _valueText(dynamic value) {
  if (value == null) {
    return 'Veri yok';
  }

  if (value is String) {
    final cleaned = value.trim();
    return cleaned.isEmpty ? 'Boş değer' : cleaned;
  }

  if (value is num || value is bool) {
    return value.toString();
  }

  try {
    return const JsonEncoder.withIndent('  ').convert(value);
  } catch (_) {
    return value.toString();
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

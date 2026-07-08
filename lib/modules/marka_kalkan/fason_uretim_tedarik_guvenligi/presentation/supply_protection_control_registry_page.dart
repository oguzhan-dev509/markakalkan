import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:markakalkan/core/theme/markakalkan_theme.dart';

import '../constants/supply_protection_control_enums.dart';
import '../models/supply_protection_control_model.dart';
import '../repositories/supply_facility_repository.dart';
import '../repositories/supply_partner_repository.dart';
import '../repositories/supply_protection_control_repository.dart';
import 'supply_protection_control_create_dialog.dart';

class SupplyProtectionControlRegistryPage extends StatefulWidget {
  const SupplyProtectionControlRegistryPage({super.key});

  @override
  State<SupplyProtectionControlRegistryPage> createState() {
    return _SupplyProtectionControlRegistryPageState();
  }
}

class _SupplyProtectionControlRegistryPageState
    extends State<SupplyProtectionControlRegistryPage> {
  SupplyProtectionControlStatus? _statusFilter;
  SupplyProtectionControlResult? _resultFilter;
  SupplyProtectionControlRiskLevel? _riskFilter;

  bool get _hasActiveFilter =>
      _statusFilter != null || _resultFilter != null || _riskFilter != null;

  void _clearFilters() {
    setState(() {
      _statusFilter = null;
      _resultFilter = null;
      _riskFilter = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const _SignedOutPage();
    }

    final repository = SupplyProtectionControlRepository.instance(
      tenantId: user.uid,
    );

    return Scaffold(
      backgroundColor: MarkaKalkanTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text(
          'Koruma Kontrolleri Sicili',
          style: TextStyle(
            color: MarkaKalkanTheme.navy,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await showSupplyProtectionControlCreateDialog(
            context: context,
            user: user,
            controlRepository: repository,
            partnerRepository: SupplyPartnerRepository.instance(
              tenantId: user.uid,
            ),
            facilityRepository: SupplyFacilityRepository.instance(
              tenantId: user.uid,
            ),
          );
        },
        backgroundColor: MarkaKalkanTheme.teal,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_task_outlined),
        label: const Text(
          'Yeni Kontrol',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: StreamBuilder<List<SupplyProtectionControlModel>>(
        stream: repository.watchAll(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _RegistryMessage(
              icon: Icons.error_outline,
              title: 'Koruma kontrolleri yüklenemedi',
              description: snapshot.error.toString(),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final controls =
              snapshot.data ?? const <SupplyProtectionControlModel>[];

          final activeControls = controls
              .where((item) => !item.isArchived)
              .toList(growable: false);

          final filteredControls = activeControls
              .where(_matchesFilters)
              .toList(growable: false);

          final archivedCount = controls.length - activeControls.length;

          final openCount = activeControls
              .where(
                (item) =>
                    !item.isCompleted &&
                    item.status != SupplyProtectionControlStatus.cancelled,
              )
              .length;

          final overdueCount = activeControls
              .where(
                (item) =>
                    item.status == SupplyProtectionControlStatus.overdue ||
                    item.isOverdue,
              )
              .length;

          final highRiskCount = activeControls
              .where((item) => item.isHighRisk)
              .length;

          final failedCount = activeControls
              .where((item) => item.hasFailure)
              .length;

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 104),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1180),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _SummaryStrip(
                      active: activeControls.length,
                      open: openCount,
                      overdue: overdueCount,
                      highRisk: highRiskCount,
                      failed: failedCount,
                      archived: archivedCount,
                    ),
                    const SizedBox(height: 18),
                    _FilterPanel(
                      status: _statusFilter,
                      result: _resultFilter,
                      riskLevel: _riskFilter,
                      hasActiveFilter: _hasActiveFilter,
                      onStatusChanged: (value) {
                        setState(() {
                          _statusFilter = value;
                        });
                      },
                      onResultChanged: (value) {
                        setState(() {
                          _resultFilter = value;
                        });
                      },
                      onRiskChanged: (value) {
                        setState(() {
                          _riskFilter = value;
                        });
                      },
                      onClear: _clearFilters,
                    ),
                    const SizedBox(height: 18),
                    if (activeControls.isEmpty)
                      const _RegistryMessage(
                        icon: Icons.fact_check_outlined,
                        title: 'Henüz koruma kontrolü yok',
                        description:
                            'Partner veya tesis kontrolü '
                            'oluşturulduğunda plan, sonuç, '
                            'risk, bulgu ve düzeltici faaliyet '
                            'bilgileri burada görüntülenecek.',
                      )
                    else if (filteredControls.isEmpty)
                      const _RegistryMessage(
                        icon: Icons.filter_alt_off_outlined,
                        title: 'Filtrelerle eşleşen kontrol yok',
                        description:
                            'Filtreleri temizleyerek aktif '
                            'kontrollerin tamamını görebilirsiniz.',
                      )
                    else ...[
                      Text(
                        '${filteredControls.length} '
                        'kontrol gösteriliyor',
                        style: const TextStyle(
                          color: MarkaKalkanTheme.navy,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...filteredControls.map(
                        (control) => Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: _ControlCard(control: control),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  bool _matchesFilters(SupplyProtectionControlModel control) {
    if (_statusFilter != null && control.status != _statusFilter) {
      return false;
    }

    if (_resultFilter != null && control.result != _resultFilter) {
      return false;
    }

    if (_riskFilter != null && control.riskLevel != _riskFilter) {
      return false;
    }

    return true;
  }
}

class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({
    required this.active,
    required this.open,
    required this.overdue,
    required this.highRisk,
    required this.failed,
    required this.archived,
  });

  final int active;
  final int open;
  final int overdue;
  final int highRisk;
  final int failed;
  final int archived;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _MetricCard(label: 'Aktif kontrol', value: '$active'),
        _MetricCard(label: 'Açık kontrol', value: '$open'),
        _MetricCard(label: 'Gecikmiş', value: '$overdue'),
        _MetricCard(label: 'Yüksek / kritik risk', value: '$highRisk'),
        _MetricCard(label: 'Uygunsuz sonuç', value: '$failed'),
        _MetricCard(label: 'Arşivlenen', value: '$archived'),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 174,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0E7EC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: MarkaKalkanTheme.navy,
              fontSize: 25,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF687580),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterPanel extends StatelessWidget {
  const _FilterPanel({
    required this.status,
    required this.result,
    required this.riskLevel,
    required this.hasActiveFilter,
    required this.onStatusChanged,
    required this.onResultChanged,
    required this.onRiskChanged,
    required this.onClear,
  });

  final SupplyProtectionControlStatus? status;
  final SupplyProtectionControlResult? result;
  final SupplyProtectionControlRiskLevel? riskLevel;
  final bool hasActiveFilter;

  final ValueChanged<SupplyProtectionControlStatus?> onStatusChanged;

  final ValueChanged<SupplyProtectionControlResult?> onResultChanged;

  final ValueChanged<SupplyProtectionControlRiskLevel?> onRiskChanged;

  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE0E7EC)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 820;

          final statusField =
              DropdownButtonFormField<SupplyProtectionControlStatus>(
                key: ValueKey('status-${status?.value ?? 'all'}'),
                initialValue: status,
                decoration: const InputDecoration(labelText: 'Durum'),
                items: SupplyProtectionControlStatus.values
                    .map(
                      (item) => DropdownMenuItem(
                        value: item,
                        child: Text(item.label),
                      ),
                    )
                    .toList(growable: false),
                onChanged: onStatusChanged,
              );

          final resultField =
              DropdownButtonFormField<SupplyProtectionControlResult>(
                key: ValueKey('result-${result?.value ?? 'all'}'),
                initialValue: result,
                decoration: const InputDecoration(labelText: 'Sonuç'),
                items: SupplyProtectionControlResult.values
                    .map(
                      (item) => DropdownMenuItem(
                        value: item,
                        child: Text(item.label),
                      ),
                    )
                    .toList(growable: false),
                onChanged: onResultChanged,
              );

          final riskField =
              DropdownButtonFormField<SupplyProtectionControlRiskLevel>(
                key: ValueKey('risk-${riskLevel?.value ?? 'all'}'),
                initialValue: riskLevel,
                decoration: const InputDecoration(labelText: 'Risk'),
                items: SupplyProtectionControlRiskLevel.values
                    .map(
                      (item) => DropdownMenuItem(
                        value: item,
                        child: Text(item.label),
                      ),
                    )
                    .toList(growable: false),
                onChanged: onRiskChanged,
              );

          final clearButton = OutlinedButton.icon(
            onPressed: hasActiveFilter ? onClear : null,
            icon: const Icon(Icons.filter_alt_off_outlined),
            label: const Text('Filtreleri Temizle'),
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                statusField,
                const SizedBox(height: 12),
                resultField,
                const SizedBox(height: 12),
                riskField,
                const SizedBox(height: 12),
                clearButton,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(child: statusField),
              const SizedBox(width: 12),
              Expanded(child: resultField),
              const SizedBox(width: 12),
              Expanded(child: riskField),
              const SizedBox(width: 12),
              clearButton,
            ],
          );
        },
      ),
    );
  }
}

class _ControlCard extends StatelessWidget {
  const _ControlCard({required this.control});

  final SupplyProtectionControlModel control;

  @override
  Widget build(BuildContext context) {
    final riskColor = control.isHighRisk
        ? const Color(0xFFB42318)
        : const Color(0xFF16866F);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: control.hasFailure
              ? const Color(0xFFF0B7B3)
              : const Color(0xFFE0E7EC),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: control.hasFailure
                ? const Color(0xFFFFE9E7)
                : const Color(0xFFE8F6F4),
            foregroundColor: control.hasFailure
                ? const Color(0xFFB42318)
                : MarkaKalkanTheme.teal,
            child: Icon(
              control.hasFailure
                  ? Icons.gpp_bad_outlined
                  : Icons.verified_user_outlined,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  control.title,
                  style: const TextStyle(
                    color: MarkaKalkanTheme.navy,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '${control.controlCode} · '
                  '${control.controlType.label}',
                  style: const TextStyle(
                    color: Color(0xFF687580),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _targetLabel(control),
                  style: const TextStyle(
                    color: Color(0xFF4D6470),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 11),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _Badge(label: control.status.label),
                    _Badge(label: 'Sonuç: ${control.result.label}'),
                    _Badge(
                      label: 'Risk: ${control.riskLevel.label}',
                      foreground: riskColor,
                    ),
                    if (control.plannedAt != null)
                      _Badge(label: 'Plan: ${_formatDate(control.plannedAt!)}'),
                    if (control.completedAt != null)
                      _Badge(
                        label:
                            'Tamamlandı: '
                            '${_formatDate(control.completedAt!)}',
                      ),
                    if (control.nextControlAt != null)
                      _Badge(
                        label:
                            'Sonraki: '
                            '${_formatDate(control.nextControlAt!)}',
                      ),
                    if (control.hasOpenCorrectiveAction)
                      const _Badge(
                        label: 'Açık düzeltici faaliyet',
                        foreground: Color(0xFFB54708),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _targetLabel(SupplyProtectionControlModel control) {
    switch (control.scope) {
      case SupplyProtectionControlScope.partner:
        return 'Partner: ${control.partnerId}';
      case SupplyProtectionControlScope.facility:
        return 'Tesis: ${control.facilityId}';
      case SupplyProtectionControlScope.partnerAndFacility:
        return 'Partner: ${control.partnerId} · '
            'Tesis: ${control.facilityId}';
    }
  }

  static String _formatDate(DateTime value) {
    final local = value.toLocal();

    final day = local.day.toString().padLeft(2, '0');

    final month = local.month.toString().padLeft(2, '0');

    return '$day.$month.${local.year}';
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.label,
    this.foreground = const Color(0xFF4D6470),
  });

  final String label;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F7F9),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _RegistryMessage extends StatelessWidget {
  const _RegistryMessage({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 620),
          padding: const EdgeInsets.all(30),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFE0E7EC)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 48, color: MarkaKalkanTheme.teal),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: MarkaKalkanTheme.navy,
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                description,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF687580), height: 1.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SignedOutPage extends StatelessWidget {
  const _SignedOutPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MarkaKalkanTheme.background,
      appBar: AppBar(title: const Text('Koruma Kontrolleri Sicili')),
      body: const _RegistryMessage(
        icon: Icons.lock_outline,
        title: 'Oturum gerekli',
        description:
            'Bu sicili görüntülemek için marka '
            'hesabıyla giriş yapın.',
      ),
    );
  }
}

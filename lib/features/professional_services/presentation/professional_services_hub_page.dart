import 'package:flutter/material.dart';

import '../data/professional_services_callable_client.dart';
import '../domain/professional_service_models.dart';
import 'professional_services_controller.dart';

class ProfessionalServicesHubPage extends StatefulWidget {
  const ProfessionalServicesHubPage({super.key, this.controller});

  static const String routeName = '/professional-services';

  final ProfessionalServicesController? controller;

  @override
  State<ProfessionalServicesHubPage> createState() =>
      _ProfessionalServicesHubPageState();
}

class _ProfessionalServicesHubPageState
    extends State<ProfessionalServicesHubPage> {
  late final ProfessionalServicesController _controller;
  late final bool _ownsController;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller =
        widget.controller ??
        ProfessionalServicesController(
          gateway: FirebaseProfessionalServicesCallableClient(),
        );
    _controller.addListener(_handleControllerChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_handleControllerChanged);
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  void _handleControllerChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = _controller.selectedOperation;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Profesyonel Hizmetler Merkezi')),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final contentWidth = (constraints.maxWidth - 40)
                .clamp(0.0, 1120.0)
                .toDouble();

            return SingleChildScrollView(
              key: const ValueKey('professional-services-scroll'),
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              child: Align(
                alignment: Alignment.topCenter,
                child: SizedBox(
                  width: contentWidth,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _IntroBanner(colorScheme: colorScheme),
                      const SizedBox(height: 20),
                      const _WorkflowOverview(),
                      const SizedBox(height: 24),
                      Text(
                        'Operasyon sınırları',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Sekiz callable işlem tek bir Auth + App Check '
                        'sınırından geçer. Bu temel faz yalnız bağlantı, '
                        'model ve durum omurgasını kurar; geçerli üretim '
                        'komutları otomatik olarak çalıştırılmaz.',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 16),
                      _CapabilityGrid(
                        selectedOperation: selected,
                        onSelected: _controller.selectOperation,
                      ),
                      const SizedBox(height: 20),
                      _SelectionPanel(
                        operation: selected,
                        status: _controller.status,
                        result: _controller.result,
                        failure: _controller.failure,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _IntroBanner extends StatelessWidget {
  const _IntroBanner({required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: const ValueKey('professional-services-intro-banner'),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.support_agent,
              size: 40,
              color: colorScheme.onPrimaryContainer,
            ),
            const SizedBox(height: 14),
            Text(
              'Uzmanlığı kontrollü operasyona dönüştürün.',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Hukuk, marka koruma ve uzman danışmanlık süreçlerini '
              'talep, yetki, görevlendirme, yapay zekâ desteği, insan '
              'incelemesi ve kontrollü yayın zincirinde yönetin.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 14),
            Chip(
              key: const ValueKey('professional-services-foundation-chip'),
              avatar: const Icon(Icons.verified_user_outlined),
              label: const Text('Auth + App Check korumalı frontend temeli'),
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkflowOverview extends StatelessWidget {
  const _WorkflowOverview();

  static const List<(IconData, String, String)> _steps = [
    (
      Icons.assignment_outlined,
      '1. Hizmet talebi',
      'Amaç, kapsam ve kaynak bağları kaydedilir.',
    ),
    (
      Icons.policy_outlined,
      '2. Yetki ve kapsam',
      'Yetki alanı, profesyonel sınıf ve sınırlar doğrulanır.',
    ),
    (
      Icons.group_work_outlined,
      '3. Görevlendirme',
      'Uzman, sağlayıcı ve hizmet koşulları bağlanır.',
    ),
    (
      Icons.smart_toy_outlined,
      '4. Ajan çalışması',
      'Kaynak manifestine bağlı taslak çıktı oluşturulur.',
    ),
    (
      Icons.fact_check_outlined,
      '5. İnsan incelemesi ve yayın',
      'Yetkili insan kararı olmadan çıktı yayımlanmaz.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Card(
      key: const ValueKey('professional-services-workflow'),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Kontrollü hizmet yaşam döngüsü',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 14),
            for (final step in _steps)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(step.$1),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            step.$2,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 2),
                          Text(step.$3),
                        ],
                      ),
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

class _CapabilityGrid extends StatelessWidget {
  const _CapabilityGrid({
    required this.selectedOperation,
    required this.onSelected,
  });

  final ProfessionalServiceOperation? selectedOperation;
  final ValueChanged<ProfessionalServiceOperation> onSelected;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 900
            ? 4
            : constraints.maxWidth >= 620
            ? 2
            : 1;
        final spacing = 12.0;
        final itemWidth =
            (constraints.maxWidth - (spacing * (columns - 1))) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final operation in ProfessionalServiceOperation.values)
              SizedBox(
                width: itemWidth,
                child: _CapabilityCard(
                  operation: operation,
                  selected: selectedOperation == operation,
                  onTap: () => onSelected(operation),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _CapabilityCard extends StatelessWidget {
  const _CapabilityCard({
    required this.operation,
    required this.selected,
    required this.onTap,
  });

  final ProfessionalServiceOperation operation;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      key: ValueKey('professional-service-capability-${operation.wireValue}'),
      elevation: selected ? 3 : 0,
      color: selected ? colorScheme.secondaryContainer : null,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(_operationIcon(operation)),
              const SizedBox(height: 12),
              Text(
                _operationTitle(operation),
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(_operationDescription(operation)),
              const SizedBox(height: 12),
              Text(
                operation.callableName,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectionPanel extends StatelessWidget {
  const _SelectionPanel({
    required this.operation,
    required this.status,
    required this.result,
    required this.failure,
  });

  final ProfessionalServiceOperation? operation;
  final ProfessionalServicesControllerStatus status;
  final ProfessionalServiceResult? result;
  final ProfessionalServicesClientFailure? failure;

  @override
  Widget build(BuildContext context) {
    final title = operation == null
        ? 'Bir operasyon sınırı seçin'
        : _operationTitle(operation!);
    final detail = switch (status) {
      ProfessionalServicesControllerStatus.idle =>
        operation == null
            ? 'Her kart, production callable sözleşmesindeki ayrı bir '
                  'işlem sınırını temsil eder.'
            : 'Bu sınır seçildi. Geçerli komut formu sonraki kontrollü '
                  'fazda bağlanacaktır.',
      ProfessionalServicesControllerStatus.running =>
        'İşlem güvenli callable sınırında yürütülüyor.',
      ProfessionalServicesControllerStatus.succeeded =>
        'İşlem tamamlandı: ${result?.resultType ?? 'sonuç'}',
      ProfessionalServicesControllerStatus.failed =>
        failure?.message ?? 'İşlem tamamlanamadı.',
    };

    return Card(
      key: const ValueKey('professional-services-selection-panel'),
      child: ListTile(
        leading: const Icon(Icons.hub_outlined),
        title: Text(title),
        subtitle: Text(detail),
        trailing: status == ProfessionalServicesControllerStatus.running
            ? const SizedBox.square(
                dimension: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : null,
      ),
    );
  }
}

String _operationTitle(ProfessionalServiceOperation operation) {
  return switch (operation) {
    ProfessionalServiceOperation.createServiceRequest =>
      'Profesyonel hizmet talebi',
    ProfessionalServiceOperation.transitionServiceRequest =>
      'Talep durumu geçişi',
    ProfessionalServiceOperation.createServiceEngagement =>
      'Hizmet kapsamı ve angajman',
    ProfessionalServiceOperation.createServiceAssignment =>
      'Uzman görevlendirmesi',
    ProfessionalServiceOperation.startAgentRun => 'Yapay zekâ ajan çalışması',
    ProfessionalServiceOperation.recordAgentOutput => 'Ajan çıktı taslağı',
    ProfessionalServiceOperation.recordAgentReview =>
      'Yetkili insan incelemesi',
    ProfessionalServiceOperation.publishAgentOutput => 'Kontrollü çıktı yayını',
  };
}

String _operationDescription(ProfessionalServiceOperation operation) {
  return switch (operation) {
    ProfessionalServiceOperation.createServiceRequest =>
      'Hizmet ihtiyacını kanonik marka ve kaynak kapsamına bağlar.',
    ProfessionalServiceOperation.transitionServiceRequest =>
      'Sürüm kontrollü talep yaşam döngüsü geçişini yürütür.',
    ProfessionalServiceOperation.createServiceEngagement =>
      'Kapsam, yetkilendirme ve hizmet koşullarını kesinleştirir.',
    ProfessionalServiceOperation.createServiceAssignment =>
      'Yetkili profesyonel veya sağlayıcı görevlendirmesini kaydeder.',
    ProfessionalServiceOperation.startAgentRun =>
      'Kaynak manifestine bağlı, denetlenebilir ajan çalışmasını başlatır.',
    ProfessionalServiceOperation.recordAgentOutput =>
      'Ajan çıktısını yayımlanmamış ve değişmez taslak olarak kaydeder.',
    ProfessionalServiceOperation.recordAgentReview =>
      'İnsan kararını, inceleme notunu ve yetki zincirini kaydeder.',
    ProfessionalServiceOperation.publishAgentOutput =>
      'Onaylı çıktıyı ayrı yayın yetkisiyle değişmez artefakta bağlar.',
  };
}

IconData _operationIcon(ProfessionalServiceOperation operation) {
  return switch (operation) {
    ProfessionalServiceOperation.createServiceRequest =>
      Icons.post_add_outlined,
    ProfessionalServiceOperation.transitionServiceRequest =>
      Icons.swap_horiz_outlined,
    ProfessionalServiceOperation.createServiceEngagement =>
      Icons.handshake_outlined,
    ProfessionalServiceOperation.createServiceAssignment =>
      Icons.assignment_ind_outlined,
    ProfessionalServiceOperation.startAgentRun => Icons.smart_toy_outlined,
    ProfessionalServiceOperation.recordAgentOutput =>
      Icons.description_outlined,
    ProfessionalServiceOperation.recordAgentReview => Icons.fact_check_outlined,
    ProfessionalServiceOperation.publishAgentOutput => Icons.publish_outlined,
  };
}

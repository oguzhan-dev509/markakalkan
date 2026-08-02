import 'package:flutter/material.dart';

import '../data/professional_services_callable_client.dart';
import '../domain/professional_service_models.dart';
import 'professional_services_controller.dart';
import 'professional_services_strings.dart';

class ProfessionalServicesHubPage extends StatefulWidget {
  const ProfessionalServicesHubPage({super.key, this.controller, this.locale});

  static const String routeName = '/professional-services';

  final ProfessionalServicesController? controller;
  final Locale? locale;

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
    final strings = ProfessionalServicesStrings.of(locale: widget.locale);

    return Scaffold(
      appBar: AppBar(
        title: Semantics(header: true, child: Text(strings.pageTitle)),
      ),
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
                      _IntroBanner(colorScheme: colorScheme, strings: strings),
                      const SizedBox(height: 20),
                      _WorkflowOverview(strings: strings),
                      const SizedBox(height: 24),
                      Text(
                        strings.operationBoundariesTitle,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        strings.operationBoundariesDescription,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 16),
                      _CapabilityGrid(
                        strings: strings,
                        selectedOperation: selected,
                        onSelected: _controller.selectOperation,
                      ),
                      const SizedBox(height: 20),
                      _SelectionPanel(
                        strings: strings,
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
  const _IntroBanner({required this.colorScheme, required this.strings});

  final ColorScheme colorScheme;
  final ProfessionalServicesStrings strings;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: const ValueKey('professional-services-intro-semantics'),
      container: true,
      label: strings.introSemanticLabel,
      child: DecoratedBox(
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
              Tooltip(
                message: strings.supportIconTooltip,
                child: Icon(
                  Icons.support_agent,
                  size: 40,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                strings.introTitle,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                strings.introDescription,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: 14),
              Chip(
                key: const ValueKey('professional-services-foundation-chip'),
                avatar: const Icon(Icons.verified_user_outlined),
                label: Text(strings.foundationChip),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WorkflowOverview extends StatelessWidget {
  const _WorkflowOverview({required this.strings});

  final ProfessionalServicesStrings strings;

  static const List<IconData> _icons = [
    Icons.assignment_outlined,
    Icons.policy_outlined,
    Icons.group_work_outlined,
    Icons.smart_toy_outlined,
    Icons.fact_check_outlined,
  ];

  @override
  Widget build(BuildContext context) {
    final steps = strings.workflowSteps;

    return Semantics(
      key: const ValueKey('professional-services-workflow-semantics'),
      container: true,
      label: strings.workflowSemanticLabel,
      child: Card(
        key: const ValueKey('professional-services-workflow'),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                strings.workflowTitle,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 14),
              for (var index = 0; index < steps.length; index += 1)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(_icons[index]),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              steps[index].title,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 2),
                            Text(steps[index].description),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CapabilityGrid extends StatelessWidget {
  const _CapabilityGrid({
    required this.strings,
    required this.selectedOperation,
    required this.onSelected,
  });

  final ProfessionalServicesStrings strings;
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
                  strings: strings,
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
    required this.strings,
    required this.operation,
    required this.selected,
    required this.onTap,
  });

  final ProfessionalServicesStrings strings;
  final ProfessionalServiceOperation operation;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final title = strings.operationTitle(operation);

    return Semantics(
      key: ValueKey(
        'professional-service-capability-semantics-${operation.wireValue}',
      ),
      button: true,
      selected: selected,
      label: title,
      hint: strings.selectCapabilityHint,
      child: Card(
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
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(strings.operationDescription(operation)),
                const SizedBox(height: 12),
                Text(
                  operation.callableName,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectionPanel extends StatelessWidget {
  const _SelectionPanel({
    required this.strings,
    required this.operation,
    required this.status,
    required this.result,
    required this.failure,
  });

  final ProfessionalServicesStrings strings;
  final ProfessionalServiceOperation? operation;
  final ProfessionalServicesControllerStatus status;
  final ProfessionalServiceResult? result;
  final ProfessionalServicesClientFailure? failure;

  @override
  Widget build(BuildContext context) {
    final title = operation == null
        ? strings.selectBoundaryPrompt
        : strings.operationTitle(operation!);
    final detail = switch (status) {
      ProfessionalServicesControllerStatus.idle =>
        operation == null
            ? strings.boundaryDefaultDescription
            : strings.boundarySelectedDescription,
      ProfessionalServicesControllerStatus.running =>
        strings.boundaryRunningDescription,
      ProfessionalServicesControllerStatus.succeeded =>
        strings.boundarySucceededDescription(result?.resultType ?? 'result'),
      ProfessionalServicesControllerStatus.failed =>
        failure?.message ?? strings.boundaryFailedDescription,
    };

    return Semantics(
      key: const ValueKey('professional-services-selection-semantics'),
      container: true,
      liveRegion: true,
      label: '$title. $detail',
      child: Card(
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
      ),
    );
  }
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

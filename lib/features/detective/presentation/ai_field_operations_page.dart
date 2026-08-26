import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:markakalkan/core/theme/markakalkan_theme.dart';
import 'package:markakalkan/features/detective/data/ai_field_operation_models.dart';
import 'package:markakalkan/features/detective/data/ai_field_operation_service.dart';

class AiFieldOperationsPage extends StatefulWidget {
  const AiFieldOperationsPage({super.key});

  @override
  State<AiFieldOperationsPage> createState() => _AiFieldOperationsPageState();
}

class _AiFieldOperationsPageState extends State<AiFieldOperationsPage> {
  final AiFieldOperationService _service = AiFieldOperationService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MarkaKalkanTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text(
          'Ajan Operasyonları',
          style: TextStyle(
            color: MarkaKalkanTheme.navy,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: StreamBuilder<List<AiFieldOperation>>(
        stream: _service.watchOperations(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _Message(
              icon: Icons.error_outline,
              title: 'Operasyonlar yüklenemedi',
              description: snapshot.error.toString(),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final operations = snapshot.data ?? const <AiFieldOperation>[];
          if (operations.isEmpty) {
            return const _Message(
              icon: Icons.account_tree_outlined,
              title: 'Henüz ajan operasyonu yok',
              description:
                  'Yeni operasyon oluşturulduğunda 12 ajanın ilerlemesi ve '
                  'sonuç durumu burada görünür.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(24),
            itemCount: operations.length,
            separatorBuilder: (_, _) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final operation = operations[index];
              return _OperationCard(
                operation: operation,
                onOpen: () => _showOperation(operation),
              );
            },
          );
        },
      ),
    );
  }

  void _showOperation(AiFieldOperation operation) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _OperationSheet(
        operation: operation,
        taskStream: _service.watchAgentTasks(operation.id),
      ),
    );
  }
}

class _OperationCard extends StatelessWidget {
  const _OperationCard({required this.operation, required this.onOpen});

  final AiFieldOperation operation;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final expected = operation.expectedAgentCount <= 0
        ? 12
        : operation.expectedAgentCount;
    final processed = operation.processedAgentCount.clamp(0, expected);
    final progress = expected == 0 ? 0.0 : processed / expected;
    final status = _statusPresentation(operation.status);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFDDE6EB)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 10,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _StatusPill(label: status.label, color: status.color),
                  _StatusPill(
                    label: '${operation.completedAgentCount} tamamlandı',
                    color: const Color(0xFF087F70),
                  ),
                  if (operation.failedAgentCount > 0)
                    _StatusPill(
                      label: '${operation.failedAgentCount} başarısız',
                      color: const Color(0xFFB3261E),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                operation.title.isEmpty ? 'İsimsiz operasyon' : operation.title,
                style: const TextStyle(
                  color: MarkaKalkanTheme.navy,
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (operation.objective.isNotEmpty) ...[
                const SizedBox(height: 7),
                Text(
                  operation.objective,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF667680),
                    height: 1.45,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: const Color(0xFFE8EEF1),
                  color: status.color,
                ),
              ),
              const SizedBox(height: 9),
              Row(
                children: [
                  Text(
                    '$processed / $expected ajan sonucu işlendi',
                    style: const TextStyle(
                      color: Color(0xFF53646E),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  const Icon(Icons.chevron_right, color: Color(0xFF53646E)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OperationSheet extends StatelessWidget {
  const _OperationSheet({required this.operation, required this.taskStream});

  final AiFieldOperation operation;
  final Stream<List<AiFieldAgentTask>> taskStream;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.55,
      maxChildSize: 0.96,
      builder: (context, controller) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF4F7F8),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: StreamBuilder<List<AiFieldAgentTask>>(
          stream: taskStream,
          builder: (context, snapshot) {
            final tasks = snapshot.data ?? const <AiFieldAgentTask>[];
            return ListView(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                Center(
                  child: Container(
                    width: 48,
                    height: 5,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD5DA),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  operation.title.isEmpty ? 'Ajan operasyonu' : operation.title,
                  style: const TextStyle(
                    color: MarkaKalkanTheme.navy,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'İnsan uzman onayı ayrı bir karar kapısıdır; ajan çıktıları '
                  'tek başına kesin ihlâl veya müdahale kararı oluşturmaz.',
                  style: TextStyle(color: Color(0xFF687780), height: 1.45),
                ),
                const SizedBox(height: 20),
                if (snapshot.hasError)
                  _InlineNotice(
                    icon: Icons.error_outline,
                    text: 'Ajan görevleri yüklenemedi: ${snapshot.error}',
                  )
                else if (snapshot.connectionState == ConnectionState.waiting)
                  const Center(child: CircularProgressIndicator())
                else if (tasks.isEmpty)
                  const _InlineNotice(
                    icon: Icons.hourglass_empty,
                    text: 'Ajan görevleri henüz oluşturulmadı.',
                  )
                else
                  ...tasks.map(
                    (task) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _AgentTaskTile(task: task),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _AgentTaskTile extends StatelessWidget {
  const _AgentTaskTile({required this.task});

  final AiFieldAgentTask task;

  @override
  Widget build(BuildContext context) {
    final status = _taskStatusPresentation(task.status);
    final hasOutput = task.output.isNotEmpty;
    return ExpansionTile(
      collapsedBackgroundColor: Colors.white,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFDDE6EB)),
      ),
      collapsedShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFDDE6EB)),
      ),
      leading: CircleAvatar(
        backgroundColor: status.color.withValues(alpha: 0.11),
        child: Icon(status.icon, color: status.color, size: 21),
      ),
      title: Text(
        task.agentName.isEmpty ? task.agentId : task.agentName,
        style: const TextStyle(
          color: MarkaKalkanTheme.navy,
          fontWeight: FontWeight.w800,
        ),
      ),
      subtitle: Text(
        hasOutput ? '${status.label} · Ajan çıktısı alındı' : status.label,
        style: TextStyle(color: status.color, fontWeight: FontWeight.w700),
      ),
      childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
      children: [
        if (task.errorMessage.isNotEmpty)
          _InlineNotice(icon: Icons.error_outline, text: task.errorMessage)
        else if (hasOutput)
          SelectableText(
            const JsonEncoder.withIndent('  ').convert(task.output),
            style: const TextStyle(
              color: Color(0xFF42535D),
              fontFamily: 'monospace',
              fontSize: 12.5,
              height: 1.45,
            ),
          )
        else
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Bu ajan için henüz görüntülenebilir çıktı yok.',
              style: TextStyle(color: Color(0xFF687780)),
            ),
          ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      label,
      style: TextStyle(
        color: color,
        fontSize: 11.5,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

class _InlineNotice extends StatelessWidget {
  const _InlineNotice({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF8E8),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFFE9D8A6)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: const Color(0xFF8A5A00)),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: const TextStyle(height: 1.4))),
      ],
    ),
  );
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.title,
    required this.description,
  });
  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 52, color: MarkaKalkanTheme.teal),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(description, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}

({String label, Color color}) _statusPresentation(
  AiFieldOperationStatus status,
) {
  return switch (status) {
    AiFieldOperationStatus.draft => (
      label: 'Taslak',
      color: const Color(0xFF687780),
    ),
    AiFieldOperationStatus.queued => (
      label: 'Sırada',
      color: const Color(0xFF365E7D),
    ),
    AiFieldOperationStatus.running => (
      label: 'Çalışıyor',
      color: const Color(0xFF176B87),
    ),
    AiFieldOperationStatus.waitingHumanApproval => (
      label: 'Uzman onayı bekliyor',
      color: const Color(0xFF8A5A00),
    ),
    AiFieldOperationStatus.completed => (
      label: 'Tamamlandı',
      color: const Color(0xFF087F70),
    ),
    AiFieldOperationStatus.failed => (
      label: 'Başarısız',
      color: const Color(0xFFB3261E),
    ),
    AiFieldOperationStatus.cancelled => (
      label: 'İptal edildi',
      color: const Color(0xFF687780),
    ),
  };
}

({String label, Color color, IconData icon}) _taskStatusPresentation(
  AiFieldAgentTaskStatus status,
) {
  return switch (status) {
    AiFieldAgentTaskStatus.pending => (
      label: 'Bekliyor',
      color: const Color(0xFF687780),
      icon: Icons.schedule,
    ),
    AiFieldAgentTaskStatus.queued => (
      label: 'Sırada',
      color: const Color(0xFF365E7D),
      icon: Icons.queue,
    ),
    AiFieldAgentTaskStatus.running => (
      label: 'Çalışıyor',
      color: const Color(0xFF176B87),
      icon: Icons.sync,
    ),
    AiFieldAgentTaskStatus.completed => (
      label: 'Tamamlandı',
      color: const Color(0xFF087F70),
      icon: Icons.check_circle_outline,
    ),
    AiFieldAgentTaskStatus.failed => (
      label: 'Başarısız',
      color: const Color(0xFFB3261E),
      icon: Icons.error_outline,
    ),
    AiFieldAgentTaskStatus.skipped => (
      label: 'Atlandı',
      color: const Color(0xFF687780),
      icon: Icons.skip_next,
    ),
    AiFieldAgentTaskStatus.waitingHandoff => (
      label: 'Devir bekliyor',
      color: const Color(0xFF6C4AB6),
      icon: Icons.swap_horiz,
    ),
    AiFieldAgentTaskStatus.waitingHumanApproval => (
      label: 'Uzman onayı bekliyor',
      color: const Color(0xFF8A5A00),
      icon: Icons.gpp_good_outlined,
    ),
  };
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:markakalkan/app/router.dart';
import 'package:markakalkan/core/theme/markakalkan_theme.dart';
import 'package:markakalkan/features/detective/data/detective_category_catalog.dart';
import 'package:markakalkan/features/detective/data/digital_detective_task_service.dart';

class DigitalDetectiveTasksPage extends StatefulWidget {
  const DigitalDetectiveTasksPage({super.key});

  @override
  State<DigitalDetectiveTasksPage> createState() =>
      _DigitalDetectiveTasksPageState();
}

class _DigitalDetectiveTasksPageState extends State<DigitalDetectiveTasksPage> {
  final _taskService = DigitalDetectiveTaskService();

  String _categoryName(String categoryId) {
    for (final category in DetectiveCategoryCatalog.categories) {
      if (category.id == categoryId) {
        return category.name;
      }
    }

    return categoryId;
  }

  String _formatDate(dynamic value) {
    if (value is! Timestamp) {
      return 'Tarih bekleniyor';
    }

    final date = value.toDate();
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');

    return '$day.$month.${date.year} · $hour:$minute';
  }

  List<String> _stringList(dynamic value) {
    if (value is! List) {
      return const [];
    }

    return value.whereType<String>().toList();
  }

  String _violationLabel(String violationId) {
    return switch (violationId) {
      'counterfeit_product' => 'Sahte ürün şüphesi',
      'fake_certificate' => 'Sahte sertifika',
      'fake_label' => 'Sahte etiket',
      'parallel_import_gray_market' => 'Paralel ithalat / gri pazar',
      'unauthorized_seller' => 'Yetkisiz satıcı',
      'brand_misuse' => 'Markanın izinsiz kullanımı',
      'logo_misuse' => 'Logo veya görsel kimlik ihlali',
      'domain_abuse' => 'Alan adı ihlali',
      'fake_website' => 'Sahte internet sitesi',
      'misleading_advertising' => 'Yanıltıcı reklam',
      _ => violationId,
    };
  }

  Future<void> _deleteTask(String taskId, String taskName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Görevi sil'),
        content: Text(
          '“$taskName” görevi silinsin mi?\n\n'
          'Yalnızca henüz çalışmaya başlamamış görevler silinebilir.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Görevi sil'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) {
      return;
    }

    try {
      await _taskService.deleteQueuedTask(taskId);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Görev silindi.')));
    } on StateError catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message.toString())));
    } on FirebaseException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Görev silinemedi: ${error.message ?? error.code}'),
        ),
      );
    }
  }

  void _showTaskDetails(String taskId, Map<String, dynamic> data) {
    final countries = _stringList(data['countries']);
    final sources = _stringList(data['sources']);
    final violations = _stringList(data['violationIds']);

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          (data['taskName'] as String?)?.trim().isNotEmpty == true
              ? data['taskName'] as String
              : 'Dijital Dedektif Görevi',
        ),
        content: SizedBox(
          width: 620,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _DetailRow(label: 'Görev No', value: taskId),
                _DetailRow(
                  label: 'Marka',
                  value: data['brandName']?.toString() ?? '-',
                ),
                _DetailRow(
                  label: 'Ürün',
                  value: data['productName']?.toString() ?? '-',
                ),
                _DetailRow(
                  label: 'Kategori',
                  value: _categoryName(data['categoryId']?.toString() ?? ''),
                ),
                _DetailRow(
                  label: 'Alt kategori',
                  value: data['subcategory']?.toString() ?? '-',
                ),
                _DetailRow(
                  label: 'Ülkeler',
                  value: countries.isEmpty ? '-' : countries.join(', '),
                ),
                _DetailRow(
                  label: 'Kaynaklar',
                  value: sources.isEmpty ? '-' : sources.join(', '),
                ),
                _DetailRow(
                  label: 'İhlal türleri',
                  value: violations.isEmpty
                      ? '-'
                      : violations.map(_violationLabel).join(', '),
                ),
                _DetailRow(
                  label: 'Tarama sıklığı',
                  value: data['frequency']?.toString() ?? '-',
                ),
                _DetailRow(
                  label: 'Risk seviyesi',
                  value: data['riskLevel']?.toString() ?? '-',
                ),
                _DetailRow(
                  label: 'Oluşturulma',
                  value: _formatDate(data['createdAt']),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Kapat'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MarkaKalkanTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text(
          'Dijital Dedektif Görevlerim',
          style: TextStyle(
            color: MarkaKalkanTheme.navy,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: FilledButton.icon(
              onPressed: () => AppRouter.openDigitalDetectiveTask(context),
              icon: const Icon(Icons.add),
              label: const Text('Yeni Görev'),
            ),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _taskService.watchTasks(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _TasksMessage(
              icon: Icons.error_outline,
              title: 'Görevler yüklenemedi',
              description: snapshot.error.toString(),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final tasks = snapshot.data?.docs ?? [];

          if (tasks.isEmpty) {
            return _TasksMessage(
              icon: Icons.travel_explore_outlined,
              title: 'Henüz Dijital Dedektif göreviniz yok',
              description:
                  'İlk görevinizi oluşturarak dijital pazar taramasını başlatın.',
              action: FilledButton.icon(
                onPressed: () => AppRouter.openDigitalDetectiveTask(context),
                icon: const Icon(Icons.add),
                label: const Text('İlk Görevi Oluştur'),
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1180),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _TasksHeader(taskCount: tasks.length),
                    const SizedBox(height: 22),
                    ...tasks.map((document) {
                      final data = document.data();

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _TaskCard(
                          taskId: document.id,
                          data: data,
                          categoryName: _categoryName(
                            data['categoryId']?.toString() ?? '',
                          ),
                          createdAt: _formatDate(data['createdAt']),
                          countries: _stringList(data['countries']),
                          onOpen: () => _showTaskDetails(document.id, data),
                          onFindings: () =>
                              AppRouter.openDigitalDetectiveFindings(
                                context,
                                taskId: document.id,
                                taskName:
                                    data['taskName']?.toString() ??
                                    'Dijital Dedektif Görevi',
                                brandName: data['brandName']?.toString() ?? '-',
                                productName:
                                    data['productName']?.toString() ?? '-',
                              ),
                          onDelete: data['status'] == 'queued'
                              ? () => _deleteTask(
                                  document.id,
                                  data['taskName']?.toString() ??
                                      'İsimsiz görev',
                                )
                              : null,
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TasksHeader extends StatelessWidget {
  const _TasksHeader({required this.taskCount});

  final int taskCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [MarkaKalkanTheme.navy, Color(0xFF183B4E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.assignment_outlined,
            color: MarkaKalkanTheme.teal,
            size: 42,
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Dijital araştırma görevlerinizi yönetin',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  '$taskCount görev kayıtlı. Görev durumları ve bulgular '
                  'bu ekranda canlı olarak güncellenir.',
                  style: const TextStyle(
                    color: Color(0xFFD9E5EA),
                    height: 1.45,
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

class _TaskCard extends StatelessWidget {
  const _TaskCard({
    required this.taskId,
    required this.data,
    required this.categoryName,
    required this.createdAt,
    required this.countries,
    required this.onOpen,
    required this.onFindings,
    required this.onDelete,
  });

  final String taskId;
  final Map<String, dynamic> data;
  final String categoryName;
  final String createdAt;
  final List<String> countries;
  final VoidCallback onOpen;
  final VoidCallback onFindings;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final status = data['status']?.toString() ?? 'queued';
    final resultCount = data['resultCount'] is int
        ? data['resultCount'] as int
        : 0;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE0E7EC)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F6F4),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.travel_explore_outlined,
                      color: MarkaKalkanTheme.teal,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data['taskName']?.toString() ?? 'İsimsiz görev',
                          style: const TextStyle(
                            color: MarkaKalkanTheme.navy,
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '${data['brandName'] ?? '-'} · '
                          '${data['productName'] ?? '-'}',
                          style: const TextStyle(color: Color(0xFF687580)),
                        ),
                      ],
                    ),
                  ),
                  _TaskStatusBadge(status: status),
                ],
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _TaskInfoChip(
                    icon: Icons.category_outlined,
                    label: categoryName,
                  ),
                  _TaskInfoChip(
                    icon: Icons.flag_outlined,
                    label: countries.isEmpty
                        ? 'Ülke seçilmedi'
                        : countries.join(', '),
                  ),
                  _TaskInfoChip(
                    icon: Icons.schedule_outlined,
                    label: data['frequency']?.toString() ?? '-',
                  ),
                  _TaskInfoChip(
                    icon: Icons.fact_check_outlined,
                    label: '$resultCount bulgu',
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const Divider(height: 1),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Görev No: $taskId\n$createdAt',
                      style: const TextStyle(
                        color: Color(0xFF7A8790),
                        fontSize: 12,
                        height: 1.45,
                      ),
                    ),
                  ),
                  if (onDelete != null)
                    IconButton(
                      tooltip: 'Görevi sil',
                      onPressed: onDelete,
                      icon: const Icon(Icons.delete_outline),
                    ),
                  TextButton.icon(
                    onPressed: onFindings,
                    icon: const Icon(Icons.fact_check_outlined, size: 18),
                    label: Text(
                      resultCount > 0
                          ? 'Bulguları Gör ($resultCount)'
                          : 'Bulguları Gör',
                    ),
                  ),
                  const SizedBox(width: 6),
                  TextButton.icon(
                    onPressed: onOpen,
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: const Text('Ayrıntılar'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TaskStatusBadge extends StatelessWidget {
  const _TaskStatusBadge({required this.status});

  final String status;

  String get label {
    return switch (status) {
      'running' => 'Çalışıyor',
      'completed' => 'Tamamlandı',
      'failed' => 'Başarısız',
      _ => 'Sırada',
    };
  }

  Color get backgroundColor {
    return switch (status) {
      'running' => const Color(0xFFEAF1F8),
      'completed' => const Color(0xFFE8F6F4),
      'failed' => const Color(0xFFFDECEC),
      _ => const Color(0xFFFFF4D8),
    };
  }

  Color get textColor {
    return switch (status) {
      'running' => MarkaKalkanTheme.blue,
      'completed' => MarkaKalkanTheme.teal,
      'failed' => const Color(0xFFB42318),
      _ => const Color(0xFF8A6110),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _TaskInfoChip extends StatelessWidget {
  const _TaskInfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 440),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F7F9),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 17, color: MarkaKalkanTheme.blue),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: MarkaKalkanTheme.navy,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF7A8790),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          SelectableText(
            value,
            style: const TextStyle(
              color: MarkaKalkanTheme.navy,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _TasksMessage extends StatelessWidget {
  const _TasksMessage({
    required this.icon,
    required this.title,
    required this.description,
    this.action,
  });

  final IconData icon;
  final String title;
  final String description;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 620),
          padding: const EdgeInsets.all(34),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFE0E7EC)),
          ),
          child: Column(
            children: [
              Icon(icon, size: 58, color: MarkaKalkanTheme.teal),
              const SizedBox(height: 18),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: MarkaKalkanTheme.navy,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                description,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF687580), height: 1.5),
              ),
              if (action != null) ...[const SizedBox(height: 22), action!],
            ],
          ),
        ),
      ),
    );
  }
}

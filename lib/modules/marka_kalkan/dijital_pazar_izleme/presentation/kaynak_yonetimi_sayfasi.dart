import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:markakalkan/core/theme/markakalkan_theme.dart';

import '../constants/monitoring_enums.dart';
import '../models/monitoring_source_model.dart';
import '../repositories/monitoring_source_repository.dart';

class KaynakYonetimiSayfasi extends StatefulWidget {
  const KaynakYonetimiSayfasi({super.key});

  @override
  State<KaynakYonetimiSayfasi> createState() => _KaynakYonetimiSayfasiState();
}

class _KaynakYonetimiSayfasiState extends State<KaynakYonetimiSayfasi> {
  User? get _currentUser => FirebaseAuth.instance.currentUser;

  MonitoringSourceRepository? get _repository {
    final user = _currentUser;

    if (user == null) {
      return null;
    }

    return MonitoringSourceRepository.instance(tenantId: user.uid);
  }

  Future<void> _openCreateDialog() async {
    final repository = _repository;
    final user = _currentUser;

    if (repository == null || user == null) {
      _showMessage('Kaynak eklemek için giriş yapılmalıdır.');
      return;
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _CreateSourceDialog(repository: repository, user: user),
    );
  }

  Future<void> _toggleStatus(MonitoringSourceModel source) async {
    final repository = _repository;
    final user = _currentUser;

    if (repository == null || user == null) {
      return;
    }

    final nextStatus = source.status == MonitoringRecordStatus.active
        ? MonitoringRecordStatus.paused
        : MonitoringRecordStatus.active;

    try {
      await repository.updateStatus(
        sourceId: source.id,
        status: nextStatus,
        updatedBy: user.uid,
      );

      if (!mounted) {
        return;
      }

      _showMessage(
        nextStatus == MonitoringRecordStatus.active
            ? 'Kaynak etkinleştirildi.'
            : 'Kaynak duraklatıldı.',
      );
    } on FirebaseException catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage(
        error.code == 'permission-denied'
            ? 'Bu kaynağı değiştirme yetkiniz bulunmuyor.'
            : 'Kaynak durumu güncellenemedi.',
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      _showMessage('Kaynak durumu güncellenemedi.');
    }
  }

  Future<void> _deleteSource(MonitoringSourceModel source) async {
    final repository = _repository;

    if (repository == null) {
      return;
    }

    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Kaynağı sil'),
          content: Text('"${source.name}" kaynağı kalıcı olarak silinsin mi?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Sil'),
            ),
          ],
        );
      },
    );

    if (approved != true) {
      return;
    }

    try {
      await repository.delete(source.id);

      if (!mounted) {
        return;
      }

      _showMessage('Kaynak silindi.');
    } on FirebaseException catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage(
        error.code == 'permission-denied'
            ? 'Bu kaynağı silme yetkiniz bulunmuyor.'
            : 'Kaynak silinemedi.',
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      _showMessage('Kaynak silinemedi.');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final user = _currentUser;
    final repository = _repository;

    return Scaffold(
      backgroundColor: MarkaKalkanTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text(
          'Kaynak Yönetimi',
          style: TextStyle(
            color: MarkaKalkanTheme.navy,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: user == null || repository == null
          ? const _SignedOutState()
          : StreamBuilder<List<MonitoringSourceModel>>(
              stream: repository.watchAll(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return _ErrorState(error: snapshot.error);
                }

                final sources =
                    snapshot.data ?? const <MonitoringSourceModel>[];

                return _SourceBody(
                  sources: sources,
                  onCreate: _openCreateDialog,
                  onToggleStatus: _toggleStatus,
                  onDelete: _deleteSource,
                );
              },
            ),
    );
  }
}

class _SourceBody extends StatelessWidget {
  const _SourceBody({
    required this.sources,
    required this.onCreate,
    required this.onToggleStatus,
    required this.onDelete,
  });

  final List<MonitoringSourceModel> sources;
  final VoidCallback onCreate;
  final ValueChanged<MonitoringSourceModel> onToggleStatus;
  final ValueChanged<MonitoringSourceModel> onDelete;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = constraints.maxWidth >= 900 ? 40.0 : 20.0;

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            28,
            horizontalPadding,
            48,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1240),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SourceHeader(
                    sourceCount: sources.length,
                    onCreate: onCreate,
                  ),
                  const SizedBox(height: 26),
                  if (sources.isEmpty)
                    _EmptySourceState(onCreate: onCreate)
                  else
                    _SourceGrid(
                      sources: sources,
                      onToggleStatus: onToggleStatus,
                      onDelete: onDelete,
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SourceHeader extends StatelessWidget {
  const _SourceHeader({required this.sourceCount, required this.onCreate});

  final int sourceCount;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE0E7EC)),
      ),
      child: Wrap(
        spacing: 24,
        runSpacing: 20,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 740),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Dijital kaynak merkezi',
                  style: TextStyle(
                    color: MarkaKalkanTheme.navy,
                    fontSize: 25,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$sourceCount kaynak kayıtlı. Pazaryeri, web sitesi, '
                  'sosyal medya ve diğer dijital kanalları buradan yönetin.',
                  style: const TextStyle(color: Color(0xFF687580), height: 1.5),
                ),
              ],
            ),
          ),
          FilledButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add),
            label: const Text('Yeni Kaynak'),
            style: FilledButton.styleFrom(
              backgroundColor: MarkaKalkanTheme.teal,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptySourceState extends StatelessWidget {
  const _EmptySourceState({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 64),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE0E7EC)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.hub_outlined,
            size: 64,
            color: MarkaKalkanTheme.teal,
          ),
          const SizedBox(height: 20),
          const Text(
            'Henüz izleme kaynağı eklenmedi',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: MarkaKalkanTheme.navy,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'İlk pazaryeri, web sitesi veya sosyal medya kaynağınızı ekleyin.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF687580), height: 1.5),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add),
            label: const Text('İlk Kaynağı Ekle'),
          ),
        ],
      ),
    );
  }
}

class _SourceGrid extends StatelessWidget {
  const _SourceGrid({
    required this.sources,
    required this.onToggleStatus,
    required this.onDelete,
  });

  final List<MonitoringSourceModel> sources;
  final ValueChanged<MonitoringSourceModel> onToggleStatus;
  final ValueChanged<MonitoringSourceModel> onDelete;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = constraints.maxWidth >= 900
            ? (constraints.maxWidth - 20) / 2
            : constraints.maxWidth;

        return Wrap(
          spacing: 20,
          runSpacing: 20,
          children: [
            for (final source in sources)
              SizedBox(
                width: cardWidth,
                child: _SourceCard(
                  source: source,
                  onToggleStatus: () {
                    onToggleStatus(source);
                  },
                  onDelete: () {
                    onDelete(source);
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}

class _SourceCard extends StatelessWidget {
  const _SourceCard({
    required this.source,
    required this.onToggleStatus,
    required this.onDelete,
  });

  final MonitoringSourceModel source;
  final VoidCallback onToggleStatus;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final isActive = source.status == MonitoringRecordStatus.active;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isActive ? MarkaKalkanTheme.teal : const Color(0xFFE0E7EC),
          width: isActive ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF7F6),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  _sourceIcon(source.sourceType),
                  color: MarkaKalkanTheme.teal,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      source.name,
                      style: const TextStyle(
                        color: MarkaKalkanTheme.navy,
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _sourceTypeLabel(source.sourceType),
                      style: const TextStyle(
                        color: Color(0xFF687580),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'toggle') {
                    onToggleStatus();
                  }

                  if (value == 'delete') {
                    onDelete();
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem<String>(
                    value: 'toggle',
                    child: Text(
                      isActive ? 'Kaynağı duraklat' : 'Kaynağı etkinleştir',
                    ),
                  ),
                  const PopupMenuItem<String>(
                    value: 'delete',
                    child: Text('Kaynağı sil'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),
          SelectableText(
            source.baseUrl,
            style: const TextStyle(
              color: MarkaKalkanTheme.teal,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _InfoChip(
                label: _statusLabel(source.status),
                icon: isActive
                    ? Icons.play_circle_outline
                    : Icons.pause_circle_outline,
              ),
              _InfoChip(
                label: _priorityLabel(source.priority),
                icon: Icons.flag_outlined,
              ),
              _InfoChip(
                label: _frequencyLabel(source.scanFrequency),
                icon: Icons.schedule_outlined,
              ),
              _InfoChip(
                label: _healthLabel(source.healthStatus),
                icon: Icons.health_and_safety_outlined,
              ),
              _InfoChip(
                label: _termsLabel(source.termsReviewStatus),
                icon: Icons.gavel_outlined,
              ),
              _InfoChip(
                label: _accessLabel(source.accessMethod),
                icon: Icons.vpn_key_outlined,
              ),
            ],
          ),
          if (source.notes != null && source.notes!.trim().isNotEmpty) ...[
            const SizedBox(height: 18),
            Text(
              source.notes!,
              style: const TextStyle(color: Color(0xFF687580), height: 1.45),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F7F8),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: MarkaKalkanTheme.navy),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: MarkaKalkanTheme.navy,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _CreateSourceDialog extends StatefulWidget {
  const _CreateSourceDialog({required this.repository, required this.user});

  final MonitoringSourceRepository repository;
  final User user;

  @override
  State<_CreateSourceDialog> createState() => _CreateSourceDialogState();
}

class _CreateSourceDialogState extends State<_CreateSourceDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _urlController = TextEditingController();
  final _notesController = TextEditingController();

  MonitoringSourceType _sourceType = MonitoringSourceType.marketplace;
  MonitoringAccessMethod _accessMethod = MonitoringAccessMethod.publicWeb;
  MonitoringScanFrequency _scanFrequency = MonitoringScanFrequency.daily;
  MonitoringPriority _priority = MonitoringPriority.normal;
  MonitoringSourceHealthStatus _healthStatus =
      MonitoringSourceHealthStatus.unknown;
  MonitoringTermsReviewStatus _termsStatus =
      MonitoringTermsReviewStatus.pending;
  MonitoringRecordStatus _status = MonitoringRecordStatus.active;

  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_isSaving || !_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final source = MonitoringSourceModel(
      id: '',
      tenantId: widget.user.uid,
      brandId: widget.user.uid,
      name: _nameController.text,
      sourceType: _sourceType,
      baseUrl: _urlController.text,
      accessMethod: _accessMethod,
      healthStatus: _healthStatus,
      termsReviewStatus: _termsStatus,
      status: _status,
      priority: _priority,
      scanFrequency: _scanFrequency,
      notes: _notesController.text,
      createdAt: DateTime.now(),
      createdBy: widget.user.uid,
    );

    try {
      await widget.repository.create(source);

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('İzleme kaynağı oluşturuldu.')),
      );
    } on FirebaseException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.code == 'permission-denied'
                ? 'Kaynak oluşturma yetkiniz bulunmuyor.'
                : 'Kaynak oluşturulamadı.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isSaving = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Kaynak oluşturulamadı.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900, maxHeight: 760),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(26, 22, 16, 14),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Yeni İzleme Kaynağı',
                      style: TextStyle(
                        color: MarkaKalkanTheme.navy,
                        fontSize: 23,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _isSaving
                        ? null
                        : () {
                            Navigator.of(context).pop();
                          },
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(26),
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Kaynak adı',
                          hintText: 'Örnek: Trendyol Türkiye',
                        ),
                        validator: (value) {
                          final cleaned = value?.trim() ?? '';

                          if (cleaned.length < 2) {
                            return 'Kaynak adı en az 2 karakter olmalıdır.';
                          }

                          return null;
                        },
                      ),
                      const SizedBox(height: 18),
                      TextFormField(
                        controller: _urlController,
                        decoration: const InputDecoration(
                          labelText: 'Temel URL',
                          hintText: 'https://www.trendyol.com',
                        ),
                        validator: (value) {
                          final cleaned = value?.trim() ?? '';

                          if (cleaned.isEmpty) {
                            return 'Kaynak adresi zorunludur.';
                          }

                          final normalized = cleaned.contains('://')
                              ? cleaned
                              : 'https://$cleaned';

                          final uri = Uri.tryParse(normalized);

                          if (uri == null || uri.host.isEmpty) {
                            return 'Geçerli bir URL girin.';
                          }

                          return null;
                        },
                      ),
                      const SizedBox(height: 18),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final fieldWidth = constraints.maxWidth >= 700
                              ? (constraints.maxWidth - 16) / 2
                              : constraints.maxWidth;

                          return Wrap(
                            spacing: 16,
                            runSpacing: 16,
                            children: [
                              SizedBox(
                                width: fieldWidth,
                                child:
                                    DropdownButtonFormField<
                                      MonitoringSourceType
                                    >(
                                      initialValue: _sourceType,
                                      decoration: const InputDecoration(
                                        labelText: 'Kaynak türü',
                                      ),
                                      items: MonitoringSourceType.values
                                          .map(
                                            (value) => DropdownMenuItem(
                                              value: value,
                                              child: Text(
                                                _sourceTypeLabel(value),
                                              ),
                                            ),
                                          )
                                          .toList(),
                                      onChanged: (value) {
                                        if (value != null) {
                                          setState(() {
                                            _sourceType = value;
                                          });
                                        }
                                      },
                                    ),
                              ),
                              SizedBox(
                                width: fieldWidth,
                                child:
                                    DropdownButtonFormField<
                                      MonitoringAccessMethod
                                    >(
                                      initialValue: _accessMethod,
                                      decoration: const InputDecoration(
                                        labelText: 'Erişim yöntemi',
                                      ),
                                      items: MonitoringAccessMethod.values
                                          .map(
                                            (value) => DropdownMenuItem(
                                              value: value,
                                              child: Text(_accessLabel(value)),
                                            ),
                                          )
                                          .toList(),
                                      onChanged: (value) {
                                        if (value != null) {
                                          setState(() {
                                            _accessMethod = value;
                                          });
                                        }
                                      },
                                    ),
                              ),
                              SizedBox(
                                width: fieldWidth,
                                child:
                                    DropdownButtonFormField<
                                      MonitoringScanFrequency
                                    >(
                                      initialValue: _scanFrequency,
                                      decoration: const InputDecoration(
                                        labelText: 'Tarama sıklığı',
                                      ),
                                      items: MonitoringScanFrequency.values
                                          .map(
                                            (value) => DropdownMenuItem(
                                              value: value,
                                              child: Text(
                                                _frequencyLabel(value),
                                              ),
                                            ),
                                          )
                                          .toList(),
                                      onChanged: (value) {
                                        if (value != null) {
                                          setState(() {
                                            _scanFrequency = value;
                                          });
                                        }
                                      },
                                    ),
                              ),
                              SizedBox(
                                width: fieldWidth,
                                child:
                                    DropdownButtonFormField<MonitoringPriority>(
                                      initialValue: _priority,
                                      decoration: const InputDecoration(
                                        labelText: 'Öncelik',
                                      ),
                                      items: MonitoringPriority.values
                                          .map(
                                            (value) => DropdownMenuItem(
                                              value: value,
                                              child: Text(
                                                _priorityLabel(value),
                                              ),
                                            ),
                                          )
                                          .toList(),
                                      onChanged: (value) {
                                        if (value != null) {
                                          setState(() {
                                            _priority = value;
                                          });
                                        }
                                      },
                                    ),
                              ),
                              SizedBox(
                                width: fieldWidth,
                                child:
                                    DropdownButtonFormField<
                                      MonitoringSourceHealthStatus
                                    >(
                                      initialValue: _healthStatus,
                                      decoration: const InputDecoration(
                                        labelText: 'Sağlık durumu',
                                      ),
                                      items: MonitoringSourceHealthStatus.values
                                          .map(
                                            (value) => DropdownMenuItem(
                                              value: value,
                                              child: Text(_healthLabel(value)),
                                            ),
                                          )
                                          .toList(),
                                      onChanged: (value) {
                                        if (value != null) {
                                          setState(() {
                                            _healthStatus = value;
                                          });
                                        }
                                      },
                                    ),
                              ),
                              SizedBox(
                                width: fieldWidth,
                                child:
                                    DropdownButtonFormField<
                                      MonitoringTermsReviewStatus
                                    >(
                                      initialValue: _termsStatus,
                                      decoration: const InputDecoration(
                                        labelText: 'Kullanım koşulları',
                                      ),
                                      items: MonitoringTermsReviewStatus.values
                                          .map(
                                            (value) => DropdownMenuItem(
                                              value: value,
                                              child: Text(_termsLabel(value)),
                                            ),
                                          )
                                          .toList(),
                                      onChanged: (value) {
                                        if (value != null) {
                                          setState(() {
                                            _termsStatus = value;
                                          });
                                        }
                                      },
                                    ),
                              ),
                              SizedBox(
                                width: fieldWidth,
                                child:
                                    DropdownButtonFormField<
                                      MonitoringRecordStatus
                                    >(
                                      initialValue: _status,
                                      decoration: const InputDecoration(
                                        labelText: 'Başlangıç durumu',
                                      ),
                                      items: MonitoringRecordStatus.values
                                          .map(
                                            (value) => DropdownMenuItem(
                                              value: value,
                                              child: Text(_statusLabel(value)),
                                            ),
                                          )
                                          .toList(),
                                      onChanged: (value) {
                                        if (value != null) {
                                          setState(() {
                                            _status = value;
                                          });
                                        }
                                      },
                                    ),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 18),
                      TextFormField(
                        controller: _notesController,
                        maxLines: 4,
                        maxLength: 3000,
                        decoration: const InputDecoration(
                          labelText: 'Notlar',
                          hintText:
                              'Kaynağın kapsamı, sınırlamaları veya inceleme notları',
                          alignLabelWithHint: true,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isSaving
                        ? null
                        : () {
                            Navigator.of(context).pop();
                          },
                    child: const Text('Vazgeç'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: _isSaving ? null : _save,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(_isSaving ? 'Kaydediliyor' : 'Kaynağı Kaydet'),
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

class _SignedOutState extends StatelessWidget {
  const _SignedOutState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Kaynak yönetimini kullanmak için giriş yapmalısınız.'),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error});

  final Object? error;

  @override
  Widget build(BuildContext context) {
    final isIndexError = error.toString().contains('failed-precondition');

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Text(
          isIndexError
              ? 'Kaynak indeksi hazırlanıyor. Birkaç dakika sonra yeniden deneyin.'
              : 'Kaynaklar yüklenemedi.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

IconData _sourceIcon(MonitoringSourceType value) {
  switch (value) {
    case MonitoringSourceType.marketplace:
      return Icons.storefront_outlined;
    case MonitoringSourceType.ecommerceSite:
      return Icons.shopping_cart_outlined;
    case MonitoringSourceType.socialMedia:
      return Icons.share_outlined;
    case MonitoringSourceType.searchEngine:
      return Icons.search_outlined;
    case MonitoringSourceType.classifiedSite:
      return Icons.list_alt_outlined;
    case MonitoringSourceType.domain:
      return Icons.language_outlined;
    case MonitoringSourceType.mobileApp:
      return Icons.phone_android_outlined;
    case MonitoringSourceType.manualSource:
      return Icons.upload_file_outlined;
  }
}

String _sourceTypeLabel(MonitoringSourceType value) {
  switch (value) {
    case MonitoringSourceType.marketplace:
      return 'Pazaryeri';
    case MonitoringSourceType.ecommerceSite:
      return 'E-ticaret sitesi';
    case MonitoringSourceType.socialMedia:
      return 'Sosyal medya';
    case MonitoringSourceType.searchEngine:
      return 'Arama motoru';
    case MonitoringSourceType.classifiedSite:
      return 'İlan sitesi';
    case MonitoringSourceType.domain:
      return 'Alan adı';
    case MonitoringSourceType.mobileApp:
      return 'Mobil uygulama';
    case MonitoringSourceType.manualSource:
      return 'Manuel kaynak';
  }
}

String _accessLabel(MonitoringAccessMethod value) {
  switch (value) {
    case MonitoringAccessMethod.publicWeb:
      return 'Herkese açık web';
    case MonitoringAccessMethod.officialApi:
      return 'Resmî API';
    case MonitoringAccessMethod.partnerApi:
      return 'İş ortağı API';
    case MonitoringAccessMethod.manualUpload:
      return 'Manuel yükleme';
    case MonitoringAccessMethod.webhook:
      return 'Webhook';
  }
}

String _healthLabel(MonitoringSourceHealthStatus value) {
  switch (value) {
    case MonitoringSourceHealthStatus.healthy:
      return 'Sağlıklı';
    case MonitoringSourceHealthStatus.degraded:
      return 'Kısmi sorun';
    case MonitoringSourceHealthStatus.failed:
      return 'Başarısız';
    case MonitoringSourceHealthStatus.blocked:
      return 'Engellendi';
    case MonitoringSourceHealthStatus.unknown:
      return 'Kontrol edilmedi';
  }
}

String _termsLabel(MonitoringTermsReviewStatus value) {
  switch (value) {
    case MonitoringTermsReviewStatus.pending:
      return 'İnceleme bekliyor';
    case MonitoringTermsReviewStatus.approved:
      return 'Uygun';
    case MonitoringTermsReviewStatus.restricted:
      return 'Kısıtlı';
    case MonitoringTermsReviewStatus.rejected:
      return 'Uygun değil';
  }
}

String _frequencyLabel(MonitoringScanFrequency value) {
  switch (value) {
    case MonitoringScanFrequency.hourly:
      return 'Saatlik';
    case MonitoringScanFrequency.every6Hours:
      return '6 saatte bir';
    case MonitoringScanFrequency.daily:
      return 'Günlük';
    case MonitoringScanFrequency.weekly:
      return 'Haftalık';
    case MonitoringScanFrequency.manual:
      return 'Manuel';
  }
}

String _priorityLabel(MonitoringPriority value) {
  switch (value) {
    case MonitoringPriority.low:
      return 'Düşük öncelik';
    case MonitoringPriority.normal:
      return 'Normal öncelik';
    case MonitoringPriority.high:
      return 'Yüksek öncelik';
    case MonitoringPriority.critical:
      return 'Kritik öncelik';
  }
}

String _statusLabel(MonitoringRecordStatus value) {
  switch (value) {
    case MonitoringRecordStatus.active:
      return 'Aktif';
    case MonitoringRecordStatus.paused:
      return 'Duraklatıldı';
    case MonitoringRecordStatus.archived:
      return 'Arşivlendi';
  }
}

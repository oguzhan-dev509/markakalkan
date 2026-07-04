import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:markakalkan/core/theme/markakalkan_theme.dart';

import '../constants/monitoring_enums.dart';
import '../models/brand_monitoring_profile_model.dart';
import '../repositories/brand_monitoring_profile_repository.dart';

class MarkaIzlemeProfiliSayfasi extends StatefulWidget {
  const MarkaIzlemeProfiliSayfasi({super.key});

  @override
  State<MarkaIzlemeProfiliSayfasi> createState() =>
      _MarkaIzlemeProfiliSayfasiState();
}

class _MarkaIzlemeProfiliSayfasiState extends State<MarkaIzlemeProfiliSayfasi> {
  User? get _currentUser => FirebaseAuth.instance.currentUser;

  BrandMonitoringProfileRepository? get _repository {
    final user = _currentUser;

    if (user == null) {
      return null;
    }

    return BrandMonitoringProfileRepository.instance(tenantId: user.uid);
  }

  Future<void> _openCreateDialog() async {
    final repository = _repository;
    final user = _currentUser;

    if (repository == null || user == null) {
      _showMessage('Marka izleme profili oluşturmak için giriş yapılmalıdır.');
      return;
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          _CreateMonitoringProfileDialog(repository: repository, user: user),
    );
  }

  Future<void> _toggleStatus(BrandMonitoringProfileModel profile) async {
    final repository = _repository;
    final user = _currentUser;

    if (repository == null || user == null) {
      return;
    }

    final nextStatus = profile.status == MonitoringRecordStatus.active
        ? MonitoringRecordStatus.paused
        : MonitoringRecordStatus.active;

    try {
      await repository.updateStatus(
        profileId: profile.id,
        status: nextStatus,
        updatedBy: user.uid,
      );

      if (!mounted) {
        return;
      }

      _showMessage(
        nextStatus == MonitoringRecordStatus.active
            ? 'İzleme profili etkinleştirildi.'
            : 'İzleme profili duraklatıldı.',
      );
    } on FirebaseException catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage(
        error.code == 'permission-denied'
            ? 'Bu profili değiştirme yetkiniz bulunmuyor.'
            : 'Profil durumu güncellenemedi.',
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      _showMessage('Profil durumu güncellenemedi.');
    }
  }

  Future<void> _deleteProfile(BrandMonitoringProfileModel profile) async {
    final repository = _repository;

    if (repository == null) {
      return;
    }

    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('İzleme profilini sil'),
          content: Text(
            '"${profile.profileName}" profili kalıcı olarak silinsin mi?',
          ),
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
      await repository.delete(profile.id);

      if (!mounted) {
        return;
      }

      _showMessage('İzleme profili silindi.');
    } on FirebaseException catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage(
        error.code == 'permission-denied'
            ? 'Bu profili silme yetkiniz bulunmuyor.'
            : 'İzleme profili silinemedi.',
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      _showMessage('İzleme profili silinemedi.');
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
          'Marka İzleme Profili',
          style: TextStyle(
            color: MarkaKalkanTheme.navy,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 18),
            child: Center(
              child: Text(
                user?.email ?? 'Marka kullanıcısı',
                style: const TextStyle(
                  color: Color(0xFF687580),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: repository == null
          ? null
          : FloatingActionButton.extended(
              onPressed: _openCreateDialog,
              backgroundColor: MarkaKalkanTheme.teal,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text(
                'Yeni Profil',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
      body: repository == null
          ? const _SignedOutView()
          : StreamBuilder<List<BrandMonitoringProfileModel>>(
              stream: repository.watchAll(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _ErrorView(
                    message: _streamErrorMessage(snapshot.error),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final profiles =
                    snapshot.data ?? const <BrandMonitoringProfileModel>[];

                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1180),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _ProfileHeader(profileCount: profiles.length),
                          const SizedBox(height: 26),
                          Row(
                            children: [
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'İzleme Profilleri',
                                      style: TextStyle(
                                        color: MarkaKalkanTheme.navy,
                                        fontSize: 24,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    SizedBox(height: 6),
                                    Text(
                                      'Marka, ürün grubu ve risk önceliklerine göre ayrı izleme kapsamları oluşturun.',
                                      style: TextStyle(
                                        color: Color(0xFF687580),
                                        height: 1.45,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              FilledButton.icon(
                                onPressed: _openCreateDialog,
                                icon: const Icon(Icons.add),
                                label: const Text('Yeni Profil'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          if (profiles.isEmpty)
                            _EmptyProfilesView(onCreate: _openCreateDialog)
                          else
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final width = constraints.maxWidth;

                                int columns;
                                if (width < 680) {
                                  columns = 1;
                                } else if (width < 1020) {
                                  columns = 2;
                                } else {
                                  columns = 3;
                                }

                                const spacing = 18.0;
                                final cardWidth =
                                    (width - ((columns - 1) * spacing)) /
                                    columns;

                                return Wrap(
                                  spacing: spacing,
                                  runSpacing: spacing,
                                  children: profiles
                                      .map(
                                        (profile) => SizedBox(
                                          width: cardWidth,
                                          child: _ProfileCard(
                                            profile: profile,
                                            onToggleStatus: () =>
                                                _toggleStatus(profile),
                                            onDelete: () =>
                                                _deleteProfile(profile),
                                          ),
                                        ),
                                      )
                                      .toList(),
                                );
                              },
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

  static String _streamErrorMessage(Object? error) {
    if (error is FirebaseException) {
      if (error.code == 'permission-denied') {
        return 'İzleme profillerini görüntüleme yetkiniz bulunmuyor.';
      }

      if (error.code == 'failed-precondition') {
        return 'Firestore indeksi hazırlanıyor. Birkaç dakika sonra yeniden deneyin.';
      }
    }

    return 'İzleme profilleri yüklenemedi.';
  }
}

class _CreateMonitoringProfileDialog extends StatefulWidget {
  const _CreateMonitoringProfileDialog({
    required this.repository,
    required this.user,
  });

  final BrandMonitoringProfileRepository repository;
  final User user;

  @override
  State<_CreateMonitoringProfileDialog> createState() =>
      _CreateMonitoringProfileDialogState();
}

class _CreateMonitoringProfileDialogState
    extends State<_CreateMonitoringProfileDialog> {
  static const Map<String, String> _riskOptions = {
    'counterfeit_product': 'Sahte ürün',
    'unauthorized_seller': 'Yetkisiz satıcı',
    'price_anomaly': 'Fiyat anomalisi',
    'brand_misuse': 'Marka kötüye kullanımı',
    'content_copy': 'İçerik ve görsel kopyalama',
    'seller_recurrence': 'Tekrarlayan satıcı',
  };

  final _formKey = GlobalKey<FormState>();

  final _profileNameController = TextEditingController();
  final _brandNameController = TextEditingController();
  final _categoriesController = TextEditingController();
  final _includeKeywordsController = TextEditingController();
  final _excludeKeywordsController = TextEditingController();
  final _regionsController = TextEditingController();
  final _minimumPriceController = TextEditingController();
  final _maximumPriceController = TextEditingController();

  final Set<String> _selectedRiskTypes = {
    'counterfeit_product',
    'unauthorized_seller',
  };

  MonitoringPriority _priority = MonitoringPriority.normal;
  MonitoringRecordStatus _status = MonitoringRecordStatus.active;

  bool _isSubmitting = false;

  @override
  void dispose() {
    _profileNameController.dispose();
    _brandNameController.dispose();
    _categoriesController.dispose();
    _includeKeywordsController.dispose();
    _excludeKeywordsController.dispose();
    _regionsController.dispose();
    _minimumPriceController.dispose();
    _maximumPriceController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedRiskTypes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('En az bir risk türü seçin.')),
      );
      return;
    }

    final minimumPrice = _parsePrice(_minimumPriceController.text);
    final maximumPrice = _parsePrice(_maximumPriceController.text);

    if (minimumPrice != null &&
        maximumPrice != null &&
        minimumPrice > maximumPrice) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Alt fiyat, üst fiyattan büyük olamaz.')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final now = DateTime.now();
    final userId = widget.user.uid;

    final profile = BrandMonitoringProfileModel(
      id: '',
      tenantId: userId,
      brandId: userId,
      profileName: _profileNameController.text.trim(),
      brandName: _brandNameController.text.trim(),
      productIds: const [],
      categories: _splitValues(_categoriesController.text),
      includeKeywords: _splitValues(_includeKeywordsController.text),
      excludeKeywords: _splitValues(_excludeKeywordsController.text),
      riskTypes: _selectedRiskTypes.toList(growable: false),
      prioritySourceIds: const [],
      targetRegions: _splitValues(_regionsController.text),
      minimumPrice: minimumPrice,
      maximumPrice: maximumPrice,
      currency: 'TRY',
      status: _status,
      priority: _priority,
      createdAt: now,
      createdBy: userId,
    );

    try {
      await widget.repository.create(profile);

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Marka izleme profili oluşturuldu.')),
      );
    } on FirebaseException catch (error) {
      if (!mounted) {
        return;
      }

      final message = error.code == 'permission-denied'
          ? 'Bu profil kaydı için yetkiniz bulunmuyor.'
          : 'İzleme profili kaydedilemedi.';

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('İzleme profili kaydedilemedi.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Yeni Marka İzleme Profili'),
      content: SizedBox(
        width: 720,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _responsiveFields(
                  first: TextFormField(
                    controller: _profileNameController,
                    decoration: const InputDecoration(
                      labelText: 'Profil adı',
                      hintText: 'Örnek: Kozmetik Ana İzleme',
                      prefixIcon: Icon(Icons.manage_search_outlined),
                    ),
                    validator: (value) =>
                        _requiredValidator(value, 'Profil adını girin.'),
                  ),
                  second: TextFormField(
                    controller: _brandNameController,
                    decoration: const InputDecoration(
                      labelText: 'Marka adı',
                      hintText: 'Korunacak marka',
                      prefixIcon: Icon(Icons.verified_outlined),
                    ),
                    validator: (value) =>
                        _requiredValidator(value, 'Marka adını girin.'),
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _categoriesController,
                  decoration: const InputDecoration(
                    labelText: 'Ürün kategorileri',
                    hintText: 'Kozmetik, kişisel bakım, parfüm',
                    prefixIcon: Icon(Icons.category_outlined),
                    helperText: 'Birden fazla değeri virgülle ayırın.',
                  ),
                  validator: (value) =>
                      _requiredValidator(value, 'En az bir kategori girin.'),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _includeKeywordsController,
                  decoration: const InputDecoration(
                    labelText: 'İzlenecek anahtar kelimeler',
                    hintText: 'marka adı, ürün adı, seri adı',
                    prefixIcon: Icon(Icons.key_outlined),
                    helperText: 'Birden fazla değeri virgülle ayırın.',
                  ),
                  validator: (value) => _requiredValidator(
                    value,
                    'En az bir anahtar kelime girin.',
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _excludeKeywordsController,
                  decoration: const InputDecoration(
                    labelText: 'Hariç tutulacak kelimeler',
                    hintText: 'ikinci el, boş kutu, aksesuar',
                    prefixIcon: Icon(Icons.remove_circle_outline),
                    helperText: 'İsteğe bağlıdır; değerleri virgülle ayırın.',
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _regionsController,
                  decoration: const InputDecoration(
                    labelText: 'Hedef bölgeler',
                    hintText: 'Türkiye, İstanbul, Ankara',
                    prefixIcon: Icon(Icons.location_on_outlined),
                    helperText: 'Birden fazla değeri virgülle ayırın.',
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Risk Türleri',
                  style: TextStyle(
                    color: MarkaKalkanTheme.navy,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: _riskOptions.entries.map((entry) {
                    final selected = _selectedRiskTypes.contains(entry.key);

                    return FilterChip(
                      selected: selected,
                      label: Text(entry.value),
                      onSelected: (value) {
                        setState(() {
                          if (value) {
                            _selectedRiskTypes.add(entry.key);
                          } else {
                            _selectedRiskTypes.remove(entry.key);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
                _responsiveFields(
                  first: TextFormField(
                    controller: _minimumPriceController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]')),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Alt fiyat',
                      suffixText: '₺',
                      prefixIcon: Icon(Icons.trending_down_outlined),
                    ),
                  ),
                  second: TextFormField(
                    controller: _maximumPriceController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]')),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Üst fiyat',
                      suffixText: '₺',
                      prefixIcon: Icon(Icons.trending_up_outlined),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _responsiveFields(
                  first: DropdownButtonFormField<MonitoringPriority>(
                    initialValue: _priority,
                    decoration: const InputDecoration(
                      labelText: 'İzleme önceliği',
                      prefixIcon: Icon(Icons.flag_outlined),
                    ),
                    items: MonitoringPriority.values
                        .map(
                          (priority) => DropdownMenuItem(
                            value: priority,
                            child: Text(_priorityLabel(priority)),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }

                      setState(() {
                        _priority = value;
                      });
                    },
                  ),
                  second: DropdownButtonFormField<MonitoringRecordStatus>(
                    initialValue: _status,
                    decoration: const InputDecoration(
                      labelText: 'Başlangıç durumu',
                      prefixIcon: Icon(Icons.toggle_on_outlined),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: MonitoringRecordStatus.active,
                        child: Text('Aktif'),
                      ),
                      DropdownMenuItem(
                        value: MonitoringRecordStatus.paused,
                        child: Text('Duraklatılmış'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }

                      setState(() {
                        _status = value;
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting
              ? null
              : () {
                  Navigator.of(context).pop();
                },
          child: const Text('Vazgeç'),
        ),
        FilledButton.icon(
          onPressed: _isSubmitting ? null : _submit,
          icon: _isSubmitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_outlined),
          label: Text(_isSubmitting ? 'Kaydediliyor' : 'Profili Kaydet'),
        ),
      ],
    );
  }

  Widget _responsiveFields({required Widget first, required Widget second}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 560) {
          return Column(children: [first, const SizedBox(height: 14), second]);
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: first),
            const SizedBox(width: 14),
            Expanded(child: second),
          ],
        );
      },
    );
  }

  static String? _requiredValidator(String? value, String message) {
    if ((value?.trim() ?? '').isEmpty) {
      return message;
    }

    return null;
  }

  static List<String> _splitValues(String value) {
    return value
        .split(RegExp(r'[,;\n]'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList(growable: false);
  }

  static double? _parsePrice(String value) {
    final cleaned = value.trim().replaceAll(',', '.');

    if (cleaned.isEmpty) {
      return null;
    }

    return double.tryParse(cleaned);
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.profileCount});

  final int profileCount;

  @override
  Widget build(BuildContext context) {
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
      child: Row(
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: const Color(0xFF25576B),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.manage_search_outlined,
              color: MarkaKalkanTheme.teal,
              size: 38,
            ),
          ),
          const SizedBox(width: 22),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Marka İzleme Kapsamı',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 27,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  '$profileCount izleme profili kayıtlı. '
                  'Marka, kategori, anahtar kelime, bölge ve risk önceliklerini yönetin.',
                  style: const TextStyle(color: Color(0xFFD9E5EA), height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.profile,
    required this.onToggleStatus,
    required this.onDelete,
  });

  final BrandMonitoringProfileModel profile;
  final VoidCallback onToggleStatus;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final active = profile.status == MonitoringRecordStatus.active;

    return Container(
      constraints: const BoxConstraints(minHeight: 320),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: active ? MarkaKalkanTheme.teal : const Color(0xFFE0E7EC),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F6F4),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.shield_outlined,
                  color: MarkaKalkanTheme.teal,
                ),
              ),
              const Spacer(),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'toggle') {
                    onToggleStatus();
                  } else if (value == 'delete') {
                    onDelete();
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'toggle',
                    child: Text(
                      active ? 'Profili duraklat' : 'Profili etkinleştir',
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('Profili sil'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            profile.profileName,
            style: const TextStyle(
              color: MarkaKalkanTheme.navy,
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            profile.brandName,
            style: const TextStyle(
              color: MarkaKalkanTheme.blue,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 15),
          _ProfileInfoLine(
            icon: Icons.category_outlined,
            text: profile.categories.isEmpty
                ? 'Kategori belirtilmedi'
                : profile.categories.join(', '),
          ),
          const SizedBox(height: 9),
          _ProfileInfoLine(
            icon: Icons.key_outlined,
            text: profile.includeKeywords.isEmpty
                ? 'Anahtar kelime belirtilmedi'
                : profile.includeKeywords.join(', '),
          ),
          const SizedBox(height: 9),
          _ProfileInfoLine(
            icon: Icons.location_on_outlined,
            text: profile.targetRegions.isEmpty
                ? 'Tüm bölgeler'
                : profile.targetRegions.join(', '),
          ),
          const SizedBox(height: 24),
          const Divider(height: 28),
          Row(
            children: [
              _StatusBadge(
                label: active
                    ? 'Aktif'
                    : profile.status == MonitoringRecordStatus.paused
                    ? 'Duraklatıldı'
                    : 'Arşivlendi',
                active: active,
              ),
              const Spacer(),
              Text(
                _priorityLabel(profile.priority),
                style: const TextStyle(
                  color: Color(0xFF687580),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProfileInfoLine extends StatelessWidget {
  const _ProfileInfoLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: MarkaKalkanTheme.teal),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xFF687580), height: 1.35),
          ),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.active});

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: active ? const Color(0xFFE8F6F4) : const Color(0xFFF2F4F6),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: active ? MarkaKalkanTheme.teal : const Color(0xFF687580),
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _EmptyProfilesView extends StatelessWidget {
  const _EmptyProfilesView({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(42),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE0E7EC)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.manage_search_outlined,
            size: 58,
            color: MarkaKalkanTheme.teal,
          ),
          const SizedBox(height: 16),
          const Text(
            'Henüz izleme profili yok',
            style: TextStyle(
              color: MarkaKalkanTheme.navy,
              fontSize: 21,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'İlk marka izleme kapsamınızı oluşturarak başlayın.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF687580)),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add),
            label: const Text('İlk Profili Oluştur'),
          ),
        ],
      ),
    );
  }
}

class _SignedOutView extends StatelessWidget {
  const _SignedOutView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Marka izleme profillerini görüntülemek için giriş yapın.',
        style: TextStyle(
          color: MarkaKalkanTheme.navy,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFFB42318),
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

String _priorityLabel(MonitoringPriority priority) {
  switch (priority) {
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

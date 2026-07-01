import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:markakalkan/core/theme/markakalkan_theme.dart';
import 'package:markakalkan/features/production_batches/data/production_batch_service.dart';
import 'package:markakalkan/features/products/data/product_service.dart';

class ProductionBatchesPage extends StatelessWidget {
  ProductionBatchesPage({super.key});

  final ProductionBatchService _batchService = ProductionBatchService();
  final ProductService _productService = ProductService();

  void _openCreateDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => _CreateProductionBatchDialog(
        batchService: _batchService,
        productService: _productService,
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
          'Üretim Partileri',
          style: TextStyle(
            color: MarkaKalkanTheme.navy,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: FilledButton.icon(
              onPressed: () => _openCreateDialog(context),
              icon: const Icon(Icons.add),
              label: const Text('Yeni Parti'),
            ),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _batchService.watchBatches(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const _MessageState(
              icon: Icons.error_outline,
              title: 'Üretim partileri yüklenemedi',
              description:
                  'Veriler alınırken bir sorun oluştu. Lütfen yeniden deneyin.',
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final batches = snapshot.data?.docs ?? [];

          if (batches.isEmpty) {
            return _MessageState(
              icon: Icons.factory_outlined,
              title: 'Henüz üretim partisi yok',
              description:
                  'İlk üretim, ithalat veya fason üretim partinizi oluşturun.',
              actionLabel: 'İlk Partiyi Ekle',
              onAction: () => _openCreateDialog(context),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(24),
            itemCount: batches.length,
            separatorBuilder: (_, _) => const SizedBox(height: 14),
            itemBuilder: (context, index) {
              final data = batches[index].data();

              final productName =
                  data['productName'] as String? ?? 'İsimsiz ürün';
              final batchNumber =
                  data['batchNumber'] as String? ?? 'Parti numarası yok';
              final productionType = data['productionType'] as String? ?? '';
              final authorizedQuantity =
                  data['authorizedQuantity'] as int? ?? 0;
              final defectQuantity = data['defectQuantity'] as int? ?? 0;
              final shippedQuantity = data['shippedQuantity'] as int? ?? 0;
              final status = data['status'] as String? ?? 'planned';
              final notes = data['notes'] as String? ?? '';
              final productionTimestamp = data['productionDate'] as Timestamp?;

              final productionDate = productionTimestamp?.toDate();

              return _ProductionBatchCard(
                productName: productName,
                batchNumber: batchNumber,
                productionType: productionType,
                authorizedQuantity: authorizedQuantity,
                defectQuantity: defectQuantity,
                shippedQuantity: shippedQuantity,
                status: status,
                notes: notes,
                productionDate: productionDate,
              );
            },
          );
        },
      ),
    );
  }
}

class _CreateProductionBatchDialog extends StatefulWidget {
  final ProductionBatchService batchService;
  final ProductService productService;

  const _CreateProductionBatchDialog({
    required this.batchService,
    required this.productService,
  });

  @override
  State<_CreateProductionBatchDialog> createState() =>
      _CreateProductionBatchDialogState();
}

class _CreateProductionBatchDialogState
    extends State<_CreateProductionBatchDialog> {
  final _formKey = GlobalKey<FormState>();

  final _batchNumberController = TextEditingController();
  final _authorizedQuantityController = TextEditingController();
  final _defectQuantityController = TextEditingController(text: '0');
  final _shippedQuantityController = TextEditingController(text: '0');
  final _notesController = TextEditingController();

  String? _selectedProductId;
  String? _selectedProductName;
  String _productionType = 'Kendi üretim';
  String _status = 'planned';
  DateTime _productionDate = DateTime.now();
  bool _isSubmitting = false;

  static const List<String> _productionTypes = [
    'Kendi üretim',
    'Fason üretim',
    'İthalat',
  ];

  static const Map<String, String> _statuses = {
    'planned': 'Planlandı',
    'in_production': 'Üretimde',
    'completed': 'Tamamlandı',
    'cancelled': 'İptal edildi',
  };

  @override
  void dispose() {
    _batchNumberController.dispose();
    _authorizedQuantityController.dispose();
    _defectQuantityController.dispose();
    _shippedQuantityController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  int? _parseInteger(String value) {
    return int.tryParse(value.trim());
  }

  String? _requiredValidator(String? value, String message) {
    if ((value?.trim() ?? '').isEmpty) {
      return message;
    }

    return null;
  }

  String? _positiveIntegerValidator(String? value, String fieldName) {
    final number = _parseInteger(value ?? '');

    if (number == null || number <= 0) {
      return '$fieldName sıfırdan büyük olmalıdır.';
    }

    return null;
  }

  String? _nonNegativeIntegerValidator(String? value, String fieldName) {
    final number = _parseInteger(value ?? '');

    if (number == null || number < 0) {
      return '$fieldName negatif olamaz.';
    }

    return null;
  }

  Future<void> _selectProductionDate() async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: _productionDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );

    if (selectedDate == null || !mounted) {
      return;
    }

    setState(() {
      _productionDate = selectedDate;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedProductId == null || _selectedProductName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Üretim partisinin bağlı olduğu ürünü seçin.'),
        ),
      );
      return;
    }

    final authorizedQuantity = _parseInteger(
      _authorizedQuantityController.text,
    )!;
    final defectQuantity = _parseInteger(_defectQuantityController.text)!;
    final shippedQuantity = _parseInteger(_shippedQuantityController.text)!;

    if (defectQuantity + shippedQuantity > authorizedQuantity) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Fire ve sevk miktarı toplamı yetkili üretim adedini aşamaz.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await widget.batchService.createBatch(
        productId: _selectedProductId!,
        productName: _selectedProductName!,
        batchNumber: _batchNumberController.text,
        productionType: _productionType,
        authorizedQuantity: authorizedQuantity,
        defectQuantity: defectQuantity,
        shippedQuantity: shippedQuantity,
        productionDate: _productionDate,
        notes: _notesController.text,
        status: _status,
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Üretim partisi başarıyla oluşturuldu.')),
      );
    } on FirebaseException catch (error) {
      if (!mounted) {
        return;
      }

      final message = error.code == 'permission-denied'
          ? 'Bu üretim partisini kaydetmek için yetkiniz bulunmuyor.'
          : 'Üretim partisi kaydedilemedi. Lütfen yeniden deneyin.';

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Beklenmeyen bir hata oluştu.')),
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
      title: const Text('Yeni Üretim Partisi'),
      content: SizedBox(
        width: 620,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: widget.productService.watchProducts(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return const Text(
                        'Ürün listesi yüklenemedi.',
                        style: TextStyle(color: Colors.red),
                      );
                    }

                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const LinearProgressIndicator();
                    }

                    final products = snapshot.data?.docs ?? [];

                    if (products.isEmpty) {
                      return const Text(
                        'Önce Ürünler modülünden en az bir ürün eklemelisiniz.',
                        style: TextStyle(
                          color: Color(0xFF687580),
                          fontWeight: FontWeight.w600,
                        ),
                      );
                    }

                    return DropdownButtonFormField<String>(
                      initialValue: _selectedProductId,
                      decoration: const InputDecoration(
                        labelText: 'Bağlı ürün',
                        prefixIcon: Icon(Icons.inventory_2_outlined),
                      ),
                      items: products.map((document) {
                        final data = document.data();
                        final name = data['name'] as String? ?? 'İsimsiz ürün';
                        final sku = data['sku'] as String? ?? '';

                        return DropdownMenuItem<String>(
                          value: document.id,
                          child: Text(sku.isEmpty ? name : '$name — $sku'),
                        );
                      }).toList(),
                      onChanged: (value) {
                        final selectedDocument = products
                            .where((document) => document.id == value)
                            .firstOrNull;

                        setState(() {
                          _selectedProductId = value;
                          _selectedProductName =
                              selectedDocument?.data()['name'] as String?;
                        });
                      },
                      validator: (value) {
                        if (value == null) {
                          return 'Bağlı ürünü seçin.';
                        }

                        return null;
                      },
                    );
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _batchNumberController,
                  decoration: const InputDecoration(
                    labelText: 'Parti numarası',
                    hintText: 'Örnek: DJR-2026-001',
                    prefixIcon: Icon(Icons.tag_outlined),
                  ),
                  validator: (value) =>
                      _requiredValidator(value, 'Parti numarasını girin.'),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: _productionType,
                  decoration: const InputDecoration(
                    labelText: 'Üretim türü',
                    prefixIcon: Icon(Icons.factory_outlined),
                  ),
                  items: _productionTypes
                      .map(
                        (item) => DropdownMenuItem<String>(
                          value: item,
                          child: Text(item),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }

                    setState(() {
                      _productionType = value;
                    });
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _authorizedQuantityController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Yetkili üretim adedi',
                    prefixIcon: Icon(Icons.numbers_outlined),
                  ),
                  validator: (value) =>
                      _positiveIntegerValidator(value, 'Yetkili üretim adedi'),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _defectQuantityController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Fire adedi',
                          prefixIcon: Icon(Icons.remove_circle_outline),
                        ),
                        validator: (value) =>
                            _nonNegativeIntegerValidator(value, 'Fire adedi'),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: TextFormField(
                        controller: _shippedQuantityController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Sevk edilen adet',
                          prefixIcon: Icon(Icons.local_shipping_outlined),
                        ),
                        validator: (value) => _nonNegativeIntegerValidator(
                          value,
                          'Sevk edilen adet',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: _selectProductionDate,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Üretim tarihi',
                      prefixIcon: Icon(Icons.calendar_month_outlined),
                    ),
                    child: Text(
                      '${_productionDate.day.toString().padLeft(2, '0')}.'
                      '${_productionDate.month.toString().padLeft(2, '0')}.'
                      '${_productionDate.year}',
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: _status,
                  decoration: const InputDecoration(
                    labelText: 'Parti durumu',
                    prefixIcon: Icon(Icons.flag_outlined),
                  ),
                  items: _statuses.entries
                      .map(
                        (entry) => DropdownMenuItem<String>(
                          value: entry.key,
                          child: Text(entry.value),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }

                    setState(() {
                      _status = value;
                    });
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _notesController,
                  minLines: 3,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'Parti notları',
                    alignLabelWithHint: true,
                    prefixIcon: Icon(Icons.description_outlined),
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
          label: Text(_isSubmitting ? 'Kaydediliyor...' : 'Partiyi Kaydet'),
        ),
      ],
    );
  }
}

class _ProductionBatchCard extends StatelessWidget {
  final String productName;
  final String batchNumber;
  final String productionType;
  final int authorizedQuantity;
  final int defectQuantity;
  final int shippedQuantity;
  final String status;
  final String notes;
  final DateTime? productionDate;

  const _ProductionBatchCard({
    required this.productName,
    required this.batchNumber,
    required this.productionType,
    required this.authorizedQuantity,
    required this.defectQuantity,
    required this.shippedQuantity,
    required this.status,
    required this.notes,
    required this.productionDate,
  });

  String get _statusLabel {
    return switch (status) {
      'planned' => 'Planlandı',
      'in_production' => 'Üretimde',
      'completed' => 'Tamamlandı',
      'cancelled' => 'İptal edildi',
      _ => status,
    };
  }

  @override
  Widget build(BuildContext context) {
    final remaining = authorizedQuantity - defectQuantity - shippedQuantity;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE0E7EC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                batchNumber,
                style: const TextStyle(
                  color: MarkaKalkanTheme.navy,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              _StatusBadge(label: _statusLabel),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '$productName • $productionType',
            style: const TextStyle(
              color: MarkaKalkanTheme.blue,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (productionDate != null) ...[
            const SizedBox(height: 8),
            Text(
              'Üretim tarihi: '
              '${productionDate!.day.toString().padLeft(2, '0')}.'
              '${productionDate!.month.toString().padLeft(2, '0')}.'
              '${productionDate!.year}',
              style: const TextStyle(color: Color(0xFF687580)),
            ),
          ],
          const SizedBox(height: 18),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _QuantityItem(label: 'Yetkili', value: authorizedQuantity),
              _QuantityItem(label: 'Fire', value: defectQuantity),
              _QuantityItem(label: 'Sevk', value: shippedQuantity),
              _QuantityItem(label: 'Kalan', value: remaining),
            ],
          ),
          if (notes.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              notes,
              style: const TextStyle(color: Color(0xFF687580), height: 1.45),
            ),
          ],
        ],
      ),
    );
  }
}

class _QuantityItem extends StatelessWidget {
  final String label;
  final int value;

  const _QuantityItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 110),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F7F8),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: Color(0xFF687580), fontSize: 12),
          ),
          const SizedBox(height: 3),
          Text(
            value.toString(),
            style: const TextStyle(
              color: MarkaKalkanTheme.navy,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;

  const _StatusBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F6F4),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: MarkaKalkanTheme.teal,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _MessageState({
    required this.icon,
    required this.title,
    required this.description,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 64, color: MarkaKalkanTheme.teal),
              const SizedBox(height: 18),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: MarkaKalkanTheme.navy,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                description,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF687580), height: 1.5),
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 22),
                FilledButton.icon(
                  onPressed: onAction,
                  icon: const Icon(Icons.add),
                  label: Text(actionLabel!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

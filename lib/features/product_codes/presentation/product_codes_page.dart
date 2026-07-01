import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:markakalkan/core/theme/markakalkan_theme.dart';
import 'package:markakalkan/features/product_codes/data/product_code_service.dart';
import 'package:markakalkan/features/production_batches/data/production_batch_service.dart';
import 'package:markakalkan/features/products/data/product_service.dart';

class ProductCodesPage extends StatelessWidget {
  ProductCodesPage({super.key});

  final ProductCodeService _codeService = ProductCodeService();
  final ProductService _productService = ProductService();
  final ProductionBatchService _batchService = ProductionBatchService();

  void _openCreateDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => _CreateProductCodeDialog(
        codeService: _codeService,
        productService: _productService,
        batchService: _batchService,
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
          'Tekil Kodlar',
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
              label: const Text('Yeni Kod'),
            ),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _codeService.watchOwnCodes(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const _MessageState(
              icon: Icons.error_outline,
              title: 'Tekil kodlar yüklenemedi',
              description:
                  'Veriler alınırken bir sorun oluştu. Lütfen yeniden deneyin.',
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final codes = snapshot.data?.docs ?? [];

          if (codes.isEmpty) {
            return _MessageState(
              icon: Icons.qr_code_2_outlined,
              title: 'Henüz tekil kod oluşturulmadı',
              description:
                  'Bir ürün ve üretim partisi seçerek ilk tekil kodunuzu oluşturun.',
              actionLabel: 'İlk Kodu Oluştur',
              onAction: () => _openCreateDialog(context),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(24),
            itemCount: codes.length,
            separatorBuilder: (_, _) => const SizedBox(height: 14),
            itemBuilder: (context, index) {
              final data = codes[index].data();

              return _ProductCodeCard(
                publicCode: data['publicCode'] as String? ?? codes[index].id,
                brandName: data['brandName'] as String? ?? '',
                productName: data['productName'] as String? ?? '',
                batchNumber: data['batchNumber'] as String? ?? '',
                status: data['status'] as String? ?? 'active',
                scanCount: data['scanCount'] as int? ?? 0,
              );
            },
          );
        },
      ),
    );
  }
}

class _CreateProductCodeDialog extends StatefulWidget {
  final ProductCodeService codeService;
  final ProductService productService;
  final ProductionBatchService batchService;

  const _CreateProductCodeDialog({
    required this.codeService,
    required this.productService,
    required this.batchService,
  });

  @override
  State<_CreateProductCodeDialog> createState() =>
      _CreateProductCodeDialogState();
}

class _CreateProductCodeDialogState extends State<_CreateProductCodeDialog> {
  String? _selectedProductId;
  String? _selectedProductName;
  String? _selectedBrandName;

  String? _selectedBatchId;
  String? _selectedBatchNumber;

  bool _isSubmitting = false;

  Future<void> _submit() async {
    if (_selectedProductId == null ||
        _selectedProductName == null ||
        _selectedBrandName == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Önce ürünü seçin.')));
      return;
    }

    if (_selectedBatchId == null || _selectedBatchNumber == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Üretim partisini seçin.')));
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final publicCode = await widget.codeService.createCode(
        brandName: _selectedBrandName!,
        productId: _selectedProductId!,
        productName: _selectedProductName!,
        batchId: _selectedBatchId!,
        batchNumber: _selectedBatchNumber!,
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Tekil kod oluşturuldu: $publicCode')),
      );
    } on FirebaseException catch (error) {
      if (!mounted) {
        return;
      }

      final message = error.code == 'permission-denied'
          ? 'Bu tekil kodu oluşturmak için yetkiniz bulunmuyor.'
          : 'Tekil kod oluşturulamadı. Lütfen yeniden deneyin.';

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
      title: const Text('Yeni Tekil Kod Oluştur'),
      content: SizedBox(
        width: 580,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: widget.productService.watchProducts(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Text(
                    'Ürünler yüklenemedi.',
                    style: TextStyle(color: Colors.red),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const LinearProgressIndicator();
                }

                final products = snapshot.data?.docs ?? [];

                if (products.isEmpty) {
                  return const Text(
                    'Önce Ürünler modülünden bir ürün eklemelisiniz.',
                    style: TextStyle(
                      color: Color(0xFF687580),
                      fontWeight: FontWeight.w600,
                    ),
                  );
                }

                return DropdownButtonFormField<String>(
                  initialValue: _selectedProductId,
                  decoration: const InputDecoration(
                    labelText: 'Ürün',
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
                    QueryDocumentSnapshot<Map<String, dynamic>>?
                    selectedDocument;

                    for (final document in products) {
                      if (document.id == value) {
                        selectedDocument = document;
                        break;
                      }
                    }

                    final data = selectedDocument?.data();

                    setState(() {
                      _selectedProductId = value;
                      _selectedProductName = data?['name'] as String?;
                      _selectedBrandName = data?['brandName'] as String?;
                      _selectedBatchId = null;
                      _selectedBatchNumber = null;
                    });
                  },
                );
              },
            ),
            const SizedBox(height: 16),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: widget.batchService.watchBatches(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Text(
                    'Üretim partileri yüklenemedi.',
                    style: TextStyle(color: Colors.red),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const LinearProgressIndicator();
                }

                final allBatches = snapshot.data?.docs ?? [];
                final filteredBatches = allBatches.where((document) {
                  final data = document.data();

                  return data['productId'] == _selectedProductId;
                }).toList();

                return DropdownButtonFormField<String>(
                  initialValue: _selectedBatchId,
                  decoration: const InputDecoration(
                    labelText: 'Üretim partisi',
                    prefixIcon: Icon(Icons.factory_outlined),
                  ),
                  items: filteredBatches.map((document) {
                    final data = document.data();
                    final batchNumber =
                        data['batchNumber'] as String? ?? 'Parti';

                    return DropdownMenuItem<String>(
                      value: document.id,
                      child: Text(batchNumber),
                    );
                  }).toList(),
                  onChanged: _selectedProductId == null
                      ? null
                      : (value) {
                          QueryDocumentSnapshot<Map<String, dynamic>>?
                          selectedDocument;

                          for (final document in filteredBatches) {
                            if (document.id == value) {
                              selectedDocument = document;
                              break;
                            }
                          }

                          setState(() {
                            _selectedBatchId = value;
                            _selectedBatchNumber =
                                selectedDocument?.data()['batchNumber']
                                    as String?;
                          });
                        },
                );
              },
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F7F8),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: MarkaKalkanTheme.blue),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Kod tahmin edilmesi zor biçimde otomatik oluşturulur. '
                      'Her fiziksel ürün için ayrı bir kod üretilmelidir.',
                      style: TextStyle(color: Color(0xFF687580), height: 1.45),
                    ),
                  ),
                ],
              ),
            ),
          ],
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
              : const Icon(Icons.qr_code_2_outlined),
          label: Text(
            _isSubmitting ? 'Oluşturuluyor...' : 'Tekil Kodu Oluştur',
          ),
        ),
      ],
    );
  }
}

class _ProductCodeCard extends StatelessWidget {
  final String publicCode;
  final String brandName;
  final String productName;
  final String batchNumber;
  final String status;
  final int scanCount;

  const _ProductCodeCard({
    required this.publicCode,
    required this.brandName,
    required this.productName,
    required this.batchNumber,
    required this.status,
    required this.scanCount,
  });

  String get _statusLabel {
    return switch (status) {
      'active' => 'Aktif',
      'blocked' => 'Engellendi',
      'revoked' => 'İptal edildi',
      _ => status,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE0E7EC)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F6F4),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.qr_code_2_outlined,
              color: MarkaKalkanTheme.teal,
              size: 32,
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SelectableText(
                      publicCode,
                      style: const TextStyle(
                        color: MarkaKalkanTheme.navy,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                    _StatusBadge(label: _statusLabel),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '$brandName • $productName • Parti: $batchNumber',
                  style: const TextStyle(
                    color: MarkaKalkanTheme.blue,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Tarama sayısı: $scanCount',
                  style: const TextStyle(color: Color(0xFF687580)),
                ),
              ],
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

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:markakalkan/core/theme/markakalkan_theme.dart';
import 'package:markakalkan/features/verification/data/product_verification_service.dart';

class ProductVerificationPage extends StatefulWidget {
  const ProductVerificationPage({super.key});

  @override
  State<ProductVerificationPage> createState() =>
      _ProductVerificationPageState();
}

class _ProductVerificationPageState extends State<ProductVerificationPage> {
  final _formKey = GlobalKey<FormState>();
  final _productCodeController = TextEditingController();
  final _secretPinController = TextEditingController();
  final ProductVerificationService _verificationService =
      ProductVerificationService();

  ProductVerificationResult? _verificationResult;
  String? _verificationError;
  bool _isVerifying = false;
  bool _showPinField = false;

  @override
  void dispose() {
    _productCodeController.dispose();
    _secretPinController.dispose();
    super.dispose();
  }

  Future<void> _verifyProduct() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isVerifying = true;
      _verificationResult = null;
      _verificationError = null;
    });

    try {
      final result = await _verificationService.verifyCode(
        _productCodeController.text,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _verificationResult = result;
      });

      if (_showPinField) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Tekil kod sorgulandı. Gizli PIN doğrulaması sonraki aşamada etkinleştirilecektir.',
            ),
          ),
        );
      }
    } on FirebaseException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _verificationError = error.code == 'permission-denied'
            ? 'Marka Dedektifi bu kod kaydına erişemedi.'
            : 'Kod sorgulanırken bağlantı hatası oluştu.';
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _verificationError =
            'Beklenmeyen bir hata oluştu. Lütfen yeniden deneyin.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isVerifying = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MarkaKalkanTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text(
          'Marka Dedektifi',
          style: TextStyle(
            color: MarkaKalkanTheme.navy,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFE0E7EC)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x14000000),
                    blurRadius: 28,
                    offset: Offset(0, 12),
                  ),
                ],
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F6F4),
                        borderRadius: BorderRadius.circular(19),
                      ),
                      child: const Icon(
                        Icons.qr_code_scanner,
                        color: MarkaKalkanTheme.teal,
                        size: 38,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Marka Dedektifi ile ürünü inceleyin',
                      style: TextStyle(
                        color: MarkaKalkanTheme.navy,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Ambalaj üzerindeki QR kodunu okutun veya tekil ürün '
                      'kodunu girerek MarkaKalkan kayıtlarıyla eşleşmesini inceleyin.',
                      style: TextStyle(color: Color(0xFF687580), height: 1.5),
                    ),
                    const SizedBox(height: 28),
                    OutlinedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Kamera ile QR tarama sonraki aşamada eklenecektir.',
                            ),
                          ),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 17),
                      ),
                      icon: const Icon(Icons.camera_alt_outlined),
                      label: const Text('Kamera ile QR Tara'),
                    ),
                    const SizedBox(height: 18),
                    const Row(
                      children: [
                        Expanded(child: Divider()),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            'veya',
                            style: TextStyle(color: Color(0xFF8A959D)),
                          ),
                        ),
                        Expanded(child: Divider()),
                      ],
                    ),
                    const SizedBox(height: 18),
                    TextFormField(
                      controller: _productCodeController,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        labelText: 'Tekil ürün kodu',
                        hintText: 'Örnek: MK-8F7K-2Q9X',
                        prefixIcon: Icon(Icons.fingerprint),
                      ),
                      validator: (value) {
                        if ((value?.trim() ?? '').isEmpty) {
                          return 'Tekil ürün kodunu girin.';
                        }

                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: _showPinField,
                      title: const Text(
                        'Üründe gizli doğrulama PIN’i var',
                        style: TextStyle(
                          color: MarkaKalkanTheme.navy,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: const Text(
                        'Kazınabilir veya ambalaj içindeki kodu girin.',
                      ),
                      onChanged: (value) {
                        setState(() {
                          _showPinField = value;

                          if (!value) {
                            _secretPinController.clear();
                          }
                        });
                      },
                    ),
                    if (_showPinField) ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _secretPinController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Gizli doğrulama PIN’i',
                          prefixIcon: Icon(Icons.password_outlined),
                        ),
                        validator: (value) {
                          if (_showPinField && (value?.trim() ?? '').isEmpty) {
                            return 'Gizli doğrulama PIN’ini girin.';
                          }

                          return null;
                        },
                      ),
                    ],
                    const SizedBox(height: 22),
                    FilledButton.icon(
                      onPressed: _isVerifying ? null : _verifyProduct,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 17),
                      ),
                      icon: _isVerifying
                          ? const SizedBox(
                              width: 19,
                              height: 19,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.verified_outlined),
                      label: Text(
                        _isVerifying ? 'İnceleniyor...' : 'Ürünü İncele',
                      ),
                    ),
                    if (_verificationError != null) ...[
                      const SizedBox(height: 18),
                      _VerificationMessageCard(
                        icon: Icons.error_outline,
                        title: 'Sorgulama yapılamadı',
                        description: _verificationError!,
                        backgroundColor: const Color(0xFFFFF1F0),
                        foregroundColor: const Color(0xFFB42318),
                      ),
                    ],

                    if (_verificationResult != null) ...[
                      const SizedBox(height: 18),
                      _VerificationResultCard(result: _verificationResult!),
                    ],
                    const SizedBox(height: 22),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F7F8),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: MarkaKalkanTheme.blue,
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Marka Dedektifi, ürün üzerindeki tekil kodun doğrulanmış '
                              'marka kayıtlarıyla eşleşip eşleşmediğini ve şüpheli '
                              'tarama işaretleri bulunup bulunmadığını gösterecektir.',
                              style: TextStyle(
                                color: Color(0xFF687580),
                                height: 1.45,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _VerificationResultCard extends StatelessWidget {
  final ProductVerificationResult result;

  const _VerificationResultCard({required this.result});

  @override
  Widget build(BuildContext context) {
    if (!result.found) {
      return const _VerificationMessageCard(
        icon: Icons.search_off_outlined,
        title: 'Kod bulunamadı',
        description:
            'Bu tekil ürün kodu MarkaKalkan kayıtlarında bulunamadı. '
            'Kodu kontrol edin veya ürünü satın aldığınız satıcıdan bilgi isteyin.',
        backgroundColor: Color(0xFFFFF7E8),
        foregroundColor: Color(0xFF9A6700),
      );
    }

    if (result.isBlocked) {
      return _VerificationMessageCard(
        icon: Icons.block_outlined,
        title: 'Kod engellenmiş',
        description:
            '${result.brandName ?? 'Marka'} tarafından bu kod engellenmiştir. '
            'Ürünle ilgili ek doğrulama yapılması önerilir.',
        backgroundColor: const Color(0xFFFFF1F0),
        foregroundColor: const Color(0xFFB42318),
      );
    }

    if (result.isRevoked) {
      return const _VerificationMessageCard(
        icon: Icons.cancel_outlined,
        title: 'Kod iptal edilmiş',
        description:
            'Bu tekil ürün kodu marka tarafından iptal edilmiştir. '
            'Ürünü kullanmadan veya satın almadan önce marka ile iletişime geçin.',
        backgroundColor: Color(0xFFFFF1F0),
        foregroundColor: Color(0xFFB42318),
      );
    }

    if (!result.isActive) {
      return const _VerificationMessageCard(
        icon: Icons.help_outline,
        title: 'Ek doğrulama gerekli',
        description:
            'Kod bulundu ancak güncel durumu kesin olarak belirlenemedi.',
        backgroundColor: Color(0xFFFFF7E8),
        foregroundColor: Color(0xFF9A6700),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF8F4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF9FD8CA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.verified_user_outlined,
                color: MarkaKalkanTheme.teal,
                size: 30,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Kod marka kaydıyla eşleşti',
                  style: TextStyle(
                    color: MarkaKalkanTheme.navy,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'Bu tekil ürün kodu, doğrulanmış marka kayıtlarıyla eşleşmektedir.',
            style: TextStyle(color: Color(0xFF40515A), height: 1.45),
          ),
          const SizedBox(height: 16),
          _ResultLine(
            label: 'Marka',
            value: result.brandName ?? 'Belirtilmemiş',
          ),
          _ResultLine(
            label: 'Ürün',
            value: result.productName ?? 'Belirtilmemiş',
          ),
          _ResultLine(
            label: 'Üretim partisi',
            value: result.batchNumber ?? 'Belirtilmemiş',
          ),
          _ResultLine(
            label: 'Tekil kod',
            value: result.publicCode ?? 'Belirtilmemiş',
          ),
        ],
      ),
    );
  }
}

class _VerificationMessageCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color backgroundColor;
  final Color foregroundColor;

  const _VerificationMessageCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: foregroundColor.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: foregroundColor, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: foregroundColor,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: const TextStyle(
                    color: Color(0xFF40515A),
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

class _ResultLine extends StatelessWidget {
  final String label;
  final String value;

  const _ResultLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF687580),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: MarkaKalkanTheme.navy,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

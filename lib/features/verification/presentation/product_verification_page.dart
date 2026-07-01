import 'package:flutter/material.dart';
import 'package:markakalkan/core/theme/markakalkan_theme.dart';

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

  bool _showPinField = false;

  @override
  void dispose() {
    _productCodeController.dispose();
    _secretPinController.dispose();
    super.dispose();
  }

  void _verifyProduct() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Ürün doğrulama servisi Firebase bağlantısından sonra aktif olacaktır.',
        ),
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
          'Ürün Doğrula',
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
                      'Ürününüzü kontrol edin',
                      style: TextStyle(
                        color: MarkaKalkanTheme.navy,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Ambalaj üzerindeki QR kodunu okutun veya ürün '
                      'doğrulama kodunu aşağıdaki alana girin.',
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
                        labelText: 'Ürün doğrulama kodu',
                        hintText: 'Örnek: MK-8F7K-2Q9X',
                        prefixIcon: Icon(Icons.fingerprint),
                      ),
                      validator: (value) {
                        if ((value?.trim() ?? '').isEmpty) {
                          return 'Ürün doğrulama kodunu girin.';
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
                      onPressed: _verifyProduct,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 17),
                      ),
                      icon: const Icon(Icons.verified_outlined),
                      label: const Text('Ürünü Doğrula'),
                    ),
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
                              'Doğrulama sonucu, ürün üzerindeki tekil kodun '
                              'doğrulanmış marka kayıtlarıyla eşleşip '
                              'eşleşmediğini gösterecektir.',
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

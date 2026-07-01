import 'package:flutter/material.dart';
import 'package:markakalkan/app/router.dart';
import 'package:markakalkan/core/theme/markakalkan_theme.dart';

class MarkaKalkanHomePage extends StatelessWidget {
  const MarkaKalkanHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SelectionArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _Header()),
            SliverToBoxAdapter(child: _HeroSection()),
            SliverToBoxAdapter(child: _FeatureSection()),
            SliverToBoxAdapter(child: _ProtectionSection()),
            SliverToBoxAdapter(child: _Footer()),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: MarkaKalkanTheme.navy,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.verified_user_outlined,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'MarkaKalkan',
                      style: TextStyle(
                        color: MarkaKalkanTheme.navy,
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'Dijital ürün kimliği ve marka koruma',
                      style: TextStyle(color: Color(0xFF66727D), fontSize: 12),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () {
                  AppRouter.openProductVerification(context);
                },
                child: const Text('Marka Dedektifi'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: () {
                  AppRouter.openBrandLogin(context);
                },
                icon: const Icon(Icons.business_outlined),
                label: const Text('Marka Girişi'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [MarkaKalkanTheme.navy, Color(0xFF183B4E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 72),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 820;

              final introduction = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _HeroLabel(),
                  const SizedBox(height: 22),
                  const Text(
                    'Müşteriniz orijinalini bilsin,\nsiz sahtesini görün.',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 46,
                      height: 1.12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Her ürüne benzersiz dijital kimlik verin. '
                    'Tüketicinin ürünü doğrulamasını sağlayın; '
                    'kopyalanmış kodları, şüpheli taramaları ve '
                    'yetkisiz üretim risklerini tek panelden izleyin.',
                    style: TextStyle(
                      color: Color(0xFFD9E5EA),
                      fontSize: 17,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      FilledButton.icon(
                        onPressed: () {
                          AppRouter.openBrandLogin(context);
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: MarkaKalkanTheme.teal,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 22,
                            vertical: 17,
                          ),
                        ),
                        icon: const Icon(Icons.add_business_outlined),
                        label: const Text('Markanızı Koruyun'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () {
                          AppRouter.openProductVerification(context);
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Color(0xFF92ADB8)),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 22,
                            vertical: 17,
                          ),
                        ),
                        icon: const Icon(Icons.qr_code_scanner),
                        label: const Text('Marka Dedektifi'),
                      ),
                    ],
                  ),
                ],
              );

              const verificationCard = _VerificationCard();

              if (isNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    introduction,
                    const SizedBox(height: 40),
                    verificationCard,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(flex: 6, child: introduction),
                  const SizedBox(width: 52),
                  const Expanded(flex: 4, child: verificationCard),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _HeroLabel extends StatelessWidget {
  const _HeroLabel();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF254D60),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: const Color(0xFF3D6A7E)),
      ),
      child: const Text(
        'HER ÜRÜNE KİMLİK, HER MARKAYA KORUMA',
        style: TextStyle(
          color: Color(0xFFBCE7E3),
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _VerificationCard extends StatefulWidget {
  const _VerificationCard();

  @override
  State<_VerificationCard> createState() => _VerificationCardState();
}

class _VerificationCardState extends State<_VerificationCard> {
  final TextEditingController _productCodeController = TextEditingController();

  @override
  void dispose() {
    _productCodeController.dispose();
    super.dispose();
  }

  Future<void> _scanQrCode() async {
    final scannedCode = await AppRouter.openQrScanner(context);

    if (!mounted || scannedCode == null || scannedCode.trim().isEmpty) {
      return;
    }

    final normalizedCode = scannedCode.trim().toUpperCase();
    _productCodeController.text = normalizedCode;

    await AppRouter.openProductVerification(
      context,
      initialCode: normalizedCode,
      autoVerify: true,
    );
  }

  Future<void> _inspectProduct() async {
    final productCode = _productCodeController.text.trim().toUpperCase();

    if (productCode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Lütfen tekil ürün kodunu girin veya QR kodunu okutun.',
          ),
        ),
      );
      return;
    }

    await AppRouter.openProductVerification(
      context,
      initialCode: productCode,
      autoVerify: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 28,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F6F4),
              borderRadius: BorderRadius.circular(17),
            ),
            child: const Icon(
              Icons.qr_code_scanner,
              color: MarkaKalkanTheme.teal,
              size: 31,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Marka Dedektifi',
            style: TextStyle(
              color: MarkaKalkanTheme.navy,
              fontSize: 23,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'QR kodunu okutun veya tekil ürün kodunu girerek ürünü inceleyin.',
            style: TextStyle(color: Color(0xFF687580), height: 1.45),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _scanQrCode,
            style: FilledButton.styleFrom(
              backgroundColor: MarkaKalkanTheme.teal,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            ),
            icon: const Icon(Icons.camera_alt_outlined),
            label: const Text('Kamerayla QR Tara'),
          ),
          const SizedBox(height: 18),
          const Row(
            children: [
              Expanded(child: Divider()),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'veya',
                  style: TextStyle(
                    color: Color(0xFF8A959D),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(child: Divider()),
            ],
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _productCodeController,
            textCapitalization: TextCapitalization.characters,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _inspectProduct(),
            decoration: const InputDecoration(
              labelText: 'Tekil ürün kodunu girin',
              hintText: 'Örnek: MK-S394-MFC2-DKT6',
              prefixIcon: Icon(Icons.password_outlined),
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: _inspectProduct,
            icon: const Icon(Icons.verified_outlined),
            label: const Text('Ürünü İncele'),
          ),
          const SizedBox(height: 12),
          const Text(
            'Kamera kullanmak istemiyorsanız ürün kodunu elle girebilirsiniz.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF8A959D), fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _FeatureSection extends StatelessWidget {
  final List<_FeatureData> features = const [
    _FeatureData(
      icon: Icons.fingerprint,
      title: 'Tekil ürün kimliği',
      description:
          'Her fiziksel ürün için tahmin edilemeyen benzersiz bir dijital kimlik oluşturun.',
    ),
    _FeatureData(
      icon: Icons.qr_code_2,
      title: 'QR ve gizli PIN',
      description:
          'Açık QR kodunu gizli doğrulama koduyla güçlendirerek kopyalamayı zorlaştırın.',
    ),
    _FeatureData(
      icon: Icons.warning_amber_rounded,
      title: 'Şüpheli tarama alarmı',
      description:
          'Aynı kodun farklı cihaz ve şehirlerde olağan dışı kullanımını takip edin.',
    ),
    _FeatureData(
      icon: Icons.factory_outlined,
      title: 'Yetkili üretim takibi',
      description:
          'Fason üretim emirlerini, yetkili adetleri, fireyi ve sevk miktarlarını kaydedin.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 70),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Column(
            children: [
              const Text(
                'Markanızı üretimden tüketiciye koruyun',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: MarkaKalkanTheme.navy,
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Ürün kimliği, tüketici doğrulaması ve marka koruma verileri tek sistemde.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF687580), fontSize: 16),
              ),
              const SizedBox(height: 38),
              LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;

                  int columns;
                  if (width < 620) {
                    columns = 1;
                  } else if (width < 980) {
                    columns = 2;
                  } else {
                    columns = 4;
                  }

                  final itemWidth = (width - ((columns - 1) * 18)) / columns;

                  return Wrap(
                    spacing: 18,
                    runSpacing: 18,
                    children: features
                        .map(
                          (feature) => SizedBox(
                            width: itemWidth,
                            child: _FeatureCard(feature: feature),
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
  }
}

class _FeatureCard extends StatelessWidget {
  final _FeatureData feature;

  const _FeatureCard({required this.feature});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 230),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: const Color(0xFFE0E7EC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF4F6),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(feature.icon, color: MarkaKalkanTheme.blue),
          ),
          const SizedBox(height: 20),
          Text(
            feature.title,
            style: const TextStyle(
              color: MarkaKalkanTheme.navy,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            feature.description,
            style: const TextStyle(color: Color(0xFF687580), height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _ProtectionSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFE9F0F3),
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 62),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: const Wrap(
            alignment: WrapAlignment.center,
            spacing: 30,
            runSpacing: 24,
            children: [
              _ProtectionItem(
                icon: Icons.inventory_2_outlined,
                title: 'Ürün ve parti',
                subtitle: 'Üretim ve ithalat kayıtları',
              ),
              _ProtectionItem(
                icon: Icons.location_on_outlined,
                title: 'Bölgesel risk',
                subtitle: 'Şüpheli tarama hareketleri',
              ),
              _ProtectionItem(
                icon: Icons.report_outlined,
                title: 'Vaka dosyası',
                subtitle: 'Fotoğraf, fatura ve satıcı kaydı',
              ),
              _ProtectionItem(
                icon: Icons.gavel_outlined,
                title: 'Hukuki sürece destek',
                subtitle: 'Düzenli inceleme ve kanıt verisi',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProtectionItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _ProtectionItem({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 245,
      child: Row(
        children: [
          Icon(icon, color: MarkaKalkanTheme.blue, size: 31),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: MarkaKalkanTheme.navy,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFF687580),
                    fontSize: 12,
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

class _Footer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: MarkaKalkanTheme.navy,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 26),
      child: const Center(
        child: Text(
          'MarkaKalkan • Dijital Ürün Kimliği ve Marka Koruma Platformu',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFFB8C7CF)),
        ),
      ),
    );
  }
}

class _FeatureData {
  final IconData icon;
  final String title;
  final String description;

  const _FeatureData({
    required this.icon,
    required this.title,
    required this.description,
  });
}

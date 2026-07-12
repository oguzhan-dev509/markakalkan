import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:markakalkan/app/router.dart';
import 'package:markakalkan/modules/marka_kalkan/sahte_ikiz_sicili/presentation/counterfeit_twin_report_dialog.dart';
import 'package:markakalkan/core/theme/markakalkan_theme.dart';
import 'package:markakalkan/features/home/presentation/widgets/home_solution_families_section.dart';
import 'package:markakalkan/features/home/presentation/widgets/home_partners_sponsor_section.dart';

class MarkaKalkanHomePage extends StatelessWidget {
  const MarkaKalkanHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF061722),
      body: SelectionArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _Header()),
            SliverToBoxAdapter(child: _HeroSection()),
            SliverToBoxAdapter(child: _PublicRadarSection()),
            SliverToBoxAdapter(child: _PublicServicesSection()),
            SliverToBoxAdapter(child: _AiFieldDetectivesShowcase()),
            SliverToBoxAdapter(child: _DefenseChainSection()),
            SliverToBoxAdapter(child: HomeSolutionFamiliesSection()),
            SliverToBoxAdapter(child: _FeatureSection()),
            SliverToBoxAdapter(child: _ProtectionSection()),
            SliverToBoxAdapter(child: HomePartnersSponsorSection()),
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
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 720;

              final identity = Row(
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
                          style: TextStyle(
                            color: Color(0xFF66727D),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );

              final actions = Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: isNarrow ? WrapAlignment.start : WrapAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      AppRouter.openProductVerification(context);
                    },
                    child: const Text('Marka Dedektifi'),
                  ),
                  FilledButton.icon(
                    onPressed: () {
                      AppRouter.openBrandLogin(context);
                    },
                    icon: const Icon(Icons.business_outlined),
                    label: const Text('Marka Girişi'),
                  ),
                ],
              );

              if (isNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [identity, const SizedBox(height: 14), actions],
                );
              }

              return Row(
                children: [
                  Expanded(child: identity),
                  const SizedBox(width: 20),
                  actions,
                ],
              );
            },
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

class _PublicRadarSection extends StatelessWidget {
  Future<void> _openReport(BuildContext context) async {
    if (FirebaseAuth.instance.currentUser == null) {
      final shouldLogin = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Bildirim için giriş gerekli'),
          content: const Text(
            'Sahte ikiz bildirimini güvenli biçimde göndermek ve '
            'başvuru kimliği almak için önce MarkaKalkan hesabınızla '
            'giriş yapmalısınız.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Giriş Yap'),
            ),
          ],
        ),
      );

      if (shouldLogin != true || !context.mounted) return;
      await AppRouter.openBrandLogin(context);
      if (!context.mounted) return;

      if (FirebaseAuth.instance.currentUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Bildirim formunu açmak için giriş işlemini tamamlayın.',
            ),
          ),
        );
        return;
      }
    }

    final reportId = await showCounterfeitTwinReportDialog(context: context);
    if (!context.mounted || reportId == null) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Bildiriminiz incelemeye alındı. Başvuru: $reportId'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF3F7F8),
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 72),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: const Color(0xFFD8E5E9)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0D000000),
                  blurRadius: 24,
                  offset: Offset(0, 12),
                ),
              ],
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final content = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F6F4),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: const Text(
                        'SAHTE İKİZ RADARI',
                        style: TextStyle(
                          color: MarkaKalkanTheme.teal,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.7,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Gerçek Ürün – Sahte İkiz Karşılaştırmaları',
                      style: TextStyle(
                        color: MarkaKalkanTheme.navy,
                        fontSize: 30,
                        height: 1.18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Ürün, platform, SaaS, turizm, finans, ödeme sayfası, '
                      'mobil uygulama, robot ve otonom ajan taklitlerini '
                      'inceleyin. Şüpheli bir ikizle karşılaştıysanız '
                      'delilleriyle birlikte MarkaKalkan’a bildirin.',
                      style: TextStyle(
                        color: Color(0xFF5D6B75),
                        fontSize: 16,
                        height: 1.55,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        FilledButton.icon(
                          onPressed: () {
                            AppRouter.openCounterfeitTwinPublicRadar(context);
                          },
                          icon: const Icon(Icons.compare_arrows_outlined),
                          label: const Text('Karşılaştırmaları İncele'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _openReport(context),
                          icon: const Icon(Icons.report_outlined),
                          label: const Text('Sahte İkiz Bildir'),
                        ),
                      ],
                    ),
                  ],
                );

                final visual = Container(
                  constraints: const BoxConstraints(minHeight: 250),
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [MarkaKalkanTheme.navy, Color(0xFF1E5261)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.radar_outlined,
                        color: Color(0xFFBCE7E3),
                        size: 76,
                      ),
                      SizedBox(height: 20),
                      Text(
                        'Gerçek kimliği doğrula.\nSahte ikizi görünür kıl.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 21,
                          height: 1.35,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                );

                if (constraints.maxWidth < 820) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [content, const SizedBox(height: 28), visual],
                  );
                }

                return Row(
                  children: [
                    Expanded(flex: 6, child: content),
                    const SizedBox(width: 36),
                    Expanded(flex: 4, child: visual),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _PublicServicesSection extends StatelessWidget {
  const _PublicServicesSection();

  @override
  Widget build(BuildContext context) {
    const services = <_PublicServiceData>[
      _PublicServiceData(
        icon: Icons.radar_outlined,
        eyebrow: 'KAMUYA AÇIK',
        title: 'Sahte İkiz Radarı',
        description:
            'Gerçek ürünleri, platformları ve dijital varlıkları sahte '
            'ikizleriyle karşılaştırın; şüpheli vakaları delilleriyle bildirin.',
        actionLabel: 'Radarı Aç',
        accent: MarkaKalkanTheme.teal,
        background: Color(0xFFE8F6F4),
        action: _PublicServiceAction.counterfeitRadar,
      ),
      _PublicServiceData(
        icon: Icons.history_edu_outlined,
        eyebrow: 'YARATICILAR İÇİN',
        title: 'Yaratım Öncelik Sicili',
        description:
            'Fikir, tasarım, yazılım, eser ve buluşlarınızın zaman çizelgesini, '
            'sürümlerini ve delil paketini güvenli biçimde kayıt altına alın.',
        actionLabel: 'Sicile Git',
        accent: Color(0xFF9A6A16),
        background: Color(0xFFFFF5DF),
        action: _PublicServiceAction.creationRegistry,
      ),
      _PublicServiceData(
        icon: Icons.verified_outlined,
        eyebrow: 'ANINDA DOĞRULAMA',
        title: 'Ürün ve Marka Doğrulama',
        description:
            'QR kodunu okutun veya tekil ürün kodunu girin; ürün kimliğini '
            've doğrulama kaydını birkaç saniye içinde inceleyin.',
        actionLabel: 'Ürünü Doğrula',
        accent: MarkaKalkanTheme.blue,
        background: Color(0xFFEAF4F6),
        action: _PublicServiceAction.productVerification,
      ),
    ];

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 78),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionHeading(
                eyebrow: 'HERKESE AÇIK MARKAKALKAN HİZMETLERİ',
                title: 'Koruma, doğrulama ve kayıt tek kapıda',
                description:
                    'MarkaKalkan’ın kamu yararı taşıyan temel araçlarına '
                    'hesap duvarına takılmadan ulaşın; gerektiğinde ortak '
                    'MarkaKalkan hesabınızla işleme devam edin.',
              ),
              const SizedBox(height: 38),
              LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final columns = width < 720 ? 1 : (width < 1040 ? 2 : 3);
                  final itemWidth = (width - ((columns - 1) * 20)) / columns;

                  return Wrap(
                    spacing: 20,
                    runSpacing: 20,
                    children: services
                        .map(
                          (service) => SizedBox(
                            width: itemWidth,
                            child: _PublicServiceCard(service: service),
                          ),
                        )
                        .toList(growable: false),
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

class _PublicServiceCard extends StatelessWidget {
  const _PublicServiceCard({required this.service});

  final _PublicServiceData service;

  void _open(BuildContext context) {
    switch (service.action) {
      case _PublicServiceAction.counterfeitRadar:
        AppRouter.openCounterfeitTwinPublicRadar(context);
      case _PublicServiceAction.creationRegistry:
        AppRouter.openIpCreationPriorityRegistry(context);
      case _PublicServiceAction.productVerification:
        AppRouter.openProductVerification(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 330),
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFDDE6EA)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 22,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: service.background,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(service.icon, color: service.accent, size: 31),
          ),
          const SizedBox(height: 22),
          Text(
            service.eyebrow,
            style: TextStyle(
              color: service.accent,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            service.title,
            style: const TextStyle(
              color: MarkaKalkanTheme.navy,
              fontSize: 22,
              height: 1.2,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            service.description,
            style: const TextStyle(
              color: Color(0xFF687580),
              fontSize: 15,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 22),
          TextButton.icon(
            onPressed: () => _open(context),
            style: TextButton.styleFrom(
              foregroundColor: service.accent,
              padding: EdgeInsets.zero,
            ),
            iconAlignment: IconAlignment.end,
            icon: const Icon(Icons.arrow_forward_rounded, size: 19),
            label: Text(
              service.actionLabel,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _AiFieldDetectivesShowcase extends StatelessWidget {
  const _AiFieldDetectivesShowcase();

  @override
  Widget build(BuildContext context) {
    const agents = <_AiAgentPreviewData>[
      _AiAgentPreviewData(
        icon: Icons.travel_explore_outlined,
        title: 'Dijital Saha Tarama',
      ),
      _AiAgentPreviewData(
        icon: Icons.image_search_outlined,
        title: 'Görsel Eşleştirme',
      ),
      _AiAgentPreviewData(
        icon: Icons.account_tree_outlined,
        title: 'Satıcı ve Varlık Ağı',
      ),
      _AiAgentPreviewData(
        icon: Icons.change_circle_outlined,
        title: 'Sayfa Değişim İzleme',
      ),
      _AiAgentPreviewData(
        icon: Icons.fact_check_outlined,
        title: 'Kanıt Dosyası',
      ),
      _AiAgentPreviewData(
        icon: Icons.priority_high_rounded,
        title: 'Risk Önceliklendirme',
      ),
    ];

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF071923), MarkaKalkanTheme.navy, Color(0xFF123E4B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 88),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final content = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _DarkSectionEyebrow(
                    text: 'YAPAY ZEKÂ SAHA DEDEKTİFLERİ',
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    '12 uzman yapay zekâ dedektifi,\nmarkanız için aynı operasyonda çalışır.',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 38,
                      height: 1.14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Dijital mağazaları tarar, görselleri eşleştirir, '
                    'satıcı ağlarını çözümler, değişen sayfaları izler, '
                    'risk sinyallerini birleştirir ve müdahale dosyası hazırlar.',
                    style: TextStyle(
                      color: Color(0xFFC9D8DE),
                      fontSize: 16,
                      height: 1.65,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      FilledButton.icon(
                        onPressed: () {
                          AppRouter.openAiFieldDetectivesHub(context);
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: MarkaKalkanTheme.teal,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 22,
                            vertical: 17,
                          ),
                        ),
                        icon: const Icon(Icons.hub_outlined),
                        label: const Text('Dedektifleri Keşfet'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () {
                          AppRouter.openBrandLogin(context);
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Color(0xFF6C909E)),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 22,
                            vertical: 17,
                          ),
                        ),
                        icon: const Icon(Icons.play_circle_outline),
                        label: const Text('Markanız İçin Görev Başlat'),
                      ),
                    ],
                  ),
                ],
              );

              final operationMap = Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: const Color(0x1AFFFFFF),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: const Color(0x336ECFC5)),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF123B49),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFF3B7B84)),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.psychology_alt_outlined,
                            color: Color(0xFFBCE7E3),
                          ),
                          SizedBox(width: 10),
                          Flexible(
                            child: Text(
                              'Görev Planlama Merkezi',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    LayoutBuilder(
                      builder: (context, gridConstraints) {
                        final itemWidth = (gridConstraints.maxWidth - 12) / 2;

                        return Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: agents
                              .map(
                                (agent) => SizedBox(
                                  width: itemWidth,
                                  child: _AiAgentPreview(agent: agent),
                                ),
                              )
                              .toList(growable: false),
                        );
                      },
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      '12 uzman ajan • ortak kanıt zinciri • tek operasyon',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFFAFC6CF),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              );

              if (constraints.maxWidth < 880) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [content, const SizedBox(height: 42), operationMap],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(flex: 11, child: content),
                  const SizedBox(width: 54),
                  Expanded(flex: 9, child: operationMap),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _AiAgentPreview extends StatelessWidget {
  const _AiAgentPreview({required this.agent});

  final _AiAgentPreviewData agent;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 106),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0x14000000),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: const Color(0x267FB8C1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(agent.icon, color: const Color(0xFF86DAD1), size: 24),
          const SizedBox(height: 10),
          Text(
            agent.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              height: 1.25,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _DefenseChainSection extends StatelessWidget {
  const _DefenseChainSection();

  @override
  Widget build(BuildContext context) {
    const steps = <_DefenseStepData>[
      _DefenseStepData(
        number: '01',
        icon: Icons.category_outlined,
        title: 'Tanımla',
        description: 'Markanızı, ürününüzü ve fikri varlıklarınızı belirleyin.',
      ),
      _DefenseStepData(
        number: '02',
        icon: Icons.edit_note_outlined,
        title: 'Kaydet',
        description: 'Hak, öncelik, belge ve delil zincirini oluşturun.',
      ),
      _DefenseStepData(
        number: '03',
        icon: Icons.factory_outlined,
        title: 'Güvenceye Al',
        description: 'Üretim, tedarik ve yetki sınırlarını koruyun.',
      ),
      _DefenseStepData(
        number: '04',
        icon: Icons.visibility_outlined,
        title: 'İzle',
        description:
            'Dijital kaynakları, satıcıları ve değişimleri takip edin.',
      ),
      _DefenseStepData(
        number: '05',
        icon: Icons.radar_outlined,
        title: 'Tespit Et',
        description: 'Sahte ikizleri ve risk sinyallerini görünür kılın.',
      ),
      _DefenseStepData(
        number: '06',
        icon: Icons.fact_check_outlined,
        title: 'Kanıtla',
        description: 'Görsel, belge, kaynak ve zaman çizelgesini birleştirin.',
      ),
      _DefenseStepData(
        number: '07',
        icon: Icons.gavel_outlined,
        title: 'Müdahale Et',
        description: 'Vaka dosyasını yönetin ve doğru aksiyonu başlatın.',
      ),
    ];

    return Container(
      color: const Color(0xFFF4F7F8),
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 80),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionHeading(
                eyebrow: 'MARKAKALKAN SAVUNMA ZİNCİRİ',
                title:
                    'Birbirinden kopuk araçlar değil, yaşayan bir savunma sistemi',
                description:
                    'MarkaKalkan; ilk varlık kaydından dijital tehdidin '
                    'tespitine, kanıt dosyasından müdahaleye kadar bütün '
                    'savunma adımlarını aynı izlenebilir zincirde birleştirir.',
              ),
              const SizedBox(height: 38),
              LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final columns = width < 620 ? 1 : (width < 940 ? 2 : 4);
                  final itemWidth = (width - ((columns - 1) * 16)) / columns;

                  return Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: steps
                        .map(
                          (step) => SizedBox(
                            width: itemWidth,
                            child: _DefenseStepCard(step: step),
                          ),
                        )
                        .toList(growable: false),
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

class _DefenseStepCard extends StatelessWidget {
  const _DefenseStepCard({required this.step});

  final _DefenseStepData step;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 212),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(21),
        border: Border.all(color: const Color(0xFFDCE6EA)),
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
                child: Icon(step.icon, color: MarkaKalkanTheme.teal, size: 25),
              ),
              const Spacer(),
              Text(
                step.number,
                style: const TextStyle(
                  color: Color(0xFFB4C1C7),
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            step.title,
            style: const TextStyle(
              color: MarkaKalkanTheme.navy,
              fontSize: 19,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            step.description,
            style: const TextStyle(
              color: Color(0xFF687580),
              height: 1.5,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.eyebrow,
    required this.title,
    required this.description,
  });

  final String eyebrow;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 830),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            eyebrow,
            style: const TextStyle(
              color: MarkaKalkanTheme.teal,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              color: MarkaKalkanTheme.navy,
              fontSize: 34,
              height: 1.17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            description,
            style: const TextStyle(
              color: Color(0xFF687580),
              fontSize: 16,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _DarkSectionEyebrow extends StatelessWidget {
  const _DarkSectionEyebrow({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0x1A6ECFC5),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: const Color(0x556ECFC5)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFFBCE7E3),
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

enum _PublicServiceAction {
  counterfeitRadar,
  creationRegistry,
  productVerification,
}

class _PublicServiceData {
  const _PublicServiceData({
    required this.icon,
    required this.eyebrow,
    required this.title,
    required this.description,
    required this.actionLabel,
    required this.accent,
    required this.background,
    required this.action,
  });

  final IconData icon;
  final String eyebrow;
  final String title;
  final String description;
  final String actionLabel;
  final Color accent;
  final Color background;
  final _PublicServiceAction action;
}

class _AiAgentPreviewData {
  const _AiAgentPreviewData({required this.icon, required this.title});

  final IconData icon;
  final String title;
}

class _DefenseStepData {
  const _DefenseStepData({
    required this.number,
    required this.icon,
    required this.title,
    required this.description,
  });

  final String number;
  final IconData icon;
  final String title;
  final String description;
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

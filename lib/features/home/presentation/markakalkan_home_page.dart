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
            SliverToBoxAdapter(child: _ProtectionIntentSection()),
            SliverToBoxAdapter(child: _MobileVerificationSection()),
            SliverToBoxAdapter(child: _PublicRadarSection()),
            SliverToBoxAdapter(child: _PublicRiskScanSection()),
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
    final compact = MediaQuery.sizeOf(context).width < 820;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [MarkaKalkanTheme.navy, Color(0xFF183B4E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 24 : 28,
        vertical: compact ? 40 : 72,
      ),
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
                  SizedBox(height: compact ? 16 : 22),
                  Text(
                    'Müşteriniz orijinalini bilsin,\nsiz sahtesini görün.',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: compact ? 34 : 46,
                      height: compact ? 1.08 : 1.12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: compact ? 14 : 20),
                  Text(
                    'Riskleri bulun, delilleri koruyun, vakaya dönüştürün '
                    've sonuca kadar yönetin.',
                    style: TextStyle(
                      color: const Color(0xFFD9E5EA),
                      fontSize: compact ? 15 : 17,
                      height: compact ? 1.45 : 1.6,
                    ),
                  ),
                  SizedBox(height: compact ? 22 : 28),
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
                          padding: EdgeInsets.symmetric(
                            horizontal: 22,
                            vertical: compact ? 14 : 17,
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
                          padding: EdgeInsets.symmetric(
                            horizontal: 22,
                            vertical: compact ? 14 : 17,
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
                return introduction;
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

class _MobileVerificationSection extends StatelessWidget {
  const _MobileVerificationSection();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 820) {
          return const SizedBox.shrink();
        }

        return Container(
          color: const Color(0xFFF7FAFC),
          padding: const EdgeInsets.fromLTRB(28, 0, 28, 64),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: const _VerificationCard(),
            ),
          ),
        );
      },
    );
  }
}

Future<void> _openProtectionIntentDestination(
  BuildContext context,
  _ProtectionIntentData intent,
) {
  return switch (intent.destination) {
    _ProtectionIntentDestination.brandDetective =>
      AppRouter.openBrandDetectiveHub(context),
    _ProtectionIntentDestination.digitalMarketMonitoring =>
      AppRouter.openDijitalPazarIzleme(context),
    _ProtectionIntentDestination.digitalDetectiveTasks =>
      AppRouter.openDigitalDetectiveTasks(context),
    _ProtectionIntentDestination.supplySecurity =>
      AppRouter.openSupplySecurityHub(context),
    _ProtectionIntentDestination.customsSecurity =>
      AppRouter.openCustomsSecurityHub(context),
    _ProtectionIntentDestination.interventionLegal =>
      AppRouter.openInterventionLegalHub(context),
  };
}

class _ProtectionIntentSection extends StatelessWidget {
  const _ProtectionIntentSection();

  static const _intents = <_ProtectionIntentData>[
    _ProtectionIntentData(
      code: 'counterfeit_product',
      ctaLabel: 'Dijital Dedektife geç',
      destination: _ProtectionIntentDestination.brandDetective,
      icon: Icons.inventory_2_outlined,
      title: 'Sahte ürün',
      description: 'Ürününüze benzeyen şüpheli satışları bulun.',
      guidanceTitle: 'Sahte ürünleri bulmak istiyorsunuz',
      guidanceDescription:
          'MarkaKalkan’ın 12 Yapay Zekâ Ajanı dijital kaynaklarda şüpheli '
          'ürünleri bulmanıza ve önceliklendirmenize yardımcı olur.',
      steps: [
        'Markanızı seçin',
        'Mevcut sonuçları inceleyin',
        'Gerekirse yeni tarama başlatın',
      ],
    ),
    _ProtectionIntentData(
      code: 'fake_account',
      ctaLabel: 'Dijital Dedektife geç',
      destination: _ProtectionIntentDestination.brandDetective,
      icon: Icons.account_circle_outlined,
      title: 'Sahte hesap',
      description: 'Markanızı taklit eden hesapları inceleyin.',
      guidanceTitle: 'Taklit hesapları incelemek istiyorsunuz',
      guidanceDescription:
          'Marka adınızı, görsellerinizi veya kimliğinizi kullanan şüpheli '
          'hesapları önce mevcut bulgular üzerinden değerlendirin.',
      steps: [
        'Markanızı seçin',
        'Mevcut hesap bulgularını inceleyin',
        'Gerekirse yeni inceleme başlatın',
      ],
    ),
    _ProtectionIntentData(
      code: 'fake_website',
      ctaLabel: 'Dijital Dedektife geç',
      destination: _ProtectionIntentDestination.brandDetective,
      icon: Icons.language_outlined,
      title: 'Taklit web sitesi',
      description: 'Markanızı kullanan şüpheli siteleri bulun.',
      guidanceTitle: 'Taklit web sitelerini incelemek istiyorsunuz',
      guidanceDescription:
          'Markanızı, ürünlerinizi veya kurumsal kimliğinizi kullanan şüpheli '
          'siteleri mevcut bulgular ve deliller üzerinden değerlendirin.',
      steps: [
        'Markanızı seçin',
        'Mevcut site bulgularını inceleyin',
        'Gerekirse yeni inceleme başlatın',
      ],
    ),
    _ProtectionIntentData(
      code: 'unauthorized_seller',
      ctaLabel: 'Satıcı takibine geç',
      destination: _ProtectionIntentDestination.digitalMarketMonitoring,
      icon: Icons.storefront_outlined,
      title: 'İzinsiz satıcı',
      description: 'Yetkisiz ve tekrar eden satışları takip edin.',
      guidanceTitle: 'İzinsiz satıcıları takip etmek istiyorsunuz',
      guidanceDescription:
          'Yetkisiz satışları, tekrar eden satıcıları ve ilişkili kanalları '
          'önce mevcut kayıtlar üzerinden inceleyin.',
      steps: [
        'Markanızı seçin',
        'Mevcut satıcı bulgularını inceleyin',
        'Gerekirse yeni takip başlatın',
      ],
    ),
    _ProtectionIntentData(
      code: 'pirated_content',
      ctaLabel: 'Dijital Dedektife geç',
      destination: _ProtectionIntentDestination.digitalDetectiveTasks,
      icon: Icons.copyright_outlined,
      title: 'Korsan içerik',
      description: 'İzinsiz kullanılan içerikleri ve dijital varlıkları bulun.',
      guidanceTitle: 'Korsan içerikleri incelemek istiyorsunuz',
      guidanceDescription:
          'İzinsiz kullanılan içeriklerinizi ve dijital varlıklarınızı mevcut '
          'bulgular, kaynaklar ve deliller üzerinden değerlendirin.',
      steps: [
        'Korunacak varlığı seçin',
        'Mevcut kullanım bulgularını inceleyin',
        'Gerekirse yeni inceleme başlatın',
      ],
    ),
    _ProtectionIntentData(
      code: 'supply_risk',
      ctaLabel: 'Tedarik güvenliğine geç',
      destination: _ProtectionIntentDestination.supplySecurity,
      icon: Icons.factory_outlined,
      title: 'Üretim ve tedarik riski',
      description: 'Üretici, tesis ve tedarik zinciri risklerini yönetin.',
      guidanceTitle: 'Üretim ve tedarik riskini yönetmek istiyorsunuz',
      guidanceDescription:
          'Üretici, tesis, üretim varlığı ve tedarik zinciri kayıtlarını '
          'korunan markanızla ilişkili olarak değerlendirin.',
      steps: [
        'Markanızı seçin',
        'Üretim ve tedarik kayıtlarını inceleyin',
        'Gerekli koruma adımını belirleyin',
      ],
    ),
    _ProtectionIntentData(
      code: 'customs_risk',
      ctaLabel: 'Gümrük güvenliğine geç',
      destination: _ProtectionIntentDestination.customsSecurity,
      icon: Icons.local_shipping_outlined,
      title: 'Gümrük riski',
      description:
          'Sahte ürünlere karşı sınır ve gümrük seçeneklerini değerlendirin.',
      guidanceTitle: 'Gümrük seçeneklerini değerlendirmek istiyorsunuz',
      guidanceDescription:
          'Sınırda durdurma ve gümrük koruması için önce mevcut vaka, delil '
          've marka bilgilerinizi değerlendirin.',
      steps: [
        'Markanızı ve ilgili vakayı seçin',
        'Mevcut delilleri inceleyin',
        'Uygun gümrük seçeneğini değerlendirin',
      ],
    ),
    _ProtectionIntentData(
      code: 'trademark_infringement',
      ctaLabel: 'Müdahale seçeneklerini incele',
      destination: _ProtectionIntentDestination.interventionLegal,
      icon: Icons.gavel_outlined,
      title: 'Marka ihlali',
      description: 'Delil, vaka ve müdahale seçeneklerine geçin.',
      guidanceTitle: 'Marka ihlaline karşı ilerlemek istiyorsunuz',
      guidanceDescription:
          'Mevcut bulgu ve delilleri vakaya dönüştürmeden veya müdahale '
          'seçmeden önce durumunuzu bütün olarak inceleyin.',
      steps: [
        'Markanızı ve bulguyu seçin',
        'Delilleri ve mevcut vakayı inceleyin',
        'Uygun müdahale seçeneğini değerlendirin',
      ],
    ),
  ];

  void _openGuidance(BuildContext context, _ProtectionIntentData intent) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ProtectionIntentGuidanceSheet(
        intent: intent,
        onContinue: () => _openProtectionIntentDestination(context, intent),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF7FAFC),
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 64),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Markanızı bugün neye karşı korumak istiyorsunuz?',
                style: TextStyle(
                  color: MarkaKalkanTheme.navy,
                  fontSize: 34,
                  height: 1.16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'İhtiyacınızı seçin; MarkaKalkan size doğru yolu göstersin.',
                style: TextStyle(
                  color: Color(0xFF667580),
                  fontSize: 16,
                  height: 1.55,
                ),
              ),
              const SizedBox(height: 34),
              LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final columns = width >= 1040 ? 4 : (width >= 620 ? 2 : 1);
                  final itemWidth = (width - ((columns - 1) * 16)) / columns;

                  return Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: _intents
                        .map(
                          (intent) => SizedBox(
                            width: itemWidth,
                            child: _ProtectionIntentCard(
                              intent: intent,
                              onTap: () => _openGuidance(context, intent),
                            ),
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

class _ProtectionIntentCard extends StatelessWidget {
  const _ProtectionIntentCard({required this.intent, required this.onTap});

  final _ProtectionIntentData intent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${intent.title}. ${intent.description}',
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          key: Key('homeIntent_${intent.code}'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            constraints: const BoxConstraints(minHeight: 176),
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFDCE6EA)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0D0B2834),
                  blurRadius: 18,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE7F4F2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    intent.icon,
                    color: MarkaKalkanTheme.teal,
                    size: 25,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  intent.title,
                  style: const TextStyle(
                    color: MarkaKalkanTheme.navy,
                    fontSize: 17,
                    height: 1.25,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  intent.description,
                  style: const TextStyle(
                    color: Color(0xFF667580),
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProtectionIntentGuidanceSheet extends StatelessWidget {
  const _ProtectionIntentGuidanceSheet({
    required this.intent,
    required this.onContinue,
  });

  final _ProtectionIntentData intent;
  final Future<void> Function() onContinue;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 640;

    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxWidth: 760),
        margin: EdgeInsets.fromLTRB(
          compact ? 12 : 24,
          24,
          compact ? 12 : 24,
          12,
        ),
        padding: EdgeInsets.all(compact ? 22 : 30),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 30,
              offset: Offset(0, 16),
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE7F4F2),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Icon(
                      intent.icon,
                      color: MarkaKalkanTheme.teal,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      intent.guidanceTitle,
                      style: const TextStyle(
                        color: MarkaKalkanTheme.navy,
                        fontSize: 24,
                        height: 1.2,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Kapat',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                intent.guidanceDescription,
                style: const TextStyle(
                  color: Color(0xFF5F6E78),
                  fontSize: 15,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 24),
              ...List.generate(intent.steps.length, (index) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          color: Color(0xFF0B7A75),
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 5),
                          child: Text(
                            intent.steps[index],
                            style: const TextStyle(
                              color: MarkaKalkanTheme.navy,
                              fontSize: 15,
                              height: 1.4,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: Key('homeIntentContinue_${intent.code}'),
                  onPressed: () async {
                    Navigator.of(context).pop();
                    await onContinue();
                  },
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: Text(intent.ctaLabel),
                  style: FilledButton.styleFrom(
                    backgroundColor: MarkaKalkanTheme.teal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    textStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Bu seçim yalnızca size doğru yolu gösterir; tarama veya '
                'başka bir işlem başlatmaz.',
                style: TextStyle(
                  color: Color(0xFF78858D),
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _ProtectionIntentDestination {
  brandDetective,
  digitalMarketMonitoring,
  digitalDetectiveTasks,
  supplySecurity,
  customsSecurity,
  interventionLegal,
}

class _ProtectionIntentData {
  const _ProtectionIntentData({
    required this.code,
    required this.ctaLabel,
    required this.destination,
    required this.icon,
    required this.title,
    required this.description,
    required this.guidanceTitle,
    required this.guidanceDescription,
    required this.steps,
  });

  final String code;
  final String ctaLabel;
  final _ProtectionIntentDestination destination;
  final IconData icon;
  final String title;
  final String description;
  final String guidanceTitle;
  final String guidanceDescription;
  final List<String> steps;
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

class _PublicRiskScanSection extends StatelessWidget {
  const _PublicRiskScanSection();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF071923), Color(0xFF0A2533), Color(0xFF123E4B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 80),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
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
                      color: const Color(0xFF173E4D),
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(color: const Color(0xFF2F6170)),
                    ),
                    child: const Text(
                      'ÜCRETSİZ HIZLI RİSK TARAMASI',
                      style: TextStyle(
                        color: Color(0xFF9BE1DA),
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.7,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Markanızı yazın,\nilk risk görünümünü alın.',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 38,
                      height: 1.14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Marka adınızı ve resmî internet adresinizi girin. '
                    'MarkaKalkan; benzer alan adı, açık web ve sınırlı '
                    'pazaryeri kanallarındaki ilk risk sinyallerini tarasın, '
                    'sonuçları anlaşılır bir özet raporda sunsun.',
                    style: TextStyle(
                      color: Color(0xFFC9D8DE),
                      fontSize: 16,
                      height: 1.65,
                    ),
                  ),
                  const SizedBox(height: 22),
                  const Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _RiskScanBenefitChip(
                        icon: Icons.person_off_outlined,
                        label: 'Hesap gerektirmez',
                      ),
                      _RiskScanBenefitChip(
                        icon: Icons.lock_outline,
                        label: 'Sonuçlar kamuya yayımlanmaz',
                      ),
                      _RiskScanBenefitChip(
                        icon: Icons.timer_outlined,
                        label: 'Hızlı ilk görünüm',
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  FilledButton.icon(
                    key: const Key('publicRiskScanHomeButton'),
                    onPressed: () {
                      AppRouter.openPublicLiteRiskScan(context);
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: MarkaKalkanTheme.teal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 18,
                      ),
                    ),
                    icon: const Icon(Icons.radar_outlined),
                    label: const Text('Markamı Ücretsiz Tara'),
                  ),
                ],
              );

              const visual = _RiskScanVisual();

              if (constraints.maxWidth < 820) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [content, const SizedBox(height: 36), visual],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(flex: 6, child: content),
                  const SizedBox(width: 48),
                  const Expanded(flex: 4, child: visual),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _RiskScanBenefitChip extends StatelessWidget {
  const _RiskScanBenefitChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFF102F3C),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: const Color(0xFF315563)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: const Color(0xFF9BE1DA), size: 17),
          const SizedBox(width: 7),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFFE5EFF2),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _RiskScanVisual extends StatelessWidget {
  const _RiskScanVisual();

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 330),
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FBFC),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFB7D3DA)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x2A000000),
            blurRadius: 30,
            offset: Offset(0, 16),
          ),
        ],
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.shield_outlined,
                color: MarkaKalkanTheme.teal,
                size: 30,
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'İlk risk görünümü',
                  style: TextStyle(
                    color: MarkaKalkanTheme.navy,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 24),
          _RiskScanStep(
            number: '1',
            title: 'Markanızı girin',
            body: 'Marka adı ve resmî internet adresi.',
          ),
          SizedBox(height: 14),
          _RiskScanStep(
            number: '2',
            title: 'Tarama çalışsın',
            body: 'Açık kaynak risk sinyalleri incelensin.',
          ),
          SizedBox(height: 14),
          _RiskScanStep(
            number: '3',
            title: 'Sonucu görün',
            body: 'Kapsam, bulgular ve önerilen sonraki adım.',
          ),
          SizedBox(height: 22),
          Text(
            'Ücretsiz tarama, kapsamı sınırlı bir ilk değerlendirmedir.',
            style: TextStyle(
              color: Color(0xFF65747D),
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _RiskScanStep extends StatelessWidget {
  const _RiskScanStep({
    required this.number,
    required this.title,
    required this.body,
  });

  final String number;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: Color(0xFFE8F6F4),
            shape: BoxShape.circle,
          ),
          child: Text(
            number,
            style: const TextStyle(
              color: MarkaKalkanTheme.teal,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: MarkaKalkanTheme.navy,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                body,
                style: const TextStyle(
                  color: Color(0xFF667780),
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
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
  const _Footer();

  static const _background = Color(0xFF071B2C);
  static const _panel = Color(0xFF102A43);
  static const _accent = Color(0xFF2F80ED);
  static const _muted = Color(0xFFB9C7D5);
  static const _soft = Color(0xFFE8EEF4);

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('homeCorporateFooter'),
      decoration: const BoxDecoration(
        color: _background,
        border: Border(
          top: BorderSide(
            color: _accent,
            width: 3,
          ),
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 40, 28, 26),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 860;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _HomeTrustSecurityPanel(),
                    const SizedBox(height: 34),
                    if (compact)
                      const _HomeCorporateFooterCompact()
                    else
                      const _HomeCorporateFooterWide(),
                    const SizedBox(height: 30),
                    Container(
                      height: 1,
                      color: Colors.white.withValues(alpha: 0.10),
                    ),
                    const SizedBox(height: 18),
                    const _HomeCorporateFooterBottom(),
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

class _HomeTrustSecurityPanel extends StatelessWidget {
  const _HomeTrustSecurityPanel();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      key: const Key('homeTrustSecurityPanel'),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: _Footer._panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.10),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 760;

          final intro = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Güvenlik ve gizlilik yaklaşımı',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'MarkaKalkan, güvenliği ve veri minimizasyonunu ürün '
                'mimarisinin temel bileşenleri olarak ele alır.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: _Footer._muted,
                  height: 1.55,
                ),
              ),
            ],
          );

          const principles = Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _HomeTrustChip('Güvenli tasarım'),
              _HomeTrustChip('Erişim ve veri minimizasyonu'),
              _HomeTrustChip('Gizlilik ilkeleri'),
              _HomeTrustChip('KVKK ve GDPR odaklı yaklaşım'),
            ],
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                intro,
                const SizedBox(height: 18),
                principles,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(flex: 5, child: intro),
              const SizedBox(width: 34),
              const Expanded(flex: 5, child: principles),
            ],
          );
        },
      ),
    );
  }
}

class _HomeTrustChip extends StatelessWidget {
  const _HomeTrustChip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 11,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.11),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: _Footer._soft,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _HomeCorporateFooterWide extends StatelessWidget {
  const _HomeCorporateFooterWide();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Expanded(
          flex: 6,
          child: _HomeCorporateBrandBlock(),
        ),
        const SizedBox(width: 42),
        Expanded(
          flex: 10,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _HomePlatformColumn()),
              const SizedBox(width: 24),
              const Expanded(
                child: _HomeFooterColumn(
                  title: 'Kaynaklar',
                  items: [
                    _HomeFooterItemData('Resmî kurumlar'),
                    _HomeFooterItemData('Kılavuzlar'),
                    _HomeFooterItemData('Sık sorulan sorular'),
                    _HomeFooterItemData('Blog'),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              const Expanded(
                child: _HomeFooterColumn(
                  title: 'Şirket',
                  items: [
                    _HomeFooterItemData('Hakkımızda'),
                    _HomeFooterItemData('İletişim'),
                    _HomeFooterItemData('Kariyer'),
                    _HomeFooterItemData('Basın odası'),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              const Expanded(
                child: _HomeFooterColumn(
                  title: 'Yasal',
                  items: [
                    _HomeFooterItemData('Kullanım koşulları'),
                    _HomeFooterItemData('Gizlilik politikası'),
                    _HomeFooterItemData('Çerez politikası'),
                    _HomeFooterItemData('KVKK Aydınlatma Metni'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HomeCorporateFooterCompact extends StatelessWidget {
  const _HomeCorporateFooterCompact();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _HomeCorporateBrandBlock(),
        SizedBox(height: 30),
        _HomePlatformColumn(),
        SizedBox(height: 26),
        _HomeFooterColumn(
          title: 'Kaynaklar',
          items: [
            _HomeFooterItemData('Resmî kurumlar'),
            _HomeFooterItemData('Kılavuzlar'),
            _HomeFooterItemData('Sık sorulan sorular'),
            _HomeFooterItemData('Blog'),
          ],
        ),
        SizedBox(height: 26),
        _HomeFooterColumn(
          title: 'Şirket',
          items: [
            _HomeFooterItemData('Hakkımızda'),
            _HomeFooterItemData('İletişim'),
            _HomeFooterItemData('Kariyer'),
            _HomeFooterItemData('Basın odası'),
          ],
        ),
        SizedBox(height: 26),
        _HomeFooterColumn(
          title: 'Yasal',
          items: [
            _HomeFooterItemData('Kullanım koşulları'),
            _HomeFooterItemData('Gizlilik politikası'),
            _HomeFooterItemData('Çerez politikası'),
            _HomeFooterItemData('KVKK Aydınlatma Metni'),
          ],
        ),
      ],
    );
  }
}

class _HomeCorporateBrandBlock extends StatelessWidget {
  const _HomeCorporateBrandBlock();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: _Footer._panel,
                borderRadius: BorderRadius.circular(13),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.12),
                ),
              ),
              child: const Icon(
                Icons.shield_outlined,
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'MarkaKalkan',
              style: theme.textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'Markanızı korumak, sahtecilikle mücadele etmek ve dijital '
          'dünyada güvenliğinizi güçlendirmek için tasarlandı.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: _Footer._muted,
            height: 1.6,
          ),
        ),
      ],
    );
  }
}

class _HomePlatformColumn extends StatelessWidget {
  const _HomePlatformColumn();

  @override
  Widget build(BuildContext context) {
    return _HomeFooterColumn(
      title: 'Platform',
      items: [
        _HomeFooterItemData(
          'Sahte İkiz Radarı',
          onTap: () => AppRouter.openCounterfeitTwinPublicRadar(context),
        ),
        _HomeFooterItemData(
          'Yaratım Öncelik Sicili',
          onTap: () => AppRouter.openIpCreationPriorityRegistry(context),
        ),
        _HomeFooterItemData(
          'Risk tarama hizmeti',
          onTap: () => AppRouter.openPublicLiteRiskScan(context),
        ),
        const _HomeFooterItemData('Tüm modüller'),
      ],
    );
  }
}

class _HomeFooterColumn extends StatelessWidget {
  const _HomeFooterColumn({
    required this.title,
    required this.items,
  });

  final String title;
  final List<_HomeFooterItemData> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 13),
        for (final item in items) ...[
          _HomeFooterLink(item: item),
          const SizedBox(height: 9),
        ],
      ],
    );
  }
}

class _HomeFooterLink extends StatelessWidget {
  const _HomeFooterLink({
    required this.item,
  });

  final _HomeFooterItemData item;

  @override
  Widget build(BuildContext context) {
    final label = Text(
      item.label,
      style: TextStyle(
        color: item.onTap == null
            ? _Footer._muted
            : Colors.white.withValues(alpha: 0.92),
        fontSize: 13,
        fontWeight: item.onTap == null
            ? FontWeight.w500
            : FontWeight.w600,
        height: 1.35,
      ),
    );

    if (item.onTap == null) {
      return label;
    }

    return Semantics(
      link: true,
      button: true,
      label: item.label,
      child: InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(child: label),
              const SizedBox(width: 5),
              const Icon(
                Icons.arrow_outward_rounded,
                size: 13,
                color: _Footer._accent,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeCorporateFooterBottom extends StatelessWidget {
  const _HomeCorporateFooterBottom();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 700;

        final copyright = Text(
          '© 2026 MarkaKalkan. Tüm hakları saklıdır.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: _Footer._muted,
          ),
        );

        final platform = Text(
          'Dijital Ürün Kimliği ve Marka Koruma Platformu',
          style: theme.textTheme.bodySmall?.copyWith(
            color: _Footer._muted,
          ),
        );

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              copyright,
              const SizedBox(height: 7),
              platform,
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: copyright),
            const SizedBox(width: 24),
            platform,
          ],
        );
      },
    );
  }
}

class _HomeFooterItemData {
  const _HomeFooterItemData(
    this.label, {
    this.onTap,
  });

  final String label;
  final VoidCallback? onTap;
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

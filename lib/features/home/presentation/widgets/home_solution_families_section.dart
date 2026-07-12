import 'package:flutter/material.dart';
import 'package:markakalkan/app/router.dart';
import 'package:markakalkan/core/theme/markakalkan_theme.dart';

class HomeSolutionFamiliesSection extends StatelessWidget {
  const HomeSolutionFamiliesSection({super.key});

  @override
  Widget build(BuildContext context) {
    const families = <_FamilyData>[
      _FamilyData(
        number: '01',
        icon: Icons.workspace_premium_outlined,
        eyebrow: 'FİKRİ VARLIKLAR',
        title: 'Fikri Varlık Savunması',
        description:
            'Yaratımlarınızı, belgelerinizi, formüllerinizi ve ticari sırlarınızı kayıt, delil ve erişim zinciriyle koruyun.',
        accent: Color(0xFF9A6A16),
        start: Color(0xFFFFF4D8),
        end: Color(0xFFFFFBF3),
        modules: [
          _ModuleData(
            icon: Icons.folder_copy_outlined,
            title: 'Fikri Mülkiyet ve Belgeler',
            description:
                'Hak, belge ve sahiplik kayıtlarını tek güvenli merkezde yönetin.',
            destination: _Destination.ipDocuments,
          ),
          _ModuleData(
            icon: Icons.history_edu_outlined,
            title: 'Yaratım Öncelik Sicili',
            description:
                'Yaratımların zaman çizelgesini, sürümlerini ve delil paketini kaydedin.',
            destination: _Destination.creationRegistry,
          ),
          _ModuleData(
            icon: Icons.shield_outlined,
            title: 'Formül ve Ticari Sır Kalkanı',
            description:
                'Formül, bileşen, erişim, ifşa ve olay kayıtlarını birlikte koruyun.',
            destination: _Destination.tradeSecretShield,
          ),
        ],
      ),
      _FamilyData(
        number: '02',
        icon: Icons.hub_outlined,
        eyebrow: 'DİJİTAL İSTİHBARAT',
        title: 'Dijital Tehdit İstihbaratı',
        description:
            'Kaynakları, sayfaları, satıcıları ve risk sinyallerini izleyin; yapay zekâ ajanlarıyla dijital sahayı sürekli tarayın.',
        accent: Color(0xFF006D77),
        start: Color(0xFFDDF3F1),
        end: Color(0xFFF6FBFB),
        modules: [
          _ModuleData(
            icon: Icons.monitor_heart_outlined,
            title: 'Dijital Pazar İzleme',
            description:
                'Marka izleme profilinden rapor merkezine uzanan tehdit akışını yönetin.',
            destination: _Destination.digitalMarket,
          ),
          _ModuleData(
            icon: Icons.manage_search_outlined,
            title: 'Marka İzleme Profilleri',
            description:
                'İzlenecek marka, anahtar kelime, kategori ve hedefleri tanımlayın.',
            destination: _Destination.monitoringProfiles,
          ),
          _ModuleData(
            icon: Icons.notification_important_outlined,
            title: 'Risk Sinyalleri',
            description:
                'Kritik dijital değişimleri ve şüpheli örüntüleri önceliklendirin.',
            destination: _Destination.riskSignals,
          ),
          _ModuleData(
            icon: Icons.psychology_alt_outlined,
            title: 'Yapay Zekâ Saha Dedektifleri',
            description:
                '12 uzman ajanla tarama, eşleştirme, kanıt ve müdahale hazırlayın.',
            destination: _Destination.aiDetectives,
          ),
          _ModuleData(
            icon: Icons.analytics_outlined,
            title: 'Rapor Merkezi',
            description:
                'Yönetici özeti, marka riski ve vaka kanıt raporlarını görüntüleyin.',
            destination: _Destination.reportCenter,
          ),
        ],
      ),
      _FamilyData(
        number: '03',
        icon: Icons.radar_outlined,
        eyebrow: 'SAHTECİLİK SAVUNMASI',
        title: 'Sahtecilik ve Klon Savunması',
        description:
            'Gerçek ile sahte ikizi karşılaştırın, kalıcı vaka kaydı oluşturun ve delilleri müdahale sürecine taşıyın.',
        accent: Color(0xFFB4473A),
        start: Color(0xFFFFE5E0),
        end: Color(0xFFFFF8F6),
        modules: [
          _ModuleData(
            icon: Icons.compare_arrows_outlined,
            title: 'Sahte İkiz Radarı',
            description:
                'Kamuya açık gerçek–sahte karşılaştırmalarını inceleyin.',
            destination: _Destination.publicRadar,
          ),
          _ModuleData(
            icon: Icons.inventory_2_outlined,
            title: 'Sahte İkiz Sicili',
            description:
                'Şüpheli ve doğrulanmış ikizleri kalıcı dosyalar hâlinde yönetin.',
            destination: _Destination.counterfeitRegistry,
          ),
          _ModuleData(
            icon: Icons.travel_explore_outlined,
            title: 'Marka Dedektifi',
            description:
                'Ürün, satıcı, kanal ve dijital kimlik bağlantılarını araştırın.',
            destination: _Destination.brandDetective,
          ),
          _ModuleData(
            icon: Icons.fact_check_outlined,
            title: 'Vaka ve Delil Merkezi',
            description:
                'Fotoğraf, belge, kaynak ve zaman çizelgesini vaka dosyasında birleştirin.',
            destination: _Destination.caseEvidence,
          ),
        ],
      ),
      _FamilyData(
        number: '04',
        icon: Icons.factory_outlined,
        eyebrow: 'ÜRETİM GÜVENLİĞİ',
        title: 'Üretim ve Tedarik Güvenliği',
        description:
            'Fason üreticileri, tesisleri, üretim varlıklarını ve koruma kontrollerini aynı izlenebilir güvenlik omurgasında yönetin.',
        accent: Color(0xFF315B7A),
        start: Color(0xFFE1EEF6),
        end: Color(0xFFF7FAFC),
        modules: [
          _ModuleData(
            icon: Icons.handshake_outlined,
            title: 'Fason Üretim ve Tedarik Güvenliği',
            description:
                'Üretici, tedarikçi, tesis ve koruma kontrollerini yönetin.',
            destination: _Destination.supplySecurity,
          ),
          _ModuleData(
            icon: Icons.precision_manufacturing_outlined,
            title: 'Kalıp ve Üretim Varlıkları',
            description:
                'Fiziksel ve dijital üretim kabiliyetlerinin yaşam döngüsünü izleyin.',
            destination: _Destination.supplySecurity,
          ),
          _ModuleData(
            icon: Icons.route_outlined,
            title: 'İzlenebilirlik Merkezi',
            description:
                'Üretimden sevkiyata uzanan ürün ve parti zincirini takip edin.',
            destination: _Destination.traceability,
          ),
        ],
      ),
      _FamilyData(
        number: '05',
        icon: Icons.qr_code_2_outlined,
        eyebrow: 'ÜRÜN KİMLİĞİ',
        title: 'Ürün Kimliği ve Doğrulama',
        description:
            'Her ürüne benzersiz kimlik verin; üretim partilerini ve tekil kodları yönetin, tüketicinin ürünü anında doğrulamasını sağlayın.',
        accent: Color(0xFF5A4EA3),
        start: Color(0xFFE9E5FF),
        end: Color(0xFFFAF9FF),
        modules: [
          _ModuleData(
            icon: Icons.category_outlined,
            title: 'Ürünler',
            description:
                'Markaya bağlı ürün portföyünü ve temel kimlik verilerini yönetin.',
            destination: _Destination.products,
          ),
          _ModuleData(
            icon: Icons.layers_outlined,
            title: 'Üretim Partileri',
            description:
                'Parti, üretim ve sevkiyat kayıtlarını izlenebilir biçimde yönetin.',
            destination: _Destination.productionBatches,
          ),
          _ModuleData(
            icon: Icons.pin_outlined,
            title: 'Tekil Ürün Kodları',
            description:
                'Kopyalanması zor, benzersiz ürün kimliklerini oluşturun ve izleyin.',
            destination: _Destination.productCodes,
          ),
          _ModuleData(
            icon: Icons.verified_outlined,
            title: 'Ürün Doğrulama',
            description:
                'QR veya ürün koduyla ürünün kimliğini ve doğrulama kaydını inceleyin.',
            destination: _Destination.productVerification,
          ),
        ],
      ),
    ];

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF061722), Color(0xFF0A2533), Color(0xFF101A3A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 92),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'MARKAKALKAN ÇÖZÜMLERİ',
                style: TextStyle(
                  color: Color(0xFFF0BD5B),
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Beş savunma ailesi, tek bütünleşik platform',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  height: 1.17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 14),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 820),
                child: Text(
                  'Her çözüm ailesi kendi uzmanlık alanında çalışır; kayıtlar, sinyaller ve deliller ortak MarkaKalkan savunma zincirinde birleşir.',
                  style: TextStyle(
                    color: Color(0xFFC7D6DD),
                    fontSize: 16,
                    height: 1.6,
                  ),
                ),
              ),
              const SizedBox(height: 44),
              ...families.map(
                (family) => Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: _FamilyPanel(family: family),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FamilyPanel extends StatelessWidget {
  const _FamilyPanel({required this.family});

  final _FamilyData family;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [family.start, family.end],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: family.accent.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: family.accent.withValues(alpha: 0.08),
            blurRadius: 34,
            spreadRadius: 1,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final heading = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 62,
                    height: 62,
                    decoration: BoxDecoration(
                      color: family.accent,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(family.icon, color: Colors.white, size: 32),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    family.number,
                    style: TextStyle(
                      color: family.accent.withValues(alpha: 0.35),
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                family.eyebrow,
                style: TextStyle(
                  color: family.accent,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.9,
                ),
              ),
              const SizedBox(height: 9),
              Text(
                family.title,
                style: const TextStyle(
                  color: MarkaKalkanTheme.navy,
                  fontSize: 28,
                  height: 1.16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 13),
              Text(
                family.description,
                style: const TextStyle(
                  color: Color(0xFF5F6E78),
                  fontSize: 15,
                  height: 1.6,
                ),
              ),
            ],
          );

          final modules = LayoutBuilder(
            builder: (context, moduleConstraints) {
              final columns = moduleConstraints.maxWidth < 620 ? 1 : 2;
              final itemWidth =
                  (moduleConstraints.maxWidth - ((columns - 1) * 14)) / columns;

              return Wrap(
                spacing: 14,
                runSpacing: 14,
                children: family.modules
                    .map(
                      (module) => SizedBox(
                        width: itemWidth,
                        child: _ModuleTile(
                          module: module,
                          accent: family.accent,
                        ),
                      ),
                    )
                    .toList(growable: false),
              );
            },
          );

          if (constraints.maxWidth < 900) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [heading, const SizedBox(height: 28), modules],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 330, child: heading),
              const SizedBox(width: 34),
              Expanded(child: modules),
            ],
          );
        },
      ),
    );
  }
}

class _ModuleTile extends StatefulWidget {
  const _ModuleTile({required this.module, required this.accent});

  final _ModuleData module;
  final Color accent;

  @override
  State<_ModuleTile> createState() => _ModuleTileState();
}

class _ModuleTileState extends State<_ModuleTile> {
  bool _hovered = false;

  Future<void> _open() async {
    switch (widget.module.destination) {
      case _Destination.ipDocuments:
        return AppRouter.openIpDocumentVault(context);
      case _Destination.creationRegistry:
        return AppRouter.openIpCreationPriorityRegistry(context);
      case _Destination.tradeSecretShield:
        return AppRouter.openIpTradeSecretShield(context);
      case _Destination.digitalMarket:
        return AppRouter.openDijitalPazarIzleme(context);
      case _Destination.monitoringProfiles:
        return AppRouter.openMarkaIzlemeProfili(context);
      case _Destination.riskSignals:
        return AppRouter.openRiskSinyalleri(context);
      case _Destination.aiDetectives:
        return AppRouter.openAiFieldDetectivesHub(context);
      case _Destination.reportCenter:
        return AppRouter.openRaporMerkezi(context);
      case _Destination.publicRadar:
        return AppRouter.openCounterfeitTwinPublicRadar(context);
      case _Destination.counterfeitRegistry:
        return AppRouter.openCounterfeitTwinRegistry(context);
      case _Destination.brandDetective:
        return AppRouter.openBrandDetectiveHub(context);
      case _Destination.caseEvidence:
        return AppRouter.openVakaKanitRaporu(context);
      case _Destination.supplySecurity:
        return AppRouter.openSupplySecurityHub(context);
      case _Destination.traceability:
        return AppRouter.openTraceabilityHub(context);
      case _Destination.products:
        AppRouter.openProducts(context);
        return;
      case _Destination.productionBatches:
        AppRouter.openProductionBatches(context);
        return;
      case _Destination.productCodes:
        AppRouter.openProductCodes(context);
        return;
      case _Destination.productVerification:
        return AppRouter.openProductVerification(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        transform: Matrix4.translationValues(0, _hovered ? -4 : 0, 0),
        decoration: BoxDecoration(
          color: _hovered ? Colors.white : Colors.white.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: widget.accent.withValues(alpha: _hovered ? 0.38 : 0.15),
          ),
          boxShadow: _hovered
              ? [
                  BoxShadow(
                    color: widget.accent.withValues(alpha: 0.13),
                    blurRadius: 20,
                    offset: const Offset(0, 9),
                  ),
                ]
              : const [],
        ),
        child: InkWell(
          onTap: _open,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(19),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 43,
                      height: 43,
                      decoration: BoxDecoration(
                        color: widget.accent.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Icon(
                        widget.module.icon,
                        color: widget.accent,
                        size: 23,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      width: 33,
                      height: 33,
                      decoration: BoxDecoration(
                        color: _hovered
                            ? widget.accent
                            : widget.accent.withValues(alpha: 0.09),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.arrow_forward_rounded,
                        color: _hovered ? Colors.white : widget.accent,
                        size: 18,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  widget.module.title,
                  style: const TextStyle(
                    color: MarkaKalkanTheme.navy,
                    fontSize: 16,
                    height: 1.25,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.module.description,
                  style: const TextStyle(
                    color: Color(0xFF687580),
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

enum _Destination {
  ipDocuments,
  creationRegistry,
  tradeSecretShield,
  digitalMarket,
  monitoringProfiles,
  riskSignals,
  aiDetectives,
  reportCenter,
  publicRadar,
  counterfeitRegistry,
  brandDetective,
  caseEvidence,
  supplySecurity,
  traceability,
  products,
  productionBatches,
  productCodes,
  productVerification,
}

class _FamilyData {
  const _FamilyData({
    required this.number,
    required this.icon,
    required this.eyebrow,
    required this.title,
    required this.description,
    required this.accent,
    required this.start,
    required this.end,
    required this.modules,
  });

  final String number;
  final IconData icon;
  final String eyebrow;
  final String title;
  final String description;
  final Color accent;
  final Color start;
  final Color end;
  final List<_ModuleData> modules;
}

class _ModuleData {
  const _ModuleData({
    required this.icon,
    required this.title,
    required this.description,
    required this.destination,
  });

  final IconData icon;
  final String title;
  final String description;
  final _Destination destination;
}

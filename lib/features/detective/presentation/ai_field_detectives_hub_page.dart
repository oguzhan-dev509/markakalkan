import 'package:flutter/material.dart';
import 'package:markakalkan/app/router.dart';
import 'package:markakalkan/core/theme/markakalkan_theme.dart';

class AiFieldDetectivesHubPage extends StatelessWidget {
  const AiFieldDetectivesHubPage({super.key});

  static const List<_AiFieldAgent> _agents = [
    _AiFieldAgent(
      number: 1,
      title: 'Görev Planlama Ajanı',
      description:
          'Marka, ürün, satıcı veya ihbar için operasyon planı oluşturur; '
          'çalışacak ajanları ve görev sırasını belirler.',
      icon: Icons.account_tree_outlined,
      status: _AgentStatus.foundation,
    ),
    _AiFieldAgent(
      number: 2,
      title: 'Dijital Saha Tarama Ajanı',
      description:
          'Pazaryerleri, sosyal medya, web siteleri ve dijital raflarda '
          'ürün, fiyat, stok, satıcı ve kaynak verisi toplar.',
      icon: Icons.travel_explore_outlined,
      status: _AgentStatus.priority,
    ),
    _AiFieldAgent(
      number: 3,
      title: 'Sayfa Değişim İzleme Ajanı',
      description:
          'Fiyat, stok, başlık, görsel, satıcı ve sayfa durumundaki '
          'değişiklikleri zaman içinde takip eder.',
      icon: Icons.change_circle_outlined,
      status: _AgentStatus.priority,
    ),
    _AiFieldAgent(
      number: 4,
      title: 'Görsel Eşleştirme Ajanı',
      description:
          'Aynı veya değiştirilmiş ürün görsellerini farklı mağaza, hesap '
          've platformlarda eşleştirir.',
      icon: Icons.image_search_outlined,
      status: _AgentStatus.planned,
    ),
    _AiFieldAgent(
      number: 5,
      title: 'Metin ve Dil Analizi Ajanı',
      description:
          'İlan açıklamalarını, riskli ifadeleri, tekrar eden metinleri ve '
          'çok dilli içerikleri analiz eder.',
      icon: Icons.translate_outlined,
      status: _AgentStatus.planned,
    ),
    _AiFieldAgent(
      number: 6,
      title: 'Satıcı ve Varlık Eşleştirme Ajanı',
      description:
          'Telefon, e-posta, adres, IBAN, alan adı, mağaza adı ve diğer '
          'izler üzerinden olası ortak kimlikleri belirler.',
      icon: Icons.hub_outlined,
      status: _AgentStatus.planned,
    ),
    _AiFieldAgent(
      number: 7,
      title: 'Ağ Analizi Ajanı',
      description:
          'Tekil mağazalar yerine bağlantılı satıcı, hesap, şirket ve '
          'dağıtım yapılarını ortaya çıkarır.',
      icon: Icons.schema_outlined,
      status: _AgentStatus.planned,
    ),
    _AiFieldAgent(
      number: 8,
      title: 'Fiyat ve Anomali Ajanı',
      description:
          'Olağan dışı fiyatları, ani düşüşleri, piyasa sapmalarını ve '
          'eşzamanlı hareketleri tespit eder.',
      icon: Icons.monitor_heart_outlined,
      status: _AgentStatus.planned,
    ),
    _AiFieldAgent(
      number: 9,
      title: 'Delil Muhafaza Ajanı',
      description:
          'Ekran görüntüsü, URL, zaman damgası, hash, arşiv ve delil '
          'bütünlüğü kayıtlarını oluşturur.',
      icon: Icons.inventory_2_outlined,
      status: _AgentStatus.priority,
    ),
    _AiFieldAgent(
      number: 10,
      title: 'Risk ve Müdahale Ajanı',
      description:
          'Bulguları risk, yayılma, delil yeterliliği ve müdahale '
          'önceliğine göre puanlar.',
      icon: Icons.policy_outlined,
      status: _AgentStatus.planned,
    ),
    _AiFieldAgent(
      number: 11,
      title: 'Raporlama Ajanı',
      description:
          'Yönetici özeti, vaka kronolojisi, ağ görünümü ve müdahale '
          'dosyası üretir.',
      icon: Icons.summarize_outlined,
      status: _AgentStatus.planned,
    ),
    _AiFieldAgent(
      number: 12,
      title: 'İnsan Uzman Onay Kapısı',
      description:
          'Kritik değerlendirmeleri, dış müdahale adımlarını ve nihai '
          'kararları yetkili insan uzman onayına bağlar.',
      icon: Icons.verified_user_outlined,
      status: _AgentStatus.control,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MarkaKalkanTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text(
          'Yapay Zekâ Saha Dedektifleri',
          style: TextStyle(
            color: MarkaKalkanTheme.navy,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1240),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _AiFieldHeader(),
                const SizedBox(height: 22),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: () async {
                      final operationId =
                          await AppRouter.openAiFieldOperationCreate(context);

                      if (!context.mounted || operationId == null) {
                        return;
                      }

                      ScaffoldMessenger.of(context)
                        ..hideCurrentSnackBar()
                        ..showSnackBar(
                          SnackBar(
                            content: Text(
                              'Operasyon ve 12 ajan görevi oluşturuldu. '
                              'Operasyon No: $operationId',
                            ),
                            duration: const Duration(seconds: 6),
                          ),
                        );
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: MarkaKalkanTheme.teal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 16,
                      ),
                    ),
                    icon: const Icon(Icons.add_circle_outline),
                    label: const Text(
                      'Yeni Operasyon Oluştur',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                const _OperationFlow(),
                const SizedBox(height: 30),
                const Text(
                  'Uzman Ajan Birimleri',
                  style: TextStyle(
                    color: MarkaKalkanTheme.navy,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Her ajan kendi uzmanlık görevini yürütür; çıktılar ortak '
                  'istihbarat zincirinde birleştirilir.',
                  style: TextStyle(
                    color: Color(0xFF687580),
                    fontSize: 15,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 20),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    final columns = width < 650
                        ? 1
                        : width < 980
                        ? 2
                        : 3;

                    const spacing = 18.0;
                    final cardWidth =
                        (width - ((columns - 1) * spacing)) / columns;

                    return Wrap(
                      spacing: spacing,
                      runSpacing: spacing,
                      children: _agents
                          .map(
                            (agent) => SizedBox(
                              width: cardWidth,
                              child: _AiFieldAgentCard(agent: agent),
                            ),
                          )
                          .toList(),
                    );
                  },
                ),
                const SizedBox(height: 26),
                const _HumanControlNotice(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AiFieldHeader extends StatelessWidget {
  const _AiFieldHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [MarkaKalkanTheme.navy, Color(0xFF173C4D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 700;

          const iconBox = _HeaderIcon();
          const content = Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Dijital sahayı ajanlarla tarayın, izi ağa dönüştürün.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 29,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  'Yapay Zekâ Saha Dedektifleri; veri toplama, değişim '
                  'izleme, delil muhafaza, varlık eşleştirme, ağ analizi '
                  've raporlamayı koordineli biçimde yürütür.',
                  style: TextStyle(
                    color: Color(0xFFD9E5EA),
                    fontSize: 15,
                    height: 1.55,
                  ),
                ),
              ],
            ),
          );

          if (isNarrow) {
            return const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                iconBox,
                SizedBox(height: 20),
                Row(children: [content]),
              ],
            );
          }

          return const Row(children: [iconBox, SizedBox(width: 24), content]);
        },
      ),
    );
  }
}

class _HeaderIcon extends StatelessWidget {
  const _HeaderIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 78,
      height: 78,
      decoration: BoxDecoration(
        color: const Color(0xFF254D60),
        borderRadius: BorderRadius.circular(22),
      ),
      child: const Icon(
        Icons.psychology_alt_outlined,
        size: 45,
        color: MarkaKalkanTheme.teal,
      ),
    );
  }
}

class _OperationFlow extends StatelessWidget {
  const _OperationFlow();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE0E7EC)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ortak Operasyon Zinciri',
            style: TextStyle(
              color: MarkaKalkanTheme.navy,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 10),
          Text(
            'Görev oluştur → dijital sahayı tara → değişimi izle → '
            'görsel ve metni karşılaştır → varlıkları eşleştir → ağı '
            'çıkar → delili koru → riski puanla → raporla → uzman onayı',
            style: TextStyle(
              color: Color(0xFF52616B),
              fontSize: 14,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }
}

class _AiFieldAgentCard extends StatelessWidget {
  const _AiFieldAgentCard({required this.agent});

  final _AiFieldAgent agent;

  @override
  Widget build(BuildContext context) {
    final statusLabel = switch (agent.status) {
      _AgentStatus.foundation => 'Orkestrasyon',
      _AgentStatus.priority => 'İlk Faz',
      _AgentStatus.planned => 'Planlandı',
      _AgentStatus.control => 'Zorunlu Kontrol',
    };

    final statusColor = switch (agent.status) {
      _AgentStatus.foundation => const Color(0xFF365E7D),
      _AgentStatus.priority => const Color(0xFF00897B),
      _AgentStatus.planned => const Color(0xFF73808A),
      _AgentStatus.control => const Color(0xFF8A5A00),
    };

    return Container(
      constraints: const BoxConstraints(minHeight: 285),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE0E7EC)),
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
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF5F4),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(agent.icon, color: MarkaKalkanTheme.teal, size: 27),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            '${agent.number.toString().padLeft(2, '0')} · ${agent.title}',
            style: const TextStyle(
              color: MarkaKalkanTheme.navy,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            agent.description,
            style: const TextStyle(
              color: Color(0xFF687580),
              fontSize: 13.5,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Icon(
                agent.status == _AgentStatus.priority
                    ? Icons.rocket_launch_outlined
                    : Icons.settings_suggest_outlined,
                size: 18,
                color: statusColor,
              ),
              const SizedBox(width: 7),
              Text(
                agent.status == _AgentStatus.priority
                    ? 'Geliştirme önceliğinde'
                    : 'Ajan altyapısı hazırlanıyor',
                style: TextStyle(
                  color: statusColor,
                  fontSize: 12,
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

class _HumanControlNotice extends StatelessWidget {
  const _HumanControlNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E8),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE9D8A6)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.gpp_good_outlined, color: Color(0xFF8A5A00)),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Yapay zekâ ajanları veri toplar, karşılaştırır ve öneri '
              'üretir. Kritik ihlâl değerlendirmeleri, dış bildirimler ve '
              'müdahale kararları insan uzman onayı olmadan kesinleştirilmez.',
              style: TextStyle(
                color: Color(0xFF6D5318),
                fontSize: 13.5,
                height: 1.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _AgentStatus { foundation, priority, planned, control }

class _AiFieldAgent {
  const _AiFieldAgent({
    required this.number,
    required this.title,
    required this.description,
    required this.icon,
    required this.status,
  });

  final int number;
  final String title;
  final String description;
  final IconData icon;
  final _AgentStatus status;
}

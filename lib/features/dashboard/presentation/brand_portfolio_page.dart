import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:markakalkan/app/router.dart';
import 'package:markakalkan/core/theme/markakalkan_theme.dart';
import 'package:markakalkan/features/dashboard/data/brand_portfolio_service.dart';

class BrandPortfolioPage extends StatefulWidget {
  const BrandPortfolioPage({super.key});
  @override
  State<BrandPortfolioPage> createState() => _BrandPortfolioPageState();
}

class _BrandPortfolioPageState extends State<BrandPortfolioPage> {
  final _service = BrandPortfolioService();
  late Future<List<BrandPortfolioItem>> _future;
  @override
  void initState() {
    super.initState();
    _future = _service.listMyApplications();
  }

  void _reload() => setState(() => _future = _service.listMyApplications());
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MarkaKalkanTheme.background,
      appBar: AppBar(
        title: const Text('Markalarım'),
        actions: [
          IconButton(
            onPressed: _reload,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => AppRouter.openBrandApplication(context),
        icon: const Icon(Icons.add_business_outlined),
        label: const Text('Yeni Marka Ekle'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(30),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [MarkaKalkanTheme.navy, Color(0xFF183B4E)],
                      ),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Column(
                      children: [
                        Icon(
                          Icons.verified_outlined,
                          color: MarkaKalkanTheme.teal,
                          size: 46,
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Bir marka güçlenir, bir ekonomi harekete geçer.',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 29,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Marka portföyünüzü yönetin, pazar güvenini büyütün ve şirketinizin üretim, yatırım ve küresel değer yaratan en güçlü varlığını koruyun.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFFD9E5EA),
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  FutureBuilder<List<BrandPortfolioItem>>(
                    future: _future,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(40),
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }
                      if (snapshot.hasError) {
                        final message =
                            snapshot.error is FirebaseFunctionsException
                            ? ((snapshot.error as FirebaseFunctionsException)
                                      .message ??
                                  'Marka listeniz yüklenemedi.')
                            : 'Marka listeniz yüklenemedi.';
                        return _MessageCard(
                          icon: Icons.error_outline_rounded,
                          title: message,
                          buttonText: 'Yeniden Dene',
                          onPressed: _reload,
                        );
                      }
                      final items = snapshot.data ?? const [];
                      if (items.isEmpty) {
                        return _MessageCard(
                          icon: Icons.add_business_outlined,
                          title: 'Henüz marka başvurunuz bulunmuyor.',
                          buttonText: 'Yeni Marka Ekle',
                          onPressed: () =>
                              AppRouter.openBrandApplication(context),
                        );
                      }
                      return Wrap(
                        spacing: 18,
                        runSpacing: 18,
                        children: items
                            .map(
                              (item) => SizedBox(
                                width: 520,
                                child: _BrandCard(item: item),
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
        ],
      ),
    );
  }
}

class _BrandCard extends StatelessWidget {
  const _BrandCard({required this.item});
  final BrandPortfolioItem item;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFFE0E7EC)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.verified_outlined, color: MarkaKalkanTheme.teal),
            const Spacer(),
            Chip(label: Text(_label(item.status))),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          item.brandName.isEmpty ? 'Adsız marka başvurusu' : item.brandName,
          style: const TextStyle(
            color: MarkaKalkanTheme.navy,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        if (item.companyName.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            item.companyName,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
        if (item.sector.isNotEmpty || item.businessType.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            [
              item.sector,
              item.businessType,
            ].where((e) => e.isNotEmpty).join(' • '),
            style: const TextStyle(color: Color(0xFF687580)),
          ),
        ],
      ],
    ),
  );
  static String _label(String value) {
    switch (value.toLowerCase()) {
      case 'approved':
      case 'active':
        return 'Onaylandı';
      case 'rejected':
        return 'Reddedildi';
      case 'under_review':
      case 'reviewing':
        return 'İnceleniyor';
      default:
        return 'Başvuru Bekliyor';
    }
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({
    required this.icon,
    required this.title,
    required this.buttonText,
    required this.onPressed,
  });
  final IconData icon;
  final String title, buttonText;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(36),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFFE0E7EC)),
    ),
    child: Column(
      children: [
        Icon(icon, size: 48, color: MarkaKalkanTheme.teal),
        const SizedBox(height: 14),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: MarkaKalkanTheme.navy,
            fontSize: 19,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 18),
        OutlinedButton(onPressed: onPressed, child: Text(buttonText)),
      ],
    ),
  );
}

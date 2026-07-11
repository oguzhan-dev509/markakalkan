import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:markakalkan/app/router.dart';
import 'package:markakalkan/core/theme/markakalkan_theme.dart';
import 'package:markakalkan/modules/marka_kalkan/sahte_ikiz_sicili/models/counterfeit_twin_public_contract.dart';
import 'package:markakalkan/modules/marka_kalkan/sahte_ikiz_sicili/models/counterfeit_twin_radar_contract.dart';

import 'counterfeit_twin_public_detail_page.dart';
import 'counterfeit_twin_report_dialog.dart';

class CounterfeitTwinPublicRadarPage extends StatefulWidget {
  const CounterfeitTwinPublicRadarPage({super.key});

  @override
  State<CounterfeitTwinPublicRadarPage> createState() =>
      _CounterfeitTwinPublicRadarPageState();
}

class _CounterfeitTwinPublicRadarPageState
    extends State<CounterfeitTwinPublicRadarPage> {
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: 'europe-west3',
  );

  List<CounterfeitTwinPublicDetail> _comparisons =
      const <CounterfeitTwinPublicDetail>[];
  String _selectedCategory = 'all';
  String _selectedSubcategory = 'all';
  bool _isLoading = true;
  String? _error;

  List<CounterfeitTwinPublicDetail> get _categoryComparisons {
    if (_selectedCategory == 'all') return _comparisons;
    return _comparisons
        .where((item) => item.publicCategory.value == _selectedCategory)
        .toList(growable: false);
  }

  List<CounterfeitTwinPublicDetail> get _visibleComparisons {
    if (_selectedSubcategory == 'all') return _categoryComparisons;
    return _categoryComparisons
        .where((item) => item.publicSubcategory == _selectedSubcategory)
        .toList(growable: false);
  }

  List<CounterfeitTwinPublicSubcategory> get _subcategoryFilters {
    if (_selectedCategory == 'all') {
      return const <CounterfeitTwinPublicSubcategory>[];
    }
    final section = CounterfeitTwinPublicSection.values.firstWhere(
      (item) => item.value == _selectedCategory,
    );
    return CounterfeitTwinPublicSubcategory.forSection(section);
  }

  bool _isOpeningReport = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = await _functions
          .httpsCallable('listPublicCounterfeitTwinComparisons')
          .call<dynamic>(const <String, dynamic>{});
      final data = result.data;
      final raw = data is Map ? data['comparisons'] : data;
      final parsed = <CounterfeitTwinPublicDetail>[];

      if (raw is List) {
        for (final item in raw) {
          if (item is Map) {
            parsed.add(CounterfeitTwinPublicDetail.fromMap(item));
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _comparisons = parsed;
        _isLoading = false;
        if (!_subcategoryFilters.any(
          (item) => item.value == _selectedSubcategory,
        )) {
          _selectedSubcategory = 'all';
        }
      });
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = error.message ?? 'Karşılaştırmalar yüklenemedi.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Karşılaştırmalar şu anda yüklenemiyor.';
      });
    }
  }

  Future<void> _openReport() async {
    if (_isOpeningReport) return;
    _isOpeningReport = true;

    try {
      final auth = FirebaseAuth.instance;

      if (auth.currentUser == null) {
        final shouldLogin = await showDialog<bool>(
          context: context,
          useRootNavigator: true,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Bildirim için giriş gerekli'),
            content: const Text(
              'Sahte ikiz bildirimini güvenli biçimde göndermek ve '
              'başvuru kimliği almak için önce MarkaKalkan hesabınızla '
              'giriş yapmalısınız.',
            ),
            actions: [
              TextButton(
                onPressed: () =>
                    Navigator.of(dialogContext, rootNavigator: true).pop(false),
                child: const Text('Vazgeç'),
              ),
              FilledButton(
                onPressed: () =>
                    Navigator.of(dialogContext, rootNavigator: true).pop(true),
                child: const Text('Giriş Yap'),
              ),
            ],
          ),
        );

        if (shouldLogin != true || !mounted) return;

        await AppRouter.openBrandLogin(context);
        if (!mounted) return;

        if (auth.currentUser == null) {
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
      if (!mounted || reportId == null) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Bildiriminiz incelemeye alındı. Başvuru: $reportId'),
        ),
      );
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message ?? 'Bildirim formu şu anda açılamıyor.'),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Bildirim formu şu anda açılamıyor. Lütfen yeniden deneyin.',
          ),
        ),
      );
    } finally {
      _isOpeningReport = false;
    }
  }

  void _selectCategory(String value) {
    setState(() {
      _selectedCategory = value;
      _selectedSubcategory = 'all';
    });
  }

  Future<void> _openDetail(CounterfeitTwinPublicDetail comparison) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: RouteSettings(name: comparison.canonicalPath),
        builder: (_) => CounterfeitTwinPublicDetailPage(
          slug: comparison.slug,
          initialDetail: comparison,
        ),
      ),
    );
  }

  int _categoryCount(String value) {
    return _comparisons
        .where((item) => item.publicCategory.value == value)
        .length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F8),
      appBar: AppBar(
        title: const Text('Sahte İkiz Radarı'),
        actions: [
          TextButton.icon(
            onPressed: _openReport,
            icon: const Icon(Icons.report_outlined),
            label: const Text('Sahte İkiz Bildir'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _buildHero()),
            SliverToBoxAdapter(child: _buildCategoryCards()),
            SliverToBoxAdapter(child: _buildFilters()),
            if (_isLoading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _ErrorState(message: _error!, onRetry: _load),
              )
            else if (_visibleComparisons.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _EmptyState(
                  onReport: _openReport,
                  selectedCategory: _selectedCategory,
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 48),
                sliver: SliverList.separated(
                  itemCount: _visibleComparisons.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final item = _visibleComparisons[index];
                    return _ComparisonCard(
                      comparison: item,
                      onOpen: () => _openDetail(item),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openReport,
        icon: const Icon(Icons.add_alert_outlined),
        label: const Text('Sahte İkiz Bildir'),
      ),
    );
  }

  Widget _buildHero() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [MarkaKalkanTheme.navy, Color(0xFF1C5260)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 52),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: const Column(
            children: [
              Icon(Icons.radar_outlined, size: 72, color: Color(0xFFBCE7E3)),
              SizedBox(height: 18),
              Text(
                'Gerçek Ürün – Sahte İkiz Karşılaştırmaları',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  height: 1.2,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 14),
              Text(
                'Gerçeği doğrula, sahte ikizi görünür kıl.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFFBCE7E3),
                  fontSize: 20,
                  height: 1.4,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 12),
              Text(
                'Fiziksel ürünlerden dijital platformlara, yapay zekâ '
                'ajanlarından robotik sistemlere kadar doğrulanmış '
                'karşılaştırmaları inceleyin.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFFD9E5EA),
                  fontSize: 16,
                  height: 1.55,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryCards() {
    final cards = <_CategoryCardData>[
      _CategoryCardData(
        value: 'physical',
        title: 'Fiziksel Sahte İkizler',
        description:
            'Ürün, ambalaj, etiket, parça ve diğer somut varlık taklitleri.',
        icon: Icons.inventory_2_outlined,
        accent: const Color(0xFF167D71),
        background: const Color(0xFFEAF7F4),
        count: _categoryCount('physical'),
        subcategories: CounterfeitTwinPublicSubcategory.forSection(
          CounterfeitTwinPublicSection.physical,
        ).map((item) => item.label).toList(growable: false),
      ),
      _CategoryCardData(
        value: 'digital',
        title: 'Dijital Sahte İkizler',
        description:
            'Web sitesi, uygulama, platform, ödeme ve hizmet taklitleri.',
        icon: Icons.language_outlined,
        accent: const Color(0xFF1769AA),
        background: const Color(0xFFEAF3FB),
        count: _categoryCount('digital'),
        subcategories: CounterfeitTwinPublicSubcategory.forSection(
          CounterfeitTwinPublicSection.digital,
        ).map((item) => item.label).toList(growable: false),
      ),
      _CategoryCardData(
        value: 'ai_robot',
        title: 'Yapay Zekâ ve Robot Sahte İkizleri',
        description:
            'Robot, dijital ajan, ses, persona ve otonom sistem taklitleri.',
        icon: Icons.smart_toy_outlined,
        accent: const Color(0xFF6941C6),
        background: const Color(0xFFF2EEFF),
        count: _categoryCount('ai_robot'),
        subcategories: CounterfeitTwinPublicSubcategory.forSection(
          CounterfeitTwinPublicSection.aiRobot,
        ).map((item) => item.label).toList(growable: false),
      ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 8),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth >= 900
                  ? (constraints.maxWidth - 32) / 3
                  : constraints.maxWidth >= 620
                  ? (constraints.maxWidth - 16) / 2
                  : constraints.maxWidth;
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: cards
                    .map(
                      (data) => SizedBox(
                        width: width,
                        child: _CategoryCard(
                          data: data,
                          selected: _selectedCategory == data.value,
                          onTap: () => _selectCategory(data.value),
                        ),
                      ),
                    )
                    .toList(growable: false),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Doğrulanmış karşılaştırmalar',
                      style: TextStyle(
                        color: MarkaKalkanTheme.navy,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  if (_selectedCategory != 'all')
                    TextButton.icon(
                      onPressed: () => _selectCategory('all'),
                      icon: const Icon(Icons.grid_view_outlined),
                      label: const Text('Tüm ana kategoriler'),
                    ),
                ],
              ),
              if (_selectedCategory == 'all') ...[
                const SizedBox(height: 10),
                const Text(
                  'Alt kategorileri görmek için yukarıdaki üç ana '
                  'kategoriden birini seçin.',
                  style: TextStyle(color: Color(0xFF667085), height: 1.5),
                ),
              ] else ...[
                const SizedBox(height: 14),
                const Text(
                  'Alt kategoriler',
                  style: TextStyle(
                    color: MarkaKalkanTheme.navy,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    ChoiceChip(
                      label: const Text('Bu bölümdeki tüm kayıtlar'),
                      selected: _selectedSubcategory == 'all',
                      onSelected: (_) {
                        setState(() => _selectedSubcategory = 'all');
                      },
                    ),
                    ..._subcategoryFilters.map(
                      (subcategory) => ChoiceChip(
                        label: Text(subcategory.label),
                        selected: _selectedSubcategory == subcategory.value,
                        onSelected: (_) {
                          setState(
                            () => _selectedSubcategory = subcategory.value,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryCardData {
  const _CategoryCardData({
    required this.value,
    required this.title,
    required this.description,
    required this.icon,
    required this.accent,
    required this.background,
    required this.count,
    required this.subcategories,
  });

  final String value;
  final String title;
  final String description;
  final IconData icon;
  final Color accent;
  final Color background;
  final int count;
  final List<String> subcategories;
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.data,
    required this.selected,
    required this.onTap,
  });

  final _CategoryCardData data;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: data.background,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          constraints: const BoxConstraints(minHeight: 355),
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: selected
                  ? data.accent
                  : data.accent.withValues(alpha: 0.18),
              width: selected ? 2.2 : 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: data.accent.withValues(alpha: selected ? 0.16 : 0.07),
                blurRadius: selected ? 22 : 12,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(17),
                    ),
                    child: Icon(data.icon, color: data.accent, size: 30),
                  ),
                  const Spacer(),
                  Chip(label: Text('${data.count} kayıt')),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                data.title,
                style: const TextStyle(
                  color: MarkaKalkanTheme.navy,
                  fontSize: 20,
                  height: 1.25,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                data.description,
                style: const TextStyle(color: Color(0xFF475467), height: 1.5),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: <Widget>[
                  ...data.subcategories
                      .take(4)
                      .map(
                        (label) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.78),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            label,
                            style: TextStyle(
                              color: data.accent,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                  if (data.subcategories.length > 4)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.78),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '+${data.subcategories.length - 4} kategori',
                        style: TextStyle(
                          color: data.accent,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                ],
              ),
              const Spacer(),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text(
                    'Karşılaştırmaları incele',
                    style: TextStyle(
                      color: data.accent,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(Icons.arrow_forward_rounded, color: data.accent),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ComparisonCard extends StatelessWidget {
  const _ComparisonCard({required this.comparison, required this.onOpen});

  final CounterfeitTwinPublicDetail comparison;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100),
        child: Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onOpen,
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Chip(label: Text(_targetLabel(comparison.targetType))),
                      if (comparison.publicSubcategory.isNotEmpty)
                        Chip(
                          label: Text(
                            _subcategoryLabel(comparison.publicSubcategory),
                          ),
                        ),
                      if (comparison.robotType.isNotEmpty)
                        Chip(label: Text(_robotLabel(comparison.robotType))),
                      if (comparison.publicRecordCode.isNotEmpty)
                        Chip(
                          avatar: const Icon(Icons.verified_outlined, size: 17),
                          label: Text(comparison.publicRecordCode),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    comparison.title.isNotEmpty
                        ? comparison.title
                        : comparison.comparisonLabel,
                    style: const TextStyle(
                      color: MarkaKalkanTheme.navy,
                      fontSize: 21,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 16),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final original = _IdentityPanel(
                        title: 'Gerçek',
                        name: comparison.originalDisplayName,
                        imageUrls: comparison.originalImageUrls,
                        background: const Color(0xFFEAF7F4),
                      );
                      final suspected = _IdentityPanel(
                        title: 'Sahte / Şüpheli İkiz',
                        name: comparison.suspectedDisplayName,
                        imageUrls: comparison.suspectedImageUrls,
                        background: const Color(0xFFFFF4E8),
                      );
                      if (constraints.maxWidth < 680) {
                        return Column(
                          children: [
                            original,
                            const SizedBox(height: 12),
                            suspected,
                          ],
                        );
                      }
                      return Row(
                        children: [
                          Expanded(child: original),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 14),
                            child: Icon(Icons.compare_arrows_outlined),
                          ),
                          Expanded(child: suspected),
                        ],
                      );
                    },
                  ),
                  if (comparison.differenceNotes.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    ...comparison.differenceNotes
                        .take(4)
                        .map((note) => Text('• $note')),
                  ],
                  const SizedBox(height: 14),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: onOpen,
                      icon: const Icon(Icons.open_in_new),
                      label: const Text('Doğrulanmış kaydı aç'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _IdentityPanel extends StatelessWidget {
  const _IdentityPanel({
    required this.title,
    required this.name,
    required this.imageUrls,
    required this.background,
  });

  final String title;
  final String name;
  final List<String> imageUrls;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 150),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          _PreviewImage(url: imageUrls.isEmpty ? '' : imageUrls.first),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF667085),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  name.isEmpty ? 'Ad bilgisi yayımlanmadı' : name,
                  style: const TextStyle(
                    color: MarkaKalkanTheme.navy,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
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

class _PreviewImage extends StatelessWidget {
  const _PreviewImage({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      width: 82,
      height: 82,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Icon(
        Icons.image_outlined,
        color: Color(0xFF98A2B3),
        size: 30,
      ),
    );

    if (url.isEmpty) return placeholder;
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Image.network(
        url,
        width: 82,
        height: 82,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => placeholder,
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onReport, required this.selectedCategory});

  final VoidCallback onReport;
  final String selectedCategory;

  @override
  Widget build(BuildContext context) {
    final category = switch (selectedCategory) {
      'physical' => 'fiziksel',
      'digital' => 'dijital',
      'ai_robot' => 'yapay zekâ ve robot',
      _ => '',
    };
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.fact_check_outlined,
                size: 64,
                color: MarkaKalkanTheme.teal,
              ),
              const SizedBox(height: 18),
              Text(
                category.isEmpty
                    ? 'Yayımlanmış karşılaştırma henüz bulunmuyor'
                    : 'Yayımlanmış $category karşılaştırması henüz yok',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: MarkaKalkanTheme.navy,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Kayıtlar delilleri doğrulandıktan sonra burada yayımlanır.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onReport,
                icon: const Icon(Icons.report_outlined),
                label: const Text('Sahte İkiz Bildir'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              size: 56,
              color: Color(0xFFB42318),
            ),
            const SizedBox(height: 14),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Yeniden Dene'),
            ),
          ],
        ),
      ),
    );
  }
}

String _subcategoryLabel(String value) {
  return CounterfeitTwinPublicSubcategory.fromValue(value).label;
}

String _targetLabel(String value) {
  const labels = <String, String>{
    'physical_product': 'Fiziksel ürün',
    'digital_product': 'Dijital ürün',
    'service': 'Hizmet',
    'saas_platform': 'SaaS platformu',
    'ecommerce_platform': 'E-ticaret platformu',
    'marketplace_store': 'Pazaryeri mağazası',
    'tourism_booking_platform': 'Turizm / rezervasyon',
    'financial_service': 'Finansal hizmet',
    'payment_page': 'Ödeme sayfası',
    'mobile_application': 'Mobil uygulama',
    'website': 'Web sitesi',
    'social_media_account': 'Sosyal medya hesabı',
    'customer_support_channel': 'Müşteri destek kanalı',
    'institution': 'Kurum / şirket',
    'robotic_system': 'Robotik sistem',
    'autonomous_ai_agent': 'Otonom yapay zekâ ajanı',
    'other': 'Diğer',
  };
  return labels[value] ?? value;
}

String _robotLabel(String value) {
  const labels = <String, String>{
    'industrial_robot': 'Endüstriyel robot',
    'service_robot': 'Hizmet robotu',
    'humanoid_robot': 'İnsansı robot',
    'medical_robot': 'Tıbbi robot',
    'logistics_robot': 'Lojistik robotu',
    'security_robot': 'Güvenlik robotu',
    'domestic_robot': 'Ev tipi robot',
    'robotic_device': 'Robotik cihaz',
    'software_robot': 'Yazılım robotu / ajan',
    'other': 'Diğer',
  };
  return labels[value] ?? value;
}

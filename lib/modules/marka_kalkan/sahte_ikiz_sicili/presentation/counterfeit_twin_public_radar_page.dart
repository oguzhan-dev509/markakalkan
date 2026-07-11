import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:markakalkan/core/theme/markakalkan_theme.dart';
import 'package:markakalkan/features/auth/presentation/brand_login_page.dart';

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

  List<_PublicComparison> _comparisons = const <_PublicComparison>[];
  String _selectedTarget = 'all';
  bool _isLoading = true;
  String? _error;

  List<_PublicComparison> get _visibleComparisons {
    if (_selectedTarget == 'all') return _comparisons;
    return _comparisons
        .where((item) => item.targetType == _selectedTarget)
        .toList(growable: false);
  }

  List<String> get _targetFilters {
    final values =
        _comparisons
            .map((item) => item.targetType)
            .where((item) => item.isNotEmpty)
            .toSet()
            .toList(growable: false)
          ..sort();
    return <String>['all', ...values];
  }

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
      final parsed = <_PublicComparison>[];

      if (raw is List) {
        for (final item in raw) {
          if (item is Map) {
            parsed.add(
              _PublicComparison.fromMap(Map<String, dynamic>.from(item)),
            );
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _comparisons = parsed;
        _isLoading = false;
        if (!_targetFilters.contains(_selectedTarget)) {
          _selectedTarget = 'all';
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
    if (FirebaseAuth.instance.currentUser == null) {
      final shouldLogin = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Bildirim için giriş gerekli'),
          content: const Text(
            'Sahte ikiz bildirimini güvenli biçimde göndermek için '
            'önce MarkaKalkan hesabınızla giriş yapmalısınız.',
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

      if (shouldLogin != true || !mounted) return;
      await Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const BrandLoginPage()));
      if (!mounted) return;

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
    if (!mounted || reportId == null) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Bildiriminiz incelemeye alındı. Başvuru: $reportId'),
      ),
    );
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
                child: _EmptyState(onReport: _openReport),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 48),
                sliver: SliverList.separated(
                  itemCount: _visibleComparisons.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    return _ComparisonCard(
                      comparison: _visibleComparisons[index],
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
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 1040),
          child: Column(
            children: [
              Icon(Icons.radar_outlined, size: 68, color: Color(0xFFBCE7E3)),
              SizedBox(height: 18),
              Text(
                'Gerçek Ürün – Sahte İkiz Karşılaştırmaları',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  height: 1.2,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 14),
              Text(
                'Doğrulanmış ürün, platform, hizmet, finans, turizm, '
                'robot ve otonom ajan taklitlerini inceleyin.',
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

  Widget _buildFilters() {
    if (_comparisons.isEmpty) return const SizedBox(height: 20);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1040),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _targetFilters
                .map((target) {
                  return ChoiceChip(
                    label: Text(
                      target == 'all' ? 'Tümü' : _targetLabel(target),
                    ),
                    selected: _selectedTarget == target,
                    onSelected: (_) {
                      setState(() => _selectedTarget = target);
                    },
                  );
                })
                .toList(growable: false),
          ),
        ),
      ),
    );
  }
}

class _PublicComparison {
  const _PublicComparison({
    required this.title,
    required this.comparisonLabel,
    required this.targetType,
    required this.originalEntityName,
    required this.suspectedEntityName,
    required this.originalBrandName,
    required this.suspectedBrandName,
    required this.platformName,
    required this.robotType,
    required this.incidentTypes,
    required this.differenceNotes,
    required this.hasMonetaryLoss,
    required this.lossAmount,
    required this.currency,
  });

  factory _PublicComparison.fromMap(Map<String, dynamic> map) {
    final financial = map['financialImpactSummary'] is Map
        ? Map<String, dynamic>.from(map['financialImpactSummary'] as Map)
        : const <String, dynamic>{};

    return _PublicComparison(
      title: _string(map['title']),
      comparisonLabel: _string(map['comparisonLabel']),
      targetType: _string(map['targetType'], fallback: 'other'),
      originalEntityName: _string(
        map['originalEntityName'],
        fallback: _string(map['originalProductName']),
      ),
      suspectedEntityName: _string(
        map['suspectedEntityName'],
        fallback: _string(map['suspectedProductName']),
      ),
      originalBrandName: _string(map['originalBrandName']),
      suspectedBrandName: _string(map['suspectedBrandName']),
      platformName: _string(map['platformName']),
      robotType: _string(map['robotType']),
      incidentTypes: _stringList(map['incidentTypes']),
      differenceNotes: _stringList(map['differenceNotes']),
      hasMonetaryLoss: financial['hasMonetaryLoss'] == true,
      lossAmount: _number(financial['lossAmount']),
      currency: _string(financial['currency'], fallback: 'TRY'),
    );
  }

  final String title;
  final String comparisonLabel;
  final String targetType;
  final String originalEntityName;
  final String suspectedEntityName;
  final String originalBrandName;
  final String suspectedBrandName;
  final String platformName;
  final String robotType;
  final List<String> incidentTypes;
  final List<String> differenceNotes;
  final bool hasMonetaryLoss;
  final double? lossAmount;
  final String currency;
}

class _ComparisonCard extends StatelessWidget {
  const _ComparisonCard({required this.comparison});

  final _PublicComparison comparison;

  @override
  Widget build(BuildContext context) {
    final originalName = comparison.originalEntityName.isNotEmpty
        ? comparison.originalEntityName
        : comparison.originalBrandName;
    final suspectedName = comparison.suspectedEntityName.isNotEmpty
        ? comparison.suspectedEntityName
        : comparison.suspectedBrandName;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1040),
        child: Card(
          margin: EdgeInsets.zero,
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
                    if (comparison.robotType.isNotEmpty)
                      Chip(label: Text(_robotLabel(comparison.robotType))),
                    if (comparison.platformName.isNotEmpty)
                      Chip(label: Text(comparison.platformName)),
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
                    final left = _IdentityPanel(
                      title: 'Gerçek',
                      name: originalName,
                      background: const Color(0xFFEAF7F4),
                    );
                    final right = _IdentityPanel(
                      title: 'Sahte / Şüpheli İkiz',
                      name: suspectedName,
                      background: const Color(0xFFFFF4E8),
                    );

                    if (constraints.maxWidth < 680) {
                      return Column(
                        children: [left, const SizedBox(height: 12), right],
                      );
                    }

                    return Row(
                      children: [
                        Expanded(child: left),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 14),
                          child: Icon(Icons.compare_arrows_outlined),
                        ),
                        Expanded(child: right),
                      ],
                    );
                  },
                ),
                if (comparison.incidentTypes.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: comparison.incidentTypes
                        .map(
                          (item) => Chip(
                            label: Text(_incidentLabel(item)),
                            visualDensity: VisualDensity.compact,
                          ),
                        )
                        .toList(growable: false),
                  ),
                ],
                if (comparison.differenceNotes.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Belirlenen farklar',
                    style: TextStyle(
                      color: MarkaKalkanTheme.navy,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...comparison.differenceNotes
                      .take(6)
                      .map(
                        (note) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text('• $note'),
                        ),
                      ),
                ],
                if (comparison.hasMonetaryLoss) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF5F4),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      comparison.lossAmount == null
                          ? 'Bu vaka için maddi kayıp bildirilmiştir.'
                          : 'Bildirilen maddi kayıp: '
                                '${comparison.lossAmount!.toStringAsFixed(2)} '
                                '${comparison.currency}',
                      style: const TextStyle(
                        color: Color(0xFFB42318),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ],
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
    required this.background,
  });

  final String title;
  final String name;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 110),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
      ),
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
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onReport});

  final VoidCallback onReport;

  @override
  Widget build(BuildContext context) {
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
              const Text(
                'Yayımlanmış karşılaştırma henüz bulunmuyor',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: MarkaKalkanTheme.navy,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Bildirilen kayıtlar MarkaKalkan tarafından incelendikten '
                've delilleri doğrulandıktan sonra burada yayımlanır.',
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

String _string(Object? value, {String fallback = ''}) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

double? _number(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '');
}

List<String> _stringList(Object? value) {
  if (value is! List) return const <String>[];
  return value
      .map((item) => item?.toString().trim() ?? '')
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
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

String _incidentLabel(String value) {
  const labels = <String, String>{
    'product_imitation': 'Ürün taklidi',
    'brand_impersonation': 'Marka kimliği taklidi',
    'platform_impersonation': 'Platform kimliği taklidi',
    'website_clone': 'Web sitesi klonu',
    'mobile_app_impersonation': 'Mobil uygulama taklidi',
    'interface_clone': 'Arayüz klonu',
    'fake_checkout': 'Sahte ödeme adımı',
    'fake_payment_page': 'Sahte ödeme sayfası',
    'fake_subscription': 'Sahte abonelik',
    'fake_reservation': 'Sahte rezervasyon',
    'fake_financial_service': 'Sahte finansal hizmet',
    'fake_investment_service': 'Sahte yatırım hizmeti',
    'fake_customer_support': 'Sahte müşteri desteği',
    'credential_phishing': 'Kimlik bilgisi avı',
    'payment_diversion': 'Ödeme yönlendirme',
    'iban_diversion': 'IBAN yönlendirme',
    'merchant_identity_deception': 'İşyeri kimliği yanıltması',
    'unauthorized_card_charge': 'Yetkisiz kart işlemi',
    'personal_data_harvesting': 'Kişisel veri toplama',
    'counterfeit_robot_hardware': 'Sahte robot donanımı',
    'robot_identity_clone': 'Robot kimliği klonu',
    'serial_number_clone': 'Seri numarası klonu',
    'device_certificate_clone': 'Cihaz sertifikası klonu',
    'control_software_clone': 'Kontrol yazılımı klonu',
    'firmware_clone': 'Firmware klonu',
    'fake_robot_certification': 'Sahte robot sertifikası',
    'teleoperation_channel_impersonation': 'Uzaktan kontrol kanalı taklidi',
    'robot_fleet_impersonation': 'Robot filosu kimliği taklidi',
    'ai_agent_impersonation': 'Yapay zekâ ajanı taklidi',
    'voice_persona_clone': 'Ses / persona klonu',
    'fake_robot_service_network': 'Sahte robot servis ağı',
    'other': 'Diğer',
  };
  return labels[value] ?? value;
}

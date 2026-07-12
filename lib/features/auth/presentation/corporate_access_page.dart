import 'package:flutter/material.dart';
import 'package:markakalkan/app/router.dart';
import 'package:markakalkan/core/theme/markakalkan_theme.dart';
import 'package:markakalkan/features/auth/data/corporate_access_service.dart';

class CorporateAccessPage extends StatefulWidget {
  const CorporateAccessPage({super.key});

  @override
  State<CorporateAccessPage> createState() => _CorporateAccessPageState();
}

class _CorporateAccessPageState extends State<CorporateAccessPage> {
  final CorporateAccessService _service = CorporateAccessService();
  late Future<CorporateAccessSnapshot> _future;
  bool _redirectScheduled = false;

  @override
  void initState() {
    super.initState();
    _future = _service.getMyAccess();
  }

  void _reload() {
    setState(() {
      _redirectScheduled = false;
      _future = _service.getMyAccess();
    });
  }

  void _openHub() {
    if (_redirectScheduled) return;
    _redirectScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) AppRouter.openCorporateHub(context);
    });
  }

  Future<void> _openApplication() async {
    await AppRouter.openBrandApplication(context);
    if (mounted) _reload();
  }

  Future<void> _openPortfolio() async {
    await AppRouter.openBrandPortfolio(context);
    if (mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MarkaKalkanTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text(
          'Kurumsal Erişim',
          style: TextStyle(
            color: MarkaKalkanTheme.navy,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: FutureBuilder<CorporateAccessSnapshot>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || snapshot.data == null) {
            return _message(
              Icons.cloud_off_outlined,
              'Kurumsal erişim doğrulanamadı',
              'Kurumsal erişim bilgisi alınamadı. Lütfen yeniden deneyin.',
              'Yeniden Dene',
              _reload,
            );
          }

          final access = snapshot.data!;
          if (access.accessGranted && access.state == 'active') {
            _openHub();
            return const Center(child: CircularProgressIndicator());
          }

          switch (access.state) {
            case 'pending':
              return _message(
                Icons.hourglass_top_rounded,
                'Başvurunuz bekliyor',
                'Marka veya şirket yetkisi başvurunuz alınmıştır.',
                'Başvurularımı Görüntüle',
                _openPortfolio,
              );
            case 'under_review':
              return _message(
                Icons.manage_search_outlined,
                'Başvurunuz inceleniyor',
                'Yetki ve sahiplik belgeleriniz incelenmektedir.',
                'Başvurularımı Görüntüle',
                _openPortfolio,
              );
            case 'rejected':
              final note = access.application?.reviewNote ?? '';
              return _message(
                Icons.assignment_late_outlined,
                'Başvurunuz onaylanmadı',
                note.isEmpty
                    ? 'Bilgilerinizi güncelleyerek yeni başvuru yapabilirsiniz.'
                    : 'İnceleme notu: $note',
                'Yeni Başvuru Yap',
                _openApplication,
              );
            case 'approved_pending_activation':
              return _message(
                Icons.sync_outlined,
                'Kurumsal alanınız hazırlanıyor',
                'Başvurunuz onaylandı; kurumsal kaydınız etkinleşiyor.',
                'Durumu Yenile',
                _reload,
              );
            case 'inactive':
              return _message(
                Icons.pause_circle_outline,
                'Kurumsal erişim etkin değil',
                'Marka kaydınız var ancak erişim durumu etkin değil.',
                'Durumu Yenile',
                _reload,
              );
            default:
              return _message(
                Icons.add_business_outlined,
                'Kurumsal yetki başvurusu gerekli',
                'Marka veya şirket yönetimi için yetki başvurusu yapın.',
                'Yetki Başvurusu Yap',
                _openApplication,
              );
          }
        },
      ),
    );
  }

  Widget _message(
    IconData icon,
    String title,
    String description,
    String buttonText,
    VoidCallback onPressed,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFE0E7EC)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 58, color: MarkaKalkanTheme.teal),
                const SizedBox(height: 18),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: MarkaKalkanTheme.navy,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                Text(description, textAlign: TextAlign.center),
                const SizedBox(height: 24),
                FilledButton(onPressed: onPressed, child: Text(buttonText)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

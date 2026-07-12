import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:markakalkan/app/router.dart';
import 'package:markakalkan/core/theme/markakalkan_theme.dart';
import 'package:markakalkan/features/auth/domain/markakalkan_auth_intent.dart';
import 'package:markakalkan/features/auth/data/brand_auth_service.dart';

class BrandLoginPage extends StatefulWidget {
  const BrandLoginPage({
    super.key,
    this.intent = MarkaKalkanAuthIntent.corporateManagement,
  });

  final MarkaKalkanAuthIntent intent;

  @override
  State<BrandLoginPage> createState() => _BrandLoginPageState();
}

class _BrandLoginPageState extends State<BrandLoginPage> {
  final _formKey = GlobalKey<FormState>();
  final BrandAuthService _authService = BrandAuthService();

  bool _isSubmitting = false;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final credential = await _authService.signIn(
        email: _emailController.text,
        password: _passwordController.text,
      );

      if (!mounted) {
        return;
      }

      final email = credential.user?.email ?? 'Marka kullanıcısı';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$email hesabıyla giriş başarılı.')),
      );
      _completeAuthenticatedFlow();
    } on FirebaseAuthException catch (error) {
      if (!mounted) {
        return;
      }

      final message = switch (error.code) {
        'invalid-email' => 'E-posta adresi geçerli değil.',
        'invalid-credential' => 'E-posta adresi veya şifre hatalı.',
        'user-not-found' =>
          'Bu e-posta adresiyle kayıtlı bir marka hesabı bulunamadı.',
        'wrong-password' => 'E-posta adresi veya şifre hatalı.',
        'user-disabled' => 'Bu marka hesabı devre dışı bırakılmış.',
        'too-many-requests' =>
          'Çok fazla başarısız deneme yapıldı. Bir süre sonra yeniden deneyin.',
        'network-request-failed' =>
          'İnternet bağlantısı kurulamadı. Bağlantınızı kontrol edin.',
        _ => 'Giriş yapılamadı. Bilgilerinizi kontrol ederek yeniden deneyin.',
      };

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Beklenmeyen bir hata oluştu. Yeniden deneyin.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _completeAuthenticatedFlow() {
    if (widget.intent.requiresCorporateFlow) {
      AppRouter.openCorporateHub(context);
      return;
    }

    Navigator.of(context).pop(true);
  }

  Future<void> _openAccountCreation() async {
    final created = await AppRouter.openBrandAccountCreation(
      context,
      intent: widget.intent,
    );

    if (!mounted || created != true) {
      return;
    }

    _completeAuthenticatedFlow();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MarkaKalkanTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text(
          'Marka Girişi',
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
            constraints: const BoxConstraints(maxWidth: 480),
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
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F6F4),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Icon(
                        Icons.verified_user_outlined,
                        color: MarkaKalkanTheme.teal,
                        size: 34,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Markanızı yönetin',
                      style: TextStyle(
                        color: MarkaKalkanTheme.navy,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Ürünlerinizi, üretim partilerinizi, tekil kodlarınızı '
                      've şüpheli hareketleri tek panelden yönetin.',
                      style: TextStyle(color: Color(0xFF687580), height: 1.5),
                    ),
                    const SizedBox(height: 28),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      decoration: const InputDecoration(
                        labelText: 'E-posta adresi',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      validator: (value) {
                        final email = value?.trim() ?? '';

                        if (email.isEmpty) {
                          return 'E-posta adresinizi girin.';
                        }

                        if (!email.contains('@')) {
                          return 'Geçerli bir e-posta adresi girin.';
                        }

                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      autofillHints: const [AutofillHints.password],
                      decoration: InputDecoration(
                        labelText: 'Şifre',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          tooltip: _obscurePassword
                              ? 'Şifreyi göster'
                              : 'Şifreyi gizle',
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                      validator: (value) {
                        if ((value ?? '').length < 6) {
                          return 'Şifre en az 6 karakter olmalıdır.';
                        }

                        return null;
                      },
                    ),
                    const SizedBox(height: 22),
                    FilledButton.icon(
                      onPressed: _isSubmitting ? null : _submit,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 17),
                      ),
                      icon: _isSubmitting
                          ? const SizedBox(
                              width: 19,
                              height: 19,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.login),
                      label: Text(
                        _isSubmitting ? 'Giriş yapılıyor...' : 'Giriş Yap',
                      ),
                    ),
                    const SizedBox(height: 12),
                    const SizedBox(height: 6),
                    const Text(
                      'Henüz MarkaKalkan hesabınız yok mu?',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF687580),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: _openAccountCreation,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 17),
                      ),
                      icon: const Icon(Icons.person_add_alt_1_outlined),
                      label: const Text('MarkaKalkan Hesabı Oluştur'),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Tek hesabınızla Sahte İkiz bildirimi, Yaratım Sicili '
                      've abonelik işlemlerini kullanabilirsiniz. Marka ve '
                      'şirket yönetimi ayrıca onaylanır.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF8A959D),
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 22),
                    const Divider(),
                    const SizedBox(height: 14),
                    const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.shield_outlined,
                          color: MarkaKalkanTheme.blue,
                          size: 21,
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Marka hesapları, hak sahipliği ve şirket '
                            'bilgileri doğrulandıktan sonra aktif edilir.',
                            style: TextStyle(
                              color: Color(0xFF687580),
                              fontSize: 13,
                              height: 1.45,
                            ),
                          ),
                        ),
                      ],
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

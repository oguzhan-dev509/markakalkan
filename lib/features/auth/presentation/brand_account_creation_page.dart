import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:markakalkan/app/router.dart';
import 'package:markakalkan/core/theme/markakalkan_theme.dart';
import 'package:markakalkan/features/auth/domain/markakalkan_auth_intent.dart';
import 'package:markakalkan/features/auth/data/brand_auth_service.dart';

class BrandAccountCreationPage extends StatefulWidget {
  const BrandAccountCreationPage({
    super.key,
    this.intent = MarkaKalkanAuthIntent.corporateManagement,
  });

  final MarkaKalkanAuthIntent intent;

  @override
  State<BrandAccountCreationPage> createState() =>
      _BrandAccountCreationPageState();
}

class _BrandAccountCreationPageState extends State<BrandAccountCreationPage> {
  final _formKey = GlobalKey<FormState>();
  final BrandAuthService _authService = BrandAuthService();

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordConfirmationController = TextEditingController();

  bool _isSubmitting = false;
  bool _obscurePassword = true;
  bool _obscurePasswordConfirmation = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _passwordConfirmationController.dispose();
    super.dispose();
  }

  Future<void> _createAccount() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await _authService.createAccount(
        email: _emailController.text,
        password: _passwordController.text,
      );

      await _authService.sendEmailVerification();

      if (!mounted) {
        return;
      }

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return AlertDialog(
            icon: const Icon(
              Icons.verified_user_outlined,
              color: MarkaKalkanTheme.teal,
              size: 42,
            ),
            title: const Text(
              'MarkaKalkan’a hoş geldiniz',
              textAlign: TextAlign.center,
            ),
            content: Text(
              widget.intent.requiresCorporateFlow
                  ? 'Hesabınız başarıyla oluşturuldu. E-posta adresinize '
                        'doğrulama bağlantısı gönderdik.\n\n'
                        'Marka ve şirket yönetimi için yetki başvurunuzu '
                        'ayrıca tamamlayabilirsiniz.'
                  : 'Hesabınız başarıyla oluşturuldu. E-posta adresinize '
                        'doğrulama bağlantısı gönderdik.\n\n'
                        'Başlattığınız MarkaKalkan işlemine devam '
                        'edebilirsiniz.',
              textAlign: TextAlign.center,
              style: TextStyle(height: 1.5),
            ),
            actionsAlignment: MainAxisAlignment.center,
            actions: [
              FilledButton.icon(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                },
                icon: const Icon(Icons.arrow_forward),
                label: Text(
                  widget.intent.requiresCorporateFlow
                      ? 'Yetki Başvurusuna Devam Et'
                      : 'İşleme Devam Et',
                ),
              ),
            ],
          );
        },
      );

      if (!mounted) {
        return;
      }

      if (widget.intent.requiresCorporateFlow) {
        await AppRouter.openBrandApplication(context);
      }

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(true);
    } on FirebaseAuthException catch (error) {
      if (!mounted) {
        return;
      }

      final message = switch (error.code) {
        'email-already-in-use' =>
          'Bu e-posta adresiyle daha önce hesap oluşturulmuş.',
        'invalid-email' => 'Geçerli bir e-posta adresi girin.',
        'weak-password' => 'Daha güçlü bir şifre belirleyin.',
        'operation-not-allowed' =>
          'E-posta ile hesap oluşturma şu anda kullanılamıyor.',
        'network-request-failed' =>
          'İnternet bağlantısı kurulamadı. Bağlantınızı kontrol edin.',
        'too-many-requests' =>
          'Çok fazla deneme yapıldı. Bir süre sonra yeniden deneyin.',
        _ => 'Hesap oluşturulamadı. Bilgilerinizi kontrol edin.',
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
          content: Text('Beklenmeyen bir hata oluştu. Lütfen yeniden deneyin.'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MarkaKalkanTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text(
          'Hesap Oluştur',
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
            constraints: const BoxConstraints(maxWidth: 500),
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
                    const Icon(
                      Icons.person_add_alt_1_outlined,
                      color: MarkaKalkanTheme.teal,
                      size: 54,
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'MarkaKalkan hesabınızı oluşturun',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: MarkaKalkanTheme.navy,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Tek hesabınızla Sahte İkiz bildirimi, Yaratım Öncelik '
                      'Sicili, abonelik ve profil işlemlerini kullanın. '
                      'Marka veya şirket yönetimi ayrıca onay gerektirir.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF687580), height: 1.5),
                    ),
                    const SizedBox(height: 28),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.newUsername],
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
                      autofillHints: const [AutofillHints.newPassword],
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
                        if ((value ?? '').length < 8) {
                          return 'Şifre en az 8 karakter olmalıdır.';
                        }

                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordConfirmationController,
                      obscureText: _obscurePasswordConfirmation,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _createAccount(),
                      decoration: InputDecoration(
                        labelText: 'Şifreyi tekrar girin',
                        prefixIcon: const Icon(Icons.lock_reset_outlined),
                        suffixIcon: IconButton(
                          tooltip: _obscurePasswordConfirmation
                              ? 'Şifreyi göster'
                              : 'Şifreyi gizle',
                          onPressed: () {
                            setState(() {
                              _obscurePasswordConfirmation =
                                  !_obscurePasswordConfirmation;
                            });
                          },
                          icon: Icon(
                            _obscurePasswordConfirmation
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                      validator: (value) {
                        if (value != _passwordController.text) {
                          return 'Şifreler birbiriyle eşleşmiyor.';
                        }

                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: _isSubmitting ? null : _createAccount,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 17),
                      ),
                      icon: _isSubmitting
                          ? const SizedBox(
                              width: 19,
                              height: 19,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.person_add_alt_1),
                      label: Text(
                        _isSubmitting
                            ? 'Hesap oluşturuluyor...'
                            : 'Hesap Oluştur',
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Hesap oluşturmak marka veya şirket yönetim yetkisi '
                      'vermez. Kurumsal panel erişimi ayrıca başvuru ve '
                      'onay gerektirir.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF7C8992),
                        fontSize: 12,
                        height: 1.45,
                      ),
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

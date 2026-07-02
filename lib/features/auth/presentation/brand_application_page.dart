import 'package:flutter/material.dart';
import 'package:markakalkan/core/theme/markakalkan_theme.dart';

import 'package:markakalkan/features/auth/data/brand_application_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BrandApplicationPage extends StatefulWidget {
  const BrandApplicationPage({super.key});

  @override
  State<BrandApplicationPage> createState() => _BrandApplicationPageState();
}

class _BrandApplicationPageState extends State<BrandApplicationPage> {
  final _formKey = GlobalKey<FormState>();
  final BrandApplicationService _applicationService = BrandApplicationService();
  final _companyNameController = TextEditingController();
  final _brandNameController = TextEditingController();
  final _authorizedPersonController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _taxNumberController = TextEditingController();
  final _websiteController = TextEditingController();
  final _problemController = TextEditingController();

  String? _businessType;
  String? _sector;

  bool _acceptTerms = false;
  bool _isSubmitting = false;

  static const List<String> _businessTypes = [
    'Üretici',
    'İthalatçı',
    'İhracatçı',
    'Marka sahibi',
    'Distribütör',
    'Toptancı',
    'Diğer',
  ];

  static const List<String> _sectors = [
    'Kozmetik',
    'Elektronik ve aksesuar',
    'Şişeli içecek',
    'Gıda',
    'Tekstil ve ayakkabı',
    'Oto yedek parça',
    'Takı ve aksesuar',
    'Sanayi ürünü',
    'Diğer',
  ];
  @override
  void initState() {
    super.initState();

    final user = FirebaseAuth.instance.currentUser;
    final accountEmail = user?.email?.trim().toLowerCase();

    if (user == null || accountEmail == null || accountEmail.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Marka başvurusu için önce hesap oluşturmalı veya giriş yapmalısınız.',
            ),
          ),
        );

        Navigator.of(context).pop();
      });

      return;
    }

    _emailController.text = accountEmail;
  }

  @override
  void dispose() {
    _companyNameController.dispose();
    _brandNameController.dispose();
    _authorizedPersonController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _taxNumberController.dispose();
    _websiteController.dispose();
    _problemController.dispose();
    super.dispose();
  }

  String? _requiredValidator(String? value, String message) {
    if ((value?.trim() ?? '').isEmpty) {
      return message;
    }

    return null;
  }

  Future<void> _submitApplication() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_businessType == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('İşletme türünü seçin.')));
      return;
    }

    if (_sector == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Sektörünüzü seçin.')));
      return;
    }

    if (!_acceptTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Başvuru ve doğrulama koşullarını kabul etmelisiniz.'),
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await _applicationService.submitApplication(
        companyName: _companyNameController.text,
        brandName: _brandNameController.text,
        businessType: _businessType!,
        sector: _sector!,
        authorizedPerson: _authorizedPersonController.text,
        email: _emailController.text,
        phone: _phoneController.text,
        taxNumber: _taxNumberController.text,
        website: _websiteController.text,
        problemDescription: _problemController.text,
      );

      if (!mounted) {
        return;
      }

      _formKey.currentState!.reset();

      _companyNameController.clear();
      _brandNameController.clear();
      _authorizedPersonController.clear();

      _phoneController.clear();
      _taxNumberController.clear();
      _websiteController.clear();
      _problemController.clear();

      setState(() {
        _businessType = null;
        _sector = null;
        _acceptTerms = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Marka başvurunuz başarıyla alındı. '
            'Bilgileriniz doğrulandıktan sonra sizinle iletişime geçilecektir.',
          ),
        ),
      );
    } on FirebaseException catch (error) {
      if (!mounted) {
        return;
      }

      final message = error.code == 'permission-denied'
          ? 'Başvuru güvenlik kontrolünden geçemedi. '
                'Lütfen alanları kontrol ederek yeniden deneyin.'
          : 'Başvuru kaydedilemedi. Lütfen daha sonra yeniden deneyin.';

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
          'Yeni Marka Başvurusu',
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
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _ApplicationIntro(),
                const SizedBox(height: 22),
                Container(
                  padding: const EdgeInsets.all(30),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFFE0E7EC)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x12000000),
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
                        const _SectionTitle(
                          icon: Icons.business_outlined,
                          title: 'İşletme ve marka bilgileri',
                        ),
                        const SizedBox(height: 20),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final isNarrow = constraints.maxWidth < 700;

                            final companyField = TextFormField(
                              controller: _companyNameController,
                              decoration: const InputDecoration(
                                labelText: 'Ticari unvan',
                                prefixIcon: Icon(Icons.apartment_outlined),
                              ),
                              validator: (value) => _requiredValidator(
                                value,
                                'Ticari unvanı girin.',
                              ),
                            );

                            final brandField = TextFormField(
                              controller: _brandNameController,
                              decoration: const InputDecoration(
                                labelText: 'Marka adı',
                                prefixIcon: Icon(Icons.verified_outlined),
                              ),
                              validator: (value) => _requiredValidator(
                                value,
                                'Marka adını girin.',
                              ),
                            );

                            if (isNarrow) {
                              return Column(
                                children: [
                                  companyField,
                                  const SizedBox(height: 16),
                                  brandField,
                                ],
                              );
                            }

                            return Row(
                              children: [
                                Expanded(child: companyField),
                                const SizedBox(width: 16),
                                Expanded(child: brandField),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final isNarrow = constraints.maxWidth < 700;

                            final businessTypeField =
                                DropdownButtonFormField<String>(
                                  initialValue: _businessType,
                                  decoration: const InputDecoration(
                                    labelText: 'İşletme türü',
                                    prefixIcon: Icon(Icons.factory_outlined),
                                  ),
                                  items: _businessTypes
                                      .map(
                                        (item) => DropdownMenuItem<String>(
                                          value: item,
                                          child: Text(item),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      _businessType = value;
                                    });
                                  },
                                );

                            final sectorField = DropdownButtonFormField<String>(
                              initialValue: _sector,
                              decoration: const InputDecoration(
                                labelText: 'Sektör',
                                prefixIcon: Icon(Icons.category_outlined),
                              ),
                              items: _sectors
                                  .map(
                                    (item) => DropdownMenuItem<String>(
                                      value: item,
                                      child: Text(item),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                setState(() {
                                  _sector = value;
                                });
                              },
                            );

                            if (isNarrow) {
                              return Column(
                                children: [
                                  businessTypeField,
                                  const SizedBox(height: 16),
                                  sectorField,
                                ],
                              );
                            }

                            return Row(
                              children: [
                                Expanded(child: businessTypeField),
                                const SizedBox(width: 16),
                                Expanded(child: sectorField),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 28),
                        const _SectionTitle(
                          icon: Icons.person_outline,
                          title: 'Yetkili kişi ve iletişim',
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _authorizedPersonController,
                          decoration: const InputDecoration(
                            labelText: 'Yetkili kişinin adı ve soyadı',
                            prefixIcon: Icon(Icons.badge_outlined),
                          ),
                          validator: (value) => _requiredValidator(
                            value,
                            'Yetkili kişinin adını girin.',
                          ),
                        ),
                        const SizedBox(height: 16),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final isNarrow = constraints.maxWidth < 700;

                            final emailField = TextFormField(
                              controller: _emailController,
                              readOnly: true,
                              decoration: const InputDecoration(
                                labelText: 'Hesap e-posta adresi',
                                helperText:
                                    'Başvuru bu MarkaKalkan hesabına bağlanacaktır.',
                                prefixIcon: Icon(Icons.verified_user_outlined),
                              ),
                            );

                            final phoneField = TextFormField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              decoration: const InputDecoration(
                                labelText: 'Telefon',
                                prefixIcon: Icon(Icons.phone_outlined),
                              ),
                              validator: (value) => _requiredValidator(
                                value,
                                'Telefon numarasını girin.',
                              ),
                            );

                            if (isNarrow) {
                              return Column(
                                children: [
                                  emailField,
                                  const SizedBox(height: 16),
                                  phoneField,
                                ],
                              );
                            }

                            return Row(
                              children: [
                                Expanded(child: emailField),
                                const SizedBox(width: 16),
                                Expanded(child: phoneField),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 28),
                        const _SectionTitle(
                          icon: Icons.assignment_outlined,
                          title: 'Doğrulama ve ihtiyaç bilgileri',
                        ),
                        const SizedBox(height: 20),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final isNarrow = constraints.maxWidth < 700;

                            final taxField = TextFormField(
                              controller: _taxNumberController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Vergi numarası',
                                prefixIcon: Icon(Icons.receipt_long_outlined),
                              ),
                              validator: (value) => _requiredValidator(
                                value,
                                'Vergi numarasını girin.',
                              ),
                            );

                            final websiteField = TextFormField(
                              controller: _websiteController,
                              keyboardType: TextInputType.url,
                              decoration: const InputDecoration(
                                labelText: 'Web sitesi veya mağaza bağlantısı',
                                prefixIcon: Icon(Icons.language),
                              ),
                            );

                            if (isNarrow) {
                              return Column(
                                children: [
                                  taxField,
                                  const SizedBox(height: 16),
                                  websiteField,
                                ],
                              );
                            }

                            return Row(
                              children: [
                                Expanded(child: taxField),
                                const SizedBox(width: 16),
                                Expanded(child: websiteField),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _problemController,
                          minLines: 4,
                          maxLines: 7,
                          decoration: const InputDecoration(
                            labelText:
                                'Sahtecilik veya yetkisiz üretim sorununuzu anlatın',
                            alignLabelWithHint: true,
                            prefixIcon: Padding(
                              padding: EdgeInsets.only(bottom: 70),
                              child: Icon(Icons.report_outlined),
                            ),
                            hintText:
                                'Örnek: Pazaryerlerinde sahte ürünler satılıyor, '
                                'fason fabrikada yetkisiz fazla üretim riski var...',
                          ),
                          validator: (value) => _requiredValidator(
                            value,
                            'Karşılaştığınız sorunu kısaca açıklayın.',
                          ),
                        ),
                        const SizedBox(height: 20),
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          value: _acceptTerms,
                          controlAffinity: ListTileControlAffinity.leading,
                          title: const Text(
                            'Verdiğim bilgilerin doğru olduğunu ve marka '
                            'hak sahipliği doğrulamasına tabi tutulacağını kabul ediyorum.',
                            style: TextStyle(
                              color: MarkaKalkanTheme.navy,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: const Text(
                            'Başvurunun gönderilmesi hesabın otomatik olarak '
                            'onaylandığı anlamına gelmez.',
                          ),
                          onChanged: (value) {
                            setState(() {
                              _acceptTerms = value ?? false;
                            });
                          },
                        ),
                        const SizedBox(height: 22),
                        FilledButton.icon(
                          onPressed: _isSubmitting ? null : _submitApplication,
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 18),
                          ),
                          icon: _isSubmitting
                              ? const SizedBox(
                                  width: 19,
                                  height: 19,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.send_outlined),
                          label: Text(
                            _isSubmitting
                                ? 'Başvuru gönderiliyor...'
                                : 'Marka Başvurusunu Gönder',
                          ),
                        ),
                      ],
                    ),
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

class _ApplicationIntro extends StatelessWidget {
  const _ApplicationIntro();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [MarkaKalkanTheme.navy, Color(0xFF183B4E)],
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.shield_outlined, color: MarkaKalkanTheme.teal, size: 38),
          SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Markanızı korumaya başlayın',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 25,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Üretici, ithalatçı, ihracatçı ve marka sahipleri için '
                  'tekil ürün kimliği, QR doğrulama, şüpheli tarama ve '
                  'yetkili üretim takibi.',
                  style: TextStyle(color: Color(0xFFD9E5EA), height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;

  const _SectionTitle({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: MarkaKalkanTheme.blue),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            color: MarkaKalkanTheme.navy,
            fontSize: 19,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

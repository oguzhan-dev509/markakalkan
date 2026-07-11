import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:markakalkan/core/theme/markakalkan_theme.dart';

import '../models/counterfeit_twin_radar_contract.dart';
import 'counterfeit_twin_comparison_codec.dart';
import 'counterfeit_twin_evidence_editor.dart';

Future<String?> showCounterfeitTwinReportDialog({
  required BuildContext context,
}) {
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _CounterfeitTwinReportDialog(),
  );
}

class _CounterfeitTwinReportDialog extends StatefulWidget {
  const _CounterfeitTwinReportDialog();

  @override
  State<_CounterfeitTwinReportDialog> createState() =>
      _CounterfeitTwinReportDialogState();
}

class _CounterfeitTwinReportDialogState
    extends State<_CounterfeitTwinReportDialog> {
  final _formKey = GlobalKey<FormState>();
  final _service = CounterfeitTwinRadarService();
  final _evidenceEditorKey = GlobalKey<CounterfeitTwinEvidenceEditorState>();

  final _originalEntityName = TextEditingController();
  final _suspectedEntityName = TextEditingController();
  final _originalBrandName = TextEditingController();
  final _suspectedBrandName = TextEditingController();
  final _platformName = TextEditingController();
  final _storeDisplayName = TextEditingController();
  final _originalUrls = TextEditingController();
  final _suspectedUrls = TextEditingController();
  final _differenceNotes = TextEditingController();
  final _evidenceNotes = TextEditingController();
  final _usagePurpose = TextEditingController();
  final _technicalIdentity = TextEditingController();
  final _counterfeitRisk = TextEditingController();

  final _lossAmount = TextEditingController();
  final _paymentMethod = TextEditingController();
  final _bankOrPaymentProvider = TextEditingController();
  final _merchantDescriptor = TextEditingController();
  final _disputeReference = TextEditingController();
  final _refundAmount = TextEditingController();

  CounterfeitTwinPublicSection _publicCategory =
      CounterfeitTwinPublicSection.physical;
  CounterfeitTwinPublicSubcategory _publicSubcategory =
      CounterfeitTwinPublicSubcategory.otherPhysical;
  CounterfeitTwinTargetType _targetType =
      CounterfeitTwinTargetType.physicalProduct;
  CounterfeitTwinRobotType? _robotType;
  final Set<CounterfeitTwinIncidentType> _incidentTypes =
      <CounterfeitTwinIncidentType>{};

  bool _hasMonetaryLoss = false;
  bool _disputeSubmitted = false;
  String _currency = 'TRY';
  String _disputeStatus = 'submitted';
  String _recoveryStatus = 'unknown';

  bool _isSubmitting = false;
  String? _error;

  bool get _isPhysical =>
      _publicCategory == CounterfeitTwinPublicSection.physical;

  bool get _isRobot => _publicCategory == CounterfeitTwinPublicSection.aiRobot;

  List<CounterfeitTwinPublicSubcategory> get _availableSubcategories =>
      CounterfeitTwinPublicSubcategory.forSection(_publicCategory);

  bool get _showFinancialSection => _hasMonetaryLoss || _disputeSubmitted;

  @override
  void dispose() {
    for (final controller in <TextEditingController>[
      _originalEntityName,
      _suspectedEntityName,
      _originalBrandName,
      _suspectedBrandName,
      _platformName,
      _storeDisplayName,
      _originalUrls,
      _suspectedUrls,
      _differenceNotes,
      _evidenceNotes,
      _usagePurpose,
      _technicalIdentity,
      _counterfeitRisk,
      _lossAmount,
      _paymentMethod,
      _bankOrPaymentProvider,
      _merchantDescriptor,
      _disputeReference,
      _refundAmount,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  List<CounterfeitTwinIncidentType> get _availableIncidentTypes {
    if (_isRobot) {
      return const <CounterfeitTwinIncidentType>[
        CounterfeitTwinIncidentType.counterfeitRobotHardware,
        CounterfeitTwinIncidentType.robotIdentityClone,
        CounterfeitTwinIncidentType.serialNumberClone,
        CounterfeitTwinIncidentType.deviceCertificateClone,
        CounterfeitTwinIncidentType.controlSoftwareClone,
        CounterfeitTwinIncidentType.firmwareClone,
        CounterfeitTwinIncidentType.fakeRobotCertification,
        CounterfeitTwinIncidentType.teleoperationChannelImpersonation,
        CounterfeitTwinIncidentType.robotFleetImpersonation,
        CounterfeitTwinIncidentType.aiAgentImpersonation,
        CounterfeitTwinIncidentType.voicePersonaClone,
        CounterfeitTwinIncidentType.fakeRobotServiceNetwork,
        CounterfeitTwinIncidentType.brandImpersonation,
        CounterfeitTwinIncidentType.platformImpersonation,
        CounterfeitTwinIncidentType.other,
      ];
    }

    switch (_targetType) {
      case CounterfeitTwinTargetType.physicalProduct:
        return const <CounterfeitTwinIncidentType>[
          CounterfeitTwinIncidentType.productImitation,
          CounterfeitTwinIncidentType.brandImpersonation,
          CounterfeitTwinIncidentType.merchantIdentityDeception,
          CounterfeitTwinIncidentType.fakeCheckout,
          CounterfeitTwinIncidentType.paymentDiversion,
          CounterfeitTwinIncidentType.other,
        ];
      case CounterfeitTwinTargetType.tourismBookingPlatform:
        return const <CounterfeitTwinIncidentType>[
          CounterfeitTwinIncidentType.platformImpersonation,
          CounterfeitTwinIncidentType.websiteClone,
          CounterfeitTwinIncidentType.fakeReservation,
          CounterfeitTwinIncidentType.fakeCheckout,
          CounterfeitTwinIncidentType.fakePaymentPage,
          CounterfeitTwinIncidentType.credentialPhishing,
          CounterfeitTwinIncidentType.paymentDiversion,
          CounterfeitTwinIncidentType.other,
        ];
      case CounterfeitTwinTargetType.financialService:
      case CounterfeitTwinTargetType.paymentPage:
        return const <CounterfeitTwinIncidentType>[
          CounterfeitTwinIncidentType.fakeFinancialService,
          CounterfeitTwinIncidentType.fakeInvestmentService,
          CounterfeitTwinIncidentType.fakePaymentPage,
          CounterfeitTwinIncidentType.credentialPhishing,
          CounterfeitTwinIncidentType.paymentDiversion,
          CounterfeitTwinIncidentType.ibanDiversion,
          CounterfeitTwinIncidentType.merchantIdentityDeception,
          CounterfeitTwinIncidentType.unauthorizedCardCharge,
          CounterfeitTwinIncidentType.personalDataHarvesting,
          CounterfeitTwinIncidentType.other,
        ];
      case CounterfeitTwinTargetType.mobileApplication:
        return const <CounterfeitTwinIncidentType>[
          CounterfeitTwinIncidentType.mobileAppImpersonation,
          CounterfeitTwinIncidentType.interfaceClone,
          CounterfeitTwinIncidentType.fakeSubscription,
          CounterfeitTwinIncidentType.credentialPhishing,
          CounterfeitTwinIncidentType.fakePaymentPage,
          CounterfeitTwinIncidentType.personalDataHarvesting,
          CounterfeitTwinIncidentType.other,
        ];
      case CounterfeitTwinTargetType.customerSupportChannel:
        return const <CounterfeitTwinIncidentType>[
          CounterfeitTwinIncidentType.fakeCustomerSupport,
          CounterfeitTwinIncidentType.brandImpersonation,
          CounterfeitTwinIncidentType.credentialPhishing,
          CounterfeitTwinIncidentType.paymentDiversion,
          CounterfeitTwinIncidentType.ibanDiversion,
          CounterfeitTwinIncidentType.personalDataHarvesting,
          CounterfeitTwinIncidentType.other,
        ];
      case CounterfeitTwinTargetType.digitalProduct:
      case CounterfeitTwinTargetType.service:
      case CounterfeitTwinTargetType.saasPlatform:
      case CounterfeitTwinTargetType.ecommercePlatform:
      case CounterfeitTwinTargetType.marketplaceStore:
      case CounterfeitTwinTargetType.website:
      case CounterfeitTwinTargetType.socialMediaAccount:
      case CounterfeitTwinTargetType.institution:
        return const <CounterfeitTwinIncidentType>[
          CounterfeitTwinIncidentType.brandImpersonation,
          CounterfeitTwinIncidentType.platformImpersonation,
          CounterfeitTwinIncidentType.websiteClone,
          CounterfeitTwinIncidentType.interfaceClone,
          CounterfeitTwinIncidentType.fakeCheckout,
          CounterfeitTwinIncidentType.fakePaymentPage,
          CounterfeitTwinIncidentType.fakeSubscription,
          CounterfeitTwinIncidentType.credentialPhishing,
          CounterfeitTwinIncidentType.paymentDiversion,
          CounterfeitTwinIncidentType.merchantIdentityDeception,
          CounterfeitTwinIncidentType.personalDataHarvesting,
          CounterfeitTwinIncidentType.other,
        ];
      case CounterfeitTwinTargetType.roboticSystem:
      case CounterfeitTwinTargetType.autonomousAiAgent:
        return const <CounterfeitTwinIncidentType>[];
      case CounterfeitTwinTargetType.other:
        return CounterfeitTwinIncidentType.values;
    }
  }

  void _changePublicSection(CounterfeitTwinPublicSection value) {
    final subcategory = CounterfeitTwinPublicSubcategory.forSection(
      value,
    ).first;
    setState(() {
      _publicCategory = value;
      _publicSubcategory = subcategory;
      _targetType = subcategory.targetType;
      _robotType = subcategory.robotType;
      final allowed = _availableIncidentTypes.toSet();
      _incidentTypes.removeWhere((item) => !allowed.contains(item));
      _error = null;
    });
  }

  void _changePublicSubcategory(CounterfeitTwinPublicSubcategory value) {
    setState(() {
      _publicSubcategory = value;
      _targetType = value.targetType;
      _robotType = value.robotType;
      final allowed = _availableIncidentTypes.toSet();
      _incidentTypes.removeWhere((item) => !allowed.contains(item));
      _error = null;
    });
  }

  String? _required(String? value, String label, int maxLength) {
    final cleaned = value?.trim() ?? '';
    if (cleaned.isEmpty) return '$label zorunludur.';
    if (cleaned.length > maxLength) {
      return '$label en fazla $maxLength karakter olabilir.';
    }
    return null;
  }

  String? _optional(String? value, String label, int maxLength) {
    final cleaned = value?.trim() ?? '';
    if (cleaned.length > maxLength) {
      return '$label en fazla $maxLength karakter olabilir.';
    }
    return null;
  }

  String? _validateUrls(String? value, String label) {
    final urls = _lines(value ?? '');
    if (urls.length > 20) return '$label en fazla 20 bağlantı içerebilir.';

    for (final value in urls) {
      if (value.length > 1200) {
        return '$label içindeki bir bağlantı çok uzun.';
      }
      final uri = Uri.tryParse(value);
      if (uri == null ||
          !<String>{'http', 'https'}.contains(uri.scheme) ||
          uri.host.isEmpty) {
        return '$label yalnız geçerli http/https bağlantıları içermelidir.';
      }
    }
    return null;
  }

  String? _validateLossAmount(String? value) {
    if (!_hasMonetaryLoss) return null;
    final amount = _amount(value ?? '');
    if (amount == null || amount <= 0) {
      return 'Maddi kayıp tutarı sıfırdan büyük olmalıdır.';
    }
    return null;
  }

  String? _validateDifferenceNotes(String? value) {
    final notes = _lines(value ?? '');
    if (notes.length > 20) {
      return 'En fazla 20 fark notu eklenebilir.';
    }
    if (notes.any((item) => item.length > 500)) {
      return 'Her fark notu en fazla 500 karakter olabilir.';
    }
    return null;
  }

  List<String> _lines(String value) {
    return value
        .split(RegExp(r'[\r\n]+'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList(growable: false);
  }

  double? _amount(String value) {
    final cleaned = value.trim().replaceAll(' ', '').replaceAll(',', '.');
    if (cleaned.isEmpty) return null;
    return double.tryParse(cleaned);
  }

  String? _nullable(String value) {
    final cleaned = value.trim();
    return cleaned.isEmpty ? null : cleaned;
  }

  Future<void> _submit() async {
    if (_isSubmitting || !(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    if (_incidentTypes.isEmpty) {
      setState(() => _error = 'En az bir olay türü seçilmelidir.');
      return;
    }

    if (_isRobot && _robotType == null) {
      setState(() => _error = 'Robot veya ajan alt türü seçilmelidir.');
      return;
    }

    final originalUrls = _lines(_originalUrls.text);
    final suspectedUrls = _lines(_suspectedUrls.text);

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      final evidence = await _evidenceEditorKey.currentState!
          .prepareForSubmit();
      final encodedDifferenceNotes = CounterfeitTwinComparisonCodec.encode(
        rows: evidence.rows,
        legacyNotes: _lines(_differenceNotes.text),
        priceObservedAt: evidence.priceObservedAt,
        originalImageSource: evidence.originalImageSource,
        suspectedImageSource: evidence.suspectedImageSource,
      );
      final mergedOriginalUrls = <String>{
        ...originalUrls,
        ...evidence.originalSourceUrls,
      }.toList(growable: false);
      final mergedSuspectedUrls = <String>{
        ...suspectedUrls,
        ...evidence.suspectedSourceUrls,
      }.toList(growable: false);

      final report = CounterfeitTwinRadarReport(
        targetType: _targetType,
        publicCategory: _publicCategory,
        publicSubcategory: _publicSubcategory,
        robotType: _robotType,
        originalEntityName: _originalEntityName.text.trim(),
        suspectedEntityName: _suspectedEntityName.text.trim(),
        originalBrandName: _isPhysical ? _originalBrandName.text.trim() : null,
        suspectedBrandName: _nullable(_suspectedBrandName.text),
        originalProductName: _isPhysical
            ? _originalEntityName.text.trim()
            : null,
        suspectedProductName: _isPhysical
            ? _suspectedEntityName.text.trim()
            : null,
        platformName: _platformName.text.trim(),
        storeDisplayName: _nullable(_storeDisplayName.text),
        originalImageUrls: evidence.originalImageUrls,
        originalUrls: mergedOriginalUrls,
        suspectedImageUrls: evidence.suspectedImageUrls,
        suspectedUrls: mergedSuspectedUrls,
        listingUrl: mergedSuspectedUrls.isEmpty
            ? null
            : mergedSuspectedUrls.first,
        incidentTypes: _incidentTypes.toList(growable: false),
        authorizedPriceMin: evidence.originalPrice,
        authorizedPriceMax: evidence.originalPrice,
        suspectedPrice: evidence.suspectedPrice,
        differenceNotes: encodedDifferenceNotes,
        evidenceNotes: _evidenceNotes.text.trim(),
        usagePurpose: _usagePurpose.text.trim(),
        technicalIdentity: _technicalIdentity.text.trim(),
        counterfeitRisk: _counterfeitRisk.text.trim(),
        currency: evidence.currency,
        financialImpact: CounterfeitTwinFinancialImpact(
          hasMonetaryLoss: _hasMonetaryLoss,
          lossAmount: _hasMonetaryLoss ? _amount(_lossAmount.text) : null,
          currency: _currency,
          paymentMethod: _nullable(_paymentMethod.text),
          bankOrPaymentProvider: _nullable(_bankOrPaymentProvider.text),
          merchantDescriptor: _nullable(_merchantDescriptor.text),
          disputeSubmitted: _disputeSubmitted,
          disputeReference: _nullable(_disputeReference.text),
          disputeStatus: _disputeSubmitted ? _disputeStatus : 'not_submitted',
          refundAmount: _amount(_refundAmount.text),
          recoveryStatus: _recoveryStatus,
        ),
      );

      final reportId = await _service.submit(report);
      _evidenceEditorKey.currentState?.markCommitted();
      if (mounted) {
        Navigator.of(context).pop(reportId);
      }
    } on FirebaseFunctionsException catch (error) {
      if (mounted) {
        setState(() => _error = _functionMessage(error));
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'Bildirim gönderilemedi: $error');
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  String _functionMessage(FirebaseFunctionsException error) {
    switch (error.code) {
      case 'unauthenticated':
        return 'Bildirim göndermek için oturum açmalısınız.';
      case 'invalid-argument':
        return error.message ?? 'Bildirim alanlarını kontrol edin.';
      case 'permission-denied':
        return 'Bu işlem için yetkiniz bulunmuyor.';
      case 'resource-exhausted':
        return 'Çok fazla istek gönderildi. Lütfen daha sonra tekrar deneyin.';
      default:
        return error.message ?? 'Bildirim sunucuya gönderilemedi.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final width = screen.width < 960 ? screen.width - 32 : 900.0;

    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      insetPadding: const EdgeInsets.all(16),
      title: const Row(
        children: [
          Icon(Icons.report_outlined, color: MarkaKalkanTheme.teal),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Sahte İkiz Bildir',
              style: TextStyle(
                color: MarkaKalkanTheme.navy,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: width,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _InfoCard(
                  icon: Icons.shield_outlined,
                  text:
                      'Ürün, platform, turizm, finans, ödeme sayfası, robot '
                      've otonom ajan sahteciliğini bildirebilirsiniz. Tam '
                      'kart numarası, açık IBAN veya parolaları yazmayın.',
                ),
                const SizedBox(height: 18),
                const _SectionTitle('1. Taklit edilen varlık'),
                DropdownButtonFormField<CounterfeitTwinPublicSection>(
                  initialValue: _publicCategory,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Ana kategori *',
                  ),
                  items: CounterfeitTwinPublicSection.values
                      .map(
                        (item) => DropdownMenuItem(
                          value: item,
                          child: Text(item.label),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: _isSubmitting
                      ? null
                      : (value) {
                          if (value != null) _changePublicSection(value);
                        },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<CounterfeitTwinPublicSubcategory>(
                  key: ValueKey<String>(_publicCategory.value),
                  initialValue: _publicSubcategory,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Alt kategori *',
                  ),
                  items: _availableSubcategories
                      .map(
                        (item) => DropdownMenuItem(
                          value: item,
                          child: Text(item.label),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: _isSubmitting
                      ? null
                      : (value) {
                          if (value != null) {
                            _changePublicSubcategory(value);
                          }
                        },
                ),
                if (_isRobot) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<CounterfeitTwinRobotType>(
                    initialValue: _robotType,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Robot / ajan alt türü *',
                    ),
                    items: CounterfeitTwinRobotType.values
                        .map(
                          (item) => DropdownMenuItem(
                            value: item,
                            child: Text(item.label),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: _isSubmitting
                        ? null
                        : (value) => setState(() => _robotType = value),
                    validator: (_) => _isRobot && _robotType == null
                        ? 'Robot veya ajan alt türü zorunludur.'
                        : null,
                  ),
                ],
                const SizedBox(height: 12),
                _ResponsivePair(
                  left: TextFormField(
                    controller: _originalEntityName,
                    enabled: !_isSubmitting,
                    decoration: InputDecoration(
                      labelText: _isPhysical
                          ? 'Gerçek ürün adı *'
                          : 'Gerçek varlık / platform adı *',
                    ),
                    validator: (value) =>
                        _required(value, 'Gerçek varlık adı', 500),
                  ),
                  right: TextFormField(
                    controller: _suspectedEntityName,
                    enabled: !_isSubmitting,
                    decoration: InputDecoration(
                      labelText: _isPhysical
                          ? 'Şüpheli ürün adı *'
                          : 'Sahte / şüpheli ikiz adı *',
                    ),
                    validator: (value) =>
                        _required(value, 'Şüpheli ikiz adı', 500),
                  ),
                ),
                if (_isPhysical) ...[
                  const SizedBox(height: 12),
                  _ResponsivePair(
                    left: TextFormField(
                      controller: _originalBrandName,
                      enabled: !_isSubmitting,
                      decoration: const InputDecoration(
                        labelText: 'Gerçek marka *',
                      ),
                      validator: (value) =>
                          _required(value, 'Gerçek marka', 240),
                    ),
                    right: TextFormField(
                      controller: _suspectedBrandName,
                      enabled: !_isSubmitting,
                      decoration: const InputDecoration(
                        labelText: 'Şüpheli marka',
                      ),
                      validator: (value) =>
                          _optional(value, 'Şüpheli marka', 240),
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                TextFormField(
                  controller: _usagePurpose,
                  enabled: !_isSubmitting,
                  minLines: 2,
                  maxLines: 5,
                  maxLength: 300,
                  decoration: const InputDecoration(
                    labelText: 'Ne için kullanılır?',
                    hintText:
                        'Ürünün, hizmetin, platformun veya sistemin temel kullanım amacını açıklayın.',
                    alignLabelWithHint: true,
                  ),
                  validator: (value) =>
                      _optional(value, 'Ne için kullanılır?', 300),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _technicalIdentity,
                  enabled: !_isSubmitting,
                  minLines: 2,
                  maxLines: 6,
                  maxLength: 500,
                  decoration: const InputDecoration(
                    labelText: 'Ayırt edici teknik bilgi / ürün kimliği',
                    hintText:
                        'Model, sürüm, seri yapısı, bileşim, ölçü, teknik özellik veya doğrulama unsurunu yazın.',
                    alignLabelWithHint: true,
                  ),
                  validator: (value) => _optional(
                    value,
                    'Ayırt edici teknik bilgi / ürün kimliği',
                    500,
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _counterfeitRisk,
                  enabled: !_isSubmitting,
                  minLines: 2,
                  maxLines: 6,
                  maxLength: 500,
                  decoration: const InputDecoration(
                    labelText: 'Sahte olduğunda doğabilecek risk',
                    hintText:
                        'Sağlık, güvenlik, veri, mali kayıp, hizmet kesintisi veya itibar riskini açıklayın.',
                    helperText: 'İsteğe bağlıdır.',
                    alignLabelWithHint: true,
                  ),
                  validator: (value) =>
                      _optional(value, 'Sahte olduğunda doğabilecek risk', 500),
                ),
                const SizedBox(height: 18),
                const _SectionTitle('2. Kaynak ve bağlantılar'),
                _ResponsivePair(
                  left: TextFormField(
                    controller: _platformName,
                    enabled: !_isSubmitting,
                    decoration: const InputDecoration(
                      labelText: 'Tespit edildiği platform / kanal *',
                      hintText: 'Web sitesi, uygulama, pazaryeri, sosyal medya',
                    ),
                    validator: (value) =>
                        _required(value, 'Platform / kanal', 160),
                  ),
                  right: TextFormField(
                    controller: _storeDisplayName,
                    enabled: !_isSubmitting,
                    decoration: const InputDecoration(
                      labelText: 'Mağaza, hesap veya işyeri adı',
                    ),
                    validator: (value) =>
                        _optional(value, 'Mağaza / hesap adı', 240),
                  ),
                ),
                const SizedBox(height: 12),
                _ResponsivePair(
                  left: TextFormField(
                    controller: _originalUrls,
                    enabled: !_isSubmitting,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Gerçek bağlantılar',
                      hintText: 'Her satıra bir http/https bağlantısı',
                    ),
                    validator: (value) =>
                        _validateUrls(value, 'Gerçek bağlantılar'),
                  ),
                  right: TextFormField(
                    controller: _suspectedUrls,
                    enabled: !_isSubmitting,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Sahte / şüpheli bağlantılar',
                      hintText: 'Her satıra bir http/https bağlantısı',
                    ),
                    validator: (value) =>
                        _validateUrls(value, 'Şüpheli bağlantılar'),
                  ),
                ),
                const SizedBox(height: 18),
                const _SectionTitle('3. Sahtecilik yöntemi'),
                Text(
                  'En az bir olay türü seçin.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF475467),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _availableIncidentTypes
                      .map(
                        (item) => FilterChip(
                          label: Text(_incidentLabel(item)),
                          selected: _incidentTypes.contains(item),
                          onSelected: _isSubmitting
                              ? null
                              : (selected) {
                                  setState(() {
                                    if (selected) {
                                      _incidentTypes.add(item);
                                    } else {
                                      _incidentTypes.remove(item);
                                    }
                                    _error = null;
                                  });
                                },
                        ),
                      )
                      .toList(growable: false),
                ),
                const SizedBox(height: 18),
                const _SectionTitle('4. Farklar ve delil özeti'),
                TextFormField(
                  controller: _differenceNotes,
                  enabled: !_isSubmitting,
                  minLines: 2,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'Gerçek ile sahte arasındaki farklar',
                    hintText: 'Her satıra bir fark yazın',
                  ),
                  validator: _validateDifferenceNotes,
                ),
                const SizedBox(height: 18),
                CounterfeitTwinEvidenceEditor(
                  key: _evidenceEditorKey,
                  enabled: !_isSubmitting,
                ),
                const SizedBox(height: 18),
                TextFormField(
                  controller: _evidenceNotes,
                  enabled: !_isSubmitting,
                  minLines: 4,
                  maxLines: 8,
                  decoration: const InputDecoration(
                    labelText: 'Delil ve olay açıklaması *',
                    hintText:
                        'Nasıl karşılaştığınızı, neden sahte olduğunu ve '
                        'varsa ödeme sürecini açıklayın.',
                  ),
                  validator: (value) =>
                      _required(value, 'Delil ve olay açıklaması', 5000),
                ),
                const SizedBox(height: 18),
                const _SectionTitle('5. Maddi kayıp ve banka itirazı'),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Maddi kayıp oluştu'),
                  subtitle: const Text(
                    'Ödenen veya kaybedilen tutarı kayda alın.',
                  ),
                  value: _hasMonetaryLoss,
                  onChanged: _isSubmitting
                      ? null
                      : (value) => setState(() => _hasMonetaryLoss = value),
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Bankaya veya ödeme kuruluşuna itiraz edildi',
                  ),
                  value: _disputeSubmitted,
                  onChanged: _isSubmitting
                      ? null
                      : (value) => setState(() {
                          _disputeSubmitted = value;
                          if (!value) _disputeStatus = 'submitted';
                        }),
                ),
                if (_showFinancialSection) ...[
                  const _InfoCard(
                    icon: Icons.lock_outline,
                    text:
                        'Tam kart numarası, CVV, açık IBAN veya parola '
                        'girmeyin. Yalnız maskelenmiş ve gerekli bilgileri '
                        'kullanın.',
                  ),
                  const SizedBox(height: 12),
                  if (_hasMonetaryLoss)
                    _ResponsivePair(
                      left: TextFormField(
                        controller: _lossAmount,
                        enabled: !_isSubmitting,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Maddi kayıp tutarı *',
                        ),
                        validator: _validateLossAmount,
                      ),
                      right: DropdownButtonFormField<String>(
                        initialValue: _currency,
                        decoration: const InputDecoration(
                          labelText: 'Para birimi',
                        ),
                        items: const <String>['TRY', 'USD', 'EUR', 'GBP']
                            .map(
                              (item) => DropdownMenuItem(
                                value: item,
                                child: Text(item),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: _isSubmitting
                            ? null
                            : (value) => setState(
                                () => _currency = value ?? _currency,
                              ),
                      ),
                    ),
                  if (_hasMonetaryLoss) const SizedBox(height: 12),
                  _ResponsivePair(
                    left: TextFormField(
                      controller: _paymentMethod,
                      enabled: !_isSubmitting,
                      decoration: const InputDecoration(
                        labelText: 'Ödeme yöntemi',
                        hintText: 'Kredi kartı, havale, sanal POS',
                      ),
                      validator: (value) =>
                          _optional(value, 'Ödeme yöntemi', 120),
                    ),
                    right: TextFormField(
                      controller: _bankOrPaymentProvider,
                      enabled: !_isSubmitting,
                      decoration: const InputDecoration(
                        labelText: 'Banka / ödeme kuruluşu',
                      ),
                      validator: (value) =>
                          _optional(value, 'Banka / ödeme kuruluşu', 240),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _merchantDescriptor,
                    enabled: !_isSubmitting,
                    decoration: const InputDecoration(
                      labelText: 'Ekstrede görünen işyeri açıklaması',
                    ),
                    validator: (value) =>
                        _optional(value, 'İşyeri açıklaması', 300),
                  ),
                  if (_disputeSubmitted) ...[
                    const SizedBox(height: 12),
                    _ResponsivePair(
                      left: DropdownButtonFormField<String>(
                        initialValue: _disputeStatus,
                        decoration: const InputDecoration(
                          labelText: 'İtiraz durumu',
                        ),
                        items: _disputeStatuses.entries
                            .map(
                              (entry) => DropdownMenuItem(
                                value: entry.key,
                                child: Text(entry.value),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: _isSubmitting
                            ? null
                            : (value) => setState(
                                () => _disputeStatus = value ?? _disputeStatus,
                              ),
                      ),
                      right: TextFormField(
                        controller: _disputeReference,
                        enabled: !_isSubmitting,
                        decoration: const InputDecoration(
                          labelText: 'İtiraz / dilekçe referansı',
                        ),
                        validator: (value) =>
                            _optional(value, 'İtiraz referansı', 240),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  _ResponsivePair(
                    left: TextFormField(
                      controller: _refundAmount,
                      enabled: !_isSubmitting,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Geri alınan tutar',
                      ),
                    ),
                    right: DropdownButtonFormField<String>(
                      initialValue: _recoveryStatus,
                      decoration: const InputDecoration(
                        labelText: 'Geri alım durumu',
                      ),
                      items: _recoveryStatuses.entries
                          .map(
                            (entry) => DropdownMenuItem(
                              value: entry.key,
                              child: Text(entry.value),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: _isSubmitting
                          ? null
                          : (value) => setState(
                              () => _recoveryStatus = value ?? _recoveryStatus,
                            ),
                    ),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  Text(
                    _error!,
                    style: const TextStyle(
                      color: Color(0xFFB42318),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Vazgeç'),
        ),
        FilledButton.icon(
          onPressed: _isSubmitting ? null : _submit,
          icon: _isSubmitting
              ? const SizedBox(
                  width: 17,
                  height: 17,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.send_outlined),
          label: Text(_isSubmitting ? 'Gönderiliyor...' : 'Bildirimi Gönder'),
        ),
      ],
    );
  }
}

const Map<String, String> _disputeStatuses = <String, String>{
  'submitted': 'Başvuru yapıldı',
  'under_review': 'İncelemede',
  'accepted': 'Kabul edildi',
  'rejected': 'Reddedildi',
  'partially_resolved': 'Kısmen sonuçlandı',
  'resolved': 'Sonuçlandı',
};

const Map<String, String> _recoveryStatuses = <String, String>{
  'unknown': 'Bilinmiyor',
  'no_recovery': 'Geri alım yok',
  'pending': 'Beklemede',
  'partial': 'Kısmi geri alım',
  'full': 'Tam geri alım',
};

String _incidentLabel(CounterfeitTwinIncidentType item) {
  const labels = <CounterfeitTwinIncidentType, String>{
    CounterfeitTwinIncidentType.productImitation: 'Ürün taklidi',
    CounterfeitTwinIncidentType.brandImpersonation: 'Marka kimliği taklidi',
    CounterfeitTwinIncidentType.platformImpersonation:
        'Platform kimliği taklidi',
    CounterfeitTwinIncidentType.websiteClone: 'Web sitesi klonu',
    CounterfeitTwinIncidentType.mobileAppImpersonation:
        'Mobil uygulama taklidi',
    CounterfeitTwinIncidentType.interfaceClone: 'Arayüz klonu',
    CounterfeitTwinIncidentType.fakeCheckout: 'Sahte ödeme adımı',
    CounterfeitTwinIncidentType.fakePaymentPage: 'Sahte ödeme sayfası',
    CounterfeitTwinIncidentType.fakeSubscription: 'Sahte abonelik',
    CounterfeitTwinIncidentType.fakeReservation: 'Sahte rezervasyon',
    CounterfeitTwinIncidentType.fakeFinancialService: 'Sahte finansal hizmet',
    CounterfeitTwinIncidentType.fakeInvestmentService: 'Sahte yatırım hizmeti',
    CounterfeitTwinIncidentType.fakeCustomerSupport: 'Sahte müşteri desteği',
    CounterfeitTwinIncidentType.credentialPhishing: 'Kimlik bilgisi avı',
    CounterfeitTwinIncidentType.paymentDiversion: 'Ödeme yönlendirme',
    CounterfeitTwinIncidentType.ibanDiversion: 'IBAN yönlendirme',
    CounterfeitTwinIncidentType.merchantIdentityDeception:
        'İşyeri kimliği yanıltması',
    CounterfeitTwinIncidentType.unauthorizedCardCharge: 'Yetkisiz kart işlemi',
    CounterfeitTwinIncidentType.personalDataHarvesting: 'Kişisel veri toplama',
    CounterfeitTwinIncidentType.counterfeitRobotHardware:
        'Sahte robot donanımı',
    CounterfeitTwinIncidentType.robotIdentityClone: 'Robot kimliği klonu',
    CounterfeitTwinIncidentType.serialNumberClone: 'Seri numarası klonu',
    CounterfeitTwinIncidentType.deviceCertificateClone:
        'Cihaz sertifikası klonu',
    CounterfeitTwinIncidentType.controlSoftwareClone: 'Kontrol yazılımı klonu',
    CounterfeitTwinIncidentType.firmwareClone: 'Firmware klonu',
    CounterfeitTwinIncidentType.fakeRobotCertification:
        'Sahte robot sertifikası',
    CounterfeitTwinIncidentType.teleoperationChannelImpersonation:
        'Uzaktan kontrol kanalı taklidi',
    CounterfeitTwinIncidentType.robotFleetImpersonation:
        'Robot filosu kimliği taklidi',
    CounterfeitTwinIncidentType.aiAgentImpersonation:
        'Yapay zekâ ajanı taklidi',
    CounterfeitTwinIncidentType.voicePersonaClone: 'Ses / persona klonu',
    CounterfeitTwinIncidentType.fakeRobotServiceNetwork:
        'Sahte robot servis ağı',
    CounterfeitTwinIncidentType.other: 'Diğer',
  };
  return labels[item] ?? item.value;
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: const TextStyle(
          color: MarkaKalkanTheme.navy,
          fontSize: 16,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF2F7F7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD0E4E2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: MarkaKalkanTheme.teal),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(color: Color(0xFF344054), height: 1.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResponsivePair extends StatelessWidget {
  const _ResponsivePair({required this.left, required this.right});

  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, constraints) {
        if (constraints.maxWidth < 680) {
          return Column(children: [left, const SizedBox(height: 12), right]);
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: left),
            const SizedBox(width: 12),
            Expanded(child: right),
          ],
        );
      },
    );
  }
}

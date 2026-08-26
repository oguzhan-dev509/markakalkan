import 'package:flutter/material.dart';
import 'package:markakalkan/core/theme/markakalkan_theme.dart';
import 'package:markakalkan/features/detective/data/ai_field_operation_models.dart';
import 'package:markakalkan/features/detective/data/ai_field_operation_service.dart';

class AiFieldOperationCreatePage extends StatefulWidget {
  const AiFieldOperationCreatePage({super.key});

  @override
  State<AiFieldOperationCreatePage> createState() =>
      _AiFieldOperationCreatePageState();
}

class _AiFieldOperationCreatePageState
    extends State<AiFieldOperationCreatePage> {
  final _formKey = GlobalKey<FormState>();
  final _operationService = AiFieldOperationService();

  final _titleController = TextEditingController();
  final _objectiveController = TextEditingController();
  final _brandNameController = TextEditingController();
  final _productNameController = TextEditingController();
  final _sellerNameController = TextEditingController();
  final _targetUrlController = TextEditingController();

  AiFieldOperationPriority _priority = AiFieldOperationPriority.normal;
  AiFieldOperationReadiness? _readiness;
  bool _isLoadingReadiness = true;
  bool _isSubmitting = false;
  String? _readinessError;

  @override
  void initState() {
    super.initState();
    _loadReadiness();
  }

  Future<void> _loadReadiness() async {
    setState(() {
      _isLoadingReadiness = true;
      _readinessError = null;
    });
    try {
      final readiness = await _operationService.getReadiness();
      if (!mounted) return;
      _brandNameController.text = readiness.brandName;
      setState(() => _readiness = readiness);
    } on AiFieldOperationFailure catch (error) {
      if (!mounted) return;
      setState(() => _readinessError = error.message);
    } finally {
      if (mounted) setState(() => _isLoadingReadiness = false);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _objectiveController.dispose();
    _brandNameController.dispose();
    _productNameController.dispose();
    _sellerNameController.dispose();
    _targetUrlController.dispose();
    super.dispose();
  }

  String? _requiredValidator(
    String? value,
    String message, {
    int minimumLength = 2,
  }) {
    final normalized = value?.trim() ?? '';

    if (normalized.isEmpty) {
      return message;
    }

    if (normalized.length < minimumLength) {
      return 'En az $minimumLength karakter girilmelidir.';
    }

    return null;
  }

  String? _optionalUrlValidator(String? value) {
    final normalized = value?.trim() ?? '';

    if (normalized.isEmpty) {
      return null;
    }

    final uri = Uri.tryParse(normalized);

    if (uri == null ||
        !uri.hasScheme ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty) {
      return 'Geçerli bir http veya https adresi girin.';
    }

    return null;
  }

  String? _concreteTargetValidator(String? _) {
    if (_productNameController.text.trim().isEmpty &&
        _sellerNameController.text.trim().isEmpty &&
        _targetUrlController.text.trim().isEmpty) {
      return 'En az bir somut hedef girin: ürün, satıcı veya URL.';
    }
    return null;
  }

  Future<bool> _confirmOperation() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Operasyonu Onayla'),
        content: Text(
          'Marka: ${_readiness?.brandName ?? ''}\n'
          'Başlık: ${_titleController.text.trim()}\n'
          'Hedef: ${_productNameController.text.trim().isNotEmpty
              ? _productNameController.text.trim()
              : _sellerNameController.text.trim().isNotEmpty
              ? _sellerNameController.text.trim()
              : _targetUrlController.text.trim()}\n\n'
          'Operasyon ve 12 ajan görevi sunucuda atomik olarak oluşturulacaktır.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Geri Dön'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Operasyonu Onayla'),
          ),
        ],
      ),
    );
    return result == true;
  }

  String _priorityLabel(AiFieldOperationPriority priority) {
    return switch (priority) {
      AiFieldOperationPriority.low => 'Düşük',
      AiFieldOperationPriority.normal => 'Normal',
      AiFieldOperationPriority.high => 'Yüksek',
      AiFieldOperationPriority.critical => 'Kritik',
    };
  }

  Future<void> _submitOperation() async {
    if (_readiness?.ready != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Marka, hizmet ve operasyon yetkisi birlikte hazır olmalıdır.',
          ),
        ),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'Lütfen kırmızı işaretli zorunlu alanları kontrol edin.',
            ),
          ),
        );
      return;
    }

    if (!await _confirmOperation()) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final initialInput = <String, dynamic>{
        'brandName': _brandNameController.text.trim(),
        'productName': _productNameController.text.trim(),
        'sellerName': _sellerNameController.text.trim(),
        'targetUrl': _targetUrlController.text.trim(),
        'requestedAgentCount': AiFieldAgentCatalog.agents.length,
      };

      final operationId = await _operationService.createOperation(
        title: _titleController.text,
        objective: _objectiveController.text,
        priority: _priority,
        initialInput: initialInput,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Operasyon ve 12 ajan görevi oluşturuldu. '
            'Operasyon No: $operationId',
          ),
          duration: const Duration(seconds: 6),
        ),
      );

      Navigator.of(context).pop(operationId);
    } on AiFieldOperationFailure catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } on StateError catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message.toString()),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Operasyon oluşturulurken hata oluştu: $error'),
          backgroundColor: Colors.red.shade700,
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
          'Yeni Yapay Zekâ Saha Operasyonu',
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
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _OperationCreateHeader(),
                  const SizedBox(height: 18),
                  _ReadinessPanel(
                    readiness: _readiness,
                    loading: _isLoadingReadiness,
                    error: _readinessError,
                    onRetry: _loadReadiness,
                  ),
                  const SizedBox(height: 22),
                  _FormSection(
                    title: 'Operasyon Tanımı',
                    description:
                        'Ajanların hangi marka koruma hedefi için '
                        'çalışacağını tanımlayın.',
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _titleController,
                          maxLength: 180,
                          validator: (value) => _requiredValidator(
                            value,
                            'Operasyon başlığı zorunludur.',
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Operasyon Başlığı *',
                            hintText:
                                'Örnek: İstanbul dijital raf fiyat taraması',
                            prefixIcon: Icon(Icons.assignment_outlined),
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _objectiveController,
                          minLines: 4,
                          maxLines: 7,
                          maxLength: 2000,
                          validator: (value) => _requiredValidator(
                            value,
                            'Operasyon amacı zorunludur.',
                            minimumLength: 3,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Operasyon Amacı *',
                            hintText:
                                'Ajanların hangi veriyi, neden ve hangi '
                                'kapsamda toplaması gerektiğini açıklayın.',
                            alignLabelWithHint: true,
                            prefixIcon: Icon(Icons.flag_outlined),
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<AiFieldOperationPriority>(
                          initialValue: _priority,
                          decoration: const InputDecoration(
                            labelText: 'Operasyon Önceliği',
                            prefixIcon: Icon(Icons.priority_high_outlined),
                            border: OutlineInputBorder(),
                          ),
                          items: AiFieldOperationPriority.values
                              .map(
                                (priority) => DropdownMenuItem(
                                  value: priority,
                                  child: Text(_priorityLabel(priority)),
                                ),
                              )
                              .toList(),
                          onChanged: _isSubmitting
                              ? null
                              : (value) {
                                  if (value == null) {
                                    return;
                                  }

                                  setState(() {
                                    _priority = value;
                                  });
                                },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  _FormSection(
                    title: 'Başlangıç Verileri',
                    description:
                        'Bu veriler ilk olarak Görev Planlama Ajanına '
                        'aktarılır.',
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _brandNameController,
                          readOnly: true,
                          decoration: const InputDecoration(
                            labelText: 'Doğrulanmış marka',
                            hintText: 'Örnek: MarkaKalkan Test Markası',
                            prefixIcon: Icon(Icons.shield_outlined),
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _productNameController,
                          validator: _concreteTargetValidator,
                          decoration: const InputDecoration(
                            labelText: 'Ürün Adı',
                            hintText: 'Örnek: Bal 850 g',
                            prefixIcon: Icon(Icons.inventory_2_outlined),
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _sellerNameController,
                          decoration: const InputDecoration(
                            labelText: 'Hedef Satıcı veya Mağaza',
                            hintText:
                                'Biliniyorsa satıcı, mağaza veya hesap adı',
                            prefixIcon: Icon(Icons.storefront_outlined),
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _targetUrlController,
                          keyboardType: TextInputType.url,
                          validator: _optionalUrlValidator,
                          decoration: const InputDecoration(
                            labelText: 'Başlangıç URL’si',
                            hintText: 'https://...',
                            helperText:
                                'Yalnız incelemenin başlayacağı açık http/https adresini girin.',
                            prefixIcon: Icon(Icons.link_outlined),
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  const _AgentCreationSummary(),
                  const SizedBox(height: 22),
                  FilledButton.icon(
                    onPressed:
                        _isSubmitting ||
                            _isLoadingReadiness ||
                            _readiness?.ready != true
                        ? null
                        : _submitOperation,
                    style: FilledButton.styleFrom(
                      backgroundColor: MarkaKalkanTheme.teal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        vertical: 18,
                        horizontal: 24,
                      ),
                    ),
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 19,
                            height: 19,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.rocket_launch_outlined),
                    label: Text(
                      _isSubmitting
                          ? 'Operasyon oluşturuluyor...'
                          : 'Operasyonu ve 12 Ajan Görevini Oluştur',
                      style: const TextStyle(fontWeight: FontWeight.w800),
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

class _ReadinessPanel extends StatelessWidget {
  const _ReadinessPanel({
    required this.readiness,
    required this.loading,
    required this.error,
    required this.onRetry,
  });

  final AiFieldOperationReadiness? readiness;
  final bool loading;
  final String? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const _FormSection(
        title: 'Operasyon Hazırlığı',
        description: 'Marka, hizmet ve işlem yetkileri doğrulanıyor.',
        child: LinearProgressIndicator(),
      );
    }
    if (error != null) {
      return _FormSection(
        title: 'Operasyon Hazırlığı',
        description: error!,
        child: Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Yeniden Doğrula'),
          ),
        ),
      );
    }
    final value = readiness;
    return _FormSection(
      title: 'Operasyon Hazırlığı',
      description: value?.ready == true
          ? 'Üç güvenlik koşulu tamamlandı. Operasyon oluşturulabilir.'
          : 'Operasyon başlamadan önce üç koşul birlikte tamamlanmalıdır.',
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          _ReadinessGate(
            label: 'Doğrulanmış marka',
            ready: value?.verifiedBrand == true,
          ),
          _ReadinessGate(
            label: 'Hizmet erişimi',
            ready: value?.serviceAccess == true,
          ),
          _ReadinessGate(
            label: 'Operasyon yetkisi',
            ready: value?.operationAuthority == true,
          ),
        ],
      ),
    );
  }
}

class _ReadinessGate extends StatelessWidget {
  const _ReadinessGate({required this.label, required this.ready});

  final String label;
  final bool ready;

  @override
  Widget build(BuildContext context) {
    final color = ready ? MarkaKalkanTheme.teal : const Color(0xFF9A5B28);
    return Chip(
      avatar: Icon(
        ready ? Icons.verified_outlined : Icons.lock_outline,
        size: 18,
        color: color,
      ),
      label: Text(ready ? '$label · Hazır' : '$label · Gerekli'),
      side: BorderSide(color: color.withValues(alpha: 0.45)),
      backgroundColor: color.withValues(alpha: 0.08),
    );
  }
}

class _OperationCreateHeader extends StatelessWidget {
  const _OperationCreateHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [MarkaKalkanTheme.navy, Color(0xFF183B4E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.psychology_alt_outlined,
            size: 42,
            color: MarkaKalkanTheme.teal,
          ),
          SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bir hedef tanımlayın, ajan teşkilatı göreve başlasın.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    height: 1.25,
                  ),
                ),
                SizedBox(height: 9),
                Text(
                  'Kayıt sırasında ana operasyon ile birlikte 12 uzman '
                  'ajan görevi atomik olarak oluşturulur.',
                  style: TextStyle(
                    color: Color(0xFFD9E5EA),
                    fontSize: 14,
                    height: 1.5,
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

class _FormSection extends StatelessWidget {
  const _FormSection({
    required this.title,
    required this.description,
    required this.child,
  });

  final String title;
  final String description;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE0E7EC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: MarkaKalkanTheme.navy,
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            description,
            style: const TextStyle(
              color: Color(0xFF687580),
              fontSize: 13.5,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }
}

class _AgentCreationSummary extends StatelessWidget {
  const _AgentCreationSummary();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF5F4),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFB9DCD8)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.account_tree_outlined, color: MarkaKalkanTheme.teal),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Görev Planlama Ajanı sıraya alınır. Diğer 11 ajan bekleyen '
              'durumda oluşturulur ve aralarındaki görev devir zinciri '
              'otomatik kurulur. Nihai karar İnsan Uzman Onay Kapısında kalır.',
              style: TextStyle(
                color: Color(0xFF315F5C),
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

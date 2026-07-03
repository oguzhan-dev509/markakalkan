import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:markakalkan/core/theme/markakalkan_theme.dart';
import 'package:markakalkan/features/detective/data/detective_category_catalog.dart';
import 'package:markakalkan/features/detective/data/detective_country_catalog.dart';
import 'package:markakalkan/features/detective/data/detective_violation_catalog.dart';
import 'package:markakalkan/features/detective/data/digital_detective_task_service.dart';

class DigitalDetectiveTaskPage extends StatefulWidget {
  const DigitalDetectiveTaskPage({super.key});

  @override
  State<DigitalDetectiveTaskPage> createState() =>
      _DigitalDetectiveTaskPageState();
}

class _DigitalDetectiveTaskPageState extends State<DigitalDetectiveTaskPage> {
  final _formKey = GlobalKey<FormState>();
  final _taskService = DigitalDetectiveTaskService();

  final _taskNameController = TextEditingController();
  final _brandNameController = TextEditingController();
  final _productNameController = TextEditingController();
  String? _selectedCategoryId;
  String? _selectedSubcategory;
  final Set<String> _selectedViolationIds = {};
  final _searchTermsController = TextEditingController();
  final _excludedTermsController = TextEditingController();
  final Set<String> _selectedCountries = {};
  final _citiesController = TextEditingController();
  final _minPriceController = TextEditingController();
  final _maxPriceController = TextEditingController();

  static const List<String> _availableSources = [
    'Açık Web',
    'Pazaryerleri',
    'Sosyal Medya',
    'Sahte Web Siteleri',
    'Alan Adları',
    'Mobil Uygulamalar',
  ];

  static const List<String> _frequencies = [
    'Günlük',
    'Haftada 3',
    'Haftalık',
    'Aylık',
  ];

  static const List<String> _riskLevels = ['Standart', 'Hassas', 'Çok Hassas'];

  static const List<String> _currencies = ['TRY', 'USD', 'EUR', 'GBP'];

  final Set<String> _selectedSources = {'Açık Web', 'Pazaryerleri'};

  String _frequency = 'Günlük';
  String _riskLevel = 'Standart';
  String _currency = 'TRY';

  DateTime? _startDate;
  DateTime? _endDate;

  bool _isSubmitting = false;

  @override
  void dispose() {
    _taskNameController.dispose();
    _brandNameController.dispose();
    _productNameController.dispose();

    _searchTermsController.dispose();
    _excludedTermsController.dispose();
    _citiesController.dispose();
    _minPriceController.dispose();
    _maxPriceController.dispose();
    super.dispose();
  }

  String? _requiredValidator(String? value, String message) {
    if ((value?.trim() ?? '').isEmpty) {
      return message;
    }

    return null;
  }

  String _formatDate(DateTime? date) {
    if (date == null) {
      return 'Tarih seçilmedi';
    }

    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');

    return '$day.$month.${date.year}';
  }

  Future<void> _selectStartDate() async {
    final now = DateTime.now();

    final selected = await showDatePicker(
      context: context,
      initialDate: _startDate ?? now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 5),
    );

    if (selected == null || !mounted) {
      return;
    }

    setState(() {
      _startDate = selected;

      if (_endDate != null && _endDate!.isBefore(selected)) {
        _endDate = null;
      }
    });
  }

  Future<void> _selectEndDate() async {
    final now = DateTime.now();
    final firstDate = _startDate ?? now;

    final selected = await showDatePicker(
      context: context,
      initialDate: _endDate ?? firstDate,
      firstDate: firstDate,
      lastDate: DateTime(now.year + 5),
    );

    if (selected == null || !mounted) {
      return;
    }

    setState(() {
      _endDate = selected;
    });
  }

  Future<void> _showCountryPicker() async {
    final selectedCountries = await showDialog<Set<String>>(
      context: context,
      builder: (context) =>
          _CountryPickerDialog(initialSelection: _selectedCountries),
    );

    if (selectedCountries == null || !mounted) {
      return;
    }

    setState(() {
      _selectedCountries
        ..clear()
        ..addAll(selectedCountries);
    });
  }

  List<String> _splitCommaSeparated(String value) {
    return value
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList();
  }

  double? _parseOptionalPrice(String value) {
    final normalized = value.trim().replaceAll(',', '.');

    if (normalized.isEmpty) {
      return null;
    }

    return double.tryParse(normalized);
  }

  Future<void> _submitTask() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Lütfen kırmızı işaretli zorunlu alanları doldurun.'),
            duration: Duration(seconds: 4),
          ),
        );
      return;
    }
    if (_selectedViolationIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('En az bir şüphe veya ihlal türü seçmelisiniz.'),
        ),
      );
      return;
    }
    if (_selectedSources.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('En az bir tarama kaynağı seçmelisiniz.')),
      );
      return;
    }

    if (_startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Görev başlangıç ve bitiş tarihlerini seçmelisiniz.'),
        ),
      );
      return;
    }

    final minimumPrice = _parseOptionalPrice(_minPriceController.text);
    final maximumPrice = _parseOptionalPrice(_maxPriceController.text);

    if (_minPriceController.text.trim().isNotEmpty && minimumPrice == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Minimum fiyat geçerli bir sayı olmalıdır.'),
        ),
      );
      return;
    }

    if (_maxPriceController.text.trim().isNotEmpty && maximumPrice == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Maksimum fiyat geçerli bir sayı olmalıdır.'),
        ),
      );
      return;
    }

    if (minimumPrice != null &&
        maximumPrice != null &&
        minimumPrice > maximumPrice) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Minimum fiyat, maksimum fiyattan büyük olamaz.'),
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final violationIds = _selectedViolationIds.toList()..sort();
      final sources = _selectedSources.toList()..sort();
      final countries = _selectedCountries.toList()..sort();

      final taskId = await _taskService.createTask(
        taskName: _taskNameController.text,
        brandName: _brandNameController.text,
        productName: _productNameController.text,
        categoryId: _selectedCategoryId!,
        subcategory: _selectedSubcategory,
        violationIds: violationIds,
        sources: sources,
        searchTerms: _splitCommaSeparated(_searchTermsController.text),
        excludedTerms: _splitCommaSeparated(_excludedTermsController.text),
        countries: countries,
        cities: _splitCommaSeparated(_citiesController.text),
        minimumPrice: minimumPrice,
        maximumPrice: maximumPrice,
        currency: _currency,
        frequency: _frequency,
        riskLevel: _riskLevel,
        startDate: _startDate!,
        endDate: _endDate!,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Dijital Dedektif görevi oluşturuldu. Görev No: $taskId',
          ),
        ),
      );
    } on FirebaseException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Görev Firestore’a kaydedilemedi: ${error.message ?? error.code}',
          ),
        ),
      );
    } on StateError catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message.toString())));
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Görev oluşturulurken hata oluştu: $error')),
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
          'Dijital Dedektif Görevi',
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
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _TaskHeader(),
                const SizedBox(height: 24),
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _FormSection(
                        title: 'Görev ve marka bilgileri',
                        icon: Icons.manage_search_outlined,
                        child: Column(
                          children: [
                            _ResponsiveFieldRow(
                              first: TextFormField(
                                controller: _taskNameController,
                                decoration: const InputDecoration(
                                  labelText: 'Görev adı',
                                  hintText:
                                      'Örnek: Dejure dijital pazar taraması',
                                  prefixIcon: Icon(Icons.assignment_outlined),
                                ),
                                validator: (value) => _requiredValidator(
                                  value,
                                  'Görev adını girin.',
                                ),
                              ),
                              second: TextFormField(
                                controller: _brandNameController,
                                decoration: const InputDecoration(
                                  labelText: 'Marka adı',
                                  hintText: 'Korunacak marka',
                                  prefixIcon: Icon(Icons.verified_outlined),
                                ),
                                validator: (value) => _requiredValidator(
                                  value,
                                  'Marka adını girin.',
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _productNameController,
                              decoration: const InputDecoration(
                                labelText: 'Ürün, model veya ürün grubu',
                                hintText:
                                    'Örnek: Dejure erkek günlük spor ayakkabı',
                                prefixIcon: Icon(Icons.inventory_2_outlined),
                              ),
                              validator: (value) => _requiredValidator(
                                value,
                                'Ürün, model veya ürün grubunu girin.',
                              ),
                            ),
                            const SizedBox(height: 16),
                            _ResponsiveFieldRow(
                              first: DropdownButtonFormField<String>(
                                initialValue: _selectedCategoryId,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'Ana kategori',
                                  prefixIcon: Icon(Icons.category_outlined),
                                ),
                                items: DetectiveCategoryCatalog.categories
                                    .map(
                                      (category) => DropdownMenuItem<String>(
                                        value: category.id,
                                        child: Text(
                                          category.name,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    )
                                    .toList(),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Ana kategori seçin.';
                                  }

                                  return null;
                                },
                                onChanged: (value) {
                                  setState(() {
                                    _selectedCategoryId = value;
                                    _selectedSubcategory = null;

                                    final allowedViolationIds =
                                        DetectiveViolationCatalog.forCategory(
                                              value,
                                            )
                                            .map((violation) => violation.id)
                                            .toSet();

                                    _selectedViolationIds.removeWhere(
                                      (id) => !allowedViolationIds.contains(id),
                                    );
                                  });
                                },
                              ),
                              second: DropdownButtonFormField<String>(
                                key: ValueKey(_selectedCategoryId),
                                initialValue: _selectedSubcategory,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'Alt kategori',
                                  prefixIcon: Icon(Icons.account_tree_outlined),
                                ),
                                items:
                                    DetectiveCategoryCatalog.subcategoriesFor(
                                          _selectedCategoryId,
                                        )
                                        .map(
                                          (subcategory) =>
                                              DropdownMenuItem<String>(
                                                value: subcategory,
                                                child: Text(
                                                  subcategory,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                        )
                                        .toList(),
                                validator: (value) {
                                  if (_selectedCategoryId == null) {
                                    return 'Önce ana kategori seçin.';
                                  }

                                  if (value == null || value.isEmpty) {
                                    return 'Alt kategori seçin.';
                                  }

                                  return null;
                                },
                                onChanged: _selectedCategoryId == null
                                    ? null
                                    : (value) {
                                        setState(() {
                                          _selectedSubcategory = value;
                                        });
                                      },
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      _FormSection(
                        title: 'Şüphe / İhlal Türü',
                        icon: Icons.policy_outlined,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'Dijital Dedektifin hangi risk ve ihlal işaretlerini '
                              'araması gerektiğini seçin.',
                              style: TextStyle(
                                color: Color(0xFF687580),
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 16),
                            if (_selectedCategoryId == null)
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF3F5F7),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Text(
                                  'İhlal türlerini görmek için önce ana kategori seçin.',
                                  style: TextStyle(
                                    color: Color(0xFF687580),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              )
                            else
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children:
                                    DetectiveViolationCatalog.forCategory(
                                      _selectedCategoryId,
                                    ).map((violation) {
                                      final selected = _selectedViolationIds
                                          .contains(violation.id);

                                      return FilterChip(
                                        label: Text(violation.name),
                                        selected: selected,
                                        onSelected: (isSelected) {
                                          setState(() {
                                            if (isSelected) {
                                              _selectedViolationIds.add(
                                                violation.id,
                                              );
                                            } else {
                                              _selectedViolationIds.remove(
                                                violation.id,
                                              );
                                            }
                                          });
                                        },
                                        selectedColor: const Color(0xFFE8F6F4),
                                        checkmarkColor: MarkaKalkanTheme.teal,
                                        tooltip: violation.description,
                                        labelStyle: TextStyle(
                                          color: selected
                                              ? MarkaKalkanTheme.navy
                                              : const Color(0xFF687580),
                                          fontWeight: selected
                                              ? FontWeight.w700
                                              : FontWeight.w500,
                                        ),
                                      );
                                    }).toList(),
                              ),
                            if (_selectedCategoryId != null &&
                                _selectedViolationIds.isEmpty) ...[
                              const SizedBox(height: 12),
                              const Text(
                                'En az bir şüphe veya ihlal türü seçilmelidir.',
                                style: TextStyle(
                                  color: Color(0xFF9B6A10),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      _FormSection(
                        title: 'Arama kelimeleri',
                        icon: Icons.manage_search_outlined,
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _searchTermsController,
                              minLines: 2,
                              maxLines: 4,
                              decoration: const InputDecoration(
                                labelText: 'Aranacak kelimeler',
                                hintText:
                                    'Virgülle ayırın: Dejure, Dejure ayakkabı, '
                                    'ucuz Dejure, replika Dejure',
                                prefixIcon: Icon(Icons.search_outlined),
                                alignLabelWithHint: true,
                                helperText:
                                    'Marka adı, ürün adı, yanlış yazımlar ve '
                                    'riskli satış ifadeleri eklenebilir.',
                              ),
                              validator: (value) => _requiredValidator(
                                value,
                                'En az bir arama kelimesi girin.',
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _excludedTermsController,
                              minLines: 2,
                              maxLines: 3,
                              decoration: const InputDecoration(
                                labelText: 'Hariç tutulacak kelimeler',
                                hintText:
                                    'Virgülle ayırın: resmi mağaza, kurumsal site',
                                prefixIcon: Icon(Icons.remove_circle_outline),
                                alignLabelWithHint: true,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      _FormSection(
                        title: 'Tarama kaynakları',
                        icon: Icons.public_outlined,
                        child: Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: _availableSources.map((source) {
                            final selected = _selectedSources.contains(source);

                            return FilterChip(
                              label: Text(source),
                              selected: selected,
                              onSelected: (isSelected) {
                                setState(() {
                                  if (isSelected) {
                                    _selectedSources.add(source);
                                  } else {
                                    _selectedSources.remove(source);
                                  }
                                });
                              },
                              selectedColor: const Color(0xFFE8F6F4),
                              checkmarkColor: MarkaKalkanTheme.teal,
                              labelStyle: TextStyle(
                                color: selected
                                    ? MarkaKalkanTheme.navy
                                    : const Color(0xFF687580),
                                fontWeight: selected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 20),
                      _FormSection(
                        title: 'Ülkeler ve fiyat kapsamı',
                        icon: Icons.location_on_outlined,
                        child: Column(
                          children: [
                            _ResponsiveFieldRow(
                              first: _CountryMultiSelectField(
                                selectedCountries: _selectedCountries,
                                onTap: _showCountryPicker,
                                onRemove: (country) {
                                  setState(() {
                                    _selectedCountries.remove(country);
                                  });
                                },
                                onClear: () {
                                  setState(() {
                                    _selectedCountries.clear();
                                  });
                                },
                              ),
                              second: TextFormField(
                                controller: _citiesController,
                                decoration: const InputDecoration(
                                  labelText: 'Şehirler',
                                  hintText: 'Virgülle ayırın: İstanbul, Ankara',
                                  prefixIcon: Icon(
                                    Icons.location_city_outlined,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final isNarrow = constraints.maxWidth < 700;

                                final minPriceField = TextFormField(
                                  controller: _minPriceController,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  decoration: const InputDecoration(
                                    labelText: 'Minimum fiyat',
                                    prefixIcon: Icon(
                                      Icons.arrow_downward_outlined,
                                    ),
                                  ),
                                );

                                final maxPriceField = TextFormField(
                                  controller: _maxPriceController,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  decoration: const InputDecoration(
                                    labelText: 'Maksimum fiyat',
                                    prefixIcon: Icon(
                                      Icons.arrow_upward_outlined,
                                    ),
                                  ),
                                );

                                final currencyField =
                                    DropdownButtonFormField<String>(
                                      initialValue: _currency,
                                      decoration: const InputDecoration(
                                        labelText: 'Para birimi',
                                        prefixIcon: Icon(
                                          Icons.payments_outlined,
                                        ),
                                      ),
                                      items: _currencies
                                          .map(
                                            (currency) => DropdownMenuItem(
                                              value: currency,
                                              child: Text(currency),
                                            ),
                                          )
                                          .toList(),
                                      onChanged: (value) {
                                        if (value == null) {
                                          return;
                                        }

                                        setState(() {
                                          _currency = value;
                                        });
                                      },
                                    );

                                if (isNarrow) {
                                  return Column(
                                    children: [
                                      minPriceField,
                                      const SizedBox(height: 16),
                                      maxPriceField,
                                      const SizedBox(height: 16),
                                      currencyField,
                                    ],
                                  );
                                }

                                return Row(
                                  children: [
                                    Expanded(child: minPriceField),
                                    const SizedBox(width: 16),
                                    Expanded(child: maxPriceField),
                                    const SizedBox(width: 16),
                                    Expanded(child: currencyField),
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      _FormSection(
                        title: 'Görev planı ve risk hassasiyeti',
                        icon: Icons.schedule_outlined,
                        child: Column(
                          children: [
                            _ResponsiveFieldRow(
                              first: DropdownButtonFormField<String>(
                                initialValue: _frequency,
                                decoration: const InputDecoration(
                                  labelText: 'Tarama sıklığı',
                                  prefixIcon: Icon(Icons.repeat_outlined),
                                ),
                                items: _frequencies
                                    .map(
                                      (frequency) => DropdownMenuItem(
                                        value: frequency,
                                        child: Text(frequency),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) {
                                  if (value == null) {
                                    return;
                                  }

                                  setState(() {
                                    _frequency = value;
                                  });
                                },
                              ),
                              second: DropdownButtonFormField<String>(
                                initialValue: _riskLevel,
                                decoration: const InputDecoration(
                                  labelText: 'Risk hassasiyeti',
                                  prefixIcon: Icon(Icons.tune_outlined),
                                ),
                                items: _riskLevels
                                    .map(
                                      (risk) => DropdownMenuItem(
                                        value: risk,
                                        child: Text(risk),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) {
                                  if (value == null) {
                                    return;
                                  }

                                  setState(() {
                                    _riskLevel = value;
                                  });
                                },
                              ),
                            ),
                            const SizedBox(height: 16),
                            _ResponsiveFieldRow(
                              first: _DateSelector(
                                label: 'Başlangıç tarihi',
                                value: _formatDate(_startDate),
                                icon: Icons.event_available_outlined,
                                onTap: _selectStartDate,
                              ),
                              second: _DateSelector(
                                label: 'Bitiş tarihi',
                                value: _formatDate(_endDate),
                                icon: Icons.event_busy_outlined,
                                onTap: _selectEndDate,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      const _RiskNotice(),
                      const SizedBox(height: 22),
                      FilledButton.icon(
                        onPressed: _isSubmitting ? null : _submitTask,
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
                            : const Icon(Icons.radar_outlined),
                        label: Text(
                          _isSubmitting
                              ? 'Görev hazırlanıyor...'
                              : 'Dijital Dedektif Görevi Oluştur',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
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

class _TaskHeader extends StatelessWidget {
  const _TaskHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [MarkaKalkanTheme.navy, Color(0xFF183B4E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.travel_explore_outlined,
            color: MarkaKalkanTheme.teal,
            size: 48,
          ),
          SizedBox(width: 22),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Dijital pazarda markanızın izini sürün',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  'Marka, ürün, bölge ve tarama kaynaklarını belirleyin. '
                  'Dijital Dedektif şüpheli ilanları, satıcıları, fiyatları '
                  've marka taklitlerini düzenli olarak araştırmak üzere '
                  'görevlendirilsin.',
                  style: TextStyle(color: Color(0xFFD9E5EA), height: 1.55),
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
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE0E7EC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, color: MarkaKalkanTheme.teal),
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
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }
}

class _ResponsiveFieldRow extends StatelessWidget {
  const _ResponsiveFieldRow({required this.first, required this.second});

  final Widget first;
  final Widget second;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 700) {
          return Column(children: [first, const SizedBox(height: 16), second]);
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: first),
            const SizedBox(width: 16),
            Expanded(child: second),
          ],
        );
      },
    );
  }
}

class _CountryMultiSelectField extends StatelessWidget {
  const _CountryMultiSelectField({
    required this.selectedCountries,
    required this.onTap,
    required this.onRemove,
    required this.onClear,
  });

  final Set<String> selectedCountries;
  final VoidCallback onTap;
  final ValueChanged<String> onRemove;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final sortedCountries = selectedCountries.toList()..sort();

    return FormField<Set<String>>(
      validator: (_) {
        if (selectedCountries.isEmpty) {
          return 'En az bir ülke seçin.';
        }

        return null;
      },
      builder: (field) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: double.infinity,
                constraints: const BoxConstraints(minHeight: 58),
                padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: field.hasError
                        ? Theme.of(context).colorScheme.error
                        : const Color(0xFFB8C2C9),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 7),
                      child: Icon(Icons.flag_outlined),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: selectedCountries.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Text(
                                'Bir veya birden fazla ülke seçin',
                                style: TextStyle(
                                  color: Color(0xFF687580),
                                  fontSize: 16,
                                ),
                              ),
                            )
                          : Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: sortedCountries
                                  .map(
                                    (country) => InputChip(
                                      label: Text(country),
                                      onDeleted: () {
                                        onRemove(country);
                                        field.validate();
                                      },
                                      deleteIcon: const Icon(
                                        Icons.close,
                                        size: 18,
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                    ),
                    IconButton(
                      tooltip: 'Ülke seç',
                      onPressed: onTap,
                      icon: const Icon(Icons.arrow_drop_down),
                    ),
                  ],
                ),
              ),
            ),
            if (field.hasError) ...[
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(left: 16),
                child: Text(
                  field.errorText!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
            if (selectedCountries.length > 1)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () {
                    onClear();
                    field.validate();
                  },
                  icon: const Icon(Icons.delete_sweep_outlined, size: 18),
                  label: const Text('Tümünü temizle'),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _CountryPickerDialog extends StatefulWidget {
  const _CountryPickerDialog({required this.initialSelection});

  final Set<String> initialSelection;

  @override
  State<_CountryPickerDialog> createState() => _CountryPickerDialogState();
}

class _CountryPickerDialogState extends State<_CountryPickerDialog> {
  final _searchController = TextEditingController();
  late final Set<String> _draftSelection;

  @override
  void initState() {
    super.initState();
    _draftSelection = Set<String>.from(widget.initialSelection);
    _searchController.addListener(_refreshSearch);
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_refreshSearch)
      ..dispose();
    super.dispose();
  }

  void _refreshSearch() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim().toLowerCase();

    final filteredCountries = DetectiveCountryCatalog.countries
        .where(
          (country) => query.isEmpty || country.toLowerCase().contains(query),
        )
        .toList();

    return AlertDialog(
      title: const Text('Ülke seçimi'),
      content: SizedBox(
        width: 620,
        height: 560,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _searchController,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Ülke ara',
                hintText: 'Örnek: Türkiye, Almanya',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Aramayı temizle',
                        onPressed: _searchController.clear,
                        icon: const Icon(Icons.close),
                      ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '${_draftSelection.length} ülke seçildi',
              style: const TextStyle(
                color: MarkaKalkanTheme.navy,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: filteredCountries.isEmpty
                  ? const Center(
                      child: Text('Aramayla eşleşen ülke bulunamadı.'),
                    )
                  : ListView.builder(
                      itemCount: filteredCountries.length,
                      itemBuilder: (context, index) {
                        final country = filteredCountries[index];
                        final selected = _draftSelection.contains(country);

                        return CheckboxListTile(
                          value: selected,
                          title: Text(country),
                          controlAffinity: ListTileControlAffinity.leading,
                          activeColor: MarkaKalkanTheme.teal,
                          onChanged: (value) {
                            setState(() {
                              if (value ?? false) {
                                _draftSelection.add(country);
                              } else {
                                _draftSelection.remove(country);
                              }
                            });
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _draftSelection.isEmpty
              ? null
              : () {
                  setState(() {
                    _draftSelection.clear();
                  });
                },
          child: const Text('Tümünü temizle'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('İptal'),
        ),
        FilledButton.icon(
          onPressed: () {
            Navigator.of(context).pop(Set<String>.from(_draftSelection));
          },
          icon: const Icon(Icons.check),
          label: const Text('Seçimi uygula'),
        ),
      ],
    );
  }
}

class _DateSelector extends StatelessWidget {
  const _DateSelector({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          suffixIcon: const Icon(Icons.calendar_month_outlined),
        ),
        child: Text(
          value,
          style: const TextStyle(
            color: MarkaKalkanTheme.navy,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _RiskNotice extends StatelessWidget {
  const _RiskNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7E8),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF1D9A9)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.policy_outlined, color: Color(0xFF9B6A10)),
          SizedBox(width: 14),
          Expanded(
            child: Text(
              'Dijital Dedektif sonuçları otomatik risk göstergeleridir. '
              'Bir ilan, ürün veya satıcı yalnızca sistem bulgusuyla '
              '“sahte” olarak nitelendirilmez. Yüksek riskli kayıtlar '
              'insan incelemesine ve gerektiğinde uzman değerlendirmesine '
              'aktarılır.',
              style: TextStyle(
                color: Color(0xFF5B461D),
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

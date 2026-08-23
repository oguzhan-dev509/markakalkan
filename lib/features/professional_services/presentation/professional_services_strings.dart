import 'package:flutter/widgets.dart';

import '../domain/professional_service_models.dart';

class ProfessionalServicesStrings {
  const ProfessionalServicesStrings._({required bool english})
    : _english = english;

  static const ProfessionalServicesStrings turkish =
      ProfessionalServicesStrings._(english: false);
  static const ProfessionalServicesStrings english =
      ProfessionalServicesStrings._(english: true);

  final bool _english;

  static ProfessionalServicesStrings of({Locale? locale}) {
    return resolve(locale ?? WidgetsBinding.instance.platformDispatcher.locale);
  }

  static ProfessionalServicesStrings resolve(Locale? locale) {
    return locale?.languageCode.toLowerCase() == 'en' ? english : turkish;
  }

  String get pageTitle => _english
      ? 'Professional Services Center'
      : 'Profesyonel Hizmetler Merkezi';

  String get operationBoundariesTitle =>
      _english ? 'Operation boundaries' : 'Operasyon sınırları';

  String get operationBoundariesDescription => _english
      ? 'Eight callable operations pass through one Auth + App Check boundary. '
            'This foundation phase only establishes the connection, model, and '
            'state layers; valid production commands never run automatically.'
      : 'Sekiz callable işlem tek bir Auth + App Check sınırından geçer. '
            'Bu temel faz yalnız bağlantı, model ve durum omurgasını kurar; '
            'geçerli üretim komutları otomatik olarak çalıştırılmaz.';

  String get introTitle => _english
      ? 'Turn expertise into a controlled operation.'
      : 'Uzmanlığı kontrollü operasyona dönüştürün.';

  String get introDescription => _english
      ? 'Manage legal, brand-protection, and specialist advisory work through '
            'a chain of requests, authorization, assignment, AI assistance, '
            'human review, and controlled publication.'
      : 'Hukuk, marka koruma ve uzman danışmanlık süreçlerini talep, yetki, '
            'görevlendirme, yapay zekâ desteği, insan incelemesi ve kontrollü '
            'yayın zincirinde yönetin.';

  String get introSemanticLabel => _english
      ? 'Professional Services introduction. $introTitle'
      : 'Profesyonel Hizmetler tanıtımı. $introTitle';

  String get supportIconTooltip =>
      _english ? 'Professional support' : 'Profesyonel destek';

  String get foundationChip => _english
      ? 'Auth + App Check protected frontend foundation'
      : 'Auth + App Check korumalı frontend temeli';

  String get workflowTitle => _english
      ? 'Controlled service lifecycle'
      : 'Kontrollü hizmet yaşam döngüsü';

  String get workflowSemanticLabel => _english
      ? 'Five-step controlled professional-service lifecycle'
      : 'Beş aşamalı kontrollü profesyonel hizmet yaşam döngüsü';

  List<({String title, String description})> get workflowSteps => _english
      ? const [
          (
            title: '1. Service request',
            description: 'The purpose, scope, and source links are recorded.',
          ),
          (
            title: '2. Authority and scope',
            description:
                'The authority domain, professional class, and boundaries '
                'are verified.',
          ),
          (
            title: '3. Assignment',
            description:
                'The specialist, provider, and service conditions are linked.',
          ),
          (
            title: '4. Agent work',
            description:
                'A draft output linked to the source manifest is created.',
          ),
          (
            title: '5. Human review and publication',
            description:
                'No output is published without an authorized human decision.',
          ),
        ]
      : const [
          (
            title: '1. Hizmet talebi',
            description: 'Amaç, kapsam ve kaynak bağları kaydedilir.',
          ),
          (
            title: '2. Yetki ve kapsam',
            description:
                'Yetki alanı, profesyonel sınıf ve sınırlar doğrulanır.',
          ),
          (
            title: '3. Görevlendirme',
            description: 'Uzman, sağlayıcı ve hizmet koşulları bağlanır.',
          ),
          (
            title: '4. Ajan çalışması',
            description: 'Kaynak manifestine bağlı taslak çıktı oluşturulur.',
          ),
          (
            title: '5. İnsan incelemesi ve yayın',
            description: 'Yetkili insan kararı olmadan çıktı yayımlanmaz.',
          ),
        ];

  String get selectCapabilityHint => _english
      ? 'Select this boundary. No business command will run.'
      : 'Bu sınırı seçin. Hiçbir iş komutu çalıştırılmaz.';

  String get selectBoundaryPrompt =>
      _english ? 'Select an operation boundary' : 'Bir operasyon sınırı seçin';

  String get boundaryDefaultDescription => _english
      ? 'Each card represents a separate operation boundary in the production '
            'callable contract.'
      : 'Her kart, production callable sözleşmesindeki ayrı bir işlem '
            'sınırını temsil eder.';

  String get boundarySelectedDescription => _english
      ? 'This boundary is selected. Complete the protected command form below; '
            'nothing runs until you explicitly submit it.'
      : 'Bu sınır seçildi. Aşağıdaki korumalı komut formunu doldurun; '
            'siz açıkça göndermeden hiçbir işlem çalıştırılmaz.';

  String get boundaryRunningDescription => _english
      ? 'The operation is running through the protected callable boundary.'
      : 'İşlem güvenli callable sınırında yürütülüyor.';

  String boundarySucceededDescription(String resultType) => _english
      ? 'Operation completed: $resultType'
      : 'İşlem tamamlandı: $resultType';

  String get boundaryFailedDescription => _english
      ? 'The operation could not be completed.'
      : 'İşlem tamamlanamadı.';

  String operationTitle(ProfessionalServiceOperation operation) {
    if (_english) {
      return switch (operation) {
        ProfessionalServiceOperation.createServiceRequest =>
          'Professional service request',
        ProfessionalServiceOperation.transitionServiceRequest =>
          'Request status transition',
        ProfessionalServiceOperation.createServiceEngagement =>
          'Service scope and engagement',
        ProfessionalServiceOperation.createServiceAssignment =>
          'Specialist assignment',
        ProfessionalServiceOperation.startAgentRun => 'AI agent run',
        ProfessionalServiceOperation.recordAgentOutput => 'Agent output draft',
        ProfessionalServiceOperation.recordAgentReview =>
          'Authorized human review',
        ProfessionalServiceOperation.publishAgentOutput =>
          'Controlled output publication',
      };
    }

    return switch (operation) {
      ProfessionalServiceOperation.createServiceRequest =>
        'Profesyonel hizmet talebi',
      ProfessionalServiceOperation.transitionServiceRequest =>
        'Talep durumu geçişi',
      ProfessionalServiceOperation.createServiceEngagement =>
        'Hizmet kapsamı ve angajman',
      ProfessionalServiceOperation.createServiceAssignment =>
        'Uzman görevlendirmesi',
      ProfessionalServiceOperation.startAgentRun => 'Yapay zekâ ajan çalışması',
      ProfessionalServiceOperation.recordAgentOutput => 'Ajan çıktı taslağı',
      ProfessionalServiceOperation.recordAgentReview =>
        'Yetkili insan incelemesi',
      ProfessionalServiceOperation.publishAgentOutput =>
        'Kontrollü çıktı yayını',
    };
  }

  String operationDescription(ProfessionalServiceOperation operation) {
    if (_english) {
      return switch (operation) {
        ProfessionalServiceOperation.createServiceRequest =>
          'Links the service need to the canonical brand and source scope.',
        ProfessionalServiceOperation.transitionServiceRequest =>
          'Runs a version-controlled request lifecycle transition.',
        ProfessionalServiceOperation.createServiceEngagement =>
          'Finalizes scope, authorization, and service conditions.',
        ProfessionalServiceOperation.createServiceAssignment =>
          'Records an authorized professional or provider assignment.',
        ProfessionalServiceOperation.startAgentRun =>
          'Starts an auditable agent run linked to the source manifest.',
        ProfessionalServiceOperation.recordAgentOutput =>
          'Records agent output as an unpublished, immutable draft.',
        ProfessionalServiceOperation.recordAgentReview =>
          'Records the human decision, review note, and authority chain.',
        ProfessionalServiceOperation.publishAgentOutput =>
          'Links approved output to an immutable artifact under separate '
              'publication authority.',
      };
    }

    return switch (operation) {
      ProfessionalServiceOperation.createServiceRequest =>
        'Hizmet ihtiyacını kanonik marka ve kaynak kapsamına bağlar.',
      ProfessionalServiceOperation.transitionServiceRequest =>
        'Sürüm kontrollü talep yaşam döngüsü geçişini yürütür.',
      ProfessionalServiceOperation.createServiceEngagement =>
        'Kapsam, yetkilendirme ve hizmet koşullarını kesinleştirir.',
      ProfessionalServiceOperation.createServiceAssignment =>
        'Yetkili profesyonel veya sağlayıcı görevlendirmesini kaydeder.',
      ProfessionalServiceOperation.startAgentRun =>
        'Kaynak manifestine bağlı, denetlenebilir ajan çalışmasını başlatır.',
      ProfessionalServiceOperation.recordAgentOutput =>
        'Ajan çıktısını yayımlanmamış ve değişmez taslak olarak kaydeder.',
      ProfessionalServiceOperation.recordAgentReview =>
        'İnsan kararını, inceleme notunu ve yetki zincirini kaydeder.',
      ProfessionalServiceOperation.publishAgentOutput =>
        'Onaylı çıktıyı ayrı yayın yetkisiyle değişmez artefakta bağlar.',
    };
  }
}

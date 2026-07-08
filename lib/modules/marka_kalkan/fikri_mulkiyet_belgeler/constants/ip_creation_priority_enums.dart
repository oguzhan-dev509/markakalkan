enum IpCreationType {
  invention('invention', 'Bulu\u015f'),
  utilityModel('utility_model', 'Faydal\u0131 model aday\u0131'),
  industrialDesign('industrial_design', 'End\u00fcstriyel tasar\u0131m'),
  productConcept('product_concept', '\u00dcr\u00fcn konsepti'),
  software('software', 'Yaz\u0131l\u0131m'),
  sourceCode('source_code', 'Kaynak kod'),
  algorithm('algorithm', 'Algoritma'),
  literaryWork('literary_work', 'Edeb\u00ee eser'),
  screenplay('screenplay', 'Senaryo'),
  visualWork('visual_work', 'G\u00f6rsel eser'),
  musicWork('music_work', 'M\u00fczik eseri'),
  audioVisualWork('audio_visual_work', 'G\u00f6rsel-i\u015fitsel eser'),
  research('research', 'Ara\u015ft\u0131rma'),
  educationContent('education_content', 'E\u011fitim i\u00e7eri\u011fi'),
  businessModel('business_model', '\u0130\u015f modeli'),
  formula('formula', 'Form\u00fcl'),
  recipe('recipe', 'Re\u00e7ete'),
  creativeIdea('creative_idea', 'Yarat\u0131c\u0131 fikir'),
  other('other', 'Di\u011fer');

  const IpCreationType(this.value, this.label);

  final String value;
  final String label;

  static IpCreationType fromValue(String? value) {
    return IpCreationType.values.firstWhere(
      (item) => item.value == value,
      orElse: () => IpCreationType.other,
    );
  }
}

enum IpCreationPriorityStatus {
  draft('draft', 'Taslak'),
  sealed('sealed', 'M\u00fch\u00fcrlendi'),
  developing('developing', 'Geli\u015ftiriliyor'),
  completed('completed', 'Tamamland\u0131'),
  registrationPreparation(
    'registration_preparation',
    'Tescil haz\u0131rl\u0131\u011f\u0131nda',
  ),
  registered('registered', 'Tescil edildi'),
  archived('archived', 'Ar\u015fivlendi');

  const IpCreationPriorityStatus(this.value, this.label);

  final String value;
  final String label;

  static IpCreationPriorityStatus fromValue(String? value) {
    return IpCreationPriorityStatus.values.firstWhere(
      (item) => item.value == value,
      orElse: () => IpCreationPriorityStatus.draft,
    );
  }
}

enum IpCreationConfidentialityLevel {
  private('private', 'Tamamen \u00f6zel'),
  selectedPeople('selected_people', 'Yaln\u0131z se\u00e7ili ki\u015filer'),
  professionalAccess(
    'professional_access',
    'Avukat veya patent vekili eri\u015fimi',
  ),
  publicStatement(
    'public_statement',
    'Kamuya a\u00e7\u0131k \u00f6ncelik beyan\u0131',
  );

  const IpCreationConfidentialityLevel(this.value, this.label);

  final String value;
  final String label;

  static IpCreationConfidentialityLevel fromValue(String? value) {
    return IpCreationConfidentialityLevel.values.firstWhere(
      (item) => item.value == value,
      orElse: () => IpCreationConfidentialityLevel.private,
    );
  }
}

enum IpCreationSealStatus {
  unsealed('unsealed', 'M\u00fch\u00fcrlenmedi'),
  sealed('sealed', 'M\u00fch\u00fcrlendi'),
  timestampPending('timestamp_pending', 'Zaman damgas\u0131 bekliyor'),
  timestamped('timestamped', 'Zaman damgal\u0131'),
  verificationFailed(
    'verification_failed',
    'Do\u011frulama ba\u015far\u0131s\u0131z',
  );

  const IpCreationSealStatus(this.value, this.label);

  final String value;
  final String label;

  static IpCreationSealStatus fromValue(String? value) {
    return IpCreationSealStatus.values.firstWhere(
      (item) => item.value == value,
      orElse: () => IpCreationSealStatus.unsealed,
    );
  }
}

enum IpCreationDevelopmentStage {
  initialIdea('initial_idea', '\u0130lk fikir'),
  concept('concept', 'Konsept'),
  draft('draft', 'Taslak'),
  research('research', 'Ara\u015ft\u0131rma'),
  design('design', 'Tasar\u0131m'),
  prototype('prototype', 'Prototip'),
  testing('testing', 'Test'),
  finalWork('final_work', 'Son eser'),
  registration('registration', 'Tescil s\u00fcreci');

  const IpCreationDevelopmentStage(this.value, this.label);

  final String value;
  final String label;

  static IpCreationDevelopmentStage fromValue(String? value) {
    return IpCreationDevelopmentStage.values.firstWhere(
      (item) => item.value == value,
      orElse: () => IpCreationDevelopmentStage.initialIdea,
    );
  }
}

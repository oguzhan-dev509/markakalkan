class SponsorContentEntry {
  const SponsorContentEntry({
    required this.id,
    required this.displayName,
    required this.categoryCode,
    required this.categoryLabel,
    required this.websiteUrl,
    required this.logoUrl,
    required this.logoAlt,
    required this.displayOrder,
    required this.status,
    required this.startsAt,
    required this.endsAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String displayName;
  final String categoryCode;
  final String categoryLabel;
  final String websiteUrl;
  final String logoUrl;
  final String logoAlt;
  final int displayOrder;
  final String status;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isActive => status == 'active';

  factory SponsorContentEntry.fromMap(Map<String, dynamic> map) {
    return SponsorContentEntry(
      id: _text(map['id']),
      displayName: _text(map['displayName']),
      categoryCode: _text(map['categoryCode']),
      categoryLabel: _text(map['categoryLabel']),
      websiteUrl: _text(map['websiteUrl']),
      logoUrl: _text(map['logoUrl']),
      logoAlt: _text(map['logoAlt']),
      displayOrder: _integer(map['displayOrder']),
      status: _text(map['status']),
      startsAt: _date(map['startsAt']),
      endsAt: _date(map['endsAt']),
      createdAt: _date(map['createdAt']),
      updatedAt: _date(map['updatedAt']),
    );
  }

  Map<String, dynamic> toAdminPayload() {
    return <String, dynamic>{
      if (id.trim().isNotEmpty) 'id': id.trim(),
      'displayName': displayName.trim(),
      'categoryCode': categoryCode.trim(),
      'categoryLabel': categoryLabel.trim(),
      'websiteUrl': websiteUrl.trim(),
      'logoUrl': logoUrl.trim(),
      'logoAlt': logoAlt.trim(),
      'displayOrder': displayOrder,
      'status': status.trim(),
      'startsAt': startsAt?.toUtc().toIso8601String() ?? '',
      'endsAt': endsAt?.toUtc().toIso8601String() ?? '',
    };
  }

  static String _text(Object? value) => (value ?? '').toString().trim();

  static int _integer(Object? value) {
    if (value is int) return value;
    return int.tryParse((value ?? '').toString()) ?? 0;
  }

  static DateTime? _date(Object? value) {
    final text = _text(value);
    return text.isEmpty ? null : DateTime.tryParse(text)?.toUtc();
  }
}

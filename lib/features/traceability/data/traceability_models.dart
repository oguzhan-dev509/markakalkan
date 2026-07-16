class SuspiciousVerificationScan {
  const SuspiciousVerificationScan({
    required this.id,
    required this.publicCode,
    required this.productId,
    required this.batchId,
    required this.brandName,
    required this.productName,
    required this.batchNumber,
    required this.status,
    required this.platform,
    required this.source,
    required this.scanNumber,
    required this.repeatScan,
    required this.riskScore,
    required this.riskLevel,
    required this.riskReasons,
    required this.reviewStatus,
    required this.reviewNotes,
    required this.caseId,
    required this.createdAt,
    required this.reviewedAt,
  });

  final String id;
  final String publicCode;
  final String productId;
  final String batchId;
  final String brandName;
  final String productName;
  final String batchNumber;
  final String status;
  final String platform;
  final String source;
  final int scanNumber;
  final bool repeatScan;
  final int riskScore;
  final String riskLevel;
  final List<String> riskReasons;
  final String reviewStatus;
  final String reviewNotes;
  final String caseId;
  final DateTime? createdAt;
  final DateTime? reviewedAt;

  factory SuspiciousVerificationScan.fromMap(Map<String, dynamic> data) {
    return SuspiciousVerificationScan(
      id: _string(data['id']),
      publicCode: _string(data['publicCode']),
      productId: _string(data['productId']),
      batchId: _string(data['batchId']),
      brandName: _string(data['brandName']),
      productName: _string(data['productName']),
      batchNumber: _string(data['batchNumber']),
      status: _string(data['status']),
      platform: _string(data['platform']),
      source: _string(data['source']),
      scanNumber: _integer(data['scanNumber']),
      repeatScan: data['repeatScan'] == true,
      riskScore: _integer(data['riskScore']),
      riskLevel: _string(data['riskLevel'], fallback: 'none'),
      riskReasons: _strings(data['riskReasons']),
      reviewStatus: _string(data['reviewStatus'], fallback: 'pending'),
      reviewNotes: _string(data['reviewNotes']),
      caseId: _string(data['caseId']),
      createdAt: _dateTime(data['createdAtMillis']),
      reviewedAt: _dateTime(data['reviewedAtMillis']),
    );
  }
}

class TraceabilityCaseSummary {
  const TraceabilityCaseSummary({
    required this.id,
    required this.caseCode,
    required this.title,
    required this.summary,
    required this.status,
    required this.priority,
    required this.sourceType,
    required this.riskScore,
    required this.riskLevel,
    required this.riskReasons,
    required this.scanIds,
    required this.publicCodes,
    required this.productIds,
    required this.batchIds,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String caseCode;
  final String title;
  final String summary;
  final String status;
  final String priority;
  final String sourceType;
  final int riskScore;
  final String riskLevel;
  final List<String> riskReasons;
  final List<String> scanIds;
  final List<String> publicCodes;
  final List<String> productIds;
  final List<String> batchIds;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory TraceabilityCaseSummary.fromMap(Map<String, dynamic> data) {
    return TraceabilityCaseSummary(
      id: _string(data['id']),
      caseCode: _string(data['caseCode']),
      title: _string(data['title']),
      summary: _string(data['summary']),
      status: _string(data['status'], fallback: 'open'),
      priority: _string(data['priority'], fallback: 'normal'),
      sourceType: _string(data['sourceType']),
      riskScore: _integer(data['riskScore']),
      riskLevel: _string(data['riskLevel'], fallback: 'none'),
      riskReasons: _strings(data['riskReasons']),
      scanIds: _strings(data['scanIds']),
      publicCodes: _strings(data['publicCodes']),
      productIds: _strings(data['productIds']),
      batchIds: _strings(data['batchIds']),
      createdAt: _dateTime(data['createdAtMillis']),
      updatedAt: _dateTime(data['updatedAtMillis']),
    );
  }
}

String _string(Object? value, {String fallback = ''}) {
  return value is String ? value : fallback;
}

int _integer(Object? value) {
  return value is num ? value.toInt() : 0;
}

List<String> _strings(Object? value) {
  if (value is! List) return const <String>[];
  return value.whereType<String>().toList(growable: false);
}

DateTime? _dateTime(Object? value) {
  if (value is! num) return null;
  return DateTime.fromMillisecondsSinceEpoch(value.toInt());
}

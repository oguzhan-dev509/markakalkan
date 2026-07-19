library;

part 'source_ingestion_key_v1.dart';
part 'case_promotion_key_v1.dart';

const String sourceIngestionKeyContractVersionV1 = 'source-ingestion-key-v1';
const String casePromotionKeyContractVersionV1 = 'case-promotion-key-v1';

String _requiredPart(Object? value, String field) {
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('$field is required');
  }
  return value.trim();
}

String _canonicalEncoding(Iterable<String> values) =>
    values.map((value) => '${value.length}:$value').join('|');

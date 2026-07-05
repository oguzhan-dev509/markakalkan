import 'package:cloud_firestore/cloud_firestore.dart';

abstract final class IpModelUtils {
  const IpModelUtils._();

  static DateTime? dateTimeFromValue(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    if (value is String) {
      return DateTime.tryParse(value);
    }

    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }

    return null;
  }

  static Timestamp? timestampOrNull(DateTime? value) {
    return value == null ? null : Timestamp.fromDate(value);
  }

  static String requiredString(dynamic value) {
    return (value ?? '').toString().trim();
  }

  static String? nullableString(dynamic value) {
    final text = value?.toString().trim();

    return text == null || text.isEmpty ? null : text;
  }

  static bool boolFromValue(dynamic value, {bool fallback = false}) {
    if (value is bool) {
      return value;
    }

    if (value is num) {
      return value != 0;
    }

    final normalized = value?.toString().trim().toLowerCase();

    if (normalized == 'true' || normalized == '1' || normalized == 'yes') {
      return true;
    }

    if (normalized == 'false' || normalized == '0' || normalized == 'no') {
      return false;
    }

    return fallback;
  }

  static int intFromValue(dynamic value, {int fallback = 0}) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static double doubleFromValue(dynamic value, {double fallback = 0}) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
          value?.toString().trim().replaceAll(',', '.') ?? '',
        ) ??
        fallback;
  }

  static int boundedScore(dynamic value) {
    final parsed = intFromValue(value);

    if (parsed < 0) {
      return 0;
    }

    if (parsed > 100) {
      return 100;
    }

    return parsed;
  }

  static List<String> stringListFromValue(dynamic value) {
    if (value is! Iterable) {
      return const <String>[];
    }

    return cleanStringList(
      value.map((item) => item?.toString() ?? '').toList(growable: false),
    );
  }

  static List<String> cleanStringList(Iterable<String> values) {
    final seen = <String>{};
    final result = <String>[];

    for (final value in values) {
      final cleaned = value.trim();

      if (cleaned.isEmpty) {
        continue;
      }

      if (seen.add(cleaned.toLowerCase())) {
        result.add(cleaned);
      }
    }

    return List<String>.unmodifiable(result);
  }

  static Map<String, dynamic> mapFromValue(dynamic value) {
    if (value is Map<String, dynamic>) {
      return Map<String, dynamic>.unmodifiable(value);
    }

    if (value is Map) {
      return Map<String, dynamic>.unmodifiable(
        value.map((key, item) => MapEntry(key.toString(), item)),
      );
    }

    return const <String, dynamic>{};
  }

  static String? cleanNullable(String? value) {
    final cleaned = value?.trim();

    return cleaned == null || cleaned.isEmpty ? null : cleaned;
  }
}

import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:markakalkan/features/sponsor_content/models/sponsor_content_entry.dart';

class SponsorLogoUpload {
  const SponsorLogoUpload({
    required this.bytes,
    required this.fileName,
    required this.mimeType,
  });

  final Uint8List bytes;
  final String fileName;
  final String mimeType;

  Map<String, dynamic> toPayload() {
    return <String, dynamic>{
      'fileName': fileName.trim(),
      'mimeType': mimeType.trim().toLowerCase(),
      'sizeBytes': bytes.length,
      'base64Data': base64Encode(bytes),
    };
  }
}

class SponsorContentService {
  SponsorContentService({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'europe-west3');

  final FirebaseFunctions _functions;

  Future<List<SponsorContentEntry>> listPublic() async {
    final result = await _functions
        .httpsCallable('listPublicSponsorContent')
        .call<Map<String, dynamic>>();

    return _entries(result.data);
  }

  Future<List<SponsorContentEntry>> listForAdmin() async {
    final result = await _functions
        .httpsCallable('listSponsorContentForAdmin')
        .call<Map<String, dynamic>>();

    return _entries(result.data);
  }

  Future<String> upsertForAdmin(
    SponsorContentEntry entry,
    SponsorLogoUpload? logoUpload,
    bool removeLogo,
  ) async {
    final payload = entry.toAdminPayload();
    if (logoUpload != null) {
      payload['logoUpload'] = logoUpload.toPayload();
    }
    if (removeLogo) {
      payload['removeLogo'] = true;
    }

    final result = await _functions
        .httpsCallable('upsertSponsorContentForAdmin')
        .call<Map<String, dynamic>>(payload);

    return (result.data['sponsorId'] ?? '').toString().trim();
  }

  static List<SponsorContentEntry> _entries(Map<String, dynamic> data) {
    final raw = data['entries'];
    if (raw is! Iterable) return const <SponsorContentEntry>[];

    return raw
        .whereType<Map>()
        .map(
          (item) =>
              SponsorContentEntry.fromMap(Map<String, dynamic>.from(item)),
        )
        .toList(growable: false);
  }
}

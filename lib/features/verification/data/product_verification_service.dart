import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

class ProductVerificationResult {
  const ProductVerificationResult({
    required this.found,
    this.publicCode,
    this.brandName,
    this.productName,
    this.batchNumber,
    this.status,
    this.scanCount,
    this.repeatScan = false,
  });

  final bool found;
  final String? publicCode;
  final String? brandName;
  final String? productName;
  final String? batchNumber;
  final String? status;
  final int? scanCount;
  final bool repeatScan;

  bool get isActive => found && status == 'active';
  bool get isBlocked => found && status == 'blocked';
  bool get isRevoked => found && status == 'revoked';
}

class ProductVerificationService {
  ProductVerificationService({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _functions =
           functions ?? FirebaseFunctions.instanceFor(region: 'europe-west3');

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  Future<ProductVerificationResult> verifyCode(
    String rawCode, {
    String source = 'manual',
  }) async {
    final normalizedCode = rawCode.trim().toUpperCase();

    if (normalizedCode.isEmpty) {
      return const ProductVerificationResult(found: false);
    }

    try {
      final callable = _functions.httpsCallable('verifyProductCode');

      final response = await callable.call<Map<String, dynamic>>({
        'publicCode': normalizedCode,
        'platform': _currentPlatform,
        'source': source == 'qr' ? 'qr' : 'manual',
      });

      final data = response.data;

      return ProductVerificationResult(
        found: data['found'] == true,
        publicCode: data['publicCode'] as String? ?? normalizedCode,
        brandName: data['brandName'] as String?,
        productName: data['productName'] as String?,
        batchNumber: data['batchNumber'] as String?,
        status: data['status'] as String?,
        scanCount: (data['scanCount'] as num?)?.toInt(),
        repeatScan: data['repeatScan'] == true,
      );
    } on FirebaseFunctionsException catch (error) {
      if (error.code != 'not-found' && error.code != 'unavailable') {
        rethrow;
      }

      return _verifyDirectlyFromFirestore(normalizedCode);
    }
  }

  Future<ProductVerificationResult> _verifyDirectlyFromFirestore(
    String normalizedCode,
  ) async {
    final document = await _firestore
        .collection('publicProductCodes')
        .doc(normalizedCode)
        .get();

    if (!document.exists) {
      return ProductVerificationResult(
        found: false,
        publicCode: normalizedCode,
      );
    }

    final data = document.data();

    if (data == null) {
      return ProductVerificationResult(
        found: false,
        publicCode: normalizedCode,
      );
    }

    return ProductVerificationResult(
      found: true,
      publicCode: data['publicCode'] as String? ?? normalizedCode,
      brandName: data['brandName'] as String?,
      productName: data['productName'] as String?,
      batchNumber: data['batchNumber'] as String?,
      status: data['status'] as String?,
    );
  }

  String get _currentPlatform {
    if (kIsWeb) {
      return 'web';
    }

    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'android',
      TargetPlatform.iOS => 'ios',
      TargetPlatform.windows => 'windows',
      TargetPlatform.macOS => 'macos',
      TargetPlatform.linux => 'linux',
      TargetPlatform.fuchsia => 'other',
    };
  }
}

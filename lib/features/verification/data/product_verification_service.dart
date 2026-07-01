import 'package:cloud_firestore/cloud_firestore.dart';

class ProductVerificationResult {
  const ProductVerificationResult({
    required this.found,
    this.publicCode,
    this.brandName,
    this.productName,
    this.batchNumber,
    this.status,
  });

  final bool found;
  final String? publicCode;
  final String? brandName;
  final String? productName;
  final String? batchNumber;
  final String? status;

  bool get isActive => found && status == 'active';
  bool get isBlocked => found && status == 'blocked';
  bool get isRevoked => found && status == 'revoked';
}

class ProductVerificationService {
  ProductVerificationService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<ProductVerificationResult> verifyCode(String rawCode) async {
    final normalizedCode = rawCode.trim().toUpperCase();

    if (normalizedCode.isEmpty) {
      return const ProductVerificationResult(found: false);
    }

    final document = await _firestore
        .collection('publicProductCodes')
        .doc(normalizedCode)
        .get();

    if (!document.exists) {
      return const ProductVerificationResult(found: false);
    }

    final data = document.data();

    if (data == null) {
      return const ProductVerificationResult(found: false);
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
}

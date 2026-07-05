import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants/ip_trade_secret_detail_enums.dart';
import '../models/ip_trade_secret_portfolio_summary_model.dart';

class IpTradeSecretPortfolioSnapshotRepository {
  IpTradeSecretPortfolioSnapshotRepository({
    FirebaseFirestore? firestore,
    this.collectionName = 'ip_trade_secret_portfolio_snapshots',
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  final String collectionName;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection(collectionName);

  Future<void> saveSnapshot(
    IpTradeSecretPortfolioSummaryModel summary, {
    bool overwrite = false,
  }) async {
    final document = _collection.doc(summary.id);
    final existing = await document.get();
    if (existing.exists && !overwrite) {
      throw StateError(
        'Aynı dönem ve kapsam için snapshot zaten mevcut: ${summary.id}',
      );
    }
    await document.set(summary.toMap());
  }

  Future<bool> snapshotExists(String snapshotId) async {
    final id = _validatedId(snapshotId);
    return (await _collection.doc(id).get()).exists;
  }

  Future<IpTradeSecretPortfolioSummaryModel?> getSnapshot(
    String snapshotId,
  ) async {
    final snapshot = await _collection.doc(_validatedId(snapshotId)).get();
    return snapshot.exists
        ? IpTradeSecretPortfolioSummaryModel.fromDocument(snapshot)
        : null;
  }

  Future<List<IpTradeSecretPortfolioSummaryModel>> listSnapshots({
    required String tenantId,
    String? brandId,
    IpTradeSecretPortfolioScope? scope,
    int limit = 50,
  }) async {
    final tenant = tenantId.trim();
    if (tenant.isEmpty) {
      throw ArgumentError.value(tenantId, 'tenantId', 'Boş olamaz.');
    }
    if (limit <= 0 || limit > 200) {
      throw RangeError.range(limit, 1, 200, 'limit');
    }

    Query<Map<String, dynamic>> query = _collection.where(
      'tenantId',
      isEqualTo: tenant,
    );
    final brand = brandId?.trim();
    if (brand != null && brand.isNotEmpty) {
      query = query.where('brandId', isEqualTo: brand);
    }
    if (scope != null) {
      query = query.where('scope', isEqualTo: scope.value);
    }

    final result = await query
        .orderBy('generatedAt', descending: true)
        .limit(limit)
        .get();
    return result.docs
        .map(IpTradeSecretPortfolioSummaryModel.fromDocument)
        .toList(growable: false);
  }

  Future<void> deleteSnapshot(String snapshotId) async {
    await _collection.doc(_validatedId(snapshotId)).delete();
  }

  String _validatedId(String value) {
    final cleaned = value.trim();
    if (cleaned.isEmpty) {
      throw ArgumentError.value(value, 'snapshotId', 'Boş olamaz.');
    }
    return cleaned;
  }
}

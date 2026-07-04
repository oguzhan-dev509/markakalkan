import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants/monitoring_collections.dart';

class MonitoringFirestoreRefs {
  MonitoringFirestoreRefs({
    required FirebaseFirestore firestore,
    required String tenantId,
  }) : _firestore = firestore,
       tenantId = _validateRequiredId(tenantId, fieldName: 'tenantId');

  factory MonitoringFirestoreRefs.instance({required String tenantId}) {
    return MonitoringFirestoreRefs(
      firestore: FirebaseFirestore.instance,
      tenantId: tenantId,
    );
  }

  final FirebaseFirestore _firestore;
  final String tenantId;

  CollectionReference<Map<String, dynamic>> get products {
    return _firestore.collection(MonitoringCollections.products);
  }

  CollectionReference<Map<String, dynamic>> get productListings {
    return _firestore.collection(MonitoringCollections.productListings);
  }

  CollectionReference<Map<String, dynamic>> get sellers {
    return _firestore.collection(MonitoringCollections.sellers);
  }

  CollectionReference<Map<String, dynamic>> get sellerStores {
    return _firestore.collection(MonitoringCollections.sellerStores);
  }

  CollectionReference<Map<String, dynamic>> get monitoredPages {
    return _firestore.collection(MonitoringCollections.monitoredPages);
  }

  CollectionReference<Map<String, dynamic>> get crawlJobs {
    return _firestore.collection(MonitoringCollections.crawlJobs);
  }

  CollectionReference<Map<String, dynamic>> get crawlRuns {
    return _firestore.collection(MonitoringCollections.crawlRuns);
  }

  CollectionReference<Map<String, dynamic>> get pageSnapshots {
    return _firestore.collection(MonitoringCollections.pageSnapshots);
  }

  CollectionReference<Map<String, dynamic>> get monitoringEvents {
    return _firestore.collection(MonitoringCollections.monitoringEvents);
  }

  CollectionReference<Map<String, dynamic>> get signalRules {
    return _firestore.collection(MonitoringCollections.signalRules);
  }

  CollectionReference<Map<String, dynamic>> get monitoringSignals {
    return _firestore.collection(MonitoringCollections.monitoringSignals);
  }

  CollectionReference<Map<String, dynamic>> get brandMonitoringProfiles {
    return _firestore.collection(MonitoringCollections.brandMonitoringProfiles);
  }

  CollectionReference<Map<String, dynamic>> get monitoringSources {
    return _firestore.collection(MonitoringCollections.monitoringSources);
  }

  CollectionReference<Map<String, dynamic>> get mediaAssets {
    return _firestore.collection(MonitoringCollections.mediaAssets);
  }

  CollectionReference<Map<String, dynamic>> get evidencePackages {
    return _firestore.collection(MonitoringCollections.evidencePackages);
  }

  Query<Map<String, dynamic>> tenantQuery(
    CollectionReference<Map<String, dynamic>> collection,
  ) {
    return collection.where('tenantId', isEqualTo: tenantId);
  }

  DocumentReference<Map<String, dynamic>> productDocument(String productId) {
    return products.doc(_validateRequiredId(productId, fieldName: 'productId'));
  }

  DocumentReference<Map<String, dynamic>> productListingDocument(
    String listingId,
  ) {
    return productListings.doc(
      _validateRequiredId(listingId, fieldName: 'listingId'),
    );
  }

  DocumentReference<Map<String, dynamic>> sellerDocument(String sellerId) {
    return sellers.doc(_validateRequiredId(sellerId, fieldName: 'sellerId'));
  }

  DocumentReference<Map<String, dynamic>> sellerStoreDocument(String storeId) {
    return sellerStores.doc(_validateRequiredId(storeId, fieldName: 'storeId'));
  }

  DocumentReference<Map<String, dynamic>> monitoredPageDocument(String pageId) {
    return monitoredPages.doc(_validateRequiredId(pageId, fieldName: 'pageId'));
  }

  DocumentReference<Map<String, dynamic>> crawlJobDocument(String jobId) {
    return crawlJobs.doc(_validateRequiredId(jobId, fieldName: 'jobId'));
  }

  DocumentReference<Map<String, dynamic>> crawlRunDocument(String runId) {
    return crawlRuns.doc(_validateRequiredId(runId, fieldName: 'runId'));
  }

  DocumentReference<Map<String, dynamic>> pageSnapshotDocument(
    String snapshotId,
  ) {
    return pageSnapshots.doc(
      _validateRequiredId(snapshotId, fieldName: 'snapshotId'),
    );
  }

  DocumentReference<Map<String, dynamic>> monitoringEventDocument(
    String eventId,
  ) {
    return monitoringEvents.doc(
      _validateRequiredId(eventId, fieldName: 'eventId'),
    );
  }

  DocumentReference<Map<String, dynamic>> signalRuleDocument(String ruleId) {
    return signalRules.doc(_validateRequiredId(ruleId, fieldName: 'ruleId'));
  }

  DocumentReference<Map<String, dynamic>> monitoringSignalDocument(
    String signalId,
  ) {
    return monitoringSignals.doc(
      _validateRequiredId(signalId, fieldName: 'signalId'),
    );
  }

  DocumentReference<Map<String, dynamic>> brandMonitoringProfileDocument(
    String profileId,
  ) {
    return brandMonitoringProfiles.doc(
      _validateRequiredId(profileId, fieldName: 'profileId'),
    );
  }

  DocumentReference<Map<String, dynamic>> monitoringSourceDocument(
    String sourceId,
  ) {
    return monitoringSources.doc(
      _validateRequiredId(sourceId, fieldName: 'sourceId'),
    );
  }

  static String _validateRequiredId(String value, {required String fieldName}) {
    final cleaned = value.trim();

    if (cleaned.isEmpty) {
      throw ArgumentError.value(value, fieldName, '$fieldName boş olamaz.');
    }

    if (cleaned.contains('/')) {
      throw ArgumentError.value(
        value,
        fieldName,
        '$fieldName "/" karakteri içeremez.',
      );
    }

    return cleaned;
  }
}

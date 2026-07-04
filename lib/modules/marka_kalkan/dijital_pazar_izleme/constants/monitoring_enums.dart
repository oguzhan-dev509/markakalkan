enum MonitoringRecordStatus { active, paused, archived }

enum MonitoringPriority { low, normal, high, critical }

enum MonitoringScanFrequency { hourly, every6Hours, daily, weekly, manual }

enum MonitoringSourceType {
  marketplace,
  ecommerceSite,
  socialMedia,
  searchEngine,
  classifiedSite,
  domain,
  mobileApp,
  manualSource,
}

enum MonitoringAccessMethod {
  publicWeb,
  officialApi,
  partnerApi,
  manualUpload,
  webhook,
}

enum MonitoringSourceHealthStatus {
  healthy,
  degraded,
  failed,
  blocked,
  unknown,
}

enum MonitoringTermsReviewStatus { pending, approved, restricted, rejected }

enum MonitoringProductStatus { active, discontinued, archived }

enum MonitoringListingStatus {
  candidate,
  active,
  inactive,
  removed,
  redirected,
  republished,
  unknown,
}

enum MonitoringStockStatus { inStock, outOfStock, limited, preorder, unknown }

enum MonitoringSellerType { individual, company, unknown }

enum MonitoringIdentityStatus {
  unverified,
  partiallyVerified,
  verified,
  conflicting,
}

enum MonitoringSellerActivityStatus { active, inactive, closed, unknown }

enum MonitoringStoreStatus {
  candidate,
  active,
  inactive,
  closed,
  renamed,
  reopened,
  unknown,
}

extension MonitoringRecordStatusX on MonitoringRecordStatus {
  String get value {
    switch (this) {
      case MonitoringRecordStatus.active:
        return 'active';
      case MonitoringRecordStatus.paused:
        return 'paused';
      case MonitoringRecordStatus.archived:
        return 'archived';
    }
  }

  static MonitoringRecordStatus fromValue(String? value) {
    switch (value) {
      case 'paused':
        return MonitoringRecordStatus.paused;
      case 'archived':
        return MonitoringRecordStatus.archived;
      case 'active':
      default:
        return MonitoringRecordStatus.active;
    }
  }
}

extension MonitoringPriorityX on MonitoringPriority {
  String get value {
    switch (this) {
      case MonitoringPriority.low:
        return 'low';
      case MonitoringPriority.normal:
        return 'normal';
      case MonitoringPriority.high:
        return 'high';
      case MonitoringPriority.critical:
        return 'critical';
    }
  }

  static MonitoringPriority fromValue(String? value) {
    switch (value) {
      case 'low':
        return MonitoringPriority.low;
      case 'high':
        return MonitoringPriority.high;
      case 'critical':
        return MonitoringPriority.critical;
      case 'normal':
      default:
        return MonitoringPriority.normal;
    }
  }
}

extension MonitoringScanFrequencyX on MonitoringScanFrequency {
  String get value {
    switch (this) {
      case MonitoringScanFrequency.hourly:
        return 'hourly';
      case MonitoringScanFrequency.every6Hours:
        return 'every_6_hours';
      case MonitoringScanFrequency.daily:
        return 'daily';
      case MonitoringScanFrequency.weekly:
        return 'weekly';
      case MonitoringScanFrequency.manual:
        return 'manual';
    }
  }

  static MonitoringScanFrequency fromValue(String? value) {
    switch (value) {
      case 'hourly':
        return MonitoringScanFrequency.hourly;
      case 'every_6_hours':
        return MonitoringScanFrequency.every6Hours;
      case 'weekly':
        return MonitoringScanFrequency.weekly;
      case 'manual':
        return MonitoringScanFrequency.manual;
      case 'daily':
      default:
        return MonitoringScanFrequency.daily;
    }
  }
}

extension MonitoringSourceTypeX on MonitoringSourceType {
  String get value {
    switch (this) {
      case MonitoringSourceType.marketplace:
        return 'marketplace';
      case MonitoringSourceType.ecommerceSite:
        return 'ecommerce_site';
      case MonitoringSourceType.socialMedia:
        return 'social_media';
      case MonitoringSourceType.searchEngine:
        return 'search_engine';
      case MonitoringSourceType.classifiedSite:
        return 'classified_site';
      case MonitoringSourceType.domain:
        return 'domain';
      case MonitoringSourceType.mobileApp:
        return 'mobile_app';
      case MonitoringSourceType.manualSource:
        return 'manual_source';
    }
  }

  static MonitoringSourceType fromValue(String? value) {
    switch (value) {
      case 'ecommerce_site':
        return MonitoringSourceType.ecommerceSite;
      case 'social_media':
        return MonitoringSourceType.socialMedia;
      case 'search_engine':
        return MonitoringSourceType.searchEngine;
      case 'classified_site':
        return MonitoringSourceType.classifiedSite;
      case 'domain':
        return MonitoringSourceType.domain;
      case 'mobile_app':
        return MonitoringSourceType.mobileApp;
      case 'manual_source':
        return MonitoringSourceType.manualSource;
      case 'marketplace':
      default:
        return MonitoringSourceType.marketplace;
    }
  }
}

extension MonitoringAccessMethodX on MonitoringAccessMethod {
  String get value {
    switch (this) {
      case MonitoringAccessMethod.publicWeb:
        return 'public_web';
      case MonitoringAccessMethod.officialApi:
        return 'official_api';
      case MonitoringAccessMethod.partnerApi:
        return 'partner_api';
      case MonitoringAccessMethod.manualUpload:
        return 'manual_upload';
      case MonitoringAccessMethod.webhook:
        return 'webhook';
    }
  }

  static MonitoringAccessMethod fromValue(String? value) {
    switch (value) {
      case 'official_api':
        return MonitoringAccessMethod.officialApi;
      case 'partner_api':
        return MonitoringAccessMethod.partnerApi;
      case 'manual_upload':
        return MonitoringAccessMethod.manualUpload;
      case 'webhook':
        return MonitoringAccessMethod.webhook;
      case 'public_web':
      default:
        return MonitoringAccessMethod.publicWeb;
    }
  }
}

extension MonitoringSourceHealthStatusX on MonitoringSourceHealthStatus {
  String get value {
    switch (this) {
      case MonitoringSourceHealthStatus.healthy:
        return 'healthy';
      case MonitoringSourceHealthStatus.degraded:
        return 'degraded';
      case MonitoringSourceHealthStatus.failed:
        return 'failed';
      case MonitoringSourceHealthStatus.blocked:
        return 'blocked';
      case MonitoringSourceHealthStatus.unknown:
        return 'unknown';
    }
  }

  static MonitoringSourceHealthStatus fromValue(String? value) {
    switch (value) {
      case 'healthy':
        return MonitoringSourceHealthStatus.healthy;
      case 'degraded':
        return MonitoringSourceHealthStatus.degraded;
      case 'failed':
        return MonitoringSourceHealthStatus.failed;
      case 'blocked':
        return MonitoringSourceHealthStatus.blocked;
      case 'unknown':
      default:
        return MonitoringSourceHealthStatus.unknown;
    }
  }
}

extension MonitoringTermsReviewStatusX on MonitoringTermsReviewStatus {
  String get value {
    switch (this) {
      case MonitoringTermsReviewStatus.pending:
        return 'pending';
      case MonitoringTermsReviewStatus.approved:
        return 'approved';
      case MonitoringTermsReviewStatus.restricted:
        return 'restricted';
      case MonitoringTermsReviewStatus.rejected:
        return 'rejected';
    }
  }

  static MonitoringTermsReviewStatus fromValue(String? value) {
    switch (value) {
      case 'approved':
        return MonitoringTermsReviewStatus.approved;
      case 'restricted':
        return MonitoringTermsReviewStatus.restricted;
      case 'rejected':
        return MonitoringTermsReviewStatus.rejected;
      case 'pending':
      default:
        return MonitoringTermsReviewStatus.pending;
    }
  }
}

extension MonitoringProductStatusX on MonitoringProductStatus {
  String get value {
    switch (this) {
      case MonitoringProductStatus.active:
        return 'active';
      case MonitoringProductStatus.discontinued:
        return 'discontinued';
      case MonitoringProductStatus.archived:
        return 'archived';
    }
  }

  static MonitoringProductStatus fromValue(String? value) {
    switch (value) {
      case 'discontinued':
        return MonitoringProductStatus.discontinued;
      case 'archived':
        return MonitoringProductStatus.archived;
      case 'active':
      default:
        return MonitoringProductStatus.active;
    }
  }
}

extension MonitoringListingStatusX on MonitoringListingStatus {
  String get value {
    switch (this) {
      case MonitoringListingStatus.candidate:
        return 'candidate';
      case MonitoringListingStatus.active:
        return 'active';
      case MonitoringListingStatus.inactive:
        return 'inactive';
      case MonitoringListingStatus.removed:
        return 'removed';
      case MonitoringListingStatus.redirected:
        return 'redirected';
      case MonitoringListingStatus.republished:
        return 'republished';
      case MonitoringListingStatus.unknown:
        return 'unknown';
    }
  }

  static MonitoringListingStatus fromValue(String? value) {
    switch (value) {
      case 'candidate':
        return MonitoringListingStatus.candidate;
      case 'active':
        return MonitoringListingStatus.active;
      case 'inactive':
        return MonitoringListingStatus.inactive;
      case 'removed':
        return MonitoringListingStatus.removed;
      case 'redirected':
        return MonitoringListingStatus.redirected;
      case 'republished':
        return MonitoringListingStatus.republished;
      case 'unknown':
      default:
        return MonitoringListingStatus.unknown;
    }
  }
}

extension MonitoringStockStatusX on MonitoringStockStatus {
  String get value {
    switch (this) {
      case MonitoringStockStatus.inStock:
        return 'in_stock';
      case MonitoringStockStatus.outOfStock:
        return 'out_of_stock';
      case MonitoringStockStatus.limited:
        return 'limited';
      case MonitoringStockStatus.preorder:
        return 'preorder';
      case MonitoringStockStatus.unknown:
        return 'unknown';
    }
  }

  static MonitoringStockStatus fromValue(String? value) {
    switch (value) {
      case 'in_stock':
        return MonitoringStockStatus.inStock;
      case 'out_of_stock':
        return MonitoringStockStatus.outOfStock;
      case 'limited':
        return MonitoringStockStatus.limited;
      case 'preorder':
        return MonitoringStockStatus.preorder;
      case 'unknown':
      default:
        return MonitoringStockStatus.unknown;
    }
  }
}

extension MonitoringSellerTypeX on MonitoringSellerType {
  String get value {
    switch (this) {
      case MonitoringSellerType.individual:
        return 'individual';
      case MonitoringSellerType.company:
        return 'company';
      case MonitoringSellerType.unknown:
        return 'unknown';
    }
  }

  static MonitoringSellerType fromValue(String? value) {
    switch (value) {
      case 'individual':
        return MonitoringSellerType.individual;
      case 'company':
        return MonitoringSellerType.company;
      case 'unknown':
      default:
        return MonitoringSellerType.unknown;
    }
  }
}

extension MonitoringIdentityStatusX on MonitoringIdentityStatus {
  String get value {
    switch (this) {
      case MonitoringIdentityStatus.unverified:
        return 'unverified';
      case MonitoringIdentityStatus.partiallyVerified:
        return 'partially_verified';
      case MonitoringIdentityStatus.verified:
        return 'verified';
      case MonitoringIdentityStatus.conflicting:
        return 'conflicting';
    }
  }

  static MonitoringIdentityStatus fromValue(String? value) {
    switch (value) {
      case 'partially_verified':
        return MonitoringIdentityStatus.partiallyVerified;
      case 'verified':
        return MonitoringIdentityStatus.verified;
      case 'conflicting':
        return MonitoringIdentityStatus.conflicting;
      case 'unverified':
      default:
        return MonitoringIdentityStatus.unverified;
    }
  }
}

extension MonitoringSellerActivityStatusX on MonitoringSellerActivityStatus {
  String get value {
    switch (this) {
      case MonitoringSellerActivityStatus.active:
        return 'active';
      case MonitoringSellerActivityStatus.inactive:
        return 'inactive';
      case MonitoringSellerActivityStatus.closed:
        return 'closed';
      case MonitoringSellerActivityStatus.unknown:
        return 'unknown';
    }
  }

  static MonitoringSellerActivityStatus fromValue(String? value) {
    switch (value) {
      case 'active':
        return MonitoringSellerActivityStatus.active;
      case 'inactive':
        return MonitoringSellerActivityStatus.inactive;
      case 'closed':
        return MonitoringSellerActivityStatus.closed;
      case 'unknown':
      default:
        return MonitoringSellerActivityStatus.unknown;
    }
  }
}

extension MonitoringStoreStatusX on MonitoringStoreStatus {
  String get value {
    switch (this) {
      case MonitoringStoreStatus.candidate:
        return 'candidate';
      case MonitoringStoreStatus.active:
        return 'active';
      case MonitoringStoreStatus.inactive:
        return 'inactive';
      case MonitoringStoreStatus.closed:
        return 'closed';
      case MonitoringStoreStatus.renamed:
        return 'renamed';
      case MonitoringStoreStatus.reopened:
        return 'reopened';
      case MonitoringStoreStatus.unknown:
        return 'unknown';
    }
  }

  static MonitoringStoreStatus fromValue(String? value) {
    switch (value) {
      case 'candidate':
        return MonitoringStoreStatus.candidate;
      case 'active':
        return MonitoringStoreStatus.active;
      case 'inactive':
        return MonitoringStoreStatus.inactive;
      case 'closed':
        return MonitoringStoreStatus.closed;
      case 'renamed':
        return MonitoringStoreStatus.renamed;
      case 'reopened':
        return MonitoringStoreStatus.reopened;
      case 'unknown':
      default:
        return MonitoringStoreStatus.unknown;
    }
  }
}

enum MonitoringPageType {
  productListing,
  sellerStore,
  searchResult,
  socialProfile,
  socialPost,
  websiteHome,
  websiteProduct,
  domainRecord,
  other,
}

enum MonitoringPageStatus {
  active,
  inactive,
  removed,
  blocked,
  redirected,
  error,
  unknown,
}

extension MonitoringPageTypeX on MonitoringPageType {
  String get value {
    switch (this) {
      case MonitoringPageType.productListing:
        return 'product_listing';
      case MonitoringPageType.sellerStore:
        return 'seller_store';
      case MonitoringPageType.searchResult:
        return 'search_result';
      case MonitoringPageType.socialProfile:
        return 'social_profile';
      case MonitoringPageType.socialPost:
        return 'social_post';
      case MonitoringPageType.websiteHome:
        return 'website_home';
      case MonitoringPageType.websiteProduct:
        return 'website_product';
      case MonitoringPageType.domainRecord:
        return 'domain_record';
      case MonitoringPageType.other:
        return 'other';
    }
  }

  static MonitoringPageType fromValue(String? value) {
    switch (value) {
      case 'product_listing':
        return MonitoringPageType.productListing;
      case 'seller_store':
        return MonitoringPageType.sellerStore;
      case 'search_result':
        return MonitoringPageType.searchResult;
      case 'social_profile':
        return MonitoringPageType.socialProfile;
      case 'social_post':
        return MonitoringPageType.socialPost;
      case 'website_home':
        return MonitoringPageType.websiteHome;
      case 'website_product':
        return MonitoringPageType.websiteProduct;
      case 'domain_record':
        return MonitoringPageType.domainRecord;
      case 'other':
      default:
        return MonitoringPageType.other;
    }
  }
}

extension MonitoringPageStatusX on MonitoringPageStatus {
  String get value {
    switch (this) {
      case MonitoringPageStatus.active:
        return 'active';
      case MonitoringPageStatus.inactive:
        return 'inactive';
      case MonitoringPageStatus.removed:
        return 'removed';
      case MonitoringPageStatus.blocked:
        return 'blocked';
      case MonitoringPageStatus.redirected:
        return 'redirected';
      case MonitoringPageStatus.error:
        return 'error';
      case MonitoringPageStatus.unknown:
        return 'unknown';
    }
  }

  static MonitoringPageStatus fromValue(String? value) {
    switch (value) {
      case 'active':
        return MonitoringPageStatus.active;
      case 'inactive':
        return MonitoringPageStatus.inactive;
      case 'removed':
        return MonitoringPageStatus.removed;
      case 'blocked':
        return MonitoringPageStatus.blocked;
      case 'redirected':
        return MonitoringPageStatus.redirected;
      case 'error':
        return MonitoringPageStatus.error;
      case 'unknown':
      default:
        return MonitoringPageStatus.unknown;
    }
  }
}

enum MonitoringCrawlJobType {
  sourceDiscovery,
  keywordSearch,
  pageScan,
  sellerScan,
  storeScan,
  priceScan,
  manualScan,
}

enum MonitoringCrawlJobStatus { draft, active, paused, disabled, archived }

enum MonitoringCrawlTargetType { source, page, seller, store, query, listing }

enum MonitoringCrawlLastRunStatus {
  neverRun,
  success,
  partialSuccess,
  failed,
  blocked,
  cancelled,
}

extension MonitoringCrawlJobTypeX on MonitoringCrawlJobType {
  String get value {
    switch (this) {
      case MonitoringCrawlJobType.sourceDiscovery:
        return 'source_discovery';
      case MonitoringCrawlJobType.keywordSearch:
        return 'keyword_search';
      case MonitoringCrawlJobType.pageScan:
        return 'page_scan';
      case MonitoringCrawlJobType.sellerScan:
        return 'seller_scan';
      case MonitoringCrawlJobType.storeScan:
        return 'store_scan';
      case MonitoringCrawlJobType.priceScan:
        return 'price_scan';
      case MonitoringCrawlJobType.manualScan:
        return 'manual_scan';
    }
  }

  static MonitoringCrawlJobType fromValue(String? value) {
    switch (value) {
      case 'source_discovery':
        return MonitoringCrawlJobType.sourceDiscovery;
      case 'keyword_search':
        return MonitoringCrawlJobType.keywordSearch;
      case 'seller_scan':
        return MonitoringCrawlJobType.sellerScan;
      case 'store_scan':
        return MonitoringCrawlJobType.storeScan;
      case 'price_scan':
        return MonitoringCrawlJobType.priceScan;
      case 'manual_scan':
        return MonitoringCrawlJobType.manualScan;
      case 'page_scan':
      default:
        return MonitoringCrawlJobType.pageScan;
    }
  }
}

extension MonitoringCrawlJobStatusX on MonitoringCrawlJobStatus {
  String get value {
    switch (this) {
      case MonitoringCrawlJobStatus.draft:
        return 'draft';
      case MonitoringCrawlJobStatus.active:
        return 'active';
      case MonitoringCrawlJobStatus.paused:
        return 'paused';
      case MonitoringCrawlJobStatus.disabled:
        return 'disabled';
      case MonitoringCrawlJobStatus.archived:
        return 'archived';
    }
  }

  static MonitoringCrawlJobStatus fromValue(String? value) {
    switch (value) {
      case 'draft':
        return MonitoringCrawlJobStatus.draft;
      case 'paused':
        return MonitoringCrawlJobStatus.paused;
      case 'disabled':
        return MonitoringCrawlJobStatus.disabled;
      case 'archived':
        return MonitoringCrawlJobStatus.archived;
      case 'active':
      default:
        return MonitoringCrawlJobStatus.active;
    }
  }
}

extension MonitoringCrawlTargetTypeX on MonitoringCrawlTargetType {
  String get value {
    switch (this) {
      case MonitoringCrawlTargetType.source:
        return 'source';
      case MonitoringCrawlTargetType.page:
        return 'page';
      case MonitoringCrawlTargetType.seller:
        return 'seller';
      case MonitoringCrawlTargetType.store:
        return 'store';
      case MonitoringCrawlTargetType.query:
        return 'query';
      case MonitoringCrawlTargetType.listing:
        return 'listing';
    }
  }

  static MonitoringCrawlTargetType fromValue(String? value) {
    switch (value) {
      case 'source':
        return MonitoringCrawlTargetType.source;
      case 'seller':
        return MonitoringCrawlTargetType.seller;
      case 'store':
        return MonitoringCrawlTargetType.store;
      case 'query':
        return MonitoringCrawlTargetType.query;
      case 'listing':
        return MonitoringCrawlTargetType.listing;
      case 'page':
      default:
        return MonitoringCrawlTargetType.page;
    }
  }
}

extension MonitoringCrawlLastRunStatusX on MonitoringCrawlLastRunStatus {
  String get value {
    switch (this) {
      case MonitoringCrawlLastRunStatus.neverRun:
        return 'never_run';
      case MonitoringCrawlLastRunStatus.success:
        return 'success';
      case MonitoringCrawlLastRunStatus.partialSuccess:
        return 'partial_success';
      case MonitoringCrawlLastRunStatus.failed:
        return 'failed';
      case MonitoringCrawlLastRunStatus.blocked:
        return 'blocked';
      case MonitoringCrawlLastRunStatus.cancelled:
        return 'cancelled';
    }
  }

  static MonitoringCrawlLastRunStatus fromValue(String? value) {
    switch (value) {
      case 'success':
        return MonitoringCrawlLastRunStatus.success;
      case 'partial_success':
        return MonitoringCrawlLastRunStatus.partialSuccess;
      case 'failed':
        return MonitoringCrawlLastRunStatus.failed;
      case 'blocked':
        return MonitoringCrawlLastRunStatus.blocked;
      case 'cancelled':
        return MonitoringCrawlLastRunStatus.cancelled;
      case 'never_run':
      default:
        return MonitoringCrawlLastRunStatus.neverRun;
    }
  }
}

enum MonitoringCrawlRunStatus {
  queued,
  running,
  success,
  partialSuccess,
  failed,
  blocked,
  cancelled,
}

extension MonitoringCrawlRunStatusX on MonitoringCrawlRunStatus {
  String get value {
    switch (this) {
      case MonitoringCrawlRunStatus.queued:
        return 'queued';
      case MonitoringCrawlRunStatus.running:
        return 'running';
      case MonitoringCrawlRunStatus.success:
        return 'success';
      case MonitoringCrawlRunStatus.partialSuccess:
        return 'partial_success';
      case MonitoringCrawlRunStatus.failed:
        return 'failed';
      case MonitoringCrawlRunStatus.blocked:
        return 'blocked';
      case MonitoringCrawlRunStatus.cancelled:
        return 'cancelled';
    }
  }

  static MonitoringCrawlRunStatus fromValue(String? value) {
    switch (value) {
      case 'queued':
        return MonitoringCrawlRunStatus.queued;
      case 'running':
        return MonitoringCrawlRunStatus.running;
      case 'success':
        return MonitoringCrawlRunStatus.success;
      case 'partial_success':
        return MonitoringCrawlRunStatus.partialSuccess;
      case 'failed':
        return MonitoringCrawlRunStatus.failed;
      case 'blocked':
        return MonitoringCrawlRunStatus.blocked;
      case 'cancelled':
        return MonitoringCrawlRunStatus.cancelled;
      default:
        return MonitoringCrawlRunStatus.queued;
    }
  }
}

enum MonitoringEventType {
  newListing,
  listingRemoved,
  listingRepublished,
  priceDecreased,
  priceIncreased,
  titleChanged,
  descriptionChanged,
  imageChanged,
  sellerChanged,
  storeChanged,
  storeNameChanged,
  stockChanged,
  contactChanged,
  pageBlocked,
  pageRedirected,
  pageRecovered,
}

enum MonitoringEventCategory {
  discovery,
  price,
  content,
  media,
  seller,
  store,
  availability,
  technical,
  identity,
}

enum MonitoringEventSeverity { info, low, medium, high, critical }

enum MonitoringEventStatus {
  newEvent,
  reviewed,
  suppressed,
  forwarded,
  resolved,
  archived,
}

extension MonitoringEventTypeX on MonitoringEventType {
  String get value {
    switch (this) {
      case MonitoringEventType.newListing:
        return 'new_listing';
      case MonitoringEventType.listingRemoved:
        return 'listing_removed';
      case MonitoringEventType.listingRepublished:
        return 'listing_republished';
      case MonitoringEventType.priceDecreased:
        return 'price_decreased';
      case MonitoringEventType.priceIncreased:
        return 'price_increased';
      case MonitoringEventType.titleChanged:
        return 'title_changed';
      case MonitoringEventType.descriptionChanged:
        return 'description_changed';
      case MonitoringEventType.imageChanged:
        return 'image_changed';
      case MonitoringEventType.sellerChanged:
        return 'seller_changed';
      case MonitoringEventType.storeChanged:
        return 'store_changed';
      case MonitoringEventType.storeNameChanged:
        return 'store_name_changed';
      case MonitoringEventType.stockChanged:
        return 'stock_changed';
      case MonitoringEventType.contactChanged:
        return 'contact_changed';
      case MonitoringEventType.pageBlocked:
        return 'page_blocked';
      case MonitoringEventType.pageRedirected:
        return 'page_redirected';
      case MonitoringEventType.pageRecovered:
        return 'page_recovered';
    }
  }

  static MonitoringEventType fromValue(String? value) {
    switch (value) {
      case 'new_listing':
        return MonitoringEventType.newListing;
      case 'listing_removed':
        return MonitoringEventType.listingRemoved;
      case 'listing_republished':
        return MonitoringEventType.listingRepublished;
      case 'price_decreased':
        return MonitoringEventType.priceDecreased;
      case 'price_increased':
        return MonitoringEventType.priceIncreased;
      case 'title_changed':
        return MonitoringEventType.titleChanged;
      case 'description_changed':
        return MonitoringEventType.descriptionChanged;
      case 'image_changed':
        return MonitoringEventType.imageChanged;
      case 'seller_changed':
        return MonitoringEventType.sellerChanged;
      case 'store_changed':
        return MonitoringEventType.storeChanged;
      case 'store_name_changed':
        return MonitoringEventType.storeNameChanged;
      case 'stock_changed':
        return MonitoringEventType.stockChanged;
      case 'contact_changed':
        return MonitoringEventType.contactChanged;
      case 'page_blocked':
        return MonitoringEventType.pageBlocked;
      case 'page_redirected':
        return MonitoringEventType.pageRedirected;
      case 'page_recovered':
        return MonitoringEventType.pageRecovered;
      default:
        return MonitoringEventType.newListing;
    }
  }
}

extension MonitoringEventCategoryX on MonitoringEventCategory {
  String get value {
    switch (this) {
      case MonitoringEventCategory.discovery:
        return 'discovery';
      case MonitoringEventCategory.price:
        return 'price';
      case MonitoringEventCategory.content:
        return 'content';
      case MonitoringEventCategory.media:
        return 'media';
      case MonitoringEventCategory.seller:
        return 'seller';
      case MonitoringEventCategory.store:
        return 'store';
      case MonitoringEventCategory.availability:
        return 'availability';
      case MonitoringEventCategory.technical:
        return 'technical';
      case MonitoringEventCategory.identity:
        return 'identity';
    }
  }

  static MonitoringEventCategory fromValue(String? value) {
    switch (value) {
      case 'price':
        return MonitoringEventCategory.price;
      case 'content':
        return MonitoringEventCategory.content;
      case 'media':
        return MonitoringEventCategory.media;
      case 'seller':
        return MonitoringEventCategory.seller;
      case 'store':
        return MonitoringEventCategory.store;
      case 'availability':
        return MonitoringEventCategory.availability;
      case 'technical':
        return MonitoringEventCategory.technical;
      case 'identity':
        return MonitoringEventCategory.identity;
      case 'discovery':
      default:
        return MonitoringEventCategory.discovery;
    }
  }
}

extension MonitoringEventSeverityX on MonitoringEventSeverity {
  String get value {
    switch (this) {
      case MonitoringEventSeverity.info:
        return 'info';
      case MonitoringEventSeverity.low:
        return 'low';
      case MonitoringEventSeverity.medium:
        return 'medium';
      case MonitoringEventSeverity.high:
        return 'high';
      case MonitoringEventSeverity.critical:
        return 'critical';
    }
  }

  static MonitoringEventSeverity fromValue(String? value) {
    switch (value) {
      case 'low':
        return MonitoringEventSeverity.low;
      case 'medium':
        return MonitoringEventSeverity.medium;
      case 'high':
        return MonitoringEventSeverity.high;
      case 'critical':
        return MonitoringEventSeverity.critical;
      case 'info':
      default:
        return MonitoringEventSeverity.info;
    }
  }
}

extension MonitoringEventStatusX on MonitoringEventStatus {
  String get value {
    switch (this) {
      case MonitoringEventStatus.newEvent:
        return 'new';
      case MonitoringEventStatus.reviewed:
        return 'reviewed';
      case MonitoringEventStatus.suppressed:
        return 'suppressed';
      case MonitoringEventStatus.forwarded:
        return 'forwarded';
      case MonitoringEventStatus.resolved:
        return 'resolved';
      case MonitoringEventStatus.archived:
        return 'archived';
    }
  }

  static MonitoringEventStatus fromValue(String? value) {
    switch (value) {
      case 'reviewed':
        return MonitoringEventStatus.reviewed;
      case 'suppressed':
        return MonitoringEventStatus.suppressed;
      case 'forwarded':
        return MonitoringEventStatus.forwarded;
      case 'resolved':
        return MonitoringEventStatus.resolved;
      case 'archived':
        return MonitoringEventStatus.archived;
      case 'new':
      default:
        return MonitoringEventStatus.newEvent;
    }
  }
}

enum MonitoringSignalRuleOperator {
  equals,
  notEquals,
  greaterThan,
  greaterThanOrEqual,
  lessThan,
  lessThanOrEqual,
  contains,
  inList,
  exists,
}

enum MonitoringSignalRuleStatus { draft, active, paused, disabled, archived }

enum MonitoringSignalLevel { info, low, medium, high, critical }

extension MonitoringSignalRuleOperatorX on MonitoringSignalRuleOperator {
  String get value {
    switch (this) {
      case MonitoringSignalRuleOperator.equals:
        return 'equals';
      case MonitoringSignalRuleOperator.notEquals:
        return 'not_equals';
      case MonitoringSignalRuleOperator.greaterThan:
        return 'greater_than';
      case MonitoringSignalRuleOperator.greaterThanOrEqual:
        return 'greater_than_or_equal';
      case MonitoringSignalRuleOperator.lessThan:
        return 'less_than';
      case MonitoringSignalRuleOperator.lessThanOrEqual:
        return 'less_than_or_equal';
      case MonitoringSignalRuleOperator.contains:
        return 'contains';
      case MonitoringSignalRuleOperator.inList:
        return 'in_list';
      case MonitoringSignalRuleOperator.exists:
        return 'exists';
    }
  }

  static MonitoringSignalRuleOperator fromValue(String? value) {
    switch (value) {
      case 'not_equals':
        return MonitoringSignalRuleOperator.notEquals;
      case 'greater_than':
        return MonitoringSignalRuleOperator.greaterThan;
      case 'greater_than_or_equal':
        return MonitoringSignalRuleOperator.greaterThanOrEqual;
      case 'less_than':
        return MonitoringSignalRuleOperator.lessThan;
      case 'less_than_or_equal':
        return MonitoringSignalRuleOperator.lessThanOrEqual;
      case 'contains':
        return MonitoringSignalRuleOperator.contains;
      case 'in_list':
        return MonitoringSignalRuleOperator.inList;
      case 'exists':
        return MonitoringSignalRuleOperator.exists;
      case 'equals':
      default:
        return MonitoringSignalRuleOperator.equals;
    }
  }
}

extension MonitoringSignalRuleStatusX on MonitoringSignalRuleStatus {
  String get value {
    switch (this) {
      case MonitoringSignalRuleStatus.draft:
        return 'draft';
      case MonitoringSignalRuleStatus.active:
        return 'active';
      case MonitoringSignalRuleStatus.paused:
        return 'paused';
      case MonitoringSignalRuleStatus.disabled:
        return 'disabled';
      case MonitoringSignalRuleStatus.archived:
        return 'archived';
    }
  }

  static MonitoringSignalRuleStatus fromValue(String? value) {
    switch (value) {
      case 'active':
        return MonitoringSignalRuleStatus.active;
      case 'paused':
        return MonitoringSignalRuleStatus.paused;
      case 'disabled':
        return MonitoringSignalRuleStatus.disabled;
      case 'archived':
        return MonitoringSignalRuleStatus.archived;
      case 'draft':
      default:
        return MonitoringSignalRuleStatus.draft;
    }
  }
}

extension MonitoringSignalLevelX on MonitoringSignalLevel {
  String get value {
    switch (this) {
      case MonitoringSignalLevel.info:
        return 'info';
      case MonitoringSignalLevel.low:
        return 'low';
      case MonitoringSignalLevel.medium:
        return 'medium';
      case MonitoringSignalLevel.high:
        return 'high';
      case MonitoringSignalLevel.critical:
        return 'critical';
    }
  }

  static MonitoringSignalLevel fromValue(String? value) {
    switch (value) {
      case 'low':
        return MonitoringSignalLevel.low;
      case 'medium':
        return MonitoringSignalLevel.medium;
      case 'high':
        return MonitoringSignalLevel.high;
      case 'critical':
        return MonitoringSignalLevel.critical;
      case 'info':
      default:
        return MonitoringSignalLevel.info;
    }
  }
}

enum MonitoringSignalStatus {
  newSignal,
  underReview,
  confirmed,
  dismissed,
  escalated,
  resolved,
  archived,
}

enum MonitoringSignalForwardingStatus {
  notForwarded,
  queued,
  forwarded,
  failed,
}

extension MonitoringSignalStatusX on MonitoringSignalStatus {
  String get value {
    switch (this) {
      case MonitoringSignalStatus.newSignal:
        return 'new';
      case MonitoringSignalStatus.underReview:
        return 'under_review';
      case MonitoringSignalStatus.confirmed:
        return 'confirmed';
      case MonitoringSignalStatus.dismissed:
        return 'dismissed';
      case MonitoringSignalStatus.escalated:
        return 'escalated';
      case MonitoringSignalStatus.resolved:
        return 'resolved';
      case MonitoringSignalStatus.archived:
        return 'archived';
    }
  }

  static MonitoringSignalStatus fromValue(String? value) {
    switch (value) {
      case 'under_review':
        return MonitoringSignalStatus.underReview;
      case 'confirmed':
        return MonitoringSignalStatus.confirmed;
      case 'dismissed':
        return MonitoringSignalStatus.dismissed;
      case 'escalated':
        return MonitoringSignalStatus.escalated;
      case 'resolved':
        return MonitoringSignalStatus.resolved;
      case 'archived':
        return MonitoringSignalStatus.archived;
      case 'new':
      default:
        return MonitoringSignalStatus.newSignal;
    }
  }
}

extension MonitoringSignalForwardingStatusX
    on MonitoringSignalForwardingStatus {
  String get value {
    switch (this) {
      case MonitoringSignalForwardingStatus.notForwarded:
        return 'not_forwarded';
      case MonitoringSignalForwardingStatus.queued:
        return 'queued';
      case MonitoringSignalForwardingStatus.forwarded:
        return 'forwarded';
      case MonitoringSignalForwardingStatus.failed:
        return 'failed';
    }
  }

  static MonitoringSignalForwardingStatus fromValue(String? value) {
    switch (value) {
      case 'queued':
        return MonitoringSignalForwardingStatus.queued;
      case 'forwarded':
        return MonitoringSignalForwardingStatus.forwarded;
      case 'failed':
        return MonitoringSignalForwardingStatus.failed;
      case 'not_forwarded':
      default:
        return MonitoringSignalForwardingStatus.notForwarded;
    }
  }
}

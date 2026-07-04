import '../models/monitoring_event_model.dart';
import '../models/monitoring_signal_model.dart';
import '../models/page_snapshot_model.dart';
import '../models/signal_rule_model.dart';

abstract interface class PageSnapshotRepositoryPort {
  Future<String> create(PageSnapshotModel snapshot);

  Future<PageSnapshotModel?> getLatestForPage(String pageId);
}

abstract interface class MonitoringEventRepositoryPort {
  Future<List<String>> createBatch(List<MonitoringEventModel> events);
}

abstract interface class SignalRuleRepositoryPort {
  Future<List<SignalRuleModel>> listActive({
    String? brandId,
    String? sourceId,
    int limit = 200,
  });
}

abstract interface class MonitoringSignalRepositoryPort {
  Future<List<String>> createBatch(List<MonitoringSignalModel> signals);
}

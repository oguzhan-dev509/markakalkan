abstract interface class IpTradeSecretDetailRepositoryPort<T> {
  Future<String> create(T model);

  Future<void> update(T model);

  Future<T?> getById(String id);

  Future<T?> findByCode({required String brandId, required String code});

  Future<List<T>> list({
    String? brandId,
    String? tradeSecretId,
    int limit = 100,
  });

  Stream<List<T>> watch({
    String? brandId,
    String? tradeSecretId,
    int limit = 100,
  });

  Future<void> delete(String id);
}

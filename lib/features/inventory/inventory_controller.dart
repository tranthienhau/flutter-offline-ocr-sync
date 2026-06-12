import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';
import '../../core/db/product_dao.dart';
import '../../core/sync/sync_engine.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  throw UnimplementedError('Override in main()');
});

final productDaoProvider = Provider<ProductDao>((ref) {
  return ProductDao(ref.read(appDatabaseProvider));
});

final syncEngineProvider = Provider<SyncEngine>((ref) {
  throw UnimplementedError('Override in main()');
});

class InventoryController extends StateNotifier<List<Product>> {
  InventoryController(this._dao, this._sync) : super(const []) {
    _refresh();
  }

  /// In-memory constructor used for tests/screenshots: seeds state directly and
  /// keeps mutations local, so no SQLite/Firebase/connectivity plugin is needed.
  InventoryController.seeded(List<Product> seed)
      : _dao = null,
        _sync = null,
        super(seed);

  final ProductDao? _dao;
  final SyncEngine? _sync;

  Future<void> _refresh() async {
    final dao = _dao;
    if (dao == null) return;
    state = await dao.all();
  }

  Product _replace(Product p, {required int stock}) => Product(
        id: p.id,
        name: p.name,
        unit: p.unit,
        price: p.price,
        stock: stock,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );

  Future<void> addProduct({
    required String name,
    required String unit,
    required double price,
    required int stock,
  }) async {
    final dao = _dao;
    if (dao == null) {
      state = [
        Product(
          id: 'mem-${DateTime.now().microsecondsSinceEpoch}',
          name: name,
          unit: unit,
          price: price,
          stock: stock,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        ),
        ...state,
      ];
      return;
    }
    await dao.insert(name: name, unit: unit, price: price, stock: stock);
    await _refresh();
    // Fire-and-forget: SyncEngine no-ops if already running.
    unawaited(_sync?.drain() ?? Future.value());
  }

  Future<void> sell(Product product) async {
    if (product.stock <= 0) return;
    final dao = _dao;
    if (dao == null) {
      state = [
        for (final p in state)
          if (p.id == product.id) _replace(p, stock: p.stock - 1) else p,
      ];
      return;
    }
    await dao.updateStock(product, product.stock - 1);
    await _refresh();
    unawaited(_sync?.drain() ?? Future.value());
  }

  Future<void> delete(Product product) async {
    final dao = _dao;
    if (dao == null) {
      state = [
        for (final p in state)
          if (p.id != product.id) p,
      ];
      return;
    }
    await dao.softDelete(product);
    await _refresh();
    unawaited(_sync?.drain() ?? Future.value());
  }
}

void unawaited(Future<void> _) {}

final inventoryControllerProvider =
    StateNotifierProvider<InventoryController, List<Product>>((ref) {
  return InventoryController(
    ref.read(productDaoProvider),
    ref.read(syncEngineProvider),
  );
});

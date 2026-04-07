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

  final ProductDao _dao;
  final SyncEngine _sync;

  Future<void> _refresh() async {
    state = await _dao.all();
  }

  Future<void> addProduct({
    required String name,
    required String unit,
    required double price,
    required int stock,
  }) async {
    await _dao.insert(name: name, unit: unit, price: price, stock: stock);
    await _refresh();
    // Fire-and-forget: SyncEngine no-ops if already running.
    unawaited(_sync.drain());
  }

  Future<void> sell(Product product) async {
    if (product.stock <= 0) return;
    await _dao.updateStock(product, product.stock - 1);
    await _refresh();
    unawaited(_sync.drain());
  }

  Future<void> delete(Product product) async {
    await _dao.softDelete(product);
    await _refresh();
    unawaited(_sync.drain());
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

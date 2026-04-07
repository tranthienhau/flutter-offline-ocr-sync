import 'dart:convert';

import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import 'database.dart';

class Product {
  Product({
    required this.id,
    required this.name,
    required this.unit,
    required this.price,
    required this.stock,
    required this.updatedAt,
    this.deleted = false,
  });

  final String id;
  final String name;
  final String unit;
  final double price;
  final int stock;
  final int updatedAt;
  final bool deleted;

  Map<String, Object?> toRow() => {
        'id': id,
        'name': name,
        'unit': unit,
        'price': price,
        'stock': stock,
        'updated_at': updatedAt,
        'deleted': deleted ? 1 : 0,
      };

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'unit': unit,
        'price': price,
        'stock': stock,
        'updated_at': updatedAt,
        'deleted': deleted,
      };

  static Product fromRow(Map<String, Object?> row) => Product(
        id: row['id'] as String,
        name: row['name'] as String,
        unit: row['unit'] as String,
        price: (row['price'] as num).toDouble(),
        stock: row['stock'] as int,
        updatedAt: row['updated_at'] as int,
        deleted: (row['deleted'] as int) == 1,
      );
}

/// CRUD that ALWAYS writes a change_log entry in the same transaction as the
/// data write. This is what makes the app safe to use offline: a power cut
/// after the local commit but before sync still leaves a durable replay
/// instruction in change_log.
class ProductDao {
  ProductDao(this._db);
  final AppDatabase _db;
  final _uuid = const Uuid();

  Future<List<Product>> all() async {
    final rows = await _db.db.query(
      'products',
      where: 'deleted = 0',
      orderBy: 'updated_at DESC',
    );
    return rows.map(Product.fromRow).toList();
  }

  Future<Product> insert({
    required String name,
    required String unit,
    required double price,
    required int stock,
  }) async {
    final product = Product(
      id: _uuid.v4(),
      name: name,
      unit: unit,
      price: price,
      stock: stock,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );

    await _db.db.transaction((txn) async {
      await txn.insert('products', product.toRow());
      await _appendChangeLog(txn, op: 'insert', product: product);
    });

    return product;
  }

  Future<void> updateStock(Product product, int newStock) async {
    final updated = Product(
      id: product.id,
      name: product.name,
      unit: product.unit,
      price: product.price,
      stock: newStock,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );

    await _db.db.transaction((txn) async {
      await txn.update(
        'products',
        updated.toRow(),
        where: 'id = ?',
        whereArgs: [product.id],
      );
      await _appendChangeLog(txn, op: 'update', product: updated);
    });
  }

  Future<void> softDelete(Product product) async {
    final tombstone = Product(
      id: product.id,
      name: product.name,
      unit: product.unit,
      price: product.price,
      stock: product.stock,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
      deleted: true,
    );

    await _db.db.transaction((txn) async {
      await txn.update(
        'products',
        {'deleted': 1, 'updated_at': tombstone.updatedAt},
        where: 'id = ?',
        whereArgs: [product.id],
      );
      await _appendChangeLog(txn, op: 'delete', product: tombstone);
    });
  }

  Future<void> _appendChangeLog(
    Transaction txn, {
    required String op,
    required Product product,
  }) {
    return txn.insert('change_log', {
      'entity': 'products',
      'entity_id': product.id,
      'op': op,
      'payload': jsonEncode(product.toJson()),
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }
}

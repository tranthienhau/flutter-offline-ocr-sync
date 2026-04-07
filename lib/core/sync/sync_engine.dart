import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../db/database.dart';

/// Drains the local change_log into Firestore whenever the device is online.
///
/// Behaviour:
///  - Subscribes to connectivity changes
///  - On reconnect, reads up to N pending changes in id order
///  - Writes them to Firestore in a batch
///  - Deletes the local change_log rows on success
///  - Backs off and retries on failure (the rows stay in change_log)
class SyncEngine {
  SyncEngine({
    required this.appDb,
    required this.firestore,
    this.batchSize = 50,
  });

  final AppDatabase appDb;
  final FirebaseFirestore firestore;
  final int batchSize;

  StreamSubscription<List<ConnectivityResult>>? _sub;
  bool _running = false;

  void start() {
    _sub = Connectivity().onConnectivityChanged.listen((results) {
      final online = results.any((r) => r != ConnectivityResult.none);
      if (online) drain();
    });
    // Attempt an initial drain on startup.
    drain();
  }

  Future<void> stop() async {
    await _sub?.cancel();
  }

  Future<void> drain() async {
    if (_running) return;
    _running = true;
    try {
      while (await _drainOnce()) {
        // Loop until the change_log is empty.
      }
    } catch (e) {
      // Leave the change_log intact and let the next connectivity event retry.
      // ignore: avoid_print
      print('SyncEngine.drain failed, will retry on next connectivity event: $e');
    } finally {
      _running = false;
    }
  }

  /// Returns true if there is more work after this batch.
  Future<bool> _drainOnce() async {
    final pending = await appDb.db.query(
      'change_log',
      orderBy: 'id ASC',
      limit: batchSize,
    );
    if (pending.isEmpty) return false;

    final batch = firestore.batch();
    for (final row in pending) {
      final op = row['op'] as String;
      final entity = row['entity'] as String;
      final entityId = row['entity_id'] as String;
      final payload = jsonDecode(row['payload'] as String) as Map<String, Object?>;

      final ref = firestore.collection(entity).doc(entityId);
      switch (op) {
        case 'insert':
        case 'update':
          batch.set(ref, payload, SetOptions(merge: true));
          break;
        case 'delete':
          batch.delete(ref);
          break;
      }
    }

    await batch.commit();

    final lastId = pending.last['id'] as int;
    await appDb.db.delete('change_log', where: 'id <= ?', whereArgs: [lastId]);

    return pending.length == batchSize;
  }

  Future<int> pendingCount() async {
    final result = await appDb.db.rawQuery('SELECT COUNT(*) as c FROM change_log');
    return (result.first['c'] as int?) ?? 0;
  }
}

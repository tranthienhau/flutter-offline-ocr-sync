import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/sync/connectivity_provider.dart';
import 'inventory_controller.dart';

class InventoryScreen extends ConsumerWidget {
  const InventoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final products = ref.watch(inventoryControllerProvider);
    final controller = ref.read(inventoryControllerProvider.notifier);
    final online = ref.watch(connectivityProvider).valueOrNull ?? true;

    return Scaffold(
      appBar: AppBar(title: const Text('Stock')),
      body: Column(
        children: [
          if (!online)
            Container(
              width: double.infinity,
              color: Colors.green.shade600,
              padding: const EdgeInsets.all(12),
              child: const Text(
                'Saving locally - will sync when data returns',
                style: TextStyle(color: Colors.white, fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ),
          Expanded(
            child: ListView.builder(
              itemCount: products.length,
              itemBuilder: (context, i) {
                final p = products[i];
                return ListTile(
                  title: Text(p.name, style: const TextStyle(fontSize: 22)),
                  subtitle: Text('${p.stock} ${p.unit}  |  ${p.price.toStringAsFixed(2)}'),
                  trailing: SizedBox(
                    width: 96,
                    child: ElevatedButton(
                      onPressed: () => controller.sell(p),
                      child: const Text('Sell'),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.camera_alt),
        label: const Text('Add with camera'),
        onPressed: () {
          // Camera capture screen lives in camera_capture_screen.dart - in a real
          // build this opens the OcrTextRecognizer flow.
          controller.addProduct(name: 'Olonka of garri', unit: 'olonka', price: 12.0, stock: 10);
        },
      ),
    );
  }
}

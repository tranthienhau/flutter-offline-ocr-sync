import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:flutter_offline_ocr_sync/core/db/product_dao.dart';
import 'package:flutter_offline_ocr_sync/core/sync/connectivity_provider.dart';
import 'package:flutter_offline_ocr_sync/features/inventory/inventory_controller.dart';
import 'package:flutter_offline_ocr_sync/features/inventory/inventory_screen.dart';

List<Product> _seed() {
  final now = DateTime.now().millisecondsSinceEpoch;
  Product mk(String id, String name, String unit, double price, int stock) =>
      Product(id: id, name: name, unit: unit, price: price, stock: stock, updatedAt: now);
  return [
    mk('p1', 'Bag of rice (50kg)', 'bag', 62.00, 14),
    mk('p2', 'Olonka of garri', 'olonka', 12.00, 30),
    mk('p3', 'Crate of eggs', 'crate', 9.50, 8),
    mk('p4', 'Carton of noodles', 'carton', 18.00, 21),
    mk('p5', 'Sachet water (bag)', 'bag', 4.00, 45),
    mk('p6', 'Tin of milk', 'tin', 6.25, 60),
    mk('p7', 'Loaf of bread', 'loaf', 3.75, 12),
  ];
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> shoot(WidgetTester tester, String name) async {
    await binding.convertFlutterSurfaceToImage();
    await tester.pumpAndSettle();
    await binding.takeScreenshot(name);
  }

  // Seeds the real InventoryController in-memory (no SQLite/Firebase) and feeds
  // a fixed online/offline value so no connectivity plugin is touched.
  Widget app({required bool online}) {
    return ProviderScope(
      overrides: [
        inventoryControllerProvider
            .overrideWith((ref) => InventoryController.seeded(_seed())),
        connectivityProvider.overrideWith((ref) => Stream.value(online)),
      ],
      child: MaterialApp(
        title: 'Vendor Inventory',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.orange),
          useMaterial3: true,
        ),
        home: const InventoryScreen(),
      ),
    );
  }

  testWidgets('capture inventory flow', (tester) async {
    // 01 - online stock list with real-looking inventory.
    await tester.pumpWidget(app(online: true));
    await tester.pumpAndSettle();
    await shoot(tester, '01-stock-online');

    // 02 - sell a couple of units to show stock counts changing.
    final sellButtons = find.text('Sell');
    await tester.tap(sellButtons.first);
    await tester.pumpAndSettle();
    await tester.tap(sellButtons.first);
    await tester.pumpAndSettle();
    await shoot(tester, '02-after-sale');

    // 03 - offline mode shows the green "saving locally" sync banner.
    // Tear the tree down to an empty frame first so the new ProviderScope
    // builds a fresh InventoryController and a fresh connectivity stream,
    // then let the StreamProvider emit `false` before the screenshot.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await tester.pumpWidget(app(online: false));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(find.text('Saving locally - will sync when data returns'),
        findsOneWidget);
    await shoot(tester, '03-offline-sync');
  });
}

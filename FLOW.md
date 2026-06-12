# Screenshot capture flow

Real captures from the iOS Simulator via an integration-test driver (no mockups).

## Steps

1. Boot the simulator:
   ```bash
   xcrun simctl boot "iPhone 17 Pro Max"
   open -a Simulator
   ```
2. Scaffold the iOS platform folder (lib-only project) and get dependencies:
   ```bash
   flutter create . --platforms=ios --project-name flutter_offline_ocr_sync
   flutter pub get
   ```
3. Drive the screenshot test:
   ```bash
   flutter drive \
     --driver test_driver/integration_test.dart \
     --target integration_test/screenshot_test.dart \
     -d "B4172C2F-DF1D-4269-85FD-CBC4ADC6D393"
   ```
4. Build the demo GIF from the PNGs:
   ```bash
   cd screenshots
   ffmpeg -y -framerate 1 -pattern_type glob -i '*.png' \
     -vf "scale=320:-1:flags=lanczos,split[s0][s1];[s0]palettegen[p];[s1][p]paletteuse" \
     -loop 0 demo.gif
   ```

PNGs + `demo.gif` are written to `screenshots/` and embedded in `README.md`.

## How it works

- `test_driver/integration_test.dart` - `integrationDriver(onScreenshot:)` writes each PNG to `screenshots/<name>.png`.
- `integration_test/screenshot_test.dart` - pumps `InventoryScreen` wrapped in a `ProviderScope` whose overrides seed the **real** `InventoryController.seeded(...)` with an in-memory product list and feed the `connectivityProvider` a fixed online/offline value. No SQLite, Firebase, or connectivity plugin is touched, so the inventory + sync UI renders deterministically on the simulator. It calls `binding.convertFlutterSurfaceToImage()` + `binding.takeScreenshot('NN-name')` at each key view:
  1. `01-stock-online` - the stock list with real product names, units, prices, and stock counts.
  2. `02-after-sale` - taps the first "Sell" button twice; the bag-of-rice stock count drops, showing reactive Riverpod state.
  3. `03-offline-sync` - re-pumps the tree with `online: false`; the `connectivityProvider` stream emits `false` and the green "Saving locally - will sync when data returns" banner appears.

## Note on iOS simulator dependencies

The full app uses `google_mlkit_text_recognition` and `camera` for on-device OCR capture. Those plugins' iOS pods (GoogleMLKit / MLImage) ship x86_64-only simulator slices and cannot link on Apple-Silicon arm64 simulators. They are omitted from the dependency set used for this screenshot capture so the inventory + offline-sync flow can be driven on the simulator. The OCR wrapper (`lib/core/ocr/text_recognizer.dart`) keeps the same public API behind a stub; swap it back to ML Kit for a physical-device build.

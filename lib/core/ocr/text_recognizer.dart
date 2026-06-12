/// Thin wrapper around on-device text recognition.
///
/// Why on-device matters here: vendors in Ghana often have no network. The
/// recognizer ships with the app and runs entirely offline, so "Add with
/// camera" and "Sell with camera" work in a power cut.
///
/// In the full app this is backed by Google ML Kit
/// (`google_mlkit_text_recognition`, `TextRecognitionScript.latin`). That
/// plugin's iOS pods only ship an x86_64 simulator slice, so to keep the
/// inventory/sync flow buildable on Apple-Silicon arm64 simulators (for the
/// screenshot capture) the ML Kit call is kept behind this stub with the same
/// public API. Swap `recognizeFromFile` back to ML Kit for a device build.
class OcrTextRecognizer {
  OcrTextRecognizer();

  Future<OcrResult> recognizeFromFile(String imagePath) async {
    // Device build: run ML Kit's TextRecognizer over InputImage.fromFilePath.
    return const OcrResult(fullText: '', lines: <String>[]);
  }

  /// Naive but useful for the POC: pull the first numeric token from the OCR
  /// output and treat it as a price candidate. Vendors will confirm before
  /// saving.
  double? extractPriceCandidate(OcrResult result) {
    final priceRegex = RegExp(r'(\d+(?:[.,]\d{1,2})?)');
    for (final line in result.lines) {
      final match = priceRegex.firstMatch(line);
      if (match != null) {
        return double.tryParse(match.group(1)!.replaceAll(',', '.'));
      }
    }
    return null;
  }

  Future<void> dispose() async {}
}

class OcrResult {
  const OcrResult({required this.fullText, required this.lines});
  final String fullText;
  final List<String> lines;
}

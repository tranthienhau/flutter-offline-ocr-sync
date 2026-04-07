import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Thin wrapper around Google ML Kit on-device text recognition.
///
/// Why on-device matters here: vendors in Ghana often have no network. The
/// ML Kit text recognizer ships with the app and runs entirely offline, so
/// "Add with camera" and "Sell with camera" work in a power cut.
class OcrTextRecognizer {
  OcrTextRecognizer() : _recognizer = TextRecognizer(script: TextRecognitionScript.latin);

  final TextRecognizer _recognizer;

  Future<OcrResult> recognizeFromFile(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    final result = await _recognizer.processImage(inputImage);

    return OcrResult(
      fullText: result.text,
      lines: [
        for (final block in result.blocks)
          for (final line in block.lines) line.text,
      ],
    );
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

  Future<void> dispose() => _recognizer.close();
}

class OcrResult {
  OcrResult({required this.fullText, required this.lines});
  final String fullText;
  final List<String> lines;
}

import 'dart:typed_data';

/// Minimal ESC/POS command builder for 58/80mm Bluetooth thermal printers.
///
/// Receipts are sent as a raster image (GS v 0) so Hindi text and the ₹ sign
/// print correctly on cheap printers that have no Devanagari font.
class EscPos {
  static const List<int> init = [0x1B, 0x40];
  static const List<int> alignCenter = [0x1B, 0x61, 0x01];
  static const List<int> alignLeft = [0x1B, 0x61, 0x00];

  static List<int> feedLines(int n) => [0x1B, 0x64, n.clamp(0, 255)];

  /// Partial cut. Printers without a cutter ignore it.
  static const List<int> cut = [0x1D, 0x56, 0x42, 0x00];

  /// Plain ASCII text line (for test prints). Non-ASCII characters become '?'.
  static List<int> textLine(String text) {
    final bytes = text.codeUnits.map((c) => c < 128 ? c : 0x3F).toList();
    return [...bytes, 0x0A];
  }

  /// Converts RGBA pixels into GS v 0 raster commands.
  ///
  /// [stride] is the pixel width of each source row when wider than [width] (cropping).
  ///
  /// Pixels darker than [threshold] (0-255 luminance) print black; transparent
  /// pixels count as white paper. The image is sent in bands of [bandHeight]
  /// rows because many budget printers have small receive buffers.
  static List<int> rasterImage({
    required int width,
    required int height,
    required Uint8List rgba,
    int? stride,
    int threshold = 170,
    int bandHeight = 120,
  }) {
    final rowPixels = stride ?? width;
    if (rowPixels < width || rgba.length < rowPixels * height * 4) {
      throw ArgumentError('rgba buffer too small for ${width}x$height');
    }
    final bytesPerRow = (width + 7) >> 3;
    final out = <int>[];

    for (var top = 0; top < height; top += bandHeight) {
      final rows = (height - top) < bandHeight ? (height - top) : bandHeight;
      out.addAll([
        0x1D, 0x76, 0x30, 0x00, //
        bytesPerRow & 0xFF, (bytesPerRow >> 8) & 0xFF,
        rows & 0xFF, (rows >> 8) & 0xFF,
      ]);
      for (var y = top; y < top + rows; y++) {
        for (var bx = 0; bx < bytesPerRow; bx++) {
          var byte = 0;
          for (var bit = 0; bit < 8; bit++) {
            final x = bx * 8 + bit;
            if (x >= width) continue;
            final i = (y * rowPixels + x) * 4;
            final a = rgba[i + 3];
            // Blend onto white paper, then compute luminance.
            final r = 255 - ((255 - rgba[i]) * a ~/ 255);
            final g = 255 - ((255 - rgba[i + 1]) * a ~/ 255);
            final b = 255 - ((255 - rgba[i + 2]) * a ~/ 255);
            final lum = (299 * r + 587 * g + 114 * b) ~/ 1000;
            if (lum < threshold) byte |= 0x80 >> bit;
          }
          out.add(byte);
        }
      }
    }
    return out;
  }
}

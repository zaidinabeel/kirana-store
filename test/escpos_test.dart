import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kirana_store/core/printing/escpos.dart';
import 'package:kirana_store/core/printing/paper_width.dart';

Uint8List _image(int w, int h, bool Function(int x, int y) black, {int alpha = 255}) {
  final out = Uint8List(w * h * 4);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final i = (y * w + x) * 4;
      final v = black(x, y) ? 0 : 255;
      out[i] = v;
      out[i + 1] = v;
      out[i + 2] = v;
      out[i + 3] = alpha;
    }
  }
  return out;
}

void main() {
  group('EscPos raster encoding', () {
    test('header is GS v 0 with width in bytes and row count', () {
      final bytes = EscPos.rasterImage(width: 16, height: 2, rgba: _image(16, 2, (_, __) => false));
      expect(bytes.sublist(0, 8), [0x1D, 0x76, 0x30, 0x00, 2, 0, 2, 0]);
      expect(bytes.length, 8 + 2 * 2);
    });

    test('black pixels set bits MSB-first, white pixels stay clear', () {
      // Left half black on a 16px-wide line.
      final bytes = EscPos.rasterImage(width: 16, height: 1, rgba: _image(16, 1, (x, _) => x < 8));
      expect(bytes.sublist(8), [0xFF, 0x00]);
      // Only the very first pixel black.
      final one = EscPos.rasterImage(width: 8, height: 1, rgba: _image(8, 1, (x, _) => x == 0));
      expect(one.last, 0x80);
    });

    test('transparent pixels print as white paper', () {
      final bytes = EscPos.rasterImage(width: 8, height: 1, rgba: _image(8, 1, (_, __) => true, alpha: 0));
      expect(bytes.last, 0x00);
    });

    test('width not divisible by 8 pads the last byte with white', () {
      final bytes = EscPos.rasterImage(width: 10, height: 1, rgba: _image(10, 1, (_, __) => true));
      expect(bytes.sublist(4, 6), [2, 0]); // 2 bytes per row
      expect(bytes.sublist(8), [0xFF, 0xC0]);
    });

    test('tall images are split into bands', () {
      final bytes = EscPos.rasterImage(width: 8, height: 250, rgba: _image(8, 250, (_, __) => false), bandHeight: 120);
      // 3 bands: 120 + 120 + 10 rows, each with an 8-byte header.
      expect(bytes.length, 3 * 8 + 250);
      expect(bytes.sublist(120 * 1 + 8, 120 * 1 + 8 + 8), [0x1D, 0x76, 0x30, 0x00, 1, 0, 120, 0]);
    });

    test('stride crops images wider than the print head', () {
      final rgba = _image(10, 1, (x, _) => x >= 8); // only pixels 8-9 black
      final bytes = EscPos.rasterImage(width: 8, stride: 10, height: 1, rgba: rgba);
      expect(bytes.sublist(8), [0x00]);
    });
  });

  test('paper widths map to standard 203 dpi dot counts', () {
    expect(PaperWidth.mm58.dots, 384);
    expect(PaperWidth.mm80.dots, 576);
  });

  test('test-print text replaces non-ASCII characters', () {
    expect(EscPos.textLine('A₹'), [0x41, 0x3F, 0x0A]);
  });
}

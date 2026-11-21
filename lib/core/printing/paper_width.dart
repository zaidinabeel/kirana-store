enum PaperWidth { mm58, mm80 }

extension PaperWidthExt on PaperWidth {
  String get label => this == PaperWidth.mm58 ? '58mm (छोटा)' : '80mm (बड़ा)';

  /// Printable dots per line on a standard 203 dpi thermal head.
  int get dots => this == PaperWidth.mm58 ? 384 : 576;

  /// Width the receipt is laid out at on screen (logical pixels).
  /// Captured at `dots / logicalWidth` pixel ratio so text prints at a readable size.
  double get logicalWidth => this == PaperWidth.mm58 ? 230.0 : 345.0;

  /// Kept for older call sites.
  double get pixelWidth => logicalWidth;
}

import 'package:drift/drift.dart' show BooleanExpressionOperators;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/db/app_database.dart';
import '../../../core/i18n/app_strings.dart';
import '../domain/product_model.dart';
import '../state/inventory_notifier.dart';
import 'widgets/quick_add_product_sheet.dart';

class _ScanLine {
  final Product product;
  double added;
  _ScanLine(this.product, this.added);
}

/// Scan screen that stays open: every scan of a known item adds 1 to stock,
/// an unknown barcode opens the short "new item" form. Built for unloading
/// a delivery quickly.
class StockScanScreen extends ConsumerStatefulWidget {
  const StockScanScreen({super.key});

  @override
  ConsumerState<StockScanScreen> createState() => _StockScanScreenState();
}

class _StockScanScreenState extends ConsumerState<StockScanScreen> {
  final _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
  );
  final _manualController = TextEditingController();

  /// Lines scanned in this session, newest first.
  final List<_ScanLine> _lines = [];
  String? _lastCode;
  DateTime? _lastAt;
  bool _busy = false;
  bool _torchOn = false;
  String? _banner;
  bool _bannerIsNew = false;

  @override
  void dispose() {
    _controller.dispose();
    _manualController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    for (final b in capture.barcodes) {
      final code = b.rawValue?.trim();
      if (code != null && code.isNotEmpty) {
        _handleCode(code);
        return;
      }
    }
  }

  Future<void> _handleCode(String code) async {
    // Close the keyboard so the list of scanned items stays visible.
    FocusManager.instance.primaryFocus?.unfocus();
    final now = DateTime.now();
    // The camera sees the same barcode many times a second; count it once per 2s.
    if (_busy || (code == _lastCode && _lastAt != null && now.difference(_lastAt!).inMilliseconds < 2000)) return;
    _busy = true;
    _lastCode = code;
    _lastAt = now;
    final hi = ref.read(localeProvider) == AppLanguage.hi;

    try {
      final db = ref.read(databaseProvider);
      final product = await (db.select(db.products)
            ..where((p) => p.barcode.equals(code) & p.isActive.equals(true)))
          .getSingleOrNull();

      if (product != null) {
        await _addStock(product, 1);
        HapticFeedback.mediumImpact();
        SystemSound.play(SystemSoundType.click);
        return;
      }

      // Unknown barcode: pause the camera and ask for name + price.
      HapticFeedback.heavyImpact();
      await _controller.stop();
      if (!mounted) return;
      final saved = await showQuickAddProductSheet(context, barcode: code);
      if (!mounted) return;
      FocusManager.instance.primaryFocus?.unfocus();
      if (saved != null) {
        setState(() {
          _lines.insert(0, _ScanLine(saved, saved.stockQty));
          _banner = hi ? '✓ नया सामान जुड़ा: ${saved.nameHi ?? saved.nameEn}' : '✓ New item added: ${saved.nameEn}';
          _bannerIsNew = true;
        });
      }
      await _controller.start();
    } finally {
      _busy = false;
    }
  }

  Future<void> _addStock(Product product, double qty) async {
    final hi = ref.read(localeProvider) == AppLanguage.hi;
    await ref.read(inventoryProvider.notifier).adjustStock(product.id, qty, qty >= 0 ? 'purchase' : 'adjustment');
    final db = ref.read(databaseProvider);
    final fresh = await (db.select(db.products)..where((p) => p.id.equals(product.id))).getSingle();
    if (!mounted) return;
    setState(() {
      final idx = _lines.indexWhere((l) => l.product.id == product.id);
      if (idx >= 0) {
        final line = _lines.removeAt(idx);
        _lines.insert(0, _ScanLine(fresh, line.added + qty));
      } else {
        _lines.insert(0, _ScanLine(fresh, qty));
      }
      final name = hi ? (fresh.nameHi ?? fresh.nameEn) : fresh.nameEn;
      final sign = qty >= 0 ? '+' : '';
      _banner = hi
          ? '$name  $sign${_fmt(qty)}   (कुल स्टॉक: ${_fmt(fresh.stockQty)})'
          : '$name  $sign${_fmt(qty)}   (stock: ${_fmt(fresh.stockQty)})';
      _bannerIsNew = false;
    });
  }

  Future<void> _setLineQty(_ScanLine line) async {
    final hi = ref.read(localeProvider) == AppLanguage.hi;
    final controller = TextEditingController(text: _fmt(line.added));
    final value = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(hi ? 'कितने आए?' : 'How many received?'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(hi ? 'रद्द' : 'Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, double.tryParse(controller.text)),
            child: Text(hi ? 'ठीक है' : 'OK'),
          ),
        ],
      ),
    );
    if (value == null || value < 0) return;
    final delta = value - line.added;
    if (delta != 0) await _addStock(line.product, delta);
  }

  Future<void> _addWithoutBarcode() async {
    await _controller.stop();
    if (!mounted) return;
    final saved = await showQuickAddProductSheet(context);
    if (!mounted) return;
    FocusManager.instance.primaryFocus?.unfocus();
    if (saved != null) {
      setState(() => _lines.insert(0, _ScanLine(saved, saved.stockQty)));
    }
    await _controller.start();
  }

  static String _fmt(double q) => q % 1 == 0 ? q.toInt().toString() : q.toStringAsFixed(2);

  @override
  Widget build(BuildContext context) {
    final hi = ref.watch(localeProvider) == AppLanguage.hi;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: Text(hi ? 'सामान स्कैन करें' : 'Scan items', style: const TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            tooltip: hi ? 'टॉर्च' : 'Torch',
            icon: Icon(_torchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded),
            onPressed: () {
              _controller.toggleTorch();
              setState(() => _torchOn = !_torchOn);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.32,
            child: Stack(
              alignment: Alignment.center,
              children: [
                MobileScanner(
                  controller: _controller,
                  onDetect: _onDetect,
                  errorBuilder: (context, error, child) => _CameraProblem(hindi: hi),
                ),
                Container(
                  width: 260,
                  height: 130,
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.accent, width: 3),
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                Positioned(
                  bottom: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(20)),
                    child: Text(
                      hi ? 'बारकोड को पीले डिब्बे में रखें' : 'Hold the barcode inside the yellow box',
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_banner != null)
            Container(
              width: double.infinity,
              color: _bannerIsNew ? AppColors.accentLight : AppColors.successLight,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Text(
                _banner!,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: _bannerIsNew ? AppColors.textPrimary : AppColors.success,
                ),
              ),
            ),
          Expanded(
            child: _lines.isEmpty
                ? Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        hi
                            ? 'पैकेट का बारकोड कैमरे के सामने रखें।\nपुराना सामान: स्टॉक अपने आप +1 होगा।\nनया सामान: नाम और दाम पूछेगा।'
                            : 'Point the camera at a barcode.\nKnown item: stock +1 automatically.\nNew item: you will be asked for name and price.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 16, height: 1.6, color: AppColors.textSecondary),
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: _lines.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final line = _lines[i];
                      final p = line.product;
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        title: Text(
                          hi ? (p.nameHi ?? p.nameEn) : p.nameEn,
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                        ),
                        subtitle: Text(
                          hi ? 'कुल स्टॉक: ${_fmt(p.stockQty)}' : 'Stock: ${_fmt(p.stockQty)}',
                          style: const TextStyle(fontSize: 14),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton.outlined(
                              iconSize: 26,
                              onPressed: () => _addStock(p, -1),
                              icon: const Icon(Icons.remove),
                            ),
                            InkWell(
                              onTap: () => _setLineQty(line),
                              child: Container(
                                constraints: const BoxConstraints(minWidth: 52),
                                alignment: Alignment.center,
                                padding: const EdgeInsets.symmetric(horizontal: 6),
                                child: Text(
                                  '+${_fmt(line.added)}',
                                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.success),
                                ),
                              ),
                            ),
                            IconButton.filled(
                              iconSize: 26,
                              onPressed: () => _addStock(p, 1),
                              icon: const Icon(Icons.add),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _manualController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            hintText: hi ? 'या बारकोड नंबर लिखें' : 'Or type the barcode number',
                            isDense: true,
                          ),
                          onSubmitted: (v) {
                            if (v.trim().isNotEmpty) _handleCode(v.trim());
                            _manualController.clear();
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {
                          final v = _manualController.text.trim();
                          if (v.isNotEmpty) _handleCode(v);
                          _manualController.clear();
                        },
                        child: const Text('OK'),
                      ),
                    ],
                  ),
                  if (kDebugMode)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: () => _handleCode('8901030000041'),
                        child: const Text('Test scan (debug)'),
                      ),
                    ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(minimumSize: const Size(0, 52)),
                          onPressed: _addWithoutBarcode,
                          icon: const Icon(Icons.edit_note_rounded),
                          label: Text(hi ? 'बिना बारकोड वाला' : 'No barcode', style: const TextStyle(fontSize: 15)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(0, 52),
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.check_rounded),
                          label: Text(hi ? 'हो गया' : 'Done', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shown instead of the camera when it can't start (no permission, no camera).
class _CameraProblem extends StatelessWidget {
  final bool hindi;
  const _CameraProblem({required this.hindi});

  @override
  Widget build(BuildContext context) {
    // Sits above the yellow frame so the two never overlap.
    return Container(
      color: Colors.black,
      alignment: Alignment.topCenter,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Text(
        hindi ? '📷 कैमरा नहीं खुला — नीचे बारकोड नंबर लिखें' : '📷 Camera unavailable — type the barcode below',
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.5),
      ),
    );
  }
}

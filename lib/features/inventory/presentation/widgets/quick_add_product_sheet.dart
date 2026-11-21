import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/db/app_database.dart';
import '../../../../core/i18n/app_strings.dart';
import '../../../../core/services/barcode_api_service.dart';
import '../../../../core/services/translation_service.dart';
import '../../../../core/validation/formatters.dart';
import '../../domain/product_model.dart';
import '../../state/inventory_notifier.dart';

/// Shows the short "new item" form. Returns the saved product, or null if cancelled.
Future<Product?> showQuickAddProductSheet(
  BuildContext context, {
  String? barcode,
  double initialQty = 1,
}) {
  return showModalBottomSheet<Product>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => QuickAddProductSheet(barcode: barcode, initialQty: initialQty),
  );
}

/// Three-field product form (name, price, quantity) for fast entry at the counter.
/// The name is looked up online from the barcode when possible.
class QuickAddProductSheet extends ConsumerStatefulWidget {
  final String? barcode;
  final double initialQty;

  const QuickAddProductSheet({super.key, this.barcode, this.initialQty = 1});

  @override
  ConsumerState<QuickAddProductSheet> createState() => _QuickAddProductSheetState();
}

class _QuickAddProductSheetState extends ConsumerState<QuickAddProductSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _nameHiController = TextEditingController();
  final _priceController = TextEditingController();
  final _mrpController = TextEditingController();
  final _costController = TextEditingController();
  final _qtyController = TextEditingController();
  final _nameFocus = FocusNode();
  final _priceFocus = FocusNode();

  bool _isLoose = false;
  bool _showMore = false;
  bool _lookingUp = false;
  bool _saving = false;
  double _gstRate = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _qtyController.text = _fmtQty(widget.initialQty);
    final code = widget.barcode;
    if (code != null && code.isNotEmpty) {
      _lookup(code);
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => _nameFocus.requestFocus());
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nameHiController.dispose();
    _priceController.dispose();
    _mrpController.dispose();
    _costController.dispose();
    _qtyController.dispose();
    _nameFocus.dispose();
    _priceFocus.dispose();
    super.dispose();
  }

  static String _fmtQty(double q) => q % 1 == 0 ? q.toInt().toString() : q.toString();

  Future<void> _lookup(String code) async {
    setState(() => _lookingUp = true);
    final info = await BarcodeApiService.lookup(code);
    if (!mounted) return;
    if (info != null && _nameController.text.trim().isEmpty) {
      final name = [if (info.brand != null && !info.nameEn.toLowerCase().contains(info.brand!.toLowerCase())) info.brand, info.nameEn, info.quantityHint]
          .whereType<String>()
          .join(' ');
      _nameController.text = name;
      final hi = await TranslationService.translateToHindi(info.nameEn);
      if (mounted && hi != null && _nameHiController.text.isEmpty) _nameHiController.text = hi;
    }
    if (!mounted) return;
    setState(() => _lookingUp = false);
    // Jump straight to the field the shopkeeper still has to fill.
    (_nameController.text.trim().isEmpty ? _nameFocus : _priceFocus).requestFocus();
  }

  void _stepQty(double delta) {
    final current = double.tryParse(_qtyController.text) ?? 0;
    final next = (current + delta).clamp(0, 99999).toDouble();
    setState(() => _qtyController.text = _fmtQty(next));
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final notifier = ref.read(inventoryProvider.notifier);
    final name = _nameController.text.trim();
    final nameHi = _nameHiController.text.trim();
    final error = await notifier.saveProduct(
      barcode: widget.barcode,
      nameEn: name,
      nameHi: nameHi.isEmpty ? null : nameHi,
      itemType: _isLoose ? 'loose' : 'packed',
      unit: _isLoose ? 'kg' : 'piece',
      price: double.parse(_priceController.text),
      mrp: double.tryParse(_mrpController.text),
      costPrice: double.tryParse(_costController.text),
      gstRate: _gstRate,
      stockQty: double.tryParse(_qtyController.text) ?? 0,
      reorderLevel: _isLoose ? 2 : 3,
    );
    if (!mounted) return;
    if (error != null) {
      setState(() {
        _saving = false;
        _error = error;
      });
      return;
    }
    final db = ref.read(databaseProvider);
    final query = db.select(db.products)
      ..where((p) => p.isActive.equals(true))
      ..where((p) => widget.barcode != null ? p.barcode.equals(widget.barcode!) : p.nameEn.equals(name))
      ..orderBy([(p) => OrderingTerm.desc(p.createdAt)])
      ..limit(1);
    final saved = await query.getSingleOrNull();
    if (mounted) Navigator.of(context).pop(saved);
  }

  @override
  Widget build(BuildContext context) {
    final hi = ref.watch(localeProvider) == AppLanguage.hi;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + bottomInset),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                hi ? 'नया सामान जोड़ें' : 'Add new item',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.primary),
              ),
              if (widget.barcode != null)
                Text(
                  '${hi ? "बारकोड" : "Barcode"}: ${widget.barcode}',
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
              if (_lookingUp) ...[
                const SizedBox(height: 10),
                const LinearProgressIndicator(minHeight: 3),
                const SizedBox(height: 4),
                Text(
                  hi ? 'इंटरनेट से नाम ढूँढ रहे हैं…' : 'Looking up the name online…',
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
              ],
              const SizedBox(height: 14),
              _bigField(
                controller: _nameController,
                focusNode: _nameFocus,
                label: hi ? 'सामान का नाम' : 'Item name',
                hint: hi ? 'जैसे: पारले-जी 100 ग्राम' : 'e.g. Parle-G 100g',
                textInputAction: TextInputAction.next,
                onSubmitted: (_) => _priceFocus.requestFocus(),
                validator: (v) => (v == null || v.trim().length < 2) ? (hi ? 'नाम लिखें' : 'Enter a name') : null,
              ),
              const SizedBox(height: 12),
              _bigField(
                controller: _priceController,
                focusNode: _priceFocus,
                label: hi ? (_isLoose ? 'दाम (₹ प्रति किलो)' : 'बेचने का दाम (₹)') : (_isLoose ? 'Price (₹ per kg)' : 'Selling price (₹)'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [DecimalInputFormatter(2)],
                prefix: '₹ ',
                validator: (v) {
                  final n = double.tryParse(v ?? '');
                  if (n == null || n <= 0) return hi ? 'दाम लिखें' : 'Enter a price';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              _bigField(
                controller: _costController,
                label: hi
                    ? (_isLoose ? 'खरीद का दाम ₹/किलो (ज़रूरी नहीं, मुनाफ़े के लिए)' : 'खरीद का दाम (ज़रूरी नहीं, मुनाफ़े के लिए)')
                    : (_isLoose ? 'Purchase price ₹/kg (optional, for profit)' : 'Purchase price (optional, for profit)'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [DecimalInputFormatter(2)],
                prefix: '₹ ',
              ),
              const SizedBox(height: 12),
              Text(
                hi ? (_isLoose ? 'कितना माल आया (किलो)' : 'कितने पीस आए') : (_isLoose ? 'Stock received (kg)' : 'Pieces received'),
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  _stepButton(Icons.remove, () => _stepQty(-1)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _qtyController,
                      textAlign: TextAlign.center,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [DecimalInputFormatter(3)],
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                      decoration: const InputDecoration(isDense: true),
                    ),
                  ),
                  const SizedBox(width: 10),
                  _stepButton(Icons.add, () => _stepQty(1)),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: Text(hi ? '📦 पैकेट / पीस' : '📦 Packet / piece', style: const TextStyle(fontSize: 15)),
                    selected: !_isLoose,
                    onSelected: (_) => setState(() => _isLoose = false),
                  ),
                  ChoiceChip(
                    label: Text(hi ? '⚖️ खुला (किलो)' : '⚖️ Loose (kg)', style: const TextStyle(fontSize: 15)),
                    selected: _isLoose,
                    onSelected: (_) => setState(() => _isLoose = true),
                  ),
                ],
              ),
              TextButton.icon(
                onPressed: () => setState(() => _showMore = !_showMore),
                icon: Icon(_showMore ? Icons.expand_less : Icons.expand_more),
                label: Text(hi ? 'और जानकारी (ज़रूरी नहीं)' : 'More details (optional)'),
              ),
              if (_showMore) ...[
                _bigField(
                  controller: _nameHiController,
                  label: hi ? 'हिंदी में नाम' : 'Name in Hindi',
                ),
                const SizedBox(height: 10),
                _bigField(
                  controller: _mrpController,
                  label: 'MRP (₹)',
                  prefix: '₹ ',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [DecimalInputFormatter(2)],
                ),
                const SizedBox(height: 10),
                Text(hi ? 'GST %' : 'GST %', style: const TextStyle(fontWeight: FontWeight.w700)),
                Wrap(
                  spacing: 6,
                  children: [0.0, 5.0, 12.0, 18.0, 28.0]
                      .map((r) => ChoiceChip(
                            label: Text('${r.toInt()}%'),
                            selected: _gstRate == r,
                            onSelected: (_) => setState(() => _gstRate = r),
                          ))
                      .toList(),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(color: AppColors.alert, fontWeight: FontWeight.w700)),
              ],
              const SizedBox(height: 14),
              SizedBox(
                height: 56,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                      : const Icon(Icons.check_rounded, size: 28),
                  label: Text(hi ? 'सेव करें' : 'Save', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stepButton(IconData icon, VoidCallback onTap) {
    return SizedBox(
      width: 56,
      height: 56,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          side: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        onPressed: onTap,
        child: Icon(icon, size: 28, color: AppColors.primary),
      ),
    );
  }

  Widget _bigField({
    required TextEditingController controller,
    required String label,
    FocusNode? focusNode,
    String? hint,
    String? prefix,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    ValueChanged<String>? onSubmitted,
    List<TextInputFormatter>? inputFormatters,
    FormFieldValidator<String>? validator,
  }) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      onFieldSubmitted: onSubmitted,
      inputFormatters: inputFormatters,
      validator: validator,
      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixText: prefix,
        labelStyle: const TextStyle(fontSize: 16),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      ),
    );
  }
}

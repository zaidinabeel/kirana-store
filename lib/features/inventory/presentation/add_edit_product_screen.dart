import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:barcode_widget/barcode_widget.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/i18n/app_strings.dart';
import '../../../core/services/barcode_api_service.dart';
import '../../../core/services/translation_service.dart';
import '../../../core/db/app_database.dart';
import '../../../core/validation/validators.dart';
import '../../../core/validation/formatters.dart';
import '../../../shared/widgets/app_header.dart';
import '../../../shared/widgets/debounced_button.dart';
import '../../../shared/widgets/discard_dialog.dart';
import '../state/inventory_notifier.dart';
import 'widgets/barcode_scanner_modal.dart';

class AddEditProductScreen extends ConsumerStatefulWidget {
  final Product? productToEdit;
  final String? initialBarcode;

  const AddEditProductScreen({
    super.key,
    this.productToEdit,
    this.initialBarcode,
  });

  @override
  ConsumerState<AddEditProductScreen> createState() => _AddEditProductScreenState();
}

class _AddEditProductScreenState extends ConsumerState<AddEditProductScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _barcodeController;
  late TextEditingController _nameEnController;
  late TextEditingController _nameHiController;
  late TextEditingController _priceController;
  late TextEditingController _mrpController;
  late TextEditingController _hsnController;
  late TextEditingController _stockController;
  late TextEditingController _reorderController;

  late final String _initialBarcode;
  late final String _initialNameEn;
  late final String _initialNameHi;
  late final String _initialPrice;
  late final String _initialMrp;
  late final String _initialHsn;
  late final String _initialStock;
  late final String _initialReorder;
  late final String _initialItemType;
  late final String _initialUnit;
  late final String? _initialCategoryId;
  late final double _initialGstRate;

  String _itemType = 'packed'; // 'packed' | 'loose'
  String _unit = 'piece';
  String? _selectedCategoryId;
  double _gstRate = 0.0;
  bool _isLookingUpBarcode = false;
  String? _errorMessage;

  final List<String> _packedUnits = ['piece', 'box', 'packet', 'bottle', 'can'];
  final List<String> _looseUnits = ['kg', 'gm', 'litre', 'ml'];
  final List<double> _gstRates = [0.0, 5.0, 12.0, 18.0, 28.0];

  @override
  void initState() {
    super.initState();
    final p = widget.productToEdit;

    _initialBarcode = p?.barcode ?? widget.initialBarcode ?? '';
    _initialNameEn = p?.nameEn ?? '';
    _initialNameHi = p?.nameHi ?? '';
    _initialPrice = p != null ? p.price.toStringAsFixed(1) : '';
    _initialMrp = p?.mrp != null ? p!.mrp!.toStringAsFixed(1) : '';
    _initialHsn = p?.hsnCode ?? '';
    _initialStock = p != null ? p.stockQty.toString() : '10';
    _initialReorder = p != null ? p.reorderLevel.toString() : '5';
    _initialItemType = p?.itemType ?? 'packed';
    _initialUnit = p?.unit ?? 'piece';
    _initialCategoryId = p?.categoryId;
    _initialGstRate = p?.gstRate ?? 0.0;

    _barcodeController = TextEditingController(text: _initialBarcode);
    _nameEnController = TextEditingController(text: _initialNameEn);
    _nameHiController = TextEditingController(text: _initialNameHi);
    _priceController = TextEditingController(text: _initialPrice);
    _mrpController = TextEditingController(text: _initialMrp);
    _hsnController = TextEditingController(text: _initialHsn);
    _stockController = TextEditingController(text: _initialStock);
    _reorderController = TextEditingController(text: _initialReorder);

    _itemType = _initialItemType;
    _unit = _initialUnit;
    _selectedCategoryId = _initialCategoryId;
    _gstRate = _initialGstRate;

    if (widget.initialBarcode != null && widget.initialBarcode!.isNotEmpty && widget.productToEdit == null) {
      _lookupBarcodeOnline(widget.initialBarcode!);
    }
  }

  bool _isFormDirty() {
    return _barcodeController.text.trim() != _initialBarcode ||
        _nameEnController.text.trim() != _initialNameEn ||
        _nameHiController.text.trim() != _initialNameHi ||
        _priceController.text.trim() != _initialPrice ||
        _mrpController.text.trim() != _initialMrp ||
        _hsnController.text.trim() != _initialHsn ||
        _stockController.text.trim() != _initialStock ||
        _reorderController.text.trim() != _initialReorder ||
        _itemType != _initialItemType ||
        _unit != _initialUnit ||
        _selectedCategoryId != _initialCategoryId ||
        _gstRate != _initialGstRate;
  }

  @override
  void dispose() {
    _barcodeController.dispose();
    _nameEnController.dispose();
    _nameHiController.dispose();
    _priceController.dispose();
    _mrpController.dispose();
    _hsnController.dispose();
    _stockController.dispose();
    _reorderController.dispose();
    super.dispose();
  }

  Future<void> _lookupBarcodeOnline(String code) async {
    setState(() => _isLookingUpBarcode = true);
    final externalInfo = await BarcodeApiService.lookup(code);
    setState(() => _isLookingUpBarcode = false);

    if (externalInfo != null && mounted) {
      if (_nameEnController.text.trim().isEmpty) {
        _nameEnController.text = externalInfo.nameEn;
        
        // Auto-translate / transliterate English name to Hindi Devanagari
        final hindiName = await TranslationService.translateToHindi(externalInfo.nameEn);
        if (hindiName != null && mounted) {
          _nameHiController.text = hindiName;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Found item: ${externalInfo.nameEn} ${hindiName != null ? "($hindiName)" : ""}'),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _autoTranslateNameToHindi() async {
    final en = _nameEnController.text.trim();
    if (en.isEmpty) return;

    final hindi = await TranslationService.translateToHindi(en);
    if (hindi != null && mounted) {
      setState(() {
        _nameHiController.text = hindi;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Hindi translated: $hindi'),
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _openBarcodeScanner() {
    showDialog(
      context: context,
      builder: (ctx) => BarcodeScannerModal(
        onBarcodeScanned: (code) {
          _barcodeController.text = code;
          _lookupBarcodeOnline(code);
        },
      ),
    );
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _errorMessage = null);

    final price = double.tryParse(_priceController.text.trim()) ?? 0.0;
    final mrp = double.tryParse(_mrpController.text.trim());
    final stock = double.tryParse(_stockController.text.trim()) ?? 0.0;
    final reorder = double.tryParse(_reorderController.text.trim()) ?? 0.0;

    final result = await ref.read(inventoryProvider.notifier).saveProduct(
      id: widget.productToEdit?.id,
      barcode: _barcodeController.text.trim(),
      nameEn: _nameEnController.text.trim(),
      nameHi: _nameHiController.text.trim().isNotEmpty ? _nameHiController.text.trim() : null,
      categoryId: _selectedCategoryId,
      itemType: _itemType,
      unit: _unit,
      price: price,
      mrp: mrp,
      gstRate: _gstRate,
      hsnCode: _hsnController.text.trim(),
      stockQty: stock,
      reorderLevel: reorder,
    );

    if (result != null) {
      setState(() => _errorMessage = result);
    } else {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Product saved successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(localeProvider);
    final invState = ref.watch(inventoryProvider);
    final isEditing = widget.productToEdit != null;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (_isFormDirty()) {
          final shouldDiscard = await showDiscardConfirmationDialog(context, lang: lang);
          if (shouldDiscard && context.mounted) {
            Navigator.of(context).pop();
          }
        } else {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppHeader(
          title: isEditing ? AppStrings.editProduct(lang) : AppStrings.addProduct(lang),
          showBackButton: true,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: AppColors.alertLight,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.alert, width: 1),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: AppColors.alert, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(color: AppColors.alert, fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Item Type Selector (Packed vs Loose)
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceMuted,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _typeTab(
                            label: AppStrings.packedItems(lang),
                            icon: Icons.inventory_2_outlined,
                            isSelected: _itemType == 'packed',
                            onTap: () {
                              setState(() {
                                _itemType = 'packed';
                                if (!_packedUnits.contains(_unit)) {
                                  _unit = _packedUnits.first;
                                }
                              });
                            },
                          ),
                        ),
                        Expanded(
                          child: _typeTab(
                            label: AppStrings.looseItems(lang),
                            icon: Icons.scale_outlined,
                            isSelected: _itemType == 'loose',
                            onTap: () {
                              setState(() {
                                _itemType = 'loose';
                                if (!_looseUnits.contains(_unit)) {
                                  _unit = _looseUnits.first;
                                }
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Barcode Field with Scan Button
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _barcodeController,
                          keyboardType: TextInputType.number,
                          autofillHints: null,
                          maxLength: 18,
                          inputFormatters: [DigitsOnlyFormatter(18)],
                          decoration: InputDecoration(
                            labelText: AppStrings.barcode(lang),
                            hintText: _itemType == 'loose' ? 'Optional for loose items' : 'Scan or type barcode',
                            prefixIcon: const Icon(Icons.qr_code, color: AppColors.primary),
                            counterText: '',
                            suffixIcon: _isLookingUpBarcode
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: Padding(
                                      padding: EdgeInsets.all(12),
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    ),
                                  )
                                : null,
                          ),
                          validator: (val) {
                            final err = Validators.barcode(val, isRequired: _itemType == 'packed');
                            if (err != null) return err;
                            if (val != null && val.trim().isNotEmpty) {
                              final dup = invState.products.any((p) =>
                                  p.product.barcode == val.trim() && p.product.id != widget.productToEdit?.id);
                              if (dup) return 'Barcode already used by another product';
                            }
                            return null;
                          },
                          onChanged: (val) {
                            if (val.length >= 8 && widget.productToEdit == null) {
                              _lookupBarcodeOnline(val);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        height: 52,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                          ),
                          onPressed: _openBarcodeScanner,
                          icon: const Icon(Icons.camera_alt_rounded, size: 20),
                          label: Text(AppStrings.scanBarcode(lang), style: const TextStyle(fontSize: 13)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Names (English + Hindi)
                  TextFormField(
                    controller: _nameEnController,
                    maxLength: 100,
                    decoration: InputDecoration(
                      labelText: '${AppStrings.productNameEn(lang)} *',
                      hintText: 'e.g. Aashirvaad Atta 5kg / Fevi Kwik',
                      counterText: '',
                    ),
                    validator: Validators.productNameEn,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _nameHiController,
                    maxLength: 100,
                    decoration: InputDecoration(
                      labelText: AppStrings.productNameHi(lang),
                      hintText: 'उदा. आशीर्वाद आटा 5 किग्रा / फेवी क्विक',
                      counterText: '',
                      suffixIcon: Tooltip(
                        message: 'Translate English name to Hindi',
                        child: IconButton(
                          icon: const Icon(Icons.translate_rounded, color: AppColors.primary),
                          onPressed: _autoTranslateNameToHindi,
                        ),
                      ),
                    ),
                    validator: Validators.productNameHi,
                  ),
                  const SizedBox(height: 14),

                  // Category & Unit
                  Row(
                    children: [
                      // Category Dropdown
                      Expanded(
                        flex: 3,
                        child: DropdownButtonFormField<String>(
                          value: _selectedCategoryId,
                          decoration: InputDecoration(
                            labelText: AppStrings.category(lang),
                          ),
                          items: [
                            const DropdownMenuItem<String>(
                              value: null,
                              child: Text('General Grocery', style: TextStyle(fontSize: 14)),
                            ),
                            ...invState.categories.map((cat) {
                              return DropdownMenuItem<String>(
                                value: cat.id,
                                child: Text(
                                  lang == AppLanguage.hi && cat.nameHi != null ? cat.nameHi! : cat.nameEn,
                                  style: const TextStyle(fontSize: 14),
                                ),
                              );
                            }),
                          ],
                          onChanged: (val) => setState(() => _selectedCategoryId = val),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Unit Dropdown
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<String>(
                          value: _unit,
                          decoration: InputDecoration(
                            labelText: AppStrings.unit(lang),
                          ),
                          items: (_itemType == 'packed' ? _packedUnits : _looseUnits).map((u) {
                            return DropdownMenuItem<String>(
                              value: u,
                              child: Text(u, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                            );
                          }).toList(),
                          onChanged: (val) => setState(() => _unit = val ?? 'piece'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Pricing Row (Selling Price & MRP)
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _priceController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [DecimalInputFormatter(2)],
                          decoration: InputDecoration(
                            labelText: '${AppStrings.sellingPrice(lang)} *',
                            prefixText: '₹ ',
                            prefixStyle: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary),
                          ),
                          validator: (val) => Validators.price(val, isRequired: true, fieldName: AppStrings.sellingPrice(lang)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: _mrpController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [DecimalInputFormatter(2)],
                          decoration: InputDecoration(
                            labelText: AppStrings.mrp(lang),
                            prefixText: '₹ ',
                            prefixStyle: const TextStyle(color: AppColors.textSecondary),
                          ),
                          validator: (val) {
                            final err = Validators.price(val, isRequired: false, fieldName: AppStrings.mrp(lang));
                            if (err != null) return err;
                            if (val != null && val.trim().isNotEmpty && _priceController.text.trim().isNotEmpty) {
                              final sp = double.tryParse(_priceController.text.trim());
                              final mp = double.tryParse(val.trim());
                              if (sp != null && mp != null && mp < sp) {
                                return 'MRP cannot be less than selling price';
                              }
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // GST & HSN Row
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<double>(
                          value: _gstRate,
                          decoration: InputDecoration(
                            labelText: AppStrings.gstRate(lang),
                          ),
                          items: _gstRates.map((rate) {
                            return DropdownMenuItem<double>(
                              value: rate,
                              child: Text('${rate.toStringAsFixed(0)}% GST', style: const TextStyle(fontSize: 14)),
                            );
                          }).toList(),
                          onChanged: (val) => setState(() => _gstRate = val ?? 0.0),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: _hsnController,
                          keyboardType: TextInputType.number,
                          autofillHints: null,
                          maxLength: 8,
                          inputFormatters: [DigitsOnlyFormatter(8)],
                          decoration: InputDecoration(
                            labelText: AppStrings.hsnCode(lang),
                            hintText: 'e.g. 1101',
                            counterText: '',
                          ),
                          validator: Validators.hsnCode,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Stock Qty & Reorder Level
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _stockController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: _itemType == 'loose'
                              ? [DecimalInputFormatter(3)]
                              : [WholeNumberInputFormatter(99999)],
                          decoration: InputDecoration(
                            labelText: AppStrings.stockQuantity(lang),
                            suffixText: _unit,
                          ),
                          validator: (val) => _itemType == 'loose'
                              ? Validators.looseQuantity(val, isRequired: true, fieldName: AppStrings.stockQuantity(lang))
                              : Validators.packedQuantity(val, isRequired: true, fieldName: AppStrings.stockQuantity(lang)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: _reorderController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: _itemType == 'loose'
                              ? [DecimalInputFormatter(3)]
                              : [WholeNumberInputFormatter(99999)],
                          decoration: InputDecoration(
                            labelText: AppStrings.reorderLevel(lang),
                            suffixText: _unit,
                          ),
                          validator: (val) => _itemType == 'loose'
                              ? Validators.looseQuantity(val, isRequired: false, fieldName: AppStrings.reorderLevel(lang))
                              : Validators.packedQuantity(val, isRequired: false, fieldName: AppStrings.reorderLevel(lang)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Barcode Preview for Loose / Custom Products
                  if (_barcodeController.text.trim().isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.divider),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'Generated Barcode Label',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 48,
                            child: BarcodeWidget(
                              barcode: Barcode.code128(),
                              data: _barcodeController.text.trim(),
                              drawText: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Save Action Button
                  DebouncedButton(
                    onPressed: _saveProduct,
                    height: 52,
                    backgroundColor: AppColors.primary,
                    semanticLabel: 'Save product button',
                    child: Text(
                      AppStrings.save(lang),
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _typeTab({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? Colors.white : AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isSelected ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

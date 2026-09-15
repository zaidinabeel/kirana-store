import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/i18n/app_strings.dart';
import '../../../core/db/app_database.dart';
import '../../../shared/widgets/app_header.dart';
import '../state/inventory_notifier.dart';
import 'add_edit_product_screen.dart';
import 'widgets/barcode_scanner_modal.dart';

class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openBarcodeScanner() {
    showDialog(
      context: context,
      builder: (ctx) => BarcodeScannerModal(
        onBarcodeScanned: (code) {
          _searchController.text = code;
          ref.read(inventoryProvider.notifier).setSearchQuery(code);
        },
      ),
    );
  }

  void _showQuickStockDialog(Product product) {
    final qtyController = TextEditingController(text: '1');
    String reason = 'purchase';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Adjust Stock: ${product.nameEn}',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.primary),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                Text(
                  'Current Stock: ${product.stockQty} ${product.unit}',
                  style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: qtyController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: 'Quantity to Add / Remove',
                          suffixText: product.unit,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    DropdownButton<String>(
                      value: reason,
                      items: const [
                        DropdownMenuItem(value: 'purchase', child: Text('Purchase (+)')),
                        DropdownMenuItem(value: 'adjustment', child: Text('Count Adjust (+/-)')),
                        DropdownMenuItem(value: 'return', child: Text('Customer Return (+)')),
                      ],
                      onChanged: (val) {
                        if (val != null) setSheetState(() => reason = val);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.alert,
                          side: const BorderSide(color: AppColors.alert),
                        ),
                        onPressed: () {
                          final q = double.tryParse(qtyController.text) ?? 0.0;
                          ref.read(inventoryProvider.notifier).adjustStock(product.id, -q, reason);
                          Navigator.pop(ctx);
                        },
                        child: const Text('Deduct (-)', style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
                        onPressed: () {
                          final q = double.tryParse(qtyController.text) ?? 0.0;
                          ref.read(inventoryProvider.notifier).adjustStock(product.id, q, reason);
                          Navigator.pop(ctx);
                        },
                        child: const Text('Add (+)', style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(localeProvider);
    final invState = ref.watch(inventoryProvider);
    final products = invState.filteredProducts;

    return Scaffold(
      appBar: AppHeader(
        title: AppStrings.inventory(lang),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
            tooltip: 'Scan Barcode',
            onPressed: _openBarcodeScanner,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.accent,
        foregroundColor: AppColors.textPrimary,
        elevation: 2,
        icon: const Icon(Icons.add_rounded, size: 22),
        label: Text(
          AppStrings.addProduct(lang),
          style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.1),
        ),
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const AddEditProductScreen()),
          );
        },
      ),
      body: Column(
        children: [
          // Top Search Bar
          Container(
            color: AppColors.primary,
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 14),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 46,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (val) => ref.read(inventoryProvider.notifier).setSearchQuery(val),
                      decoration: InputDecoration(
                        hintText: AppStrings.searchProducts(lang),
                        hintStyle: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                        prefixIcon: const Icon(Icons.search, color: AppColors.primary, size: 20),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  ref.read(inventoryProvider.notifier).setSearchQuery('');
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Filter Chips (All, Low Stock, Packed, Loose)
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _filterChip(
                    label: AppStrings.allItems(lang),
                    isSelected: invState.filter == InventoryFilter.all,
                    onSelected: () => ref.read(inventoryProvider.notifier).setFilter(InventoryFilter.all),
                  ),
                  const SizedBox(width: 8),
                  _filterChip(
                    label: '${AppStrings.lowStockFilter(lang)} (${invState.lowStockCount})',
                    isSelected: invState.filter == InventoryFilter.lowStock,
                    badgeColor: AppColors.alert,
                    onSelected: () => ref.read(inventoryProvider.notifier).setFilter(InventoryFilter.lowStock),
                  ),
                  const SizedBox(width: 8),
                  _filterChip(
                    label: AppStrings.packedItems(lang),
                    isSelected: invState.filter == InventoryFilter.packed,
                    onSelected: () => ref.read(inventoryProvider.notifier).setFilter(InventoryFilter.packed),
                  ),
                  const SizedBox(width: 8),
                  _filterChip(
                    label: AppStrings.looseItems(lang),
                    isSelected: invState.filter == InventoryFilter.loose,
                    onSelected: () => ref.read(inventoryProvider.notifier).setFilter(InventoryFilter.loose),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),

          // Product List with Clean Dividers (No card soup)
          Expanded(
            child: invState.isLoading
                ? const Center(child: CircularProgressIndicator())
                : products.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.inventory_2_outlined, size: 54, color: AppColors.textMuted.withOpacity(0.5)),
                              const SizedBox(height: 12),
                              Text(
                                _searchController.text.isNotEmpty
                                    ? 'No items match "${_searchController.text}"'
                                    : 'No inventory items found. Tap "+ Add Product" to get started.',
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 15, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.separated(
                        itemCount: products.length,
                        separatorBuilder: (_, __) => const Divider(height: 1, indent: 16, endIndent: 16),
                        itemBuilder: (ctx, index) {
                          final item = products[index];
                          final p = item.product;
                          final isLowStock = p.stockQty <= p.reorderLevel;

                          final displayName = lang == AppLanguage.hi && p.nameHi != null && p.nameHi!.isNotEmpty
                              ? p.nameHi!
                              : p.nameEn;
                          final subName = lang == AppLanguage.hi ? p.nameEn : (p.nameHi ?? '');

                          return InkWell(
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => AddEditProductScreen(productToEdit: p),
                                ),
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  // Leading Item Icon / Barcode Indicator
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: isLowStock ? AppColors.alertLight : AppColors.surfaceMuted,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: isLowStock ? AppColors.alert.withOpacity(0.3) : AppColors.divider,
                                      ),
                                    ),
                                    child: Icon(
                                      p.itemType == 'loose' ? Icons.scale_outlined : Icons.qr_code_2_rounded,
                                      color: isLowStock ? AppColors.alert : AppColors.primary,
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(width: 12),

                                  // Product Info
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          displayName,
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                        if (subName.isNotEmpty) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            subName,
                                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                          ),
                                        ],
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            if (p.barcode != null) ...[
                                              Text(
                                                '#${p.barcode}',
                                                style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                                              ),
                                              const SizedBox(width: 8),
                                            ],
                                            if (p.gstRate > 0)
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                                decoration: BoxDecoration(
                                                  color: AppColors.surfaceMuted,
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  '${p.gstRate.toStringAsFixed(0)}% GST',
                                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Price & Stock Badge Column
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '₹${p.price.toStringAsFixed(1)}',
                                        style: const TextStyle(
                                          fontFamily: 'Manrope',
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      InkWell(
                                        onTap: () => _showQuickStockDialog(p),
                                        borderRadius: BorderRadius.circular(4),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: isLowStock ? AppColors.alertLight : AppColors.successLight,
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(
                                              color: isLowStock ? AppColors.alert : AppColors.success,
                                              width: 0.8,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                '${p.stockQty % 1 == 0 ? p.stockQty.toInt() : p.stockQty} ${p.unit}',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700,
                                                  color: isLowStock ? AppColors.alert : AppColors.success,
                                                ),
                                              ),
                                              const SizedBox(width: 3),
                                              Icon(
                                                Icons.edit,
                                                size: 11,
                                                color: isLowStock ? AppColors.alert : AppColors.success,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onSelected,
    Color? badgeColor,
  }) {
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontFamily: 'Manrope',
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
          color: isSelected ? Colors.white : AppColors.textPrimary,
        ),
      ),
      selected: isSelected,
      onSelected: (_) => onSelected(),
      selectedColor: AppColors.primary,
      backgroundColor: AppColors.surfaceMuted,
      side: BorderSide(
        color: isSelected ? AppColors.primary : AppColors.border,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    );
  }
}

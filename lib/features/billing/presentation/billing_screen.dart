import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' as drift;
import '../../../core/constants/app_colors.dart';
import '../../../core/i18n/app_strings.dart';
import '../../../core/money/money_utils.dart';
import '../../../core/db/app_database.dart';
import '../../../shared/widgets/app_header.dart';
import '../../../shared/widgets/discard_dialog.dart';
import '../../inventory/domain/product_model.dart';
import '../../inventory/presentation/widgets/barcode_scanner_modal.dart';
import '../domain/cart_item.dart';
import '../state/billing_notifier.dart';
import 'bill_preview_screen.dart';
import 'widgets/keypad_dialog.dart';
import 'widgets/payment_modal.dart';

class BillingScreen extends ConsumerStatefulWidget {
  const BillingScreen({super.key});

  @override
  ConsumerState<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends ConsumerState<BillingScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Product> _searchResults = [];
  List<Product> _quickLooseItems = [];
  bool _isSearching = false;
  DateTime? _lastBarcodeScanTime;
  String? _lastScannedBarcode;

  @override
  void initState() {
    super.initState();
    _loadQuickLooseItems();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadQuickLooseItems() async {
    final db = ref.read(databaseProvider);
    final loose = await (db.select(db.products)
      ..where((p) => p.itemType.equals('loose') & p.isActive.equals(true)))
      .get();
    if (mounted) {
      setState(() {
        _quickLooseItems = loose;
      });
    }
  }

  void _onSearchChanged(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    final db = ref.read(databaseProvider);
    final q = query.toLowerCase().trim();
    final allProds = await (db.select(db.products)..where((p) => p.isActive.equals(true))).get();

    final matches = allProds.where((p) {
      final mEn = p.nameEn.toLowerCase().contains(q);
      final mHi = p.nameHi != null && p.nameHi!.toLowerCase().contains(q);
      final mCode = p.barcode != null && p.barcode!.toLowerCase().contains(q);
      return mEn || mHi || mCode;
    }).toList();

    setState(() {
      _searchResults = matches;
      _isSearching = true;
    });
  }

  void _openBarcodeScanner() {
    showDialog(
      context: context,
      builder: (ctx) => BarcodeScannerModal(
        title: 'Scan Item to Add to Bill',
        onBarcodeScanned: (code) async {
          final now = DateTime.now();
          if (_lastScannedBarcode == code &&
              _lastBarcodeScanTime != null &&
              now.difference(_lastBarcodeScanTime!).inMilliseconds < 1500) {
            // Debounce rapid duplicate scan
            return;
          }
          _lastBarcodeScanTime = now;
          _lastScannedBarcode = code;

          final found = await ref.read(billingProvider.notifier).scanBarcode(code);
          if (!found && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Barcode "$code" not found in inventory'),
                backgroundColor: AppColors.alert,
                duration: const Duration(seconds: 2),
              ),
            );
          }
        },
      ),
    );
  }

  void _openKeypadDialog(CartItem item) {
    showDialog(
      context: context,
      builder: (ctx) => KeypadDialog(
        item: item,
        onQuantityConfirmed: (qty) {
          ref.read(billingProvider.notifier).updateQuantity(item.id, qty);
        },
        onRupeeAmountConfirmed: (rupeeAmount) {
          ref.read(billingProvider.notifier).updateLooseByRupeeAmount(item.id, rupeeAmount);
        },
      ),
    );
  }

  void _addLooseItemDirectly(Product product) {
    ref.read(billingProvider.notifier).addProduct(product);
    final cartItems = ref.read(billingProvider).items;
    final addedItem = cartItems.firstWhere((it) => it.productId == product.id);
    _openKeypadDialog(addedItem);
  }

  void _openLooseItemSearchModal() {
    final searchCtrl = TextEditingController();
    List<Product> filteredLoose = List.from(_quickLooseItems);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final isHi = ref.watch(localeProvider) == AppLanguage.hi;

            return Container(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              constraints: const BoxConstraints(maxHeight: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.scale_rounded, color: AppColors.primary, size: 24),
                          const SizedBox(width: 8),
                          Text(
                            isHi ? 'खुला सामान चुनें (वजन / रुपये)' : 'Select Loose Items (Weight / ₹)',
                            style: const TextStyle(
                              fontFamily: 'Manrope',
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Dedicated Loose Search Bar
                  Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceMuted,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: TextField(
                      controller: searchCtrl,
                      autofocus: true,
                      onChanged: (val) {
                        final q = val.toLowerCase().trim();
                        setSheetState(() {
                          filteredLoose = _quickLooseItems.where((p) {
                            final mEn = p.nameEn.toLowerCase().contains(q);
                            final mHi = p.nameHi != null && p.nameHi!.toLowerCase().contains(q);
                            return mEn || mHi;
                          }).toList();
                        });
                      },
                      decoration: InputDecoration(
                        hintText: isHi ? 'खुला सामान खोजें (उदा. चीनी, दाल, आलू)...' : 'Search loose items (e.g. Sugar, Dal, Potato)...',
                        hintStyle: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                        prefixIcon: const Icon(Icons.search, color: AppColors.primary, size: 20),
                        suffixIcon: searchCtrl.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  searchCtrl.clear();
                                  setSheetState(() {
                                    filteredLoose = List.from(_quickLooseItems);
                                  });
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Grid of Loose Items
                  Expanded(
                    child: filteredLoose.isEmpty
                        ? const Center(
                            child: Text(
                              'No matching loose items found.',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          )
                        : GridView.builder(
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              childAspectRatio: 2.2,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                            ),
                            itemCount: filteredLoose.length,
                            itemBuilder: (ctx, i) {
                              final p = filteredLoose[i];
                              final displayName = isHi && p.nameHi != null ? p.nameHi! : p.nameEn;

                              return InkWell(
                                onTap: () {
                                  Navigator.pop(ctx);
                                  _addLooseItemDirectly(p);
                                },
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AppColors.background,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: AppColors.border, width: 1.2),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: AppColors.primaryContainer,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Icon(Icons.scale_outlined, size: 18, color: AppColors.primary),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              displayName,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                                            ),
                                            Text(
                                              '₹${p.price}/${p.unit}',
                                              style: const TextStyle(
                                                fontFamily: 'Manrope',
                                                fontSize: 12,
                                                fontWeight: FontWeight.w800,
                                                color: AppColors.primary,
                                              ),
                                            ),
                                          ],
                                        ),
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
          },
        );
      },
    );
  }

  void _showPaymentModal() {
    final billingState = ref.read(billingProvider);
    if (billingState.items.isEmpty) return;

    final calc = billingState.calculation;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => PaymentModal(
        grandTotal: calc.total,
        onConfirmPayment: ({
          required String paymentMode,
          required Decimal amountPaid,
          required Decimal amountDue,
        }) async {
          Navigator.of(ctx).pop(); // Close modal
          final invoice = await ref.read(billingProvider.notifier).finalizeSale(
                paymentMode: paymentMode,
                amountPaid: amountPaid,
                amountDue: amountDue,
              );

          if (invoice != null && mounted) {
            // Navigate to thermal receipt preview
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => BillPreviewScreen(invoice: invoice),
              ),
            );
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(localeProvider);
    final billingState = ref.watch(billingProvider);
    final calc = billingState.calculation;
    final isHindi = lang == AppLanguage.hi;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (billingState.items.isNotEmpty) {
          final shouldDiscard = await showDiscardConfirmationDialog(
            context,
            title: isHindi ? 'सक्रिय बिल छोड़ें?' : 'Discard Active Cart?',
            content: isHindi
                ? 'कार्ट में सामान मौजूद है। बाहर निकलने पर यह बिल रद्द हो जाएगा।'
                : 'You have items in your active cart. Leaving will discard the current bill.',
            confirmText: isHindi ? 'बिल हटाएं' : 'Discard Bill',
            cancelText: isHindi ? 'जारी रखें' : 'Keep Billing',
            lang: lang,
          );
          if (shouldDiscard && context.mounted) {
            ref.read(billingProvider.notifier).clearCart();
            Navigator.of(context).pop();
          }
        } else {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppHeader(
          title: AppStrings.billing(lang),
          actions: [
            IconButton(
              icon: const Icon(Icons.scale_rounded, color: Colors.white),
              tooltip: 'Loose Items',
              onPressed: _openLooseItemSearchModal,
            ),
            IconButton(
              icon: const Icon(Icons.qr_code_scanner_rounded, color: Colors.white),
              tooltip: 'Scan Barcode',
              onPressed: _openBarcodeScanner,
            ),
            if (billingState.items.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.delete_sweep_outlined, color: Colors.white70),
                tooltip: 'Clear Cart',
                onPressed: () async {
                  final confirm = await showDiscardConfirmationDialog(
                    context,
                    title: isHindi ? 'कार्ट खाली करें?' : 'Clear Cart?',
                    content: isHindi
                        ? 'क्या आप कार्ट का सारा सामान हटाना चाहते हैं?'
                        : 'Are you sure you want to remove all items from the current cart?',
                    confirmText: isHindi ? 'खाली करें' : 'Clear All',
                    cancelText: isHindi ? 'रद्द करें' : 'Cancel',
                    lang: lang,
                  );
                  if (confirm && context.mounted) {
                    ref.read(billingProvider.notifier).clearCart();
                  }
                },
              ),
          ],
        ),
      body: Column(
        children: [
          // Top Bar: Universal Search & Scan Bar
          Container(
            color: AppColors.primary,
            padding: const EdgeInsets.only(left: 14, right: 14, bottom: 12),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: _onSearchChanged,
                      decoration: InputDecoration(
                        hintText: isHindi ? 'सामान, खुला सामान या बारकोड खोजें...' : 'Search packed / loose items, barcode...',
                        hintStyle: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                        prefixIcon: const Icon(Icons.search, color: AppColors.primary, size: 20),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  _onSearchChanged('');
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: _openBarcodeScanner,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    height: 44,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.camera_alt_rounded, color: AppColors.textPrimary, size: 18),
                        SizedBox(width: 4),
                        Text(
                          'Scan',
                          style: TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Search Dropdown Overlay if active
          if (_isSearching) ...[
            Container(
              constraints: const BoxConstraints(maxHeight: 240),
              color: Colors.white,
              child: ListView.separated(
                itemCount: _searchResults.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (ctx, i) {
                  final p = _searchResults[i];
                  final isLoose = p.itemType == 'loose';
                  final displayName = isHindi && p.nameHi != null ? p.nameHi! : p.nameEn;

                  return ListTile(
                    dense: true,
                    leading: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: isLoose ? AppColors.accentLight : AppColors.surfaceMuted,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        isLoose ? Icons.scale_outlined : Icons.inventory_2_outlined,
                        size: 18,
                        color: isLoose ? AppColors.accentHover : AppColors.primary,
                      ),
                    ),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            displayName,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isLoose ? AppColors.accentLight : AppColors.surfaceMuted,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            isLoose ? 'Loose (₹/kg)' : 'Packed',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: isLoose ? AppColors.accentHover : AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    subtitle: Text('₹${p.price}/${p.unit} • Stock: ${p.stockQty}'),
                    trailing: const Icon(Icons.add_circle, color: AppColors.primary, size: 28),
                    onTap: () {
                      _searchController.clear();
                      setState(() {
                        _searchResults = [];
                        _isSearching = false;
                      });
                      if (isLoose) {
                        _addLooseItemDirectly(p);
                      } else {
                        ref.read(billingProvider.notifier).addProduct(p);
                      }
                    },
                  );
                },
              ),
            ),
          ],

          // Quick Loose Items Tray (Horizontal Fast Select)
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                InkWell(
                  onTap: _openLooseItemSearchModal,
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.scale_rounded, color: AppColors.accent, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          isHindi ? 'खुला सामान' : 'Loose Items',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white),
                        ),
                        const SizedBox(width: 2),
                        const Icon(Icons.arrow_drop_down, color: Colors.white, size: 16),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _quickLooseItems.take(5).map((p) {
                        final displayName = isHindi && p.nameHi != null ? p.nameHi! : p.nameEn.split(' ').first;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ActionChip(
                            backgroundColor: AppColors.surfaceMuted,
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                            avatar: const Icon(Icons.scale_outlined, size: 14, color: AppColors.primary),
                            label: Text(
                              '$displayName (₹${p.price.toStringAsFixed(0)}/${p.unit})',
                              style: const TextStyle(
                                fontFamily: 'Manrope',
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            onPressed: () => _addLooseItemDirectly(p),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // GST / Non-GST Switch Bar
          Container(
            color: AppColors.surfaceMuted,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.receipt_long_outlined, size: 18, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Text(
                      billingState.isGstInvoice ? AppStrings.gstInvoice(lang) : AppStrings.nonGstBill(lang),
                      style: const TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    const Text('Non-GST', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                    Switch(
                      value: billingState.isGstInvoice,
                      activeColor: AppColors.primary,
                      activeTrackColor: AppColors.primaryContainer,
                      onChanged: (val) {
                        ref.read(billingProvider.notifier).toggleGst(val);
                      },
                    ),
                    const Text('GST', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Main Cart Items List (Clean Divider layout, no card soup)
          Expanded(
            child: billingState.items.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.shopping_cart_outlined, size: 64, color: AppColors.textMuted.withOpacity(0.4)),
                          const SizedBox(height: 12),
                          Text(
                            AppStrings.emptyCartTitle(lang),
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.primary),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            AppStrings.emptyCartSubtitle(lang),
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 16),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              side: const BorderSide(color: AppColors.primary, width: 1.5),
                            ),
                            onPressed: _openLooseItemSearchModal,
                            icon: const Icon(Icons.scale_rounded, size: 18),
                            label: Text(
                              isHindi ? 'खुला सामान चुनें' : 'Browse Loose Items',
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: billingState.items.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, indent: 14, endIndent: 14),
                    itemBuilder: (ctx, index) {
                      final item = billingState.items[index];

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Product info & rate
                            Expanded(
                              flex: 5,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      if (item.isLoose) ...[
                                        const Icon(Icons.scale_outlined, size: 14, color: AppColors.accentHover),
                                        const SizedBox(width: 4),
                                      ],
                                      Expanded(
                                        child: Text(
                                          item.displayName(isHindi),
                                          style: const TextStyle(
                                            fontFamily: 'Manrope',
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '₹${item.rate} / ${item.unit} ${item.gstRate > Decimal.zero && billingState.isGstInvoice ? "(${item.gstRate}% GST)" : ""}',
                                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                            ),

                            // Quantity Stepper with direct tap keypad trigger
                            Container(
                              decoration: BoxDecoration(
                                color: AppColors.surfaceMuted,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.divider),
                              ),
                              child: Row(
                                children: [
                                  _stepperBtn(
                                    icon: Icons.remove,
                                    onTap: () {
                                      final newQty = item.qty - Decimal.one;
                                      ref.read(billingProvider.notifier).updateQuantity(item.id, newQty);
                                    },
                                  ),
                                  InkWell(
                                    onTap: () => _openKeypadDialog(item),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      child: Text(
                                        item.qty.toString(),
                                        style: const TextStyle(
                                          fontFamily: 'Manrope',
                                          fontSize: 15,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ),
                                  ),
                                  _stepperBtn(
                                    icon: Icons.add,
                                    onTap: () {
                                      final newQty = item.qty + Decimal.one;
                                      ref.read(billingProvider.notifier).updateQuantity(item.id, newQty);
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 14),

                            // Line Total
                            SizedBox(
                              width: 70,
                              child: Text(
                                '₹${item.lineTotal.toStringAsFixed(1)}',
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                  fontFamily: 'Manrope',
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),

          // Bottom Hero Checkout Bar (Thumb Zone)
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  offset: const Offset(0, -3),
                  blurRadius: 10,
                ),
              ],
              border: const Border(top: BorderSide(color: AppColors.divider)),
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Breakdown row if GST active
                  if (billingState.isGstInvoice) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Subtotal: ₹${calc.subtotal.toStringAsFixed(1)}', style: const TextStyle(fontSize: 12)),
                        Text('GST Tax: ₹${calc.totalTax.toStringAsFixed(1)}', style: const TextStyle(fontSize: 12)),
                        if (calc.roundOff != Decimal.zero)
                          Text('Round Off: ₹${calc.roundOff.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 6),
                  ],

                  // Hero Grand Total & Finalize Button
                  Row(
                    children: [
                      // Total Display Hero
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${AppStrings.grandTotal(lang)} (${billingState.totalItemCount} items)',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          Text(
                            MoneyUtils.formatCurrency(calc.total),
                            style: const TextStyle(
                              fontFamily: 'Manrope',
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              color: AppColors.primary,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 16),

                      // Finalize Sale Button
                      Expanded(
                        child: SizedBox(
                          height: 52,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: billingState.items.isNotEmpty ? AppColors.accent : AppColors.surfaceMuted,
                              foregroundColor: billingState.items.isNotEmpty ? AppColors.textPrimary : AppColors.textMuted,
                              elevation: billingState.items.isNotEmpty ? 2 : 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: billingState.items.isNotEmpty ? _showPaymentModal : null,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  AppStrings.finalizeSale(lang),
                                  style: const TextStyle(
                                    fontFamily: 'Manrope',
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Icon(Icons.arrow_forward_rounded, size: 20),
                              ],
                            ),
                          ),
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
    ),
  );
  }

  Widget _stepperBtn({required IconData icon, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 38,
        height: 38,
        alignment: Alignment.center,
        child: Icon(icon, size: 18, color: AppColors.primary),
      ),
    );
  }
}

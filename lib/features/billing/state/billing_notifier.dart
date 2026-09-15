import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';
import '../../../core/db/app_database.dart';
import '../../../core/money/money_utils.dart';
import '../../inventory/domain/product_model.dart';
import '../domain/cart_item.dart';

class PaymentSplit {
  final Decimal cash;
  final Decimal upi;
  final Decimal card;
  final Decimal credit;

  PaymentSplit({
    Decimal? cash,
    Decimal? upi,
    Decimal? card,
    Decimal? credit,
  })  : cash = cash ?? Decimal.zero,
        upi = upi ?? Decimal.zero,
        card = card ?? Decimal.zero,
        credit = credit ?? Decimal.zero;

  Decimal get totalPaid => cash + upi + card;
  Decimal get totalAllocated => cash + upi + card + credit;

  PaymentSplit copyWith({
    Decimal? cash,
    Decimal? upi,
    Decimal? card,
    Decimal? credit,
  }) {
    return PaymentSplit(
      cash: cash ?? this.cash,
      upi: upi ?? this.upi,
      card: card ?? this.card,
      credit: credit ?? this.credit,
    );
  }
}

class BillingState {
  final List<CartItem> items;
  final bool isGstInvoice;
  final Customer? selectedCustomer;
  final Decimal overallDiscount;
  final PaymentSplit paymentSplit;
  final String primaryPaymentMode; // 'cash'|'upi'|'card'|'credit'|'split'
  final bool isFinalizing;
  final String? errorMessage;

  BillingState({
    this.items = const [],
    this.isGstInvoice = false,
    this.selectedCustomer,
    Decimal? overallDiscount,
    PaymentSplit? paymentSplit,
    this.primaryPaymentMode = 'cash',
    this.isFinalizing = false,
    this.errorMessage,
  })  : overallDiscount = overallDiscount ?? Decimal.zero,
        paymentSplit = paymentSplit ?? PaymentSplit();

  InvoiceCalculationResult get calculation {
    final lineInputs = items.map((item) {
      return LineItemInput(
        rate: item.rate,
        qty: item.qty,
        gstRate: item.gstRate,
        discount: item.discount,
      );
    }).toList();

    return MoneyUtils.calculateInvoice(
      items: lineInputs,
      isGstInvoice: isGstInvoice,
      overallDiscount: overallDiscount,
    );
  }

  int get totalItemCount => items.fold(0, (sum, it) => sum + (it.qty > Decimal.zero ? 1 : 0));

  BillingState copyWith({
    List<CartItem>? items,
    bool? isGstInvoice,
    Customer? selectedCustomer,
    bool clearCustomer = false,
    Decimal? overallDiscount,
    PaymentSplit? paymentSplit,
    String? primaryPaymentMode,
    bool? isFinalizing,
    String? errorMessage,
  }) {
    return BillingState(
      items: items ?? this.items,
      isGstInvoice: isGstInvoice ?? this.isGstInvoice,
      selectedCustomer: clearCustomer ? null : (selectedCustomer ?? this.selectedCustomer),
      overallDiscount: overallDiscount ?? this.overallDiscount,
      paymentSplit: paymentSplit ?? this.paymentSplit,
      primaryPaymentMode: primaryPaymentMode ?? this.primaryPaymentMode,
      isFinalizing: isFinalizing ?? this.isFinalizing,
      errorMessage: errorMessage,
    );
  }
}

final billingProvider = StateNotifierProvider<BillingNotifier, BillingState>((ref) {
  final db = ref.watch(databaseProvider);
  return BillingNotifier(db);
});

class BillingNotifier extends StateNotifier<BillingState> {
  final AppDatabase db;

  BillingNotifier(this.db) : super(BillingState());

  void toggleGst(bool isGst) {
    state = state.copyWith(isGstInvoice: isGst);
  }

  void selectCustomer(Customer? customer) {
    if (customer == null) {
      state = state.copyWith(clearCustomer: true);
    } else {
      state = state.copyWith(selectedCustomer: customer);
    }
  }

  void setOverallDiscount(Decimal discount) {
    state = state.copyWith(overallDiscount: discount);
  }

  void setPaymentMode(String mode) {
    state = state.copyWith(primaryPaymentMode: mode);
  }

  void setPaymentSplit(PaymentSplit split) {
    state = state.copyWith(paymentSplit: split);
  }

  /// Add product to cart. If already present, increment quantity by 1.
  void addProduct(Product product, {Decimal? customQty}) {
    final existingIndex = state.items.indexWhere((it) => it.productId == product.id);
    final List<CartItem> updated = List.from(state.items);

    if (existingIndex >= 0) {
      final existing = updated[existingIndex];
      final addedQty = customQty ?? Decimal.one;
      updated[existingIndex] = existing.copyWith(qty: existing.qty + addedQty);
    } else {
      updated.add(CartItem.fromProduct(product, initialQty: customQty));
    }

    state = state.copyWith(items: updated);
  }

  /// Scan barcode: look up local DB, add item or return false if not found
  Future<bool> scanBarcode(String barcode) async {
    final clean = barcode.trim();
    if (clean.isEmpty) return false;

    final product = await (db.select(db.products)
      ..where((p) => p.barcode.equals(clean) & p.isActive.equals(true)))
      .getSingleOrNull();

    if (product != null) {
      addProduct(product);
      return true;
    }
    return false;
  }

  /// Update item quantity directly. If <= 0, remove the item.
  void updateQuantity(String itemId, Decimal newQty) {
    final List<CartItem> updated = [];
    for (final item in state.items) {
      if (item.id == itemId) {
        if (newQty > Decimal.zero) {
          updated.add(item.copyWith(qty: newQty));
        }
        // Else dropped (removed from cart)
      } else {
        updated.add(item);
      }
    }
    state = state.copyWith(items: updated);
  }

  /// Reverse quantity calculation for loose goods:
  /// e.g. Customer says "₹50 of sugar" -> qty = 50 / rate
  void updateLooseByRupeeAmount(String itemId, Decimal rupeeAmount) {
    final List<CartItem> updated = state.items.map((item) {
      if (item.id == itemId) {
        final derivedQty = MoneyUtils.calculateReverseQuantity(
          targetRupeeAmount: rupeeAmount,
          pricePerUnit: item.rate,
        );
        return item.copyWith(qty: derivedQty);
      }
      return item;
    }).toList();

    state = state.copyWith(items: updated);
  }

  void clearCart() {
    state = BillingState(isGstInvoice: state.isGstInvoice);
  }

  /// Atomic transaction to finalize the sale
  Future<Invoice?> finalizeSale({
    required String paymentMode, // 'cash'|'upi'|'card'|'credit'|'split'
    required Decimal amountPaid,
    required Decimal amountDue,
  }) async {
    if (state.items.isEmpty) {
      state = state.copyWith(errorMessage: 'Cart is empty');
      return null;
    }

    // Require customer for credit sale
    if ((paymentMode == 'credit' || amountDue > Decimal.zero) && state.selectedCustomer == null) {
      state = state.copyWith(errorMessage: 'Please select a customer for credit (Udhaar) sales');
      return null;
    }

    state = state.copyWith(isFinalizing: true, errorMessage: null);

    try {
      final calc = state.calculation;
      final cartLines = state.items.map((it) {
        return CartLineData(
          productId: it.productId,
          nameSnapshot: it.nameSnapshotEn,
          hsnSnapshot: it.hsnSnapshot,
          qty: it.qty,
          unit: it.unit,
          rate: it.rate,
          gstRate: it.gstRate,
          discount: it.discount,
          lineTotal: it.lineTotal,
        );
      }).toList();

      final invoice = await db.finalizeSaleTransaction(
        invoiceType: state.isGstInvoice ? 'gst' : 'non_gst',
        customerId: state.selectedCustomer?.id,
        cartItems: cartLines,
        subtotal: calc.subtotal,
        discount: calc.discount,
        cgst: calc.cgst,
        sgst: calc.sgst,
        igst: calc.igst,
        roundOff: calc.roundOff,
        total: calc.total,
        paymentMode: paymentMode,
        amountPaid: amountPaid,
        amountDue: amountDue,
      );

      // Reset cart
      clearCart();
      return invoice;
    } catch (e) {
      state = state.copyWith(isFinalizing: false, errorMessage: 'Finalize sale failed: $e');
      return null;
    }
  }
}

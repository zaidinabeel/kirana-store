import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'tables.dart';
import 'connection/connection.dart' as conn;
import '../money/money_utils.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [
  Categories,
  Products,
  Customers,
  Invoices,
  InvoiceItems,
  StockLedger,
  Payments,
  Suppliers,
  Purchases,
  PurchaseItems,
  Settings,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? e]) : super(e ?? conn.openConnection());

  @override
  int get schemaVersion => 1;

  static AppDatabase inMemory() {
    return AppDatabase(conn.openInMemory());
  }

  // --- Financial Year Utility ---
  static String getCurrentFinancialYear([DateTime? date]) {
    final now = date ?? DateTime.now();
    final year = now.year;
    // FY runs from April 1 to March 31
    if (now.month >= 4) {
      final nextYear = (year + 1) % 100;
      return '$year-${nextYear.toString().padLeft(2, '0')}';
    } else {
      final currentYearShort = year % 100;
      final prevYear = year - 1;
      return '$prevYear-${currentYearShort.toString().padLeft(2, '0')}';
    }
  }

  // --- Invoice Number Generator ---
  Future<int> getNextInvoiceNumber(String financialYear, String invoiceType) async {
    final query = selectOnly(invoices)
      ..addColumns([invoices.invoiceNo.max()])
      ..where(invoices.financialYear.equals(financialYear) &
              invoices.invoiceType.equals(invoiceType));
    final result = await query.getSingle();
    final maxNo = result.read(invoices.invoiceNo.max());
    return (maxNo ?? 0) + 1;
  }

  // --- Finalize Sale Atomic Transaction ---
  Future<Invoice> finalizeSaleTransaction({
    required String invoiceType, // 'gst' | 'non_gst'
    required String? customerId,
    required List<CartLineData> cartItems,
    required Decimal subtotal,
    required Decimal discount,
    required Decimal cgst,
    required Decimal sgst,
    required Decimal igst,
    required Decimal roundOff,
    required Decimal total,
    required String paymentMode, // 'cash'|'upi'|'card'|'credit'|'split'
    required Decimal amountPaid,
    required Decimal amountDue,
  }) async {
    return transaction(() async {
      final fy = getCurrentFinancialYear();
      final nextInvoiceNo = await getNextInvoiceNumber(fy, invoiceType);
      final invoiceId = const Uuid().v4();
      final nowMs = DateTime.now().millisecondsSinceEpoch;

      // 1. Insert Invoice
      final invoiceCompanion = InvoicesCompanion.insert(
        id: invoiceId,
        invoiceNo: nextInvoiceNo,
        financialYear: fy,
        invoiceType: invoiceType,
        customerId: Value(customerId),
        subtotal: subtotal.toDouble(),
        discount: Value(discount.toDouble()),
        cgst: Value(cgst.toDouble()),
        sgst: Value(sgst.toDouble()),
        igst: Value(igst.toDouble()),
        roundOff: Value(roundOff.toDouble()),
        total: total.toDouble(),
        paymentMode: paymentMode,
        amountPaid: amountPaid.toDouble(),
        amountDue: Value(amountDue.toDouble()),
        status: const Value('active'),
        createdAt: nowMs,
      );

      await into(invoices).insert(invoiceCompanion);

      // 2. Insert Invoice Items (Frozen Snapshot) & Update Stock
      for (final item in cartItems) {
        final itemId = const Uuid().v4();
        await into(invoiceItems).insert(
          InvoiceItemsCompanion.insert(
            id: itemId,
            invoiceId: invoiceId,
            productId: Value(item.productId),
            nameSnapshot: item.nameSnapshot,
            hsnSnapshot: Value(item.hsnSnapshot),
            qty: item.qty.toDouble(),
            unit: item.unit,
            rate: item.rate.toDouble(),
            gstRateSnapshot: Value(item.gstRate.toDouble()),
            discount: Value(item.discount.toDouble()),
            lineTotal: item.lineTotal.toDouble(),
          ),
        );

        // Deduct product stock if product exists in catalog
        if (item.productId != null) {
          final product = await (select(products)..where((p) => p.id.equals(item.productId!))).getSingleOrNull();
          if (product != null) {
            final newStock = product.stockQty - item.qty.toDouble();
            
            // Insert Stock Ledger Entry
            await into(stockLedger).insert(
              StockLedgerCompanion.insert(
                id: const Uuid().v4(),
                productId: product.id,
                changeQty: -item.qty.toDouble(),
                reason: 'sale',
                refId: Value(invoiceId),
                balanceAfter: newStock,
                createdAt: nowMs,
              ),
            );

            // Update Product stock
            await (update(products)..where((p) => p.id.equals(product.id))).write(
              ProductsCompanion(
                stockQty: Value(newStock),
                updatedAt: Value(nowMs),
              ),
            );
          }
        }
      }

      // Fetch newly created invoice object
      return await (select(invoices)..where((i) => i.id.equals(invoiceId))).getSingle();
    });
  }

  // --- Void Invoice Atomic Transaction ---
  Future<void> voidInvoiceTransaction(String invoiceId) async {
    await transaction(() async {
      final invoice = await (select(invoices)..where((i) => i.id.equals(invoiceId))).getSingleOrNull();
      if (invoice == null || invoice.status == 'void') return;

      final nowMs = DateTime.now().millisecondsSinceEpoch;

      // 1. Mark Invoice as void
      await (update(invoices)..where((i) => i.id.equals(invoiceId))).write(
        const InvoicesCompanion(status: Value('void')),
      );

      // 2. Fetch items and restore stock
      final items = await (select(invoiceItems)..where((it) => it.invoiceId.equals(invoiceId))).get();
      for (final item in items) {
        if (item.productId != null) {
          final product = await (select(products)..where((p) => p.id.equals(item.productId!))).getSingleOrNull();
          if (product != null) {
            final restoredStock = product.stockQty + item.qty;

            // Audit in stock ledger
            await into(stockLedger).insert(
              StockLedgerCompanion.insert(
                id: const Uuid().v4(),
                productId: product.id,
                changeQty: item.qty,
                reason: 'void',
                refId: Value(invoiceId),
                balanceAfter: restoredStock,
                createdAt: nowMs,
              ),
            );

            // Restore product table stock
            await (update(products)..where((p) => p.id.equals(product.id))).write(
              ProductsCompanion(
                stockQty: Value(restoredStock),
                updatedAt: Value(nowMs),
              ),
            );
          }
        }
      }
    });
  }

  // --- Customer Ledger Running Balance ---
  Future<Decimal> getCustomerBalance(String customerId) async {
    final customer = await (select(customers)..where((c) => c.id.equals(customerId))).getSingleOrNull();
    if (customer == null) return Decimal.zero;

    Decimal balance = MoneyUtils.parse(customer.openingBalance);

    // Sum all active credit invoice amount_dues
    final creditInvoices = await (select(invoices)
      ..where((i) => i.customerId.equals(customerId) & i.status.equals('active')))
      .get();

    for (final inv in creditInvoices) {
      balance += MoneyUtils.parse(inv.amountDue);
    }

    // Subtract all payment collections
    final customerPayments = await (select(payments)..where((p) => p.customerId.equals(customerId))).get();
    for (final pay in customerPayments) {
      if (pay.type == 'collection') {
        balance -= MoneyUtils.parse(pay.amount);
      } else if (pay.type == 'refund') {
        balance += MoneyUtils.parse(pay.amount);
      }
    }

    return balance;
  }

  // --- Collect Customer Payment Atomic Transaction ---
  Future<Payment> recordCustomerPayment({
    required String customerId,
    required Decimal amount,
    required String mode, // 'cash' | 'upi'
    String? note,
    String? invoiceId,
  }) async {
    return transaction(() async {
      final paymentId = const Uuid().v4();
      final nowMs = DateTime.now().millisecondsSinceEpoch;

      final companion = PaymentsCompanion.insert(
        id: paymentId,
        customerId: customerId,
        invoiceId: Value(invoiceId),
        amount: amount.toDouble(),
        mode: mode,
        type: 'collection',
        note: Value(note),
        createdAt: nowMs,
      );

      await into(payments).insert(companion);
      return await (select(payments)..where((p) => p.id.equals(paymentId))).getSingle();
    });
  }

  // --- Record Direct Customer Debit (Give Credit / Udhaar) ---
  Future<Invoice> recordCustomerDebit({
    required String customerId,
    required Decimal amount,
    required String note,
    DateTime? date,
  }) async {
    return transaction(() async {
      final invoiceId = const Uuid().v4();
      final now = date ?? DateTime.now();
      final nowMs = now.millisecondsSinceEpoch;
      final fy = getCurrentFinancialYear(now);
      final invoiceNo = await getNextInvoiceNumber(fy, 'non_gst');

      final invoiceCompanion = InvoicesCompanion.insert(
        id: invoiceId,
        invoiceNo: invoiceNo,
        financialYear: fy,
        invoiceType: 'non_gst',
        customerId: Value(customerId),
        subtotal: amount.toDouble(),
        discount: const Value(0.0),
        cgst: const Value(0.0),
        sgst: const Value(0.0),
        igst: const Value(0.0),
        roundOff: const Value(0.0),
        total: amount.toDouble(),
        paymentMode: 'credit',
        amountPaid: 0.0,
        amountDue: Value(amount.toDouble()),
        status: const Value('active'),
        createdAt: nowMs,
      );

      await into(invoices).insert(invoiceCompanion);

      // Insert snapshot item with description/note
      final itemId = const Uuid().v4();
      await into(invoiceItems).insert(
        InvoiceItemsCompanion.insert(
          id: itemId,
          invoiceId: invoiceId,
          nameSnapshot: note.trim().isNotEmpty ? note.trim() : 'Khata Debit / Udhaar',
          qty: 1.0,
          unit: 'entry',
          rate: amount.toDouble(),
          lineTotal: amount.toDouble(),
        ),
      );

      return await (select(invoices)..where((i) => i.id.equals(invoiceId))).getSingle();
    });
  }
}

class CartLineData {
  final String? productId;
  final String nameSnapshot;
  final String? hsnSnapshot;
  final Decimal qty;
  final String unit;
  final Decimal rate;
  final Decimal gstRate;
  final Decimal discount;
  final Decimal lineTotal;

  CartLineData({
    this.productId,
    required this.nameSnapshot,
    this.hsnSnapshot,
    required this.qty,
    required this.unit,
    required this.rate,
    required this.gstRate,
    Decimal? discount,
    required this.lineTotal,
  }) : discount = discount ?? Decimal.zero;
}

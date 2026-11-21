import 'dart:io';

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kirana_store/core/db/app_database.dart';
import 'package:kirana_store/core/security/pin_lock.dart';
import 'package:kirana_store/features/reports/report_service.dart';
import 'package:path/path.dart' as p;

Decimal d(num v) => Decimal.parse(v.toString());

Future<void> _product(AppDatabase db, String id, String name, double price, {double? cost}) {
  final now = DateTime.now().millisecondsSinceEpoch;
  return db.into(db.products).insert(ProductsCompanion.insert(
        id: id,
        nameEn: name,
        itemType: 'packed',
        unit: 'piece',
        price: price,
        costPrice: Value(cost),
        stockQty: const Value(100),
        createdAt: now,
        updatedAt: now,
      ));
}

CartLineData _line(String id, String name, num qty, num rate) => CartLineData(
      productId: id,
      nameSnapshot: name,
      qty: d(qty),
      unit: 'piece',
      rate: d(rate),
      gstRate: Decimal.zero,
      discount: Decimal.zero,
      lineTotal: d(qty * rate),
    );

Future<Invoice> _sale(AppDatabase db, List<CartLineData> lines, String mode, {num discount = 0, String? customer}) {
  final subtotal = lines.fold<Decimal>(Decimal.zero, (s, l) => s + l.lineTotal);
  final total = subtotal - d(discount);
  final credit = mode == 'credit';
  return db.finalizeSaleTransaction(
    invoiceType: 'non_gst',
    customerId: customer,
    cartItems: lines,
    subtotal: subtotal,
    discount: d(discount),
    cgst: Decimal.zero,
    sgst: Decimal.zero,
    igst: Decimal.zero,
    roundOff: Decimal.zero,
    total: total,
    paymentMode: mode,
    amountPaid: credit ? Decimal.zero : total,
    amountDue: credit ? total : Decimal.zero,
  );
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  group('Reports', () {
    late AppDatabase db;
    setUp(() async {
      db = AppDatabase.inMemory();
      await _product(db, 'maggi', 'Maggi', 14, cost: 11);
      await _product(db, 'soap', 'Lux Soap', 40); // no purchase price saved
      await db.into(db.customers).insert(CustomersCompanion.insert(id: 'c1', name: 'Ramesh', createdAt: 0));
    });
    tearDown(() => db.close());

    DateRange today() => rangeFor(ReportPeriod.today, DateTime.now());

    test('sales, bills, payment split, profit and best sellers', () async {
      await _sale(db, [_line('maggi', 'Maggi', 10, 14)], 'cash'); // 140, profit 30
      await _sale(db, [_line('soap', 'Lux Soap', 2, 40)], 'upi'); // 80, cost unknown
      await _sale(db, [_line('maggi', 'Maggi', 5, 14)], 'credit', customer: 'c1'); // 70 udhaar, profit 15

      final r = await ReportService.build(db, today());
      expect(r.totalSales, 290);
      expect(r.billCount, 3);
      expect(r.byPaymentMode, {'cash': 140, 'upi': 80, 'credit': 70});
      expect(r.udhaarGiven, 70);
      expect(r.grossProfit, closeTo(45, 0.001));
      expect(r.salesWithoutCost, 80);
      expect(r.profitIsPartial, isTrue);
      expect(r.topItems.first.name, 'Maggi');
      expect(r.topItems.first.qty, 15);
      expect(r.topItems.first.revenue, 210);
    });

    test('bill discount reduces profit proportionally', () async {
      await _sale(db, [_line('maggi', 'Maggi', 10, 14)], 'cash', discount: 14); // pays 126 for cost 110
      final r = await ReportService.build(db, today());
      expect(r.totalSales, 126);
      expect(r.grossProfit, closeTo(16, 0.001));
    });

    test('voided bills are ignored', () async {
      final inv = await _sale(db, [_line('maggi', 'Maggi', 3, 14)], 'cash');
      await db.voidInvoiceTransaction(inv.id);
      final r = await ReportService.build(db, today());
      expect(r.totalSales, 0);
      expect(r.billCount, 0);
    });

    test('khata "you gave" entries count as udhaar, not as sales', () async {
      await db.recordCustomerDebit(customerId: 'c1', amount: d(500), note: 'old dues');
      await db.recordCustomerPayment(customerId: 'c1', amount: d(200), mode: 'cash');
      final r = await ReportService.build(db, today());
      expect(r.totalSales, 0);
      expect(r.billCount, 0);
      expect(r.topItems, isEmpty);
      expect(r.udhaarGiven, 500);
      expect(r.udhaarCollected, 200);
    });

    test('expenses reduce net profit and are grouped by category', () async {
      await _sale(db, [_line('maggi', 'Maggi', 10, 14)], 'cash'); // profit 30
      final now = DateTime.now().millisecondsSinceEpoch;
      for (final e in [('rent', 20.0), ('tea', 5.0), ('tea', 5.0)]) {
        await db.into(db.expenses).insert(ExpensesCompanion.insert(
              id: '${e.$1}${e.$2}$now${db.hashCode}${DateTime.now().microsecond}',
              category: e.$1,
              amount: e.$2,
              spentAt: now,
              createdAt: now,
            ));
      }
      final r = await ReportService.build(db, today());
      expect(r.expenses, 30);
      expect(r.expensesByCategory, {'rent': 20, 'tea': 10});
      expect(r.netProfit, closeTo(0, 0.001));
    });

    test('periods cover the right days', () {
      final now = DateTime(2026, 11, 21, 15); // a Saturday
      expect(rangeFor(ReportPeriod.today, now).start, DateTime(2026, 11, 21));
      expect(rangeFor(ReportPeriod.yesterday, now).start, DateTime(2026, 11, 20));
      expect(rangeFor(ReportPeriod.thisWeek, now).start, DateTime(2026, 11, 16)); // Monday
      expect(rangeFor(ReportPeriod.thisMonth, now).start, DateTime(2026, 11, 1));
      final last = rangeFor(ReportPeriod.lastMonth, now);
      expect(last.start, DateTime(2026, 10, 1));
      expect(last.end, DateTime(2026, 11, 1));
      // January's "last month" is December of the previous year.
      expect(rangeFor(ReportPeriod.lastMonth, DateTime(2027, 1, 5)).start, DateTime(2026, 12, 1));
    });
  });

  test('upgrading an existing v1 database keeps the shop data', () async {
    final tmp = await Directory.systemTemp.createTemp('kirana_migration');
    addTearDown(() => tmp.delete(recursive: true));
    final file = File(p.join(tmp.path, 'kirana_store.sqlite'));

    // Build a database, then turn it back into the old v1 layout.
    final v2 = AppDatabase(NativeDatabase(file));
    await _product(v2, 'atta', 'Aashirvaad Atta', 245);
    await v2.customStatement('ALTER TABLE products DROP COLUMN cost_price');
    await v2.customStatement('ALTER TABLE invoice_items DROP COLUMN cost_snapshot');
    await v2.customStatement('DROP TABLE expenses');
    await v2.customStatement('PRAGMA user_version = 1');
    await v2.close();

    // Opening it with the new app runs the upgrade.
    final upgraded = AppDatabase(NativeDatabase(file));
    final products = await upgraded.select(upgraded.products).get();
    expect(products.single.nameEn, 'Aashirvaad Atta');
    expect(products.single.costPrice, isNull);
    await upgraded.into(upgraded.expenses).insert(
        ExpensesCompanion.insert(id: 'e1', category: 'rent', amount: 1000, spentAt: 0, createdAt: 0));
    expect((await upgraded.select(upgraded.expenses).get()).length, 1);
    await upgraded.close();
  });

  group('PIN lock', () {
    late Directory tmp;
    late PinLockStore store;
    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('kirana_pin');
      store = PinLockStore(() async => tmp);
    });
    tearDown(() => tmp.delete(recursive: true));

    test('off by default; set, verify, clear', () async {
      expect(await store.isEnabled(), isFalse);
      await store.setPin('4821');
      expect(await store.isEnabled(), isTrue);
      expect(await store.verify('4821'), isTrue);
      expect(await store.verify('1234'), isFalse);
      await store.clear();
      expect(await store.isEnabled(), isFalse);
    });

    test('the PIN is never stored as plain text', () async {
      await store.setPin('4821');
      final saved = File(p.join(tmp.path, PinLockStore.fileName)).readAsStringSync();
      expect(saved.contains('4821'), isFalse);
    });

    test('only 4 digits are accepted', () async {
      expect(PinLockStore.isValidPin('12a4'), isFalse);
      expect(PinLockStore.isValidPin('12345'), isFalse);
      expect(() => store.setPin('12'), throwsArgumentError);
    });
  });
}

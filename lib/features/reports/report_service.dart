import 'package:drift/drift.dart';

import '../../core/db/app_database.dart';

/// Unit used for khata "you gave ₹X" entries (see AppDatabase.recordCustomerDebit).
const manualKhataEntryUnit = 'entry';

/// Time windows offered on the reports screen.
enum ReportPeriod { today, yesterday, thisWeek, thisMonth, lastMonth }

class DateRange {
  final DateTime start; // inclusive
  final DateTime end; // exclusive
  const DateRange(this.start, this.end);

  int get days => end.difference(start).inDays.clamp(1, 366);
}

DateRange rangeFor(ReportPeriod period, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  switch (period) {
    case ReportPeriod.today:
      return DateRange(today, today.add(const Duration(days: 1)));
    case ReportPeriod.yesterday:
      return DateRange(today.subtract(const Duration(days: 1)), today);
    case ReportPeriod.thisWeek:
      final monday = today.subtract(Duration(days: today.weekday - 1));
      return DateRange(monday, today.add(const Duration(days: 1)));
    case ReportPeriod.thisMonth:
      return DateRange(DateTime(now.year, now.month, 1), today.add(const Duration(days: 1)));
    case ReportPeriod.lastMonth:
      return DateRange(DateTime(now.year, now.month - 1, 1), DateTime(now.year, now.month, 1));
  }
}

class ItemSales {
  final String name;
  final String unit;
  double qty;
  double revenue;
  ItemSales(this.name, this.unit, this.qty, this.revenue);
}

class ReportData {
  final DateRange range;
  final double totalSales;
  final int billCount;

  /// Amount by payment mode: cash, upi, card, credit (udhaar), split.
  final Map<String, double> byPaymentMode;

  /// Udhaar given in bills during the period.
  final double udhaarGiven;

  /// Udhaar paid back by customers during the period.
  final double udhaarCollected;

  /// Profit on items whose purchase price is known.
  final double grossProfit;

  /// Sales (after discount, before tax) of items with no purchase price saved.
  final double salesWithoutCost;
  final double expenses;
  final Map<String, double> expensesByCategory;
  final List<ItemSales> topItems;

  /// Sales per day, oldest first (one entry per day in the range).
  final List<MapEntry<DateTime, double>> daily;

  const ReportData({
    required this.range,
    required this.totalSales,
    required this.billCount,
    required this.byPaymentMode,
    required this.udhaarGiven,
    required this.udhaarCollected,
    required this.grossProfit,
    required this.salesWithoutCost,
    required this.expenses,
    required this.expensesByCategory,
    required this.topItems,
    required this.daily,
  });

  double get averageBill => billCount == 0 ? 0 : totalSales / billCount;
  double get netProfit => grossProfit - expenses;
  bool get profitIsPartial => salesWithoutCost > 0.009;
}

/// Builds reports straight from the on-phone database. Voided bills are ignored.
class ReportService {
  static Future<ReportData> build(AppDatabase db, DateRange range) async {
    final from = range.start.millisecondsSinceEpoch;
    final to = range.end.millisecondsSinceEpoch;

    final invoices = await (db.select(db.invoices)
          ..where((i) =>
              i.status.equals('active') &
              i.createdAt.isBiggerOrEqualValue(from) &
              i.createdAt.isSmallerThanValue(to)))
        .get();

    // Khata "you gave ₹X" entries are stored as bills with a single 'entry' line.
    // They are udhaar, not sales, so they are left out of sales, bills and items.
    final byId = {for (final i in invoices) i.id: i};
    final lines = byId.isEmpty
        ? <InvoiceItem>[]
        : await (db.select(db.invoiceItems)..where((l) => l.invoiceId.isIn(byId.keys))).get();
    final manualEntryIds = {for (final l in lines) if (l.unit == manualKhataEntryUnit) l.invoiceId};

    double total = 0;
    double udhaarGiven = 0;
    var billCount = 0;
    final byMode = <String, double>{};
    final dailyMap = <DateTime, double>{};
    for (var d = range.start; d.isBefore(range.end); d = DateTime(d.year, d.month, d.day + 1)) {
      dailyMap[d] = 0;
    }
    for (final inv in invoices) {
      udhaarGiven += inv.amountDue;
      if (manualEntryIds.contains(inv.id)) continue;
      billCount++;
      total += inv.total;
      byMode[inv.paymentMode] = (byMode[inv.paymentMode] ?? 0) + inv.total;
      final t = DateTime.fromMillisecondsSinceEpoch(inv.createdAt);
      final day = DateTime(t.year, t.month, t.day);
      dailyMap[day] = (dailyMap[day] ?? 0) + inv.total;
    }

    // Line items: profit and best sellers.
    double grossProfit = 0;
    double salesWithoutCost = 0;
    final items = <String, ItemSales>{};
    for (final line in lines) {
      if (manualEntryIds.contains(line.invoiceId)) continue;
      final inv = byId[line.invoiceId]!;
      // Spread the bill-level discount over its lines.
      final discountFactor = inv.subtotal > 0 ? (inv.subtotal - inv.discount) / inv.subtotal : 1.0;
      final netLine = line.lineTotal * discountFactor;
      final cost = line.costSnapshot;
      if (cost != null) {
        grossProfit += netLine - line.qty * cost;
      } else {
        salesWithoutCost += netLine;
      }
      final key = line.productId ?? line.nameSnapshot;
      final entry = items.putIfAbsent(key, () => ItemSales(line.nameSnapshot, line.unit, 0, 0));
      entry.qty += line.qty;
      entry.revenue += netLine;
    }
    final top = items.values.toList()..sort((a, b) => b.revenue.compareTo(a.revenue));

    final collections = await (db.select(db.payments)
          ..where((p) =>
              p.type.equals('collection') & p.createdAt.isBiggerOrEqualValue(from) & p.createdAt.isSmallerThanValue(to)))
        .get();

    final expenses = await (db.select(db.expenses)
          ..where((e) => e.spentAt.isBiggerOrEqualValue(from) & e.spentAt.isSmallerThanValue(to)))
        .get();
    final byCategory = <String, double>{};
    for (final e in expenses) {
      byCategory[e.category] = (byCategory[e.category] ?? 0) + e.amount;
    }

    return ReportData(
      range: range,
      totalSales: total,
      billCount: billCount,
      byPaymentMode: byMode,
      udhaarGiven: udhaarGiven,
      udhaarCollected: collections.fold(0.0, (s, p) => s + p.amount),
      grossProfit: grossProfit,
      salesWithoutCost: salesWithoutCost,
      expenses: expenses.fold(0.0, (s, e) => s + e.amount),
      expensesByCategory: byCategory,
      topItems: top.take(10).toList(),
      daily: dailyMap.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );
  }
}

import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../../../core/db/app_database.dart';
import '../../../core/money/money_utils.dart';
import '../../inventory/domain/product_model.dart';

class CustomerWithBalance {
  final Customer customer;
  final Decimal currentBalance;

  CustomerWithBalance({
    required this.customer,
    required this.currentBalance,
  });
}

enum LedgerEntryType { openingBalance, bill, payment }

class LedgerEntry {
  final String id;
  final LedgerEntryType type;
  final int timestamp;
  final Decimal debitAmount;   // > 0 when store gave credit / goods (Debit)
  final Decimal creditAmount;  // > 0 when store received payment (Credit)
  Decimal runningBalance;      // Running net balance at this point in time
  final String title;
  final String subtitle;
  final String? refId;
  final bool isLatest;
  final List<String> items;

  LedgerEntry({
    required this.id,
    required this.type,
    required this.timestamp,
    required this.debitAmount,
    required this.creditAmount,
    Decimal? runningBalance,
    required this.title,
    required this.subtitle,
    this.refId,
    this.isLatest = false,
    this.items = const [],
  }) : runningBalance = runningBalance ?? Decimal.zero;

  // Backwards compatibility getter
  Decimal get amount => debitAmount > Decimal.zero ? debitAmount : creditAmount;
}

class CustomerLedgerData {
  final Customer customer;
  final List<LedgerEntry> entries;
  final Decimal totalDebit;
  final Decimal totalCredit;
  final Decimal netBalance;
  final String dateRangeString;

  CustomerLedgerData({
    required this.customer,
    required this.entries,
    required this.totalDebit,
    required this.totalCredit,
    required this.netBalance,
    required this.dateRangeString,
  });
}

class KhataState {
  final List<CustomerWithBalance> customers;
  final String searchQuery;
  final bool isLoading;
  final String? errorMessage;

  KhataState({
    this.customers = const [],
    this.searchQuery = '',
    this.isLoading = false,
    this.errorMessage,
  });

  Decimal get totalOutstanding =>
      customers.fold(Decimal.zero, (sum, c) => sum + c.currentBalance);

  List<CustomerWithBalance> get filteredCustomers {
    if (searchQuery.trim().isEmpty) return customers;
    final q = searchQuery.toLowerCase().trim();
    return customers.where((c) {
      final matchName = c.customer.name.toLowerCase().contains(q);
      final matchPhone = c.customer.phone != null && c.customer.phone!.contains(q);
      return matchName || matchPhone;
    }).toList();
  }

  KhataState copyWith({
    List<CustomerWithBalance>? customers,
    String? searchQuery,
    bool? isLoading,
    String? errorMessage,
  }) {
    return KhataState(
      customers: customers ?? this.customers,
      searchQuery: searchQuery ?? this.searchQuery,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

final khataProvider = StateNotifierProvider<KhataNotifier, KhataState>((ref) {
  final db = ref.watch(databaseProvider);
  return KhataNotifier(db);
});

class KhataNotifier extends StateNotifier<KhataState> {
  final AppDatabase db;

  KhataNotifier(this.db) : super(KhataState()) {
    loadCustomers();
  }

  Future<void> loadCustomers() async {
    state = state.copyWith(isLoading: true);
    try {
      final custList = await db.select(db.customers).get();
      final List<CustomerWithBalance> listWithBalance = [];

      for (final c in custList) {
        final balance = await db.getCustomerBalance(c.id);
        listWithBalance.add(CustomerWithBalance(customer: c, currentBalance: balance));
      }

      // Sort by highest outstanding balance first
      listWithBalance.sort((a, b) => b.currentBalance.compareTo(a.currentBalance));

      state = state.copyWith(
        customers: listWithBalance,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  Future<String?> addCustomer({
    required String name,
    String? phone,
    String? address,
    double openingBalance = 0.0,
  }) async {
    final cleanPhone = (phone != null && phone.trim().isNotEmpty) ? phone.trim() : null;

    if (cleanPhone != null) {
      final existing = await (db.select(db.customers)..where((c) => c.phone.equals(cleanPhone))).getSingleOrNull();
      if (existing != null) {
        return 'Customer with phone number "$cleanPhone" already exists (${existing.name}).';
      }
    }

    try {
      final newId = const Uuid().v4();
      final now = DateTime.now().millisecondsSinceEpoch;

      await db.into(db.customers).insert(
        CustomersCompanion.insert(
          id: newId,
          name: name.trim(),
          phone: Value(cleanPhone),
          address: Value(address?.trim()),
          openingBalance: Value(openingBalance),
          createdAt: now,
        ),
      );

      await loadCustomers();
      return null;
    } catch (e) {
      return 'Failed to add customer: $e';
    }
  }

  Future<CustomerLedgerData> getCustomerLedgerData(String customerId) async {
    final customer = await (db.select(db.customers)..where((c) => c.id.equals(customerId))).getSingle();
    final List<LedgerEntry> entries = [];

    // 1. Add Opening Balance entry if non-zero
    if (customer.openingBalance != 0.0) {
      final opBal = MoneyUtils.parse(customer.openingBalance);
      final isDebit = customer.openingBalance > 0;
      entries.add(
        LedgerEntry(
          id: 'op_${customer.id}',
          type: LedgerEntryType.openingBalance,
          timestamp: customer.createdAt,
          debitAmount: isDebit ? opBal : Decimal.zero,
          creditAmount: !isDebit ? -opBal : Decimal.zero,
          title: isDebit ? 'Opening Due Balance' : 'Opening Advance Balance',
          subtitle: 'Initial ledger balance',
        ),
      );
    }

    // 2. Fetch all Invoices for this customer with line item snapshots
    final invoices = await (db.select(db.invoices)
      ..where((i) => i.customerId.equals(customerId) & i.status.equals('active')))
      .get();

    for (final inv in invoices) {
      // Fetch line items for this invoice
      final items = await (db.select(db.invoiceItems)..where((it) => it.invoiceId.equals(inv.id))).get();
      final itemNames = items.map((it) => it.nameSnapshot).toList();
      final itemsSummary = itemNames.isNotEmpty ? itemNames.join(', ') : 'Credit Sale';

      entries.add(
        LedgerEntry(
          id: inv.id,
          type: LedgerEntryType.bill,
          timestamp: inv.createdAt,
          debitAmount: MoneyUtils.parse(inv.amountDue),
          creditAmount: Decimal.zero,
          title: 'Bill #${inv.invoiceNo}',
          subtitle: itemsSummary,
          refId: inv.id,
          items: itemNames,
        ),
      );
    }

    // 3. Fetch all Payments for this customer
    final payments = await (db.select(db.payments)..where((p) => p.customerId.equals(customerId))).get();

    for (final pay in payments) {
      final modeStr = pay.mode.toUpperCase();
      entries.add(
        LedgerEntry(
          id: pay.id,
          type: LedgerEntryType.payment,
          timestamp: pay.createdAt,
          debitAmount: Decimal.zero,
          creditAmount: MoneyUtils.parse(pay.amount),
          title: 'Payment Received ($modeStr)',
          subtitle: pay.note != null && pay.note!.isNotEmpty
              ? pay.note!
              : (modeStr == 'UPI' ? 'UPI Online Payment' : 'Cash Received'),
          refId: pay.id,
        ),
      );
    }

    // 4. Chronological calculation (oldest to newest) for exact running balances
    entries.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    Decimal running = Decimal.zero;
    Decimal totalDebit = Decimal.zero;
    Decimal totalCredit = Decimal.zero;

    for (final e in entries) {
      running = running + e.debitAmount - e.creditAmount;
      totalDebit += e.debitAmount;
      totalCredit += e.creditAmount;
      e.runningBalance = running;
    }

    // 5. Sort newest first for Khatabook presentation
    final displayEntries = List<LedgerEntry>.from(entries.reversed);
    if (displayEntries.isNotEmpty) {
      displayEntries[0] = LedgerEntry(
        id: displayEntries[0].id,
        type: displayEntries[0].type,
        timestamp: displayEntries[0].timestamp,
        debitAmount: displayEntries[0].debitAmount,
        creditAmount: displayEntries[0].creditAmount,
        runningBalance: displayEntries[0].runningBalance,
        title: displayEntries[0].title,
        subtitle: displayEntries[0].subtitle,
        refId: displayEntries[0].refId,
        isLatest: true,
        items: displayEntries[0].items,
      );
    }

    String dateRangeStr = 'All Time';
    if (entries.isNotEmpty) {
      final start = DateTime.fromMillisecondsSinceEpoch(entries.first.timestamp);
      final end = DateTime.fromMillisecondsSinceEpoch(entries.last.timestamp);
      final fmt = (DateTime d) => '${d.day.toString().padLeft(2, '0')} ${_monthName(d.month)} ${d.year}';
      dateRangeStr = '${fmt(start)} - ${fmt(end)}';
    }

    return CustomerLedgerData(
      customer: customer,
      entries: displayEntries,
      totalDebit: totalDebit,
      totalCredit: totalCredit,
      netBalance: running,
      dateRangeString: dateRangeStr,
    );
  }

  static String _monthName(int m) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return (m >= 1 && m <= 12) ? months[m - 1] : '';
  }

  Future<List<LedgerEntry>> getCustomerLedgerHistory(String customerId) async {
    final data = await getCustomerLedgerData(customerId);
    return data.entries;
  }

  Future<void> collectPayment({
    required String customerId,
    required Decimal amount,
    required String mode,
    String? note,
  }) async {
    await db.recordCustomerPayment(
      customerId: customerId,
      amount: amount,
      mode: mode,
      note: note,
    );
    await loadCustomers();
  }

  Future<void> recordDebit({
    required String customerId,
    required Decimal amount,
    required String note,
    DateTime? date,
  }) async {
    await db.recordCustomerDebit(
      customerId: customerId,
      amount: amount,
      note: note,
      date: date,
    );
    await loadCustomers();
  }
}

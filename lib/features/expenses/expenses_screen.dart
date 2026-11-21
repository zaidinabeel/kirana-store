import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/app_colors.dart';
import '../../core/db/app_database.dart';
import '../../core/i18n/app_strings.dart';
import '../../core/validation/formatters.dart';
import '../inventory/domain/product_model.dart';

class ExpenseCategory {
  final String id;
  final String emoji;
  final String hi;
  final String en;
  const ExpenseCategory(this.id, this.emoji, this.hi, this.en);

  String label(bool hindi) => hindi ? hi : en;
}

const expenseCategories = [
  ExpenseCategory('rent', '🏠', 'दुकान का किराया', 'Rent'),
  ExpenseCategory('electricity', '💡', 'बिजली', 'Electricity'),
  ExpenseCategory('wages', '👷', 'मज़दूरी / तनख्वाह', 'Wages'),
  ExpenseCategory('transport', '🛺', 'माल ढुलाई', 'Transport'),
  ExpenseCategory('tea', '☕', 'चाय-नाश्ता', 'Tea & snacks'),
  ExpenseCategory('other', '📝', 'अन्य खर्च', 'Other'),
];

const _hindiMonths = [
  'जनवरी', 'फ़रवरी', 'मार्च', 'अप्रैल', 'मई', 'जून',
  'जुलाई', 'अगस्त', 'सितंबर', 'अक्टूबर', 'नवंबर', 'दिसंबर',
];

/// "नवंबर 2026" / "November 2026" without needing locale data loaded.
String monthLabel(DateTime m, bool hindi) =>
    hindi ? '${_hindiMonths[m.month - 1]} ${m.year}' : DateFormat('MMMM yyyy').format(m);

ExpenseCategory categoryFor(String id) =>
    expenseCategories.firstWhere((c) => c.id == id, orElse: () => expenseCategories.last);

/// Shop expenses for a month, with a big "add expense" button.
class ExpensesScreen extends ConsumerStatefulWidget {
  const ExpensesScreen({super.key});

  @override
  ConsumerState<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends ConsumerState<ExpensesScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  List<Expense> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = ref.read(databaseProvider);
    final from = _month.millisecondsSinceEpoch;
    final to = DateTime(_month.year, _month.month + 1).millisecondsSinceEpoch;
    final rows = await (db.select(db.expenses)
          ..where((e) => e.spentAt.isBiggerOrEqualValue(from) & e.spentAt.isSmallerThanValue(to))
          ..orderBy([(e) => OrderingTerm.desc(e.spentAt), (e) => OrderingTerm.desc(e.createdAt)]))
        .get();
    if (!mounted) return;
    setState(() {
      _items = rows;
      _loading = false;
    });
  }

  Future<void> _add() async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => const AddExpenseSheet(),
    );
    if (saved == true) _load();
  }

  Future<void> _delete(Expense e, bool hi) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(hi ? 'यह खर्च हटाएं?' : 'Delete this expense?'),
        content: Text('${categoryFor(e.category).label(hi)} — ₹${e.amount.toStringAsFixed(0)}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(hi ? 'नहीं' : 'No')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: Text(hi ? 'हाँ, हटाएं' : 'Yes, delete')),
        ],
      ),
    );
    if (ok != true) return;
    final db = ref.read(databaseProvider);
    await (db.delete(db.expenses)..where((x) => x.id.equals(e.id))).go();
    _load();
  }

  void _shiftMonth(int delta) {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta);
      _loading = true;
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final hi = ref.watch(localeProvider) == AppLanguage.hi;
    final total = _items.fold<double>(0, (s, e) => s + e.amount);
    final now = DateTime.now();
    final isCurrentMonth = _month.year == now.year && _month.month == now.month;
    final monthName = monthLabel(_month, hi);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: Text(hi ? 'दुकान का खर्च' : 'Shop expenses', style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'add_expense_fab',
        backgroundColor: AppColors.accent,
        foregroundColor: AppColors.textPrimary,
        onPressed: _add,
        icon: const Icon(Icons.add_rounded, size: 28),
        label: Text(hi ? 'खर्च जोड़ें' : 'Add expense', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
      ),
      body: Column(
        children: [
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(onPressed: () => _shiftMonth(-1), icon: const Icon(Icons.chevron_left_rounded, size: 32)),
                    Expanded(
                      child: Text(monthName,
                          textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    ),
                    IconButton(
                      onPressed: isCurrentMonth ? null : () => _shiftMonth(1),
                      icon: const Icon(Icons.chevron_right_rounded, size: 32),
                    ),
                  ],
                ),
                Text(hi ? 'कुल खर्च' : 'Total spent', style: const TextStyle(color: AppColors.textSecondary)),
                Text('₹${NumberFormat('#,##,##0', 'en_IN').format(total)}',
                    style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: AppColors.alert)),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _items.isEmpty
                    ? Center(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            hi
                                ? 'इस महीने कोई खर्च नहीं लिखा।\nकिराया, बिजली, मज़दूरी जैसे खर्च लिखें — तभी असली मुनाफ़ा दिखेगा।'
                                : 'No expenses this month.\nAdd rent, electricity, wages — so profit is accurate.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 16, height: 1.5, color: AppColors.textSecondary),
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.only(bottom: 90),
                        itemCount: _items.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final e = _items[i];
                          final c = categoryFor(e.category);
                          return ListTile(
                            leading: Text(c.emoji, style: const TextStyle(fontSize: 28)),
                            title: Text(c.label(hi), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                            subtitle: Text(
                              [
                                DateFormat('dd MMM').format(DateTime.fromMillisecondsSinceEpoch(e.spentAt)),
                                if (e.note != null && e.note!.isNotEmpty) e.note!,
                              ].join(' • '),
                            ),
                            trailing: Text('₹${e.amount.toStringAsFixed(0)}',
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                            onLongPress: () => _delete(e, hi),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

/// Category buttons + amount + optional note. Returns true when saved.
class AddExpenseSheet extends ConsumerStatefulWidget {
  const AddExpenseSheet({super.key});

  @override
  ConsumerState<AddExpenseSheet> createState() => _AddExpenseSheetState();
}

class _AddExpenseSheetState extends ConsumerState<AddExpenseSheet> {
  final _amount = TextEditingController();
  final _note = TextEditingController();
  String _category = 'rent';
  DateTime _day = DateTime.now();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save(bool hi) async {
    final amount = double.tryParse(_amount.text);
    if (amount == null || amount <= 0) {
      setState(() => _error = hi ? 'रकम लिखें' : 'Enter the amount');
      return;
    }
    setState(() => _saving = true);
    final db = ref.read(databaseProvider);
    final now = DateTime.now();
    await db.into(db.expenses).insert(ExpensesCompanion.insert(
          id: const Uuid().v4(),
          category: _category,
          amount: amount,
          note: Value(_note.text.trim().isEmpty ? null : _note.text.trim()),
          spentAt: DateTime(_day.year, _day.month, _day.day, 12).millisecondsSinceEpoch,
          createdAt: now.millisecondsSinceEpoch,
        ));
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final hi = ref.watch(localeProvider) == AppLanguage.hi;
    final today = DateTime.now();
    final isToday = _day.year == today.year && _day.month == today.month && _day.day == today.day;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(hi ? 'खर्च जोड़ें' : 'Add expense',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.primary)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in expenseCategories)
                  ChoiceChip(
                    label: Text('${c.emoji} ${c.label(hi)}', style: const TextStyle(fontSize: 15)),
                    selected: _category == c.id,
                    onSelected: (_) => setState(() => _category = c.id),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _amount,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [DecimalInputFormatter(2)],
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
              decoration: InputDecoration(labelText: hi ? 'कितने रुपये' : 'Amount', prefixText: '₹ ', errorText: _error),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _note,
              maxLength: 80,
              decoration: InputDecoration(labelText: hi ? 'नोट (ज़रूरी नहीं)' : 'Note (optional)', counterText: ''),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.event_rounded, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    isToday ? (hi ? 'आज' : 'Today') : DateFormat('dd MMM yyyy').format(_day),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _day,
                      firstDate: DateTime(today.year - 1),
                      lastDate: today,
                    );
                    if (picked != null) setState(() => _day = picked);
                  },
                  child: Text(hi ? 'तारीख बदलें' : 'Change date'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 56,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, foregroundColor: Colors.white),
                onPressed: _saving ? null : () => _save(hi),
                icon: const Icon(Icons.check_rounded, size: 28),
                label: Text(hi ? 'सेव करें' : 'Save', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_colors.dart';
import '../../core/i18n/app_strings.dart';
import '../expenses/expenses_screen.dart';
import '../inventory/domain/product_model.dart';
import '../khata/state/khata_notifier.dart';
import 'report_service.dart';

final _rupees = NumberFormat('#,##,##0', 'en_IN');
String _rs(double v) => '${v < 0 ? '-' : ''}₹${_rupees.format(v.abs().round())}';

/// Business summary ("हिसाब") for a chosen period, in plain Hindi.
class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  ReportPeriod _period = ReportPeriod.today;
  late Future<ReportData> _future;

  @override
  void initState() {
    super.initState();
    _reload();
    // Refresh who-owes-what after the first frame (providers can't change mid-build).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(khataProvider.notifier).loadCustomers();
    });
  }

  void _reload() {
    _future = ReportService.build(ref.read(databaseProvider), rangeFor(_period, DateTime.now()));
  }

  static String periodLabel(ReportPeriod p, bool hi) {
    switch (p) {
      case ReportPeriod.today:
        return hi ? 'आज' : 'Today';
      case ReportPeriod.yesterday:
        return hi ? 'कल' : 'Yesterday';
      case ReportPeriod.thisWeek:
        return hi ? 'इस हफ़्ते' : 'This week';
      case ReportPeriod.thisMonth:
        return hi ? 'इस महीने' : 'This month';
      case ReportPeriod.lastMonth:
        return hi ? 'पिछला महीना' : 'Last month';
    }
  }

  static String modeLabel(String mode, bool hi) {
    switch (mode) {
      case 'cash':
        return hi ? 'नकद' : 'Cash';
      case 'upi':
        return 'UPI';
      case 'card':
        return hi ? 'कार्ड' : 'Card';
      case 'credit':
        return hi ? 'उधार' : 'Udhaar';
      case 'split':
        return hi ? 'मिक्स' : 'Split';
      default:
        return mode;
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(localeProvider);
    final hi = lang == AppLanguage.hi;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: Text(hi ? 'हिसाब / रिपोर्ट' : 'Reports', style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: Column(
        children: [
          // All periods visible at once (wraps to a second line on small phones).
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final p in ReportPeriod.values)
                  Padding(
                    padding: EdgeInsets.zero,
                    child: ChoiceChip(
                      label: Text(periodLabel(p, hi), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                      selected: _period == p,
                      onSelected: (_) => setState(() {
                        _period = p;
                        _reload();
                      }),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<ReportData>(
              future: _future,
              builder: (context, snap) {
                if (snap.hasError) {
                  return Center(child: Text('${snap.error}', textAlign: TextAlign.center));
                }
                if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                return RefreshIndicator(
                  onRefresh: () async {
                    setState(_reload);
                    await _future;
                  },
                  child: _ReportBody(data: snap.data!, hi: hi, lang: lang),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportBody extends ConsumerWidget {
  final ReportData data;
  final bool hi;
  final AppLanguage lang;

  const _ReportBody({required this.data, required this.hi, required this.lang});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final khata = ref.watch(khataProvider);
    final debtors = [...khata.customers.where((c) => c.currentBalance.toDouble() > 0.009)]
      ..sort((a, b) => b.currentBalance.compareTo(a.currentBalance));

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 24),
      children: [
        // Sales hero
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(16)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(hi ? 'कुल बिक्री' : 'Total sales', style: const TextStyle(color: Colors.white70, fontSize: 15)),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(_rs(data.totalSales),
                    style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w900)),
              ),
              const SizedBox(height: 4),
              Text(
                hi
                    ? '${data.billCount} बिल • औसत बिल ${_rs(data.averageBill)}'
                    : '${data.billCount} bills • average ${_rs(data.averageBill)}',
                style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Profit
        _Card(
          title: hi ? '💰 मुनाफ़ा' : '💰 Profit',
          children: [
            _Row(hi ? 'बिक्री पर मुनाफ़ा' : 'Profit on sales', _rs(data.grossProfit)),
            _Row(hi ? 'खर्च (−)' : 'Expenses (−)', _rs(data.expenses), valueColor: AppColors.alert),
            const Divider(),
            _Row(
              hi ? 'शुद्ध मुनाफ़ा' : 'Net profit',
              _rs(data.netProfit),
              bold: true,
              valueColor: data.netProfit >= 0 ? AppColors.success : AppColors.alert,
            ),
            if (data.profitIsPartial)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: AppColors.accentLight, borderRadius: BorderRadius.circular(8)),
                child: Text(
                  hi
                      ? '${_rs(data.salesWithoutCost)} की बिक्री वाले सामान का खरीद दाम नहीं भरा है, इसलिए उनका मुनाफ़ा नहीं गिना। स्टॉक में सामान खोलकर "खरीद का दाम" भरें।'
                      : 'Purchase price is missing for ${_rs(data.salesWithoutCost)} of sales, so that profit is not counted. Add "purchase price" to those items.',
                  style: const TextStyle(fontSize: 13, height: 1.4),
                ),
              ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ExpensesScreen())),
                icon: const Icon(Icons.receipt_long_rounded),
                label: Text(hi ? 'खर्च देखें / जोड़ें' : 'View / add expenses'),
              ),
            ),
          ],
        ),

        if (data.daily.length > 1 && data.totalSales > 0)
          _Card(
            title: hi ? '📊 रोज़ की बिक्री' : '📊 Daily sales',
            children: [_DailyBars(daily: data.daily, hi: hi)],
          ),

        // Payment split
        if (data.byPaymentMode.isNotEmpty)
          _Card(
            title: hi ? '💳 पैसे कैसे आए' : '💳 How customers paid',
            children: [
              for (final e in (data.byPaymentMode.entries.toList()..sort((a, b) => b.value.compareTo(a.value))))
                _BarRow(
                  label: _ReportsScreenState.modeLabel(e.key, hi),
                  value: e.value,
                  max: data.totalSales,
                  color: e.key == 'credit' ? AppColors.alert : AppColors.primary,
                ),
            ],
          ),

        // Udhaar
        _Card(
          title: hi ? '📒 उधार' : '📒 Udhaar',
          children: [
            _Row(hi ? 'इस दौरान उधार दिया' : 'Credit given', _rs(data.udhaarGiven), valueColor: AppColors.alert),
            _Row(hi ? 'इस दौरान वापस मिला' : 'Credit collected', _rs(data.udhaarCollected), valueColor: AppColors.success),
            _Row(hi ? 'बाज़ार में कुल बाकी' : 'Total still owed', _rs(khata.totalOutstanding.toDouble()), bold: true),
            if (debtors.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(hi ? 'सबसे ज़्यादा बाकी:' : 'Owe the most:', style: const TextStyle(fontWeight: FontWeight.w800)),
              for (final d in debtors.take(5))
                _Row(d.customer.name, _rs(d.currentBalance.toDouble()), valueColor: AppColors.alert),
            ],
          ],
        ),

        // Best sellers
        if (data.topItems.isNotEmpty)
          _Card(
            title: hi ? '🏆 सबसे ज़्यादा बिकने वाला सामान' : '🏆 Best sellers',
            children: [
              for (var i = 0; i < data.topItems.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 26,
                        child: Text('${i + 1}.', style: const TextStyle(fontWeight: FontWeight.w800)),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(data.topItems[i].name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                            Text(
                              '${_qty(data.topItems[i].qty)} ${AppStrings.unitName(lang, data.topItems[i].unit)}',
                              style: const TextStyle(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      Text(_rs(data.topItems[i].revenue), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
            ],
          ),

        // Expenses by category
        if (data.expensesByCategory.isNotEmpty)
          _Card(
            title: hi ? '🧾 खर्च' : '🧾 Expenses',
            children: [
              for (final e in (data.expensesByCategory.entries.toList()..sort((a, b) => b.value.compareTo(a.value))))
                _Row('${categoryFor(e.key).emoji} ${categoryFor(e.key).label(hi)}', _rs(e.value)),
            ],
          ),

        if (data.billCount == 0)
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              hi ? 'इस दौरान कोई बिल नहीं बना।' : 'No bills in this period.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: AppColors.textSecondary),
            ),
          ),
      ],
    );
  }

  static String _qty(double q) => q % 1 == 0 ? q.toInt().toString() : q.toStringAsFixed(2);
}

class _Card extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Card({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.primary)),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  final Color? valueColor;
  const _Row(this.label, this.value, {this.bold = false, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: TextStyle(fontSize: 16, fontWeight: bold ? FontWeight.w900 : FontWeight.w500)),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: TextStyle(fontSize: bold ? 20 : 16, fontWeight: bold ? FontWeight.w900 : FontWeight.w700, color: valueColor),
          ),
        ],
      ),
    );
  }
}

class _BarRow extends StatelessWidget {
  final String label;
  final double value;
  final double max;
  final Color color;
  const _BarRow({required this.label, required this.value, required this.max, required this.color});

  @override
  Widget build(BuildContext context) {
    final share = max <= 0 ? 0.0 : (value / max).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
              Text('${_rs(value)}  (${(share * 100).round()}%)', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: share,
              minHeight: 8,
              backgroundColor: AppColors.surfaceMuted,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Simple bar chart of sales per day.
class _DailyBars extends StatelessWidget {
  final List<MapEntry<DateTime, double>> daily;
  final bool hi;
  const _DailyBars({required this.daily, required this.hi});

  static const _hiDays = ['सोम', 'मंगल', 'बुध', 'गुरु', 'शुक्र', 'शनि', 'रवि'];

  @override
  Widget build(BuildContext context) {
    final maxV = daily.fold<double>(0, (m, e) => math.max(m, e.value));
    final best = daily.reduce((a, b) => b.value > a.value ? b : a);
    final showWeekday = daily.length <= 7;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 140,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final e in daily)
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: daily.length > 15 ? 1 : 3),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Flexible(
                          child: FractionallySizedBox(
                            heightFactor: maxV <= 0 ? 0 : (e.value / maxV).clamp(0.02, 1.0),
                            child: Container(
                              decoration: BoxDecoration(
                                color: identical(e, best) ? AppColors.accent : AppColors.primary,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          showWeekday
                              ? (hi ? _hiDays[e.key.weekday - 1] : DateFormat('E').format(e.key))
                              : (e.key.day == 1 || e.key.day % 5 == 0 ? '${e.key.day}' : ''),
                          style: const TextStyle(fontSize: 11),
                          maxLines: 1,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          hi
              ? 'सबसे अच्छा दिन: ${DateFormat('dd MMM').format(best.key)} — ${_rs(best.value)}'
              : 'Best day: ${DateFormat('dd MMM').format(best.key)} — ${_rs(best.value)}',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

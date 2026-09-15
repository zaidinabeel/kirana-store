import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:decimal/decimal.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/i18n/app_strings.dart';
import '../../../core/money/money_utils.dart';
import '../../../core/db/app_database.dart';
import '../../../shared/widgets/app_header.dart';
import '../state/khata_notifier.dart';
import 'widgets/collect_payment_modal.dart';
import 'widgets/record_debit_modal.dart';

class KhataDetailScreen extends ConsumerStatefulWidget {
  final Customer customer;

  const KhataDetailScreen({
    super.key,
    required this.customer,
  });

  @override
  ConsumerState<KhataDetailScreen> createState() => _KhataDetailScreenState();
}

class _KhataDetailScreenState extends ConsumerState<KhataDetailScreen> {
  CustomerLedgerData? _ledgerData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final notifier = ref.read(khataProvider.notifier);
    final ledgerData = await notifier.getCustomerLedgerData(widget.customer.id);

    if (mounted) {
      setState(() {
        _ledgerData = ledgerData;
        _isLoading = false;
      });
    }
  }

  void _openRecordDebit() {
    final currentDue = _ledgerData?.netBalance ?? Decimal.zero;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => RecordDebitModal(
        customer: widget.customer,
        currentDue: currentDue,
        onDebitRecorded: _loadData,
      ),
    );
  }

  void _openCollectPayment() {
    final currentDue = _ledgerData?.netBalance ?? Decimal.zero;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CollectPaymentModal(
        customer: widget.customer,
        currentDue: currentDue,
        onPaymentRecorded: _loadData,
      ),
    );
  }

  Future<void> _shareStatement() async {
    if (_ledgerData == null) return;
    final buffer = StringBuffer();
    buffer.writeln('📋 *Khata Statement - ${widget.customer.name}*');
    buffer.writeln('Gupta Kirana & General Store');
    buffer.writeln('Date: ${DateFormat('dd-MM-yyyy').format(DateTime.now())}');
    buffer.writeln('Period: ${_ledgerData!.dateRangeString}');
    buffer.writeln('--------------------------------');
    buffer.writeln('🔴 *Net Balance Due: ₹${_ledgerData!.netBalance.toStringAsFixed(1)} (${_ledgerData!.netBalance >= Decimal.zero ? 'Dr' : 'Cr'})*');
    buffer.writeln('Total Debit(-): ₹${_ledgerData!.totalDebit.toStringAsFixed(1)}');
    buffer.writeln('Total Credit(+): ₹${_ledgerData!.totalCredit.toStringAsFixed(1)}');
    buffer.writeln('--------------------------------');
    buffer.writeln('*Recent Transactions:*');

    for (final entry in _ledgerData!.entries.take(10)) {
      final date = DateFormat('dd/MM/yy').format(DateTime.fromMillisecondsSinceEpoch(entry.timestamp));
      if (entry.debitAmount > Decimal.zero) {
        buffer.writeln('$date: ${entry.title} | Debit: ₹${entry.debitAmount.toStringAsFixed(1)} | Bal: ₹${entry.runningBalance.toStringAsFixed(1)} Dr');
      } else {
        buffer.writeln('$date: ${entry.title} | Credit: ₹${entry.creditAmount.toStringAsFixed(1)} | Bal: ₹${entry.runningBalance.toStringAsFixed(1)}');
      }
    }

    buffer.writeln('--------------------------------');
    buffer.writeln('Please settle the balance via UPI or Cash.');
    buffer.writeln('UPI ID: guptakirana@upi');
    buffer.writeln('Thank you for your business!');

    await Share.share(buffer.toString(), subject: 'Khata Statement - ${widget.customer.name}');
  }

  void _showEntryDetail(LedgerEntry entry) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              entry.debitAmount > Decimal.zero ? Icons.receipt_long_rounded : Icons.payments_rounded,
              color: entry.debitAmount > Decimal.zero ? AppColors.alert : AppColors.success,
              size: 24,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                entry.title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Date: ${DateFormat('dd MMMM yyyy, hh:mm a').format(DateTime.fromMillisecondsSinceEpoch(entry.timestamp))}',
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: entry.debitAmount > Decimal.zero ? const Color(0xFFFFF5F5) : const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: entry.debitAmount > Decimal.zero ? const Color(0xFFFEE2E2) : const Color(0xFFDCFCE7),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    entry.debitAmount > Decimal.zero ? 'Debit Amount (-):' : 'Credit Amount (+):',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    '₹${(entry.debitAmount > Decimal.zero ? entry.debitAmount : entry.creditAmount).toStringAsFixed(1)}',
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: entry.debitAmount > Decimal.zero ? AppColors.alert : AppColors.success,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Running Balance:', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                Text(
                  '₹${entry.runningBalance.abs().toStringAsFixed(1)} ${entry.runningBalance >= Decimal.zero ? 'Dr' : 'Cr'}',
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: entry.runningBalance >= Decimal.zero ? AppColors.alert : AppColors.success,
                  ),
                ),
              ],
            ),
            if (entry.subtitle.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('Details / Items:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
              const SizedBox(height: 4),
              Text(entry.subtitle, style: const TextStyle(fontSize: 13, color: AppColors.textPrimary)),
            ],
            if (entry.items.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text('Items Breakdown:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
              const SizedBox(height: 4),
              ...entry.items.map((it) => Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Row(
                  children: [
                    const Icon(Icons.arrow_right_rounded, size: 16, color: AppColors.primary),
                    Expanded(child: Text(it, style: const TextStyle(fontSize: 12))),
                  ],
                ),
              )),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(localeProvider);
    final data = _ledgerData;
    final isDue = (data?.netBalance ?? Decimal.zero) > Decimal.zero;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppHeader(
        title: widget.customer.name,
        showBackButton: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded, color: Colors.white),
            tooltip: AppStrings.shareStatement(lang),
            onPressed: _shareStatement,
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                offset: const Offset(0, -3),
                blurRadius: 8,
              ),
            ],
          ),
          child: Row(
            children: [
              // YOU GAVE (Debit) Button - Red
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDC2626), // Strong Red
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 1,
                  ),
                  onPressed: _openRecordDebit,
                  icon: const Icon(Icons.arrow_upward_rounded, size: 20),
                  label: Text(
                    lang == AppLanguage.hi ? 'आपने दिया ₹ (उधार)' : 'YOU GAVE ₹ (Debit)',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // YOU GOT (Credit) Button - Green
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A), // Strong Green
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 1,
                  ),
                  onPressed: _openCollectPayment,
                  icon: const Icon(Icons.arrow_downward_rounded, size: 20),
                  label: Text(
                    lang == AppLanguage.hi ? 'आपको मिला ₹ (जमा)' : 'YOU GOT ₹ (Credit)',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: _isLoading || data == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // 1. Customer Top Info Header
                _buildCustomerHeader(lang),

                // 2. Khatabook Summary Box (Transactions History / Total Debit / Total Credit / Net Balance)
                _buildSummaryKpiCard(data, lang),

                // 3. 4-Column Ledger Table Header
                _buildTableHeader(lang),

                // 4. 4-Column Ledger Table Rows
                Expanded(
                  child: data.entries.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.menu_book_rounded, size: 48, color: Colors.grey.shade400),
                              const SizedBox(height: 8),
                              Text(
                                lang == AppLanguage.hi ? 'कोई लेन-देन नहीं है' : 'No transactions recorded yet',
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 14, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: data.entries.length,
                          itemBuilder: (ctx, index) {
                            final entry = data.entries[index];
                            return _buildLedgerRow(entry, lang);
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildCustomerHeader(AppLanguage lang) {
    final initials = widget.customer.name.trim().isNotEmpty
        ? widget.customer.name.trim().split(' ').map((e) => e.isNotEmpty ? e[0].toUpperCase() : '').take(2).join()
        : 'C';

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.primary.withOpacity(0.12),
            child: Text(
              initials,
              style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800, fontSize: 15),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.customer.name,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                ),
                if (widget.customer.phone != null && widget.customer.phone!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.phone_outlined, size: 13, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        widget.customer.phone!,
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (widget.customer.phone != null && widget.customer.phone!.isNotEmpty)
            IconButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: widget.customer.phone!));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Copied phone number ${widget.customer.phone!} to clipboard'),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.divider),
                ),
                child: const Icon(Icons.phone, size: 16, color: AppColors.primary),
              ),
              tooltip: 'Copy Phone Number',
            ),
          IconButton(
            onPressed: _shareStatement,
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFDCFCE7),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF86EFAC)),
              ),
              child: const Icon(Icons.send_rounded, size: 16, color: Color(0xFF16A34A)),
            ),
            tooltip: 'Share WhatsApp Statement',
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryKpiCard(CustomerLedgerData data, AppLanguage lang) {
    final isNetDr = data.netBalance >= Decimal.zero;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Banner Top: Title & Date Range
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFFF1F5F9),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(11),
                topRight: Radius.circular(11),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.receipt_long, size: 15, color: Color(0xFF475569)),
                    const SizedBox(width: 6),
                    Text(
                      lang == AppLanguage.hi ? 'लेन-देन इतिहास (Transactions)' : 'Transactions History',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
                    ),
                  ],
                ),
                Text(
                  data.dateRangeString,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          // 2-Column Split: Totals (Left) vs Net Balance (Right)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                // Left Column: Total Debit & Total Credit
                Expanded(
                  flex: 5,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            lang == AppLanguage.hi ? 'कुल दिया (-): ' : 'Total Debit(-): ',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                          ),
                          Text(
                            '₹${data.totalDebit.toStringAsFixed(1)}',
                            style: const TextStyle(
                              fontFamily: 'Manrope',
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text(
                            lang == AppLanguage.hi ? 'कुल मिला (+): ' : 'Total Credit(+): ',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                          ),
                          Text(
                            '₹${data.totalCredit.toStringAsFixed(1)}',
                            style: const TextStyle(
                              fontFamily: 'Manrope',
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Vertical Divider
                Container(
                  height: 44,
                  width: 1,
                  color: const Color(0xFFE2E8F0),
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                ),
                // Right Column: Net Balance
                Expanded(
                  flex: 5,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        lang == AppLanguage.hi ? 'नेट बकाया (Net Balance)' : 'Net Balance',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '₹${data.netBalance.abs().toStringAsFixed(1)} ${isNetDr ? "Dr" : "Cr"}',
                        style: TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: isNetDr ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                          letterSpacing: -0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader(AppLanguage lang) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF1F5F9),
        border: Border.symmetric(
          horizontal: BorderSide(color: Color(0xFFCBD5E1), width: 1),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text(
              lang == AppLanguage.hi ? 'तारीख (Date)' : 'Date',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF334155)),
            ),
          ),
          Expanded(
            flex: 3,
            child: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 6),
              child: Text(
                lang == AppLanguage.hi ? 'Debit(-)' : 'Debit(-)',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFFDC2626)),
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 6),
              child: Text(
                lang == AppLanguage.hi ? 'Credit(+)' : 'Credit(+)',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF16A34A)),
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Container(
              alignment: Alignment.centerRight,
              child: Text(
                lang == AppLanguage.hi ? 'बैलेंस (Bal)' : 'Balance',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF334155)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLedgerRow(LedgerEntry entry, AppLanguage lang) {
    final isDr = entry.runningBalance >= Decimal.zero;
    final dateObj = DateTime.fromMillisecondsSinceEpoch(entry.timestamp);
    final formattedDate = DateFormat('dd MMM').format(dateObj);
    final formattedTime = DateFormat('hh:mm a').format(dateObj);

    return InkWell(
      onTap: () => _showEntryDetail(entry),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(
            bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Date & Description Column
            Expanded(
              flex: 4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (entry.isLatest)
                    Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDC2626),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'Latest',
                        style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800),
                      ),
                    ),
                  Text(
                    formattedDate,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
                  ),
                  Text(
                    formattedTime,
                    style: const TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      if (entry.debitAmount > Decimal.zero)
                        const Padding(
                          padding: EdgeInsets.only(right: 3),
                          child: Icon(Icons.receipt_outlined, size: 12, color: Color(0xFF64748B)),
                        ),
                      Expanded(
                        child: Text(
                          entry.subtitle.isNotEmpty ? entry.subtitle : entry.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11, color: Color(0xFF475569)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // 2. Debit(-) Column (Light pink/red cell)
            Expanded(
              flex: 3,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                decoration: BoxDecoration(
                  color: entry.debitAmount > Decimal.zero ? const Color(0xFFFFF5F5) : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                ),
                alignment: Alignment.centerRight,
                child: Text(
                  entry.debitAmount > Decimal.zero ? '₹${entry.debitAmount.toStringAsFixed(1)}' : '-',
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 13,
                    fontWeight: entry.debitAmount > Decimal.zero ? FontWeight.w800 : FontWeight.normal,
                    color: entry.debitAmount > Decimal.zero ? const Color(0xFFDC2626) : const Color(0xFF94A3B8),
                  ),
                ),
              ),
            ),

            // 3. Credit(+) Column (Light green cell)
            Expanded(
              flex: 3,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                decoration: BoxDecoration(
                  color: entry.creditAmount > Decimal.zero ? const Color(0xFFF0FDF4) : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                ),
                alignment: Alignment.centerRight,
                child: Text(
                  entry.creditAmount > Decimal.zero ? '₹${entry.creditAmount.toStringAsFixed(1)}' : '-',
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 13,
                    fontWeight: entry.creditAmount > Decimal.zero ? FontWeight.w800 : FontWeight.normal,
                    color: entry.creditAmount > Decimal.zero ? const Color(0xFF16A34A) : const Color(0xFF94A3B8),
                  ),
                ),
              ),
            ),

            // 4. Balance Column
            Expanded(
              flex: 3,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                alignment: Alignment.centerRight,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '₹${entry.runningBalance.abs().toStringAsFixed(1)}',
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: isDr ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                      ),
                    ),
                    Text(
                      isDr ? 'Dr' : 'Cr',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: isDr ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                      ),
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
}


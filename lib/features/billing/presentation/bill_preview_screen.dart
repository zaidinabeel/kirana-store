import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/i18n/app_strings.dart';
import '../../../core/printing/printer_service.dart';
import '../../../core/db/app_database.dart';
import '../../../shared/widgets/app_header.dart';
import '../../inventory/domain/product_model.dart';
import 'widgets/receipt_widget.dart';

class BillPreviewScreen extends ConsumerStatefulWidget {
  final Invoice invoice;

  const BillPreviewScreen({
    super.key,
    required this.invoice,
  });

  @override
  ConsumerState<BillPreviewScreen> createState() => _BillPreviewScreenState();
}

class _BillPreviewScreenState extends ConsumerState<BillPreviewScreen> {
  final GlobalKey _receiptKey = GlobalKey();
  List<InvoiceItem> _items = [];
  Customer? _customer;
  bool _isLoading = true;
  bool _isVoided = false;
  bool _isReceiptHindi = false;

  @override
  void initState() {
    super.initState();
    _isVoided = widget.invoice.status == 'void';
    _loadInvoiceDetails();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _isReceiptHindi = ref.watch(localeProvider) == AppLanguage.hi;
  }

  Future<void> _loadInvoiceDetails() async {
    final db = ref.read(databaseProvider);
    final items = await (db.select(db.invoiceItems)..where((it) => it.invoiceId.equals(widget.invoice.id))).get();

    Customer? customer;
    if (widget.invoice.customerId != null) {
      customer = await (db.select(db.customers)..where((c) => c.id.equals(widget.invoice.customerId!))).getSingleOrNull();
    }

    setState(() {
      _items = items;
      _customer = customer;
      _isLoading = false;
    });
  }

  Future<void> _printReceipt() async {
    final printerService = ref.read(printerProvider.notifier);
    final success = await printerService.printReceiptBitmap(repaintKey: _receiptKey);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success ? 'Receipt sent to thermal printer successfully!' : 'Printer error. Check connection in Settings.',
          ),
          backgroundColor: success ? AppColors.success : AppColors.alert,
        ),
      );
    }
  }

  Future<void> _shareBill() async {
    final text = _isReceiptHindi
        ? '''
🧾 *गुप्ता किराना स्टोर - रसीद*
बिल नं: #${widget.invoice.invoiceNo} (${widget.invoice.financialYear})
प्रकार: ${widget.invoice.invoiceType == 'gst' ? "जीएसटी इनवॉइस" : "कैश मेमो"}
कुल राशि: ₹${widget.invoice.total.toStringAsFixed(2)}
भुगतान: ${widget.invoice.paymentMode.toUpperCase()}
जमा राशि: ₹${widget.invoice.amountPaid.toStringAsFixed(2)}
${widget.invoice.amountDue > 0 ? "बकाया (उधार): ₹${widget.invoice.amountDue.toStringAsFixed(2)}" : ""}
धन्यवाद! फिर पधारें | गुप्ता किराना स्टोर
'''
        : '''
🧾 *Gupta Kirana Store - Bill Receipt*
Invoice: #${widget.invoice.invoiceNo} (${widget.invoice.financialYear})
Type: ${widget.invoice.invoiceType.toUpperCase()}
Total Amount: ₹${widget.invoice.total.toStringAsFixed(2)}
Payment Mode: ${widget.invoice.paymentMode.toUpperCase()}
Amount Paid: ₹${widget.invoice.amountPaid.toStringAsFixed(2)}
${widget.invoice.amountDue > 0 ? "Due (Khata): ₹${widget.invoice.amountDue.toStringAsFixed(2)}" : ""}
Thank You! Visit Again | Gupta Kirana
''';

    await Share.share(text, subject: 'Bill #${widget.invoice.invoiceNo}');
  }

  Future<void> _showVoidConfirmation() async {
    final lang = ref.read(localeProvider);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          AppStrings.voidBill(lang),
          style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.alert),
        ),
        content: Text(AppStrings.voidConfirm(lang)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppStrings.cancel(lang), style: const TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.alert),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(AppStrings.voidBill(lang), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final db = ref.read(databaseProvider);
      await db.voidInvoiceTransaction(widget.invoice.id);
      setState(() => _isVoided = true);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invoice voided! Stock & Ledger reversed successfully.'),
            backgroundColor: AppColors.alert,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(localeProvider);
    final printerState = ref.watch(printerProvider);

    return Scaffold(
      appBar: AppHeader(
        title: '${AppStrings.receiptPreview(lang)} #${widget.invoice.invoiceNo}',
        showBackButton: true,
        actions: [
          if (!_isVoided)
            IconButton(
              icon: const Icon(Icons.cancel_outlined, color: Colors.white70),
              tooltip: 'Void Bill',
              onPressed: _showVoidConfirmation,
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(top: BorderSide(color: AppColors.divider)),
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: _shareBill,
                  icon: const Icon(Icons.share_rounded, size: 20),
                  label: Text(AppStrings.sharePdf(lang), style: const TextStyle(fontSize: 14)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: printerState.isPrinting ? null : _printReceipt,
                  icon: printerState.isPrinting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.print_rounded, size: 22),
                  label: Text(
                    printerState.isPrinting ? 'Printing...' : AppStrings.printReceipt(lang),
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Center(
                child: Column(
                  children: [
                    // Receipt Language Switch (English vs हिन्दी)
                    Container(
                      padding: const EdgeInsets.all(4),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceMuted,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.divider),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _langTab(
                            label: 'English Bill',
                            isSelected: !_isReceiptHindi,
                            onTap: () => setState(() => _isReceiptHindi = false),
                          ),
                          _langTab(
                            label: 'हिन्दी रसीद (Hindi)',
                            isSelected: _isReceiptHindi,
                            onTap: () => setState(() => _isReceiptHindi = true),
                          ),
                        ],
                      ),
                    ),

                    if (_isVoided) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: AppColors.alertLight,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.alert),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.warning_amber_rounded, color: AppColors.alert),
                            SizedBox(width: 8),
                            Text(
                              'THIS INVOICE HAS BEEN VOIDED',
                              style: TextStyle(
                                color: AppColors.alert,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Thermal Receipt Wrapped in RepaintBoundary for Bitmap Printing
                    RepaintBoundary(
                      key: _receiptKey,
                      child: ReceiptWidget(
                        invoice: widget.invoice,
                        items: _items,
                        customer: _customer,
                        paperWidth: printerState.paperWidth,
                        isHindi: _isReceiptHindi,
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _langTab({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Manrope',
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: isSelected ? Colors.white : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

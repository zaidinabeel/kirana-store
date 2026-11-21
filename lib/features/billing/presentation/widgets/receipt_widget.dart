import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:barcode_widget/barcode_widget.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/printing/printer_service.dart';
import '../../../../core/db/app_database.dart';
import '../../../../core/settings/shop_profile.dart';

class ReceiptWidget extends StatelessWidget {
  final Invoice invoice;
  final List<InvoiceItem> items;
  final Customer? customer;
  final ShopProfile shop;
  final PaperWidth paperWidth;
  final bool isHindi;

  const ReceiptWidget({
    super.key,
    required this.invoice,
    required this.items,
    this.customer,
    required this.shop,
    this.paperWidth = PaperWidth.mm58,
    this.isHindi = false,
  });

  @override
  Widget build(BuildContext context) {
    final isGst = invoice.invoiceType == 'gst';
    final dateStr = DateFormat('dd-MM-yyyy hh:mm a').format(
      DateTime.fromMillisecondsSinceEpoch(invoice.createdAt),
    );
    final width = paperWidth.pixelWidth;

    final displayShopName = shop.displayName(isHindi);
    final opts = shop.receipt;
    final displayAddress = opts.showAddress ? shop.displayAddress(isHindi) : '';
    final displayFooter = opts.showFooter ? shop.displayFooter(isHindi) : '';

    String memoTitle;
    if (isGst) {
      memoTitle = isHindi ? 'जीएसटी टैक्स इनवॉइस' : 'TAX INVOICE';
    } else {
      memoTitle = isHindi ? 'नकद रसीद (कैश मेमो)' : 'RETAIL CASH MEMO';
    }

    String paymentModeLabel;
    switch (invoice.paymentMode.toLowerCase()) {
      case 'cash':
        paymentModeLabel = isHindi ? 'नकद (CASH)' : 'CASH';
        break;
      case 'upi':
        paymentModeLabel = isHindi ? 'यूपीआई (UPI)' : 'UPI';
        break;
      case 'card':
        paymentModeLabel = isHindi ? 'कार्ड (CARD)' : 'CARD';
        break;
      case 'credit':
        paymentModeLabel = isHindi ? 'उधार खाता (KHATA)' : 'CREDIT (KHATA)';
        break;
      case 'split':
        paymentModeLabel = isHindi ? 'मिक्स / स्प्लिट (SPLIT)' : 'SPLIT';
        break;
      default:
        paymentModeLabel = invoice.paymentMode.toUpperCase();
    }

    return Container(
      width: width,
      // Thermal paper already has side margins, so keep padding small for 58mm.
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.thermalPaper,
        border: Border.all(color: AppColors.divider, width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header: Shop Name
          Text(
            displayShopName,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Manrope',
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: AppColors.thermalText,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 3),
          if (displayAddress.isNotEmpty)
            Text(
              displayAddress,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.thermalText,
                height: 1.2,
              ),
            ),
          if (opts.showPhone && shop.phone.isNotEmpty)
            Text(
              '${isHindi ? "फोन" : "Ph"}: ${shop.phone}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.thermalText,
              ),
            ),
          if (isGst && opts.showGstin && shop.gstin.isNotEmpty) ...[
            Text(
              'GSTIN: ${shop.gstin}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.thermalText,
              ),
            ),
          ],

          const SizedBox(height: 8),
          _dashedDivider(),
          const SizedBox(height: 4),

          // Bill Metadata Header
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.thermalText, width: 0.8),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                memoTitle,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppColors.thermalText,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 8,
            children: [
              Text(
                '${isHindi ? "बिल नं" : "Inv"}: #${invoice.invoiceNo} (${invoice.financialYear})',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
              ),
              Text(
                dateStr,
                style: const TextStyle(fontSize: 10, color: AppColors.thermalText),
              ),
            ],
          ),
          if (opts.showCustomer && customer != null) ...[
            const SizedBox(height: 3),
            Text(
              '${isHindi ? "ग्राहक" : "Customer"}: ${customer!.name} ${customer!.phone != null ? "(${customer!.phone})" : ""}',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ],

          const SizedBox(height: 6),
          _dashedDivider(),
          const SizedBox(height: 4),

          // Table Columns Header
          Row(
            children: [
              Expanded(
                flex: 5,
                child: Text(
                  isHindi ? 'सामान (Item)' : 'Item',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  isHindi ? 'मात्रा' : 'Qty',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  isHindi ? 'दर' : 'Rate',
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  isHindi ? 'कुल' : 'Amount',
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          _solidDivider(),
          const SizedBox(height: 4),

          // Line Items
          ...items.map((item) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2.5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 5,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.nameSnapshot,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, height: 1.15),
                        ),
                        if (isGst && opts.showTaxDetails && item.hsnSnapshot != null && item.hsnSnapshot!.isNotEmpty)
                          Text(
                            'HSN:${item.hsnSnapshot} GST:${item.gstRateSnapshot.toStringAsFixed(0)}%',
                            style: const TextStyle(fontSize: 9, color: AppColors.textSecondary),
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      '${item.qty % 1 == 0 ? item.qty.toInt() : item.qty.toStringAsFixed(2)}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      item.rate.toStringAsFixed(1),
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      '₹${item.lineTotal.toStringAsFixed(2)}',
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            );
          }),

          const SizedBox(height: 6),
          _dashedDivider(),
          const SizedBox(height: 4),

          // Subtotal & Discount
          _summaryRow(
            isHindi ? 'उप-योग (Subtotal):' : 'Subtotal:',
            '₹${invoice.subtotal.toStringAsFixed(2)}',
          ),
          if (invoice.discount > 0)
            _summaryRow(
              isHindi ? 'छूट (Discount):' : 'Discount:',
              '-₹${invoice.discount.toStringAsFixed(2)}',
            ),

          // GST breakdown if applicable
          if (isGst && opts.showTaxDetails && (invoice.cgst > 0 || invoice.sgst > 0 || invoice.igst > 0)) ...[
            if (invoice.cgst > 0) _summaryRow('CGST (केंद्रीय कर):', '₹${invoice.cgst.toStringAsFixed(2)}'),
            if (invoice.sgst > 0) _summaryRow('SGST (राज्य कर):', '₹${invoice.sgst.toStringAsFixed(2)}'),
            if (invoice.igst > 0) _summaryRow('IGST (एकीकृत कर):', '₹${invoice.igst.toStringAsFixed(2)}'),
          ],

          if (invoice.roundOff != 0)
            _summaryRow(
              isHindi ? 'राउंड ऑफ:' : 'Round Off:',
              '${invoice.roundOff >= 0 ? "+" : ""}₹${invoice.roundOff.toStringAsFixed(2)}',
            ),

          const SizedBox(height: 4),
          _solidDivider(),
          const SizedBox(height: 4),

          // Grand Total
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  isHindi ? 'कुल देय राशि (TOTAL):' : 'TOTAL PAYABLE:',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: AppColors.thermalText,
                  ),
                ),
              ),
              Text(
                '₹${invoice.total.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: AppColors.thermalText,
                ),
              ),
            ],
          ),

          const SizedBox(height: 4),
          _solidDivider(),
          const SizedBox(height: 4),

          // Payment details
          if (opts.showPaymentDetails) ...[
            _summaryRow(isHindi ? 'भुगतान माध्यम:' : 'Payment Mode:', paymentModeLabel),
            _summaryRow(isHindi ? 'जमा राशि:' : 'Amount Paid:', '₹${invoice.amountPaid.toStringAsFixed(2)}'),
          ],
          if (invoice.amountDue > 0)
            _summaryRow(
              isHindi ? 'बकाया (उधार खाता):' : 'Due (Khata):',
              '₹${invoice.amountDue.toStringAsFixed(2)}',
              isBold: true,
            ),

          const SizedBox(height: 10),

          if (opts.showBarcode) ...[
            // Barcode for receipt tracking
            Center(
              child: SizedBox(
                height: 36,
                width: 160,
                child: BarcodeWidget(
                  barcode: Barcode.code128(),
                  data: 'INV-${invoice.financialYear}-${invoice.invoiceNo}',
                  drawText: false,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'INV-${invoice.financialYear}-${invoice.invoiceNo}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 9, letterSpacing: 1.2),
            ),
          ],
          if (displayFooter.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              displayFooter,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isBold ? FontWeight.w800 : FontWeight.w500,
                color: AppColors.thermalText,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
              color: AppColors.thermalText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _dashedDivider() {
    return LayoutBuilder(
      builder: (context, constraints) {
        const dashWidth = 4.0;
        const dashSpace = 3.0;
        final count = (constraints.maxWidth / (dashWidth + dashSpace)).floor();
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(count, (_) {
            return const SizedBox(
              width: dashWidth,
              height: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(color: AppColors.thermalText),
              ),
            );
          }),
        );
      },
    );
  }

  Widget _solidDivider() {
    return const Divider(
      color: AppColors.thermalText,
      thickness: 1,
      height: 1,
    );
  }
}

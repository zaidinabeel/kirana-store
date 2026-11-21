import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/db/app_database.dart';
import '../../../../core/i18n/app_strings.dart';
import '../../../../core/printing/printer_service.dart';
import '../../../../core/settings/shop_profile.dart';
import '../../../billing/presentation/widgets/receipt_widget.dart';

/// Printer card: connect a paired Bluetooth printer, paper size, test print.
class PrinterSection extends ConsumerWidget {
  const PrinterSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hi = ref.watch(localeProvider) == AppLanguage.hi;
    final state = ref.watch(printerProvider);
    final printer = ref.read(printerProvider.notifier);
    final busy = state.status == PrinterConnectionStatus.scanning || state.status == PrinterConnectionStatus.connecting;
    final current = state.connectedDevice ?? state.savedDevice;

    void toast(String? error, String okMsg) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(error ?? okMsg, style: const TextStyle(fontSize: 15)),
        backgroundColor: error == null ? AppColors.success : AppColors.alert,
        duration: Duration(seconds: error == null ? 2 : 5),
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(
              state.connectedDevice != null ? Icons.print_rounded : Icons.print_disabled_rounded,
              color: state.connectedDevice != null ? AppColors.success : AppColors.textSecondary,
              size: 30,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                state.connectedDevice != null
                    ? (hi ? 'जुड़ा है: ${state.connectedDevice!.name}' : 'Connected: ${state.connectedDevice!.name}')
                    : current != null
                        ? (hi ? 'चुना हुआ: ${current.name} (प्रिंट पर अपने आप जुड़ेगा)' : 'Saved: ${current.name} (connects when printing)')
                        : (hi ? 'कोई प्रिंटर नहीं चुना' : 'No printer selected'),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        if (state.errorMessage != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AppColors.alertLight, borderRadius: BorderRadius.circular(8)),
            child: Text(state.errorMessage!, style: const TextStyle(color: AppColors.alert, fontWeight: FontWeight.w700)),
          ),
        ],
        const SizedBox(height: 10),
        SizedBox(
          height: 52,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            onPressed: busy ? null : printer.scanDevices,
            icon: busy
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.bluetooth_searching_rounded),
            label: Text(hi ? 'प्रिंटर खोजें' : 'Find printer', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          hi
              ? 'प्रिंटर सूची में नहीं? पहले फ़ोन की सेटिंग → ब्लूटूथ में प्रिंटर "पेयर" करें (PIN अक्सर 0000 या 1234)।'
              : 'Not listed? Pair the printer first in phone Settings → Bluetooth (PIN is usually 0000 or 1234).',
          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        for (final d in state.availableDevices)
          Card(
            margin: const EdgeInsets.only(top: 8),
            child: ListTile(
              leading: const Icon(Icons.print_outlined, size: 28),
              title: Text(d.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              subtitle: Text(d.address),
              trailing: state.connectedDevice?.address == d.address
                  ? const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 28)
                  : Text(hi ? 'चुनें' : 'Select', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800)),
              onTap: () async {
                final ok = await printer.connect(d);
                if (context.mounted) toast(ok ? null : ref.read(printerProvider).errorMessage, hi ? '✓ प्रिंटर जुड़ गया' : '✓ Printer connected');
              },
            ),
          ),
        const Divider(height: 28),
        Text(hi ? 'कागज़ का साइज़' : 'Paper size', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        SegmentedButton<PaperWidth>(
          segments: [
            ButtonSegment(value: PaperWidth.mm58, label: Text(hi ? '58mm (छोटा)' : '58mm (small)')),
            ButtonSegment(value: PaperWidth.mm80, label: Text(hi ? '80mm (बड़ा)' : '80mm (wide)')),
          ],
          selected: {state.paperWidth},
          onSelectionChanged: (set) => ref.read(shopProfileProvider.notifier).setPaperWidth(set.first),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(minimumSize: const Size(0, 50)),
          onPressed: state.isPrinting
              ? null
              : () async {
                  final shop = ref.read(shopProfileProvider).valueOrNull ?? ShopProfile.empty;
                  final error = await printer.printTestPage(shop.displayName(false));
                  if (context.mounted) toast(error, hi ? '✓ टेस्ट प्रिंट भेजा' : '✓ Test print sent');
                },
          icon: const Icon(Icons.receipt_long_rounded),
          label: Text(hi ? 'टेस्ट प्रिंट' : 'Test print', style: const TextStyle(fontSize: 15)),
        ),
      ],
    );
  }
}

/// Switches for what appears on the receipt, with a live preview underneath.
class ReceiptOptionsSection extends ConsumerWidget {
  const ReceiptOptionsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hi = ref.watch(localeProvider) == AppLanguage.hi;
    final shop = ref.watch(shopProfileProvider).valueOrNull ?? ShopProfile.empty;
    final opts = shop.receipt;
    final notifier = ref.read(shopProfileProvider.notifier);

    Widget toggle(String label, bool value, ReceiptOptions Function(bool) apply, {String? subtitle}) {
      return SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        subtitle: subtitle == null ? null : Text(subtitle),
        value: value,
        onChanged: (v) => notifier.setReceiptOptions(apply(v)),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        toggle(hi ? 'बिल बनते ही अपने आप प्रिंट' : 'Print automatically after each bill', opts.autoPrint,
            (v) => opts.copyWith(autoPrint: v)),
        const Divider(),
        toggle(hi ? 'दुकान का पता' : 'Shop address', opts.showAddress, (v) => opts.copyWith(showAddress: v)),
        toggle(hi ? 'दुकान का फ़ोन' : 'Shop phone', opts.showPhone, (v) => opts.copyWith(showPhone: v)),
        toggle(hi ? 'GST नंबर' : 'GSTIN', opts.showGstin, (v) => opts.copyWith(showGstin: v),
            subtitle: hi ? 'सिर्फ़ GST बिल पर' : 'GST bills only'),
        toggle(hi ? 'ग्राहक का नाम' : 'Customer name', opts.showCustomer, (v) => opts.copyWith(showCustomer: v)),
        toggle(hi ? 'टैक्स (HSN, CGST/SGST)' : 'Tax details (HSN, CGST/SGST)', opts.showTaxDetails,
            (v) => opts.copyWith(showTaxDetails: v)),
        toggle(hi ? 'भुगतान का तरीका व जमा राशि' : 'Payment mode & amount paid', opts.showPaymentDetails,
            (v) => opts.copyWith(showPaymentDetails: v)),
        toggle(hi ? 'बिल का बारकोड' : 'Bill barcode', opts.showBarcode, (v) => opts.copyWith(showBarcode: v)),
        toggle(hi ? 'नीचे धन्यवाद संदेश' : 'Thank-you message', opts.showFooter, (v) => opts.copyWith(showFooter: v)),
        const SizedBox(height: 10),
        Text(hi ? 'रसीद ऐसी दिखेगी:' : 'Preview:', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Center(
          child: DecoratedBox(
            decoration: BoxDecoration(border: Border.all(color: AppColors.divider)),
            child: ReceiptWidget(
              invoice: _sampleInvoice,
              items: _sampleItems,
              customer: _sampleCustomer,
              shop: shop,
              paperWidth: shop.paperWidth,
              isHindi: hi,
            ),
          ),
        ),
      ],
    );
  }
}

final _sampleInvoice = Invoice(
  id: 'sample',
  invoiceNo: 101,
  financialYear: AppDatabase.getCurrentFinancialYear(),
  invoiceType: 'gst',
  subtotal: 140,
  discount: 0,
  cgst: 1.75,
  sgst: 1.75,
  igst: 0,
  roundOff: -0.5,
  total: 143,
  paymentMode: 'cash',
  amountPaid: 143,
  amountDue: 0,
  status: 'active',
  createdAt: DateTime.now().millisecondsSinceEpoch,
);

const _sampleItems = [
  InvoiceItem(
    id: 's1',
    invoiceId: 'sample',
    nameSnapshot: 'Parle-G 100g',
    hsnSnapshot: '1905',
    qty: 4,
    unit: 'piece',
    rate: 10,
    gstRateSnapshot: 5,
    discount: 0,
    lineTotal: 40,
  ),
  InvoiceItem(
    id: 's2',
    invoiceId: 'sample',
    nameSnapshot: 'चीनी (खुली)',
    qty: 2,
    unit: 'kg',
    rate: 50,
    gstRateSnapshot: 0,
    discount: 0,
    lineTotal: 100,
  ),
];

const _sampleCustomer = Customer(id: 'c', name: 'रमेश कुमार', phone: '9810000000', openingBalance: 0, createdAt: 0);

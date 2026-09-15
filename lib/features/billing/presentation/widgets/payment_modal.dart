import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:decimal/decimal.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/i18n/app_strings.dart';
import '../../../../core/money/money_utils.dart';
import '../../../../core/db/app_database.dart';
import '../../../../core/validation/formatters.dart';
import '../../../../shared/widgets/debounced_button.dart';
import '../../../khata/state/khata_notifier.dart';
import '../../state/billing_notifier.dart';

class PaymentModal extends ConsumerStatefulWidget {
  final Decimal grandTotal;
  final Function({
    required String paymentMode,
    required Decimal amountPaid,
    required Decimal amountDue,
  }) onConfirmPayment;

  const PaymentModal({
    super.key,
    required this.grandTotal,
    required this.onConfirmPayment,
  });

  @override
  ConsumerState<PaymentModal> createState() => _PaymentModalState();
}

class _PaymentModalState extends ConsumerState<PaymentModal> {
  String _selectedMode = 'cash'; // 'cash'|'upi'|'card'|'credit'|'split'

  // Split amounts controllers
  late TextEditingController _cashController;
  late TextEditingController _upiController;
  late TextEditingController _cardController;
  late TextEditingController _creditController;

  @override
  void initState() {
    super.initState();
    _cashController = TextEditingController(text: widget.grandTotal.toString());
    _upiController = TextEditingController(text: '0');
    _cardController = TextEditingController(text: '0');
    _creditController = TextEditingController(text: '0');
  }

  @override
  void dispose() {
    _cashController.dispose();
    _upiController.dispose();
    _cardController.dispose();
    _creditController.dispose();
    super.dispose();
  }

  void _onModeChanged(String mode) {
    setState(() {
      _selectedMode = mode;
      if (mode == 'cash') {
        _cashController.text = widget.grandTotal.toString();
        _upiController.text = '0';
        _cardController.text = '0';
        _creditController.text = '0';
      } else if (mode == 'upi') {
        _cashController.text = '0';
        _upiController.text = widget.grandTotal.toString();
        _cardController.text = '0';
        _creditController.text = '0';
      } else if (mode == 'card') {
        _cashController.text = '0';
        _upiController.text = '0';
        _cardController.text = widget.grandTotal.toString();
        _creditController.text = '0';
      } else if (mode == 'credit') {
        _cashController.text = '0';
        _upiController.text = '0';
        _cardController.text = '0';
        _creditController.text = widget.grandTotal.toString();
      }
    });
  }

  void _showCustomerPicker() {
    final khataState = ref.read(khataProvider);
    final customers = khataState.customers;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(16),
          constraints: const BoxConstraints(maxHeight: 380),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Select Customer for Khata (Credit)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.primary),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.separated(
                  itemCount: customers.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (ctx, i) {
                    final c = customers[i].customer;
                    final balance = customers[i].currentBalance;
                    return ListTile(
                      title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text(c.phone ?? 'No phone', style: const TextStyle(fontSize: 12)),
                      trailing: Text(
                        'Due: ₹${balance.toStringAsFixed(1)}',
                        style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.alert),
                      ),
                      onTap: () {
                        ref.read(billingProvider.notifier).selectCustomer(c);
                        Navigator.pop(ctx);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _submit() {
    final billingState = ref.read(billingProvider);

    Decimal cash = Decimal.tryParse(_cashController.text.trim()) ?? Decimal.zero;
    Decimal upi = Decimal.tryParse(_upiController.text.trim()) ?? Decimal.zero;
    Decimal card = Decimal.tryParse(_cardController.text.trim()) ?? Decimal.zero;
    Decimal credit = Decimal.tryParse(_creditController.text.trim()) ?? Decimal.zero;

    Decimal totalPaid;
    Decimal totalDue;

    if (_selectedMode == 'split') {
      totalPaid = cash + upi + card;
      totalDue = credit;

      if ((totalPaid + totalDue) != widget.grandTotal) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Split amounts (₹${totalPaid + totalDue}) must match bill total (₹${widget.grandTotal})'),
            backgroundColor: AppColors.alert,
          ),
        );
        return;
      }
    } else if (_selectedMode == 'credit') {
      totalPaid = Decimal.zero;
      totalDue = widget.grandTotal;
    } else {
      totalPaid = widget.grandTotal;
      totalDue = Decimal.zero;
    }

    if (totalDue > Decimal.zero && billingState.selectedCustomer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a customer for credit (Udhaar) sales'),
          backgroundColor: AppColors.alert,
        ),
      );
      _showCustomerPicker();
      return;
    }

    widget.onConfirmPayment(
      paymentMode: _selectedMode,
      amountPaid: totalPaid,
      amountDue: totalDue,
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(localeProvider);
    final billingState = ref.watch(billingProvider);
    final selectedCust = billingState.selectedCustomer;

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                AppStrings.paymentMode(lang),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.primary),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),

          // Total Due Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Bill Amount:',
                  style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600),
                ),
                Text(
                  MoneyUtils.formatCurrency(widget.grandTotal),
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Customer selection pill (optional for cash, required for credit)
          InkWell(
            onTap: _showCustomerPicker,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: selectedCust != null ? AppColors.accentLight : AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: selectedCust != null ? AppColors.accent : AppColors.divider,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.person_outline_rounded,
                    color: selectedCust != null ? AppColors.accentHover : AppColors.textSecondary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      selectedCust != null ? '${selectedCust.name} (${selectedCust.phone ?? ""})' : AppStrings.selectCustomer(lang),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: selectedCust != null ? FontWeight.w700 : FontWeight.w500,
                        color: selectedCust != null ? AppColors.textPrimary : AppColors.textSecondary,
                      ),
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios, size: 12, color: AppColors.textSecondary),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Mode Selector Grid
          Row(
            children: [
              _modeCard('cash', AppStrings.cash(lang), Icons.payments_outlined),
              const SizedBox(width: 8),
              _modeCard('upi', AppStrings.upi(lang), Icons.qr_code_2_rounded),
              const SizedBox(width: 8),
              _modeCard('credit', AppStrings.credit(lang), Icons.book_outlined),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _modeCard('card', AppStrings.card(lang), Icons.credit_card_rounded),
              const SizedBox(width: 8),
              _modeCard('split', AppStrings.split(lang), Icons.pie_chart_outline_rounded),
            ],
          ),

          // Split Mode Input Fields
          if (_selectedMode == 'split') ...[
            const SizedBox(height: 16),
            const Text(
              'Enter Split Amounts:',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _cashController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [DecimalInputFormatter(2)],
                    decoration: const InputDecoration(labelText: 'Cash (₹)', isDense: true),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _upiController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [DecimalInputFormatter(2)],
                    decoration: const InputDecoration(labelText: 'UPI (₹)', isDense: true),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _cardController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [DecimalInputFormatter(2)],
                    decoration: const InputDecoration(labelText: 'Card (₹)', isDense: true),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _creditController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [DecimalInputFormatter(2)],
                    decoration: const InputDecoration(labelText: 'Khata Due (₹)', isDense: true),
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 20),

          // Confirm Checkout Action
          DebouncedButton(
            onPressed: () async => _submit(),
            height: 52,
            backgroundColor: AppColors.primary,
            semanticLabel: 'Complete sale button',
            child: Text(
              'Complete Sale (${MoneyUtils.formatCurrency(widget.grandTotal)})',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _modeCard(String modeKey, String label, IconData icon) {
    final isSelected = _selectedMode == modeKey;

    return Expanded(
      child: InkWell(
        onTap: () => _onModeChanged(modeKey),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : AppColors.surfaceMuted,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.divider,
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected ? AppColors.accent : AppColors.primary,
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: isSelected ? Colors.white : AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

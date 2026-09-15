import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:decimal/decimal.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/i18n/app_strings.dart';
import '../../../../core/money/money_utils.dart';
import '../../../../core/db/app_database.dart';
import '../../../../core/validation/formatters.dart';
import '../../../../core/validation/validators.dart';
import '../../../../shared/widgets/debounced_button.dart';
import '../../state/khata_notifier.dart';

class CollectPaymentModal extends ConsumerStatefulWidget {
  final Customer customer;
  final Decimal currentDue;
  final VoidCallback onPaymentRecorded;

  const CollectPaymentModal({
    super.key,
    required this.customer,
    required this.currentDue,
    required this.onPaymentRecorded,
  });

  @override
  ConsumerState<CollectPaymentModal> createState() => _CollectPaymentModalState();
}

class _CollectPaymentModalState extends ConsumerState<CollectPaymentModal> {
  late TextEditingController _amountController;
  late TextEditingController _noteController;
  String _mode = 'cash'; // 'cash' | 'upi'

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.currentDue > Decimal.zero ? widget.currentDue.toString() : '',
    );
    _noteController = TextEditingController();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final amountStr = _amountController.text.trim();
    final err = Validators.price(amountStr, isRequired: true, fieldName: 'Amount');
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err), backgroundColor: AppColors.alert),
      );
      return;
    }

    final parsedAmount = Decimal.tryParse(amountStr) ?? Decimal.zero;

    await ref.read(khataProvider.notifier).collectPayment(
      customerId: widget.customer.id,
      amount: parsedAmount,
      mode: _mode,
      note: _noteController.text.trim().isNotEmpty ? _noteController.text.trim() : null,
    );

    widget.onPaymentRecorded();
    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Received ₹${parsedAmount.toStringAsFixed(2)} from ${widget.customer.name}!'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(localeProvider);
    final enteredAmount = Decimal.tryParse(_amountController.text.trim()) ?? Decimal.zero;
    final isOverpayment = widget.currentDue > Decimal.zero && enteredAmount > widget.currentDue;

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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                AppStrings.collectPayment(lang),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.primary),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          Text(
            'Customer: ${widget.customer.name}',
            style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),

          // Current balance reminder
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.alertLight,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.alert.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Outstanding Balance:', style: TextStyle(fontSize: 13, color: AppColors.alert, fontWeight: FontWeight.w700)),
                Text(
                  MoneyUtils.formatCurrency(widget.currentDue),
                  style: const TextStyle(fontFamily: 'Manrope', fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.alert),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Amount Field
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [DecimalInputFormatter(2)],
            onChanged: (val) => setState(() {}),
            style: const TextStyle(fontFamily: 'Manrope', fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.primary),
            decoration: InputDecoration(
              labelText: AppStrings.enterAmount(lang),
              prefixText: '₹ ',
              prefixStyle: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.primary),
            ),
          ),
          if (isOverpayment) ...[
            const SizedBox(height: 4),
            Text(
              'Note: Amount exceeds outstanding balance by ₹${(enteredAmount - widget.currentDue).toStringAsFixed(2)} (Advance)',
              style: const TextStyle(fontSize: 11, color: AppColors.accentHover, fontWeight: FontWeight.w600),
            ),
          ],
          const SizedBox(height: 10),

          // Quick Amount Pills
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                if (widget.currentDue > Decimal.zero)
                  _quickPill('Full Due', widget.currentDue.toString()),
                _quickPill('+₹100', '100'),
                _quickPill('+₹500', '500'),
                _quickPill('+₹1000', '1000'),
                _quickPill('+₹2000', '2000'),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Mode Selector (Cash vs UPI)
          Row(
            children: [
              Expanded(
                child: _modeTile(
                  label: AppStrings.cash(lang),
                  icon: Icons.payments_outlined,
                  isSelected: _mode == 'cash',
                  onTap: () => setState(() => _mode = 'cash'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _modeTile(
                  label: AppStrings.upi(lang),
                  icon: Icons.qr_code_rounded,
                  isSelected: _mode == 'upi',
                  onTap: () => setState(() => _mode = 'upi'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Note Field
          TextField(
            controller: _noteController,
            maxLength: 100,
            decoration: const InputDecoration(
              labelText: 'Note / Reference (Optional)',
              hintText: 'e.g. Paid via PhonePe / cash hand-over',
              counterText: '',
              isDense: true,
            ),
          ),
          const SizedBox(height: 18),

          // Submit Button
          DebouncedButton(
            onPressed: _submit,
            height: 52,
            backgroundColor: AppColors.success,
            semanticLabel: 'Record payment button',
            child: const Text(
              'Record Payment Received',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickPill(String label, String amount) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ActionChip(
        backgroundColor: AppColors.surfaceMuted,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
        label: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary)),
        onPressed: () {
          setState(() {
            _amountController.text = amount;
          });
        },
      ),
    );
  }

  Widget _modeTile({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? AppColors.primary : AppColors.divider),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: isSelected ? Colors.white : AppColors.primary),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: isSelected ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

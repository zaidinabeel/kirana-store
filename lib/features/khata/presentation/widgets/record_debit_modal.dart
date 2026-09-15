import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:decimal/decimal.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/i18n/app_strings.dart';
import '../../../../core/money/money_utils.dart';
import '../../../../core/db/app_database.dart';
import '../../../../core/validation/formatters.dart';
import '../../../../core/validation/validators.dart';
import '../../../../shared/widgets/debounced_button.dart';
import '../../state/khata_notifier.dart';

class RecordDebitModal extends ConsumerStatefulWidget {
  final Customer customer;
  final Decimal currentDue;
  final VoidCallback onDebitRecorded;

  const RecordDebitModal({
    super.key,
    required this.customer,
    required this.currentDue,
    required this.onDebitRecorded,
  });

  @override
  ConsumerState<RecordDebitModal> createState() => _RecordDebitModalState();
}

class _RecordDebitModalState extends ConsumerState<RecordDebitModal> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  DateTime _selectedDate = DateTime.now();

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final amountStr = _amountController.text.trim();
    final parsedAmount = Decimal.tryParse(amountStr) ?? Decimal.zero;
    final note = _noteController.text.trim();

    await ref.read(khataProvider.notifier).recordDebit(
      customerId: widget.customer.id,
      amount: parsedAmount,
      note: note.isNotEmpty ? note : 'Khata Debit / Udhaar',
      date: _selectedDate,
    );

    widget.onDebitRecorded();
    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added ₹${parsedAmount.toStringAsFixed(2)} debit for ${widget.customer.name}!'),
          backgroundColor: AppColors.alert,
        ),
      );
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(localeProvider);
    final isHi = lang == AppLanguage.hi;

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
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.alertLight,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(Icons.arrow_upward_rounded, color: AppColors.alert, size: 20),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isHi ? 'उधार सामान / राशि जोड़ें (Debit)' : 'You Gave ₹ / Credit Bill (Debit)',
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.alert),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            Text(
              '${isHi ? "ग्राहक" : "Customer"}: ${widget.customer.name}',
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),

            // Amount Field
            TextFormField(
              controller: _amountController,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [DecimalInputFormatter(2)],
              style: const TextStyle(fontFamily: 'Manrope', fontSize: 26, fontWeight: FontWeight.w900, color: AppColors.alert),
              decoration: InputDecoration(
                labelText: isHi ? 'उधार राशि दर्ज करें *' : 'Enter Debit Amount (₹) *',
                labelStyle: const TextStyle(color: AppColors.alert, fontWeight: FontWeight.w700),
                prefixText: '₹ ',
                prefixStyle: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: AppColors.alert),
              ),
              validator: (v) => Validators.price(v, isRequired: true, fieldName: 'Debit Amount'),
            ),
            const SizedBox(height: 10),

            // Quick Amount Pills
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _quickPill('+₹50', '50'),
                  _quickPill('+₹100', '100'),
                  _quickPill('+₹200', '200'),
                  _quickPill('+₹500', '500'),
                  _quickPill('+₹1000', '1000'),
                  _quickPill('+₹2000', '2000'),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Note / Description Field
            TextFormField(
              controller: _noteController,
              maxLength: 100,
              decoration: InputDecoration(
                labelText: isHi ? 'सामान का विवरण / नोट (उदा. अंडा, ब्रेड, आटा)' : 'Item Details / Description (e.g. Eggs, Milk, Sugar)',
                hintText: isHi ? 'सामान या विवरण दर्ज करें' : 'e.g. 5kg Sugar + 1 Packet Tea',
                counterText: '',
                isDense: true,
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return isHi ? 'कृपया विवरण दर्ज करें' : 'Please enter item details or note';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),

            // Date Picker Row
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.calendar_today_rounded, size: 16, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Text(
                          DateFormat('dd MMMM yyyy').format(_selectedDate),
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                        ),
                      ],
                    ),
                    Text(
                      isHi ? 'तिथि बदलें' : 'Change Date',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Save Debit Button
            DebouncedButton(
              onPressed: _submit,
              height: 52,
              backgroundColor: AppColors.alert,
              semanticLabel: 'Record debit entry button',
              child: Text(
                isHi ? 'उधार जोड़ें (Save Debit)' : 'Save Debit Entry',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _quickPill(String label, String amount) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ActionChip(
        backgroundColor: AppColors.alertLight,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
        label: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.alert)),
        onPressed: () {
          setState(() {
            _amountController.text = amount;
          });
        },
      ),
    );
  }
}

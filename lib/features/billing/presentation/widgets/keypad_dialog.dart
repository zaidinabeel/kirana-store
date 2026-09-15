import 'package:flutter/material.dart';
import 'package:decimal/decimal.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/money/money_utils.dart';
import '../../../../shared/widgets/custom_keypad.dart';
import '../../domain/cart_item.dart';

class KeypadDialog extends StatefulWidget {
  final CartItem item;
  final ValueChanged<Decimal> onQuantityConfirmed;
  final ValueChanged<Decimal> onRupeeAmountConfirmed;

  const KeypadDialog({
    super.key,
    required this.item,
    required this.onQuantityConfirmed,
    required this.onRupeeAmountConfirmed,
  });

  @override
  State<KeypadDialog> createState() => _KeypadDialogState();
}

class _KeypadDialogState extends State<KeypadDialog> {
  bool _isRupeeMode = false;
  String _inputBuffer = '';

  @override
  void initState() {
    super.initState();
    _inputBuffer = widget.item.qty.toString();
  }

  void _onKeyPress(String key) {
    setState(() {
      if (key == '.') {
        // Disallow decimal point for packed items in quantity mode
        if (!widget.item.isLoose && !_isRupeeMode) return;
        if (!_inputBuffer.contains('.')) {
          _inputBuffer = _inputBuffer.isEmpty ? '0.' : '$_inputBuffer.';
        }
      } else {
        if (_inputBuffer.contains('.')) {
          final parts = _inputBuffer.split('.');
          final maxDecimals = _isRupeeMode ? 2 : 3;
          if (parts.length > 1 && parts[1].length >= maxDecimals) {
            return; // Reject extra decimal digits
          }
        }
        if (_inputBuffer == '0') {
          _inputBuffer = key;
        } else {
          final next = '$_inputBuffer$key';
          final numVal = double.tryParse(next);
          if (numVal != null && numVal <= 999999) {
            _inputBuffer = next;
          }
        }
      }
    });
  }

  void _onBackspace() {
    setState(() {
      if (_inputBuffer.isNotEmpty) {
        _inputBuffer = _inputBuffer.substring(0, _inputBuffer.length - 1);
      }
    });
  }

  void _onClear() {
    setState(() {
      _inputBuffer = '';
    });
  }

  void _onQuickAdd(int val) {
    final current = Decimal.tryParse(_inputBuffer.isEmpty ? '0' : _inputBuffer) ?? Decimal.zero;
    final updated = current + Decimal.fromInt(val);
    if (updated <= Decimal.fromInt(999999)) {
      setState(() {
        _inputBuffer = updated.toString();
      });
    }
  }

  void _onDone() {
    final parsed = Decimal.tryParse(_inputBuffer) ?? Decimal.zero;
    if (parsed <= Decimal.zero) {
      Navigator.of(context).pop();
      return;
    }
    if (_isRupeeMode) {
      widget.onRupeeAmountConfirmed(parsed);
    } else {
      widget.onQuantityConfirmed(parsed);
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final rate = widget.item.rate;
    final parsedVal = Decimal.tryParse(_inputBuffer.isEmpty ? '0' : _inputBuffer) ?? Decimal.zero;

    Decimal previewQty;
    Decimal previewAmount;

    if (_isRupeeMode) {
      previewAmount = parsedVal;
      previewQty = MoneyUtils.calculateReverseQuantity(
        targetRupeeAmount: parsedVal,
        pricePerUnit: rate,
      );
    } else {
      previewQty = parsedVal;
      previewAmount = parsedVal * rate;
    }

    return Dialog(
      backgroundColor: AppColors.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      widget.item.nameSnapshotEn,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ),
                  Text(
                    '₹${widget.item.rate}/${widget.item.unit}',
                    style: const TextStyle(color: AppColors.accent, fontSize: 14, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),

            // Mode Selector (Quantity vs Rupee Amount)
            if (widget.item.isLoose) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceMuted,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _modeButton(
                          label: 'By Weight (${widget.item.unit})',
                          isSelected: !_isRupeeMode,
                          onTap: () {
                            setState(() {
                              _isRupeeMode = false;
                              _inputBuffer = widget.item.qty.toString();
                            });
                          },
                        ),
                      ),
                      Expanded(
                        child: _modeButton(
                          label: 'By Rupee (₹ Amount)',
                          isSelected: _isRupeeMode,
                          onTap: () {
                            setState(() {
                              _isRupeeMode = true;
                              _inputBuffer = (widget.item.qty * widget.item.rate).round().toString();
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            // Hero Input Display Area
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          _isRupeeMode ? 'Enter ₹ Amount:' : 'Quantity (${widget.item.unit}):',
                          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                        ),
                        Text(
                          _inputBuffer.isEmpty ? '0' : _inputBuffer,
                          style: const TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 12),
                    // Live Calculation Preview
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _isRupeeMode
                              ? 'Derived Qty: ${MoneyUtils.formatQuantity(previewQty, widget.item.unit)}'
                              : 'Total Price: ₹${previewAmount.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.success,
                          ),
                        ),
                        if (!_isRupeeMode)
                          Text(
                            '₹${rate.toStringAsFixed(1)} × $previewQty',
                            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Large Keypad
            CustomKeypad(
              onKeyPress: _onKeyPress,
              onBackspace: _onBackspace,
              onClear: _onClear,
              showDecimal: widget.item.isLoose || _isRupeeMode,
              quickAddAmounts: _isRupeeMode ? const [10, 20, 50, 100] : const [1, 2, 5, 10],
              onQuickAdd: _onQuickAdd,
            ),

            // Confirmation Action Button
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        foregroundColor: AppColors.textSecondary,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: _onDone,
                      child: const Text(
                        'Set Quantity',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _modeButton({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Manrope',
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: isSelected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
